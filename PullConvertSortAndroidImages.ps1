<#
.SYNOPSIS
    Pulls selected Android image folders, normalizes extensions, converts WEBP to JPG,
    and runs SortAndRenameImagesByColor.ps1.

.REQUIREMENTS
    - PowerShell 7+
    - adb.exe available in PATH
    - IrfanView installed
    - IrfanView plugins recommended, especially for WEBP support
    - Existing script:
      %USERPROFILE%\Desktop\Scripts\SortAndRenameImagesByColor.ps1
#>

[CmdletBinding()]
param(
    [string]$LocalRoot = "D:\Downloads\Pics",
    [string]$UnsortedDir = "D:\Downloads\Pics\unsorted",
    [string]$SortedDir = "D:\Downloads\Pics\sorted",

    [string]$IrfanViewPath = "C:\Program Files\IrfanView\i_view64.exe",

    [string]$ColorSortScript = "$env:USERPROFILE\Desktop\Scripts\SortAndRenameImagesByColor.ps1",

    [int]$JpegQuality = 90,

    [string]$AndroidExcludedMediaDir = "/sdcard/Pictures/.hide/gif",

    [string[]]$ExcludedAndroidExtensions = @(
        "gif",
        "mp4",
        "webm"
    ),

    [switch]$DeleteAndroidSourceAfterPull = $true,
    [switch]$DeleteWebpAfterConversion = $true
)

Clear-Host

# Android source directories to pull.
$AndroidDirectories = @(
    "/sdcard/Pictures/.hide/Reddit",
    "/sdcard/Pictures/.hide/readchan"
)

# Known signatures for restoring correct extensions.
# This replaces the practical effect of IrfanView Batch Rename pattern $N$Q:
# $N = original base name, $Q = detected/correct extension where possible.
$ImageSignatures = @(
    [PSCustomObject]@{
        Extension = ".jpg"
        Match     = {
            param([byte[]]$b)
            $b.Length -ge 3 -and $b[0] -eq 0xFF -and $b[1] -eq 0xD8 -and $b[2] -eq 0xFF
        }
    },
    [PSCustomObject]@{
        Extension = ".png"
        Match     = {
            param([byte[]]$b)
            $b.Length -ge 8 -and
            $b[0] -eq 0x89 -and $b[1] -eq 0x50 -and $b[2] -eq 0x4E -and $b[3] -eq 0x47 -and
            $b[4] -eq 0x0D -and $b[5] -eq 0x0A -and $b[6] -eq 0x1A -and $b[7] -eq 0x0A
        }
    },
    [PSCustomObject]@{
        Extension = ".gif"
        Match     = {
            param([byte[]]$b)
            $b.Length -ge 6 -and
            ([System.Text.Encoding]::ASCII.GetString($b, 0, 6) -in @("GIF87a", "GIF89a"))
        }
    },
    [PSCustomObject]@{
        Extension = ".bmp"
        Match     = {
            param([byte[]]$b)
            $b.Length -ge 2 -and $b[0] -eq 0x42 -and $b[1] -eq 0x4D
        }
    },
    [PSCustomObject]@{
        Extension = ".webp"
        Match     = {
            param([byte[]]$b)
            $b.Length -ge 12 -and
            [System.Text.Encoding]::ASCII.GetString($b, 0, 4) -eq "RIFF" -and
            [System.Text.Encoding]::ASCII.GetString($b, 8, 4) -eq "WEBP"
        }
    }
)

function Write-Section {
    param([string]$Text)

    Write-Host ""
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host $Text -ForegroundColor Cyan
    Write-Host "================================================================================" -ForegroundColor Cyan
}

function Assert-CommandExists {
    param([string]$CommandName)

    if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
        throw "Required command not found in PATH: $CommandName"
    }
}

function Assert-PathExists {
    param(
        [string]$Path,
        [string]$Description
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$Description not found: $Path"
    }
}


function ConvertTo-AdbShellSingleQuoted {
    param([Parameter(Mandatory)][string]$Text)

    # Android shell-safe single quoted string.
    # Example: abc'def -> 'abc'\''def'
    return "'" + ($Text -replace "'", "'\\''") + "'"
}

function Invoke-AdbShellTestDirectory {
    param([Parameter(Mandatory)][string]$AndroidPath)

    $quotedPath = ConvertTo-AdbShellSingleQuoted -Text $AndroidPath
    adb shell "test -d $quotedPath"
    return ($LASTEXITCODE -eq 0)
}

function Invoke-AdbShellTestPath {
    param([Parameter(Mandatory)][string]$AndroidPath)

    $quotedPath = ConvertTo-AdbShellSingleQuoted -Text $AndroidPath
    adb shell "test -e $quotedPath"
    return ($LASTEXITCODE -eq 0)
}

function New-AndroidDirectory {
    param([Parameter(Mandatory)][string]$AndroidPath)

    $quotedPath = ConvertTo-AdbShellSingleQuoted -Text $AndroidPath
    adb shell "mkdir -p $quotedPath"

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create Android directory: $AndroidPath"
    }
}

function Get-AndroidFileName {
    param([Parameter(Mandatory)][string]$AndroidPath)

    return ($AndroidPath -replace '^.*/', '')
}

function Get-AndroidSafeDestinationPath {
    param(
        [Parameter(Mandatory)][string]$DestinationDirectory,
        [Parameter(Mandatory)][string]$FileName
    )

    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
    $extension = [System.IO.Path]::GetExtension($FileName)

    if ([string]::IsNullOrWhiteSpace($baseName)) {
        $baseName = $FileName
        $extension = ""
    }

    $candidate = "$DestinationDirectory/$FileName"
    $counter = 1

    while (Invoke-AdbShellTestPath -AndroidPath $candidate) {
        $candidate = "$DestinationDirectory/$baseName`_$counter$extension"
        $counter++
    }

    return $candidate
}

function Move-ExcludedAndroidMediaToQuarantine {
    param(
        [Parameter(Mandatory)][string[]]$SourceDirectories,
        [Parameter(Mandatory)][string]$DestinationDirectory,
        [Parameter(Mandatory)][string[]]$Extensions
    )

    Write-Section "Moving excluded Android media files to quarantine"

    New-AndroidDirectory -AndroidPath $DestinationDirectory

    $normalizedExtensions = $Extensions |
        ForEach-Object { $_.Trim().TrimStart('.').ToLowerInvariant() } |
        Where-Object { $_ }

    if (-not $normalizedExtensions) {
        Write-Host "No excluded Android extensions configured."
        return
    }

    foreach ($androidDir in $SourceDirectories) {
        Write-Host "Checking source directory for excluded media: $androidDir" -ForegroundColor Yellow

        if (-not (Invoke-AdbShellTestDirectory -AndroidPath $androidDir)) {
            Write-Warning "Android directory does not exist, skipping excluded-media move: $androidDir"
            continue
        }

        $findParts = foreach ($extension in $normalizedExtensions) {
            "-iname '*.$extension'"
        }

        $findExpression = $findParts -join " -o "
        $quotedSource = ConvertTo-AdbShellSingleQuoted -Text $androidDir
        $findCommand = "find $quotedSource -type f \( $findExpression \)"

        $excludedFiles = @(adb shell $findCommand) |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ }

        if (-not $excludedFiles) {
            Write-Host "No excluded media found in: $androidDir"
            continue
        }

        foreach ($sourceFile in $excludedFiles) {
            $fileName = Get-AndroidFileName -AndroidPath $sourceFile
            $destinationFile = Get-AndroidSafeDestinationPath -DestinationDirectory $DestinationDirectory -FileName $fileName

            $quotedSourceFile = ConvertTo-AdbShellSingleQuoted -Text $sourceFile
            $quotedDestinationFile = ConvertTo-AdbShellSingleQuoted -Text $destinationFile

            Write-Host "Moving on Android: $sourceFile -> $destinationFile" -ForegroundColor Yellow
            adb shell "mv $quotedSourceFile $quotedDestinationFile"

            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Failed to move excluded media file on Android: $sourceFile"
            }
        }
    }
}

function Get-SafeDestinationPath {
    param(
        [Parameter(Mandatory)]
        [string]$DestinationDirectory,

        [Parameter(Mandatory)]
        [string]$FileName
    )

    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
    $extension = [System.IO.Path]::GetExtension($FileName)
    $candidate = Join-Path $DestinationDirectory $FileName
    $counter = 1

    while (Test-Path -LiteralPath $candidate) {
        $candidate = Join-Path $DestinationDirectory ("{0}_{1}{2}" -f $baseName, $counter, $extension)
        $counter++
    }

    return $candidate
}

function Get-DetectedImageExtension {
    param([Parameter(Mandatory)][string]$Path)

    try {
        $bytesToRead = [Math]::Min(32, (Get-Item -LiteralPath $Path).Length)

        if ($bytesToRead -le 0) {
            return $null
        }

        $buffer = New-Object byte[] $bytesToRead

        $stream = [System.IO.File]::OpenRead($Path)
        try {
            [void]$stream.Read($buffer, 0, $bytesToRead)
        }
        finally {
            $stream.Dispose()
        }

        foreach ($signature in $ImageSignatures) {
            if (& $signature.Match $buffer) {
                return $signature.Extension
            }
        }

        return $null
    }
    catch {
        Write-Warning "Could not detect image type for '$Path': $($_.Exception.Message)"
        return $null
    }
}

function Restore-CorrectImageExtensions {
    param([Parameter(Mandatory)][string]$Directory)

    Write-Section "Restoring image extensions based on file signatures"

    $files = Get-ChildItem -LiteralPath $Directory -File -Recurse

    foreach ($file in $files) {
        $detectedExtension = Get-DetectedImageExtension -Path $file.FullName

        if (-not $detectedExtension) {
            Write-Host "Skipped, unknown type: $($file.FullName)" -ForegroundColor DarkYellow
            continue
        }

        if ($file.Extension.ToLowerInvariant() -eq $detectedExtension) {
            Write-Host "OK: $($file.Name)"
            continue
        }

        $newName = "$($file.BaseName)$detectedExtension"
        $newPath = Get-SafeDestinationPath -DestinationDirectory $file.DirectoryName -FileName $newName

        Write-Host "Renaming: $($file.Name) -> $(Split-Path $newPath -Leaf)" -ForegroundColor Yellow
        Move-Item -LiteralPath $file.FullName -Destination $newPath
    }
}

function Convert-WebpToJpg {
    param(
        [Parameter(Mandatory)][string]$Directory,
        [Parameter(Mandatory)][string]$IrfanViewExe,
        [Parameter(Mandatory)][int]$Quality,
        [bool]$DeleteSource
    )

    Write-Section "Converting WEBP files to JPG with IrfanView, quality $Quality"

    $webpFiles = Get-ChildItem -LiteralPath $Directory -File -Recurse -Filter "*.webp"

    if (-not $webpFiles) {
        Write-Host "No WEBP files found."
        return
    }

    foreach ($file in $webpFiles) {
        $jpgName = "$($file.BaseName).jpg"
        $jpgPath = Get-SafeDestinationPath -DestinationDirectory $file.DirectoryName -FileName $jpgName

        Write-Host "Converting: $($file.FullName) -> $jpgPath" -ForegroundColor Yellow

        $args = @(
            $file.FullName,
            "/jpgq=$Quality",
            "/convert=$jpgPath"
        )

        $process = Start-Process `
            -FilePath $IrfanViewExe `
            -ArgumentList $args `
            -Wait `
            -PassThru `
            -NoNewWindow

        if ($process.ExitCode -eq 0 -and (Test-Path -LiteralPath $jpgPath)) {
            Write-Host "Converted successfully: $jpgPath" -ForegroundColor Green

            if ($DeleteSource) {
                Remove-Item -LiteralPath $file.FullName -Force
                Write-Host "Deleted source WEBP: $($file.FullName)" -ForegroundColor DarkGray
            }
        }
        else {
            Write-Warning "WEBP conversion may have failed for: $($file.FullName). ExitCode: $($process.ExitCode)"
        }
    }
}

function Remove-EmptyDirectories {
    param([Parameter(Mandatory)][string]$Directory)

    Write-Section "Removing empty local directories"

    Get-ChildItem -LiteralPath $Directory -Directory -Recurse |
    Sort-Object FullName -Descending |
    Where-Object {
        -not (Get-ChildItem -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue)
    } |
    ForEach-Object {
        Write-Host "Removing empty directory: $($_.FullName)" -ForegroundColor DarkGray
        Remove-Item -LiteralPath $_.FullName -Force
    }
}

function Move-FilesToDirectory {
    param(
        [Parameter(Mandatory)][string]$SourceDirectory,
        [Parameter(Mandatory)][string]$DestinationDirectory
    )

    Write-Section "Moving files from '$SourceDirectory' to '$DestinationDirectory'"

    $files = Get-ChildItem -LiteralPath $SourceDirectory -File -Recurse

    foreach ($file in $files) {
        $destination = Get-SafeDestinationPath -DestinationDirectory $DestinationDirectory -FileName $file.Name

        Write-Host "Moving: $($file.FullName) -> $destination"
        Move-Item -LiteralPath $file.FullName -Destination $destination
    }
}

try {
    Write-Section "Initial validation"

    Assert-CommandExists -CommandName "adb"
    Assert-PathExists -Path $IrfanViewPath -Description "IrfanView executable"
    Assert-PathExists -Path $ColorSortScript -Description "Color sorting script"

    foreach ($dir in @($LocalRoot, $UnsortedDir, $SortedDir)) {
        if (-not (Test-Path -LiteralPath $dir)) {
            Write-Host "Creating directory: $dir" -ForegroundColor Yellow
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }

    Write-Host "Date:     $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Host "Hostname: $env:COMPUTERNAME"
    Write-Host "User:     $env:USERNAME"

    Write-Section "Checking connected Android device"

    $adbDevices = adb devices -l
    $adbDevices | ForEach-Object { Write-Host $_ }

    $connectedDevices = $adbDevices |
    Where-Object { $_ -match "\sdevice\s" -and $_ -notmatch "^List of devices" }

    if (-not $connectedDevices) {
        throw "No authorized Android device detected. Check USB connection and Android USB debugging authorization."
    }

    Move-ExcludedAndroidMediaToQuarantine `
        -SourceDirectories $AndroidDirectories `
        -DestinationDirectory $AndroidExcludedMediaDir `
        -Extensions $ExcludedAndroidExtensions

    Write-Section "Pulling Android directories"

    $PulledAndroidDirectories = @()

    foreach ($androidDir in $AndroidDirectories) {
        Write-Host "Checking Android directory: $androidDir" -ForegroundColor Yellow

        if (-not (Invoke-AdbShellTestDirectory -AndroidPath $androidDir)) {
            Write-Warning "Android directory does not exist, skipping: $androidDir"
            continue
        }

        Write-Host "Pulling: $androidDir -> $LocalRoot" -ForegroundColor Yellow
        adb pull --sync $androidDir $LocalRoot

        if ($LASTEXITCODE -ne 0) {
            Write-Warning "adb pull failed, skipping further processing for: $androidDir"
            continue
        }

        $PulledAndroidDirectories += $androidDir
    }

    Write-Section "Moving pulled files into unsorted directory"

    foreach ($androidDir in $PulledAndroidDirectories) {
        $folderName = Split-Path $androidDir -Leaf
        $localPulledDir = Join-Path $LocalRoot $folderName

        if (Test-Path -LiteralPath $localPulledDir) {
            Move-FilesToDirectory -SourceDirectory $localPulledDir -DestinationDirectory $UnsortedDir
        }
        else {
            Write-Warning "Expected pulled directory not found: $localPulledDir"
        }
    }

    if ($DeleteAndroidSourceAfterPull) {
        Write-Section "Deleting successfully pulled Android source directories"

        foreach ($androidDir in $PulledAndroidDirectories) {
            Write-Host "Deleting from Android: $androidDir" -ForegroundColor Yellow
            $quotedAndroidDir = ConvertTo-AdbShellSingleQuoted -Text $androidDir
            adb shell "rm -rf $quotedAndroidDir"

            if ($LASTEXITCODE -ne 0) {
                Write-Warning "adb shell rm failed for: $androidDir"
            }
        }
    }

    Remove-EmptyDirectories -Directory $LocalRoot

    Restore-CorrectImageExtensions -Directory $UnsortedDir

    Convert-WebpToJpg `
        -Directory $UnsortedDir `
        -IrfanViewExe $IrfanViewPath `
        -Quality $JpegQuality `
        -DeleteSource ([bool]$DeleteWebpAfterConversion)

    Write-Section "Running color sorting script"

    & $ColorSortScript -ImageDirectory $UnsortedDir

    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Color sorting script returned non-zero exit code: $LASTEXITCODE"
    }

    Write-Section "Final cleanup"

    Remove-EmptyDirectories -Directory $LocalRoot

    Write-Host "Completed successfully." -ForegroundColor Green
}
catch {
    Write-Host ""
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}