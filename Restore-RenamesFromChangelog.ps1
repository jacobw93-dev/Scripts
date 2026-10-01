[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param()

$Host.UI.RawUI.WindowTitle = 'Restore renamed files/directories from changelog'
$Host.UI.RawUI.ForegroundColor = 'White'

Add-Type -AssemblyName System.Windows.Forms

function Select-ChangelogFile {
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog -Property @{
        InitialDirectory = 'D:\Downloads\Pics\'
        Title            = 'Select changelog file used to restore names'
        Filter           = 'Changelog files (changelog_*.txt)|changelog_*.txt|Text files (*.txt)|*.txt|All files (*.*)|*.*'
        FilterIndex      = 1
        CheckFileExists  = $true
        CheckPathExists  = $true
        Multiselect      = $false
    }

    if ($OpenFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        Write-Host -ForegroundColor Green "`nSelected changelog file:"
        Write-Host $OpenFileDialog.FileName
        return $OpenFileDialog.FileName
    }

    Write-Host -ForegroundColor Red "`nUser cancelled the operation."
    exit
}

function Select-SourceFolder {
    param(
        [string]$InitialDirectory = 'D:\Downloads\Pics\'
    )

    if (-not (Test-Path -LiteralPath $InitialDirectory -PathType Container)) {
        $InitialDirectory = 'D:\Downloads\Pics\'
    }

    $FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{
        SelectedPath = $InitialDirectory
        Description  = 'Select the CURRENT source directory containing the renamed files/directories'
    }

    if ($FolderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        Write-Host -ForegroundColor Green "`nSelected source directory:"
        Write-Host $FolderBrowser.SelectedPath
        return $FolderBrowser.SelectedPath.TrimEnd([char[]]'\/')
    }

    Write-Host -ForegroundColor Red "`nUser cancelled the operation."
    exit
}

function Get-CommonDirectoryPath {
    param([Parameter(Mandatory)][string[]]$Paths)

    if ($Paths.Count -eq 0) {
        return $null
    }

    $parents = foreach ($path in $Paths) {
        $normalized = $path.TrimEnd([char[]]'\/')
        [System.IO.Path]::GetDirectoryName($normalized)
    }

    $common = $parents[0].TrimEnd([char[]]'\/')

    foreach ($parent in $parents | Select-Object -Skip 1) {
        $candidate = $parent.TrimEnd([char[]]'\/')

        while ($common -and -not (
            $candidate.Equals($common, [System.StringComparison]::OrdinalIgnoreCase) -or
            $candidate.StartsWith($common + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase) -or
            $candidate.StartsWith($common + [System.IO.Path]::AltDirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)
        )) {
            $common = [System.IO.Path]::GetDirectoryName($common)
        }
    }

    return $common
}

function Get-OriginalSourceRoot {
    param(
        [Parameter(Mandatory)][string]$ChangelogFile,
        [Parameter(Mandatory)][object[]]$Operations
    )

    # The original rename script creates the log as:
    # changelog_<selected-folder-name>_yyyyMMdd_HHmmss.txt
    # Prefer that folder-name token when locating the old source root in logged paths.
    $logBaseName = [System.IO.Path]::GetFileName($ChangelogFile)
    $folderToken = $null

    if ($logBaseName -match '^changelog_(.+)_\d{8}_\d{6}\.txt$') {
        $folderToken = $Matches[1]
    }

    if ($folderToken) {
        $candidateRoots = [System.Collections.Generic.List[string]]::new()

        foreach ($operation in $Operations) {
            $path = $operation.OldPath.TrimEnd([char[]]'\/')
            $root = [System.IO.Path]::GetPathRoot($path)
            $relative = $path.Substring($root.Length)
            $parts = $relative -split '[\\/]'
            $current = $root.TrimEnd([char[]]'\/')

            foreach ($part in $parts) {
                if ([string]::IsNullOrWhiteSpace($part)) { continue }

                if ($current) {
                    $current = Join-Path -Path $current -ChildPath $part
                }
                else {
                    $current = $root + $part
                }

                $sanitized = $part -replace '[^0-9A-Za-z\.]+', '_'
                if ($sanitized -eq $folderToken) {
                    $candidateRoots.Add($current) | Out-Null
                }
            }
        }

        if ($candidateRoots.Count -gt 0) {
            return ($candidateRoots |
                Group-Object { $_.ToLowerInvariant() } |
                Sort-Object Count -Descending |
                Select-Object -First 1 |
                ForEach-Object { $_.Group[0] })
        }
    }

    # Fallback: use the common parent of all logged original paths.
    return Get-CommonDirectoryPath -Paths @($Operations.OldPath)
}

function Convert-ToCurrentSourcePath {
    param(
        [Parameter(Mandatory)][string]$LoggedPath,
        [Parameter(Mandatory)][string]$OriginalSourceRoot,
        [Parameter(Mandatory)][string]$CurrentSourceRoot
    )

    $logged = $LoggedPath.TrimEnd([char[]]'\/')
    $oldRoot = $OriginalSourceRoot.TrimEnd([char[]]'\/')
    $newRoot = $CurrentSourceRoot.TrimEnd([char[]]'\/')

    $isAtRoot = $logged.Equals($oldRoot, [System.StringComparison]::OrdinalIgnoreCase)
    $isBelowRoot = $logged.StartsWith($oldRoot + '\', [System.StringComparison]::OrdinalIgnoreCase) -or
                   $logged.StartsWith($oldRoot + '/', [System.StringComparison]::OrdinalIgnoreCase)

    if (-not ($isAtRoot -or $isBelowRoot)) {
        throw "Logged path '$LoggedPath' is outside detected original source root '$OriginalSourceRoot'."
    }

    $relative = $logged.Substring($oldRoot.Length).TrimStart([char[]]'\/')
    if ([string]::IsNullOrWhiteSpace($relative)) {
        return $newRoot
    }

    return Join-Path -Path $newRoot -ChildPath $relative
}

function Get-PathDepth {
    param([Parameter(Mandatory)][string]$Path)

    return ($Path.TrimEnd('\') -split '[\\/]').Count
}

function Get-RenameOperations {
    param([Parameter(Mandatory)][string]$Path)

    $operations = [System.Collections.Generic.List[object]]::new()
    $lineNumber = 0

    foreach ($line in Get-Content -LiteralPath $Path) {
        $lineNumber++

        # Examples produced by rename_pics.ps1:
        # 20261001_120000; Renamed file: 'D:\Pics\Set\old.jpg';'Set_01.jpg'
        # 20261001_120000; Renamed directory: 'D:\Pics\Old folder';'Parent - Set 01'
        if ($line -match "^.*?;\s*Renamed\s+(file|directory):\s*'(.*?)';'(.*?)'\s*$") {
            $type = $Matches[1].ToLowerInvariant()
            $oldPath = $Matches[2]
            $newName = $Matches[3]

            if ([string]::IsNullOrWhiteSpace($oldPath) -or [string]::IsNullOrWhiteSpace($newName)) {
                continue
            }

            # Avoid Split-Path -LiteralPath together with -Parent/-Leaf: on PowerShell 7
            # those switches belong to a different parameter set and can raise
            # 'Parameter set cannot be resolved'. System.IO handles these paths literally.
            $normalizedOldPath = $oldPath.TrimEnd([char[]]'\/')
            $parentPath = [System.IO.Path]::GetDirectoryName($normalizedOldPath)
            $oldName = [System.IO.Path]::GetFileName($normalizedOldPath)

            if ([string]::IsNullOrWhiteSpace($parentPath) -or [string]::IsNullOrWhiteSpace($oldName)) {
                Write-Host -ForegroundColor Yellow "[SKIPPED] Unable to resolve path from changelog line $lineNumber : $oldPath"
                continue
            }

            $currentPath = Join-Path -Path $parentPath -ChildPath $newName

            $operations.Add([pscustomobject]@{
                LineNumber  = $lineNumber
                Type        = $type
                OldPath     = $oldPath
                OldName     = $oldName
                CurrentPath = $currentPath
                NewName     = $newName
                Depth       = Get-PathDepth -Path $oldPath
            }) | Out-Null
        }
    }

    return $operations
}

function Restore-RenameOperation {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)]$Operation
    )

    $typeLabel = if ($Operation.Type -eq 'directory') { 'directory' } else { 'file' }

    if (Test-Path -LiteralPath $Operation.OldPath) {
        if (-not (Test-Path -LiteralPath $Operation.CurrentPath)) {
            Write-Host -ForegroundColor DarkGray "[ALREADY RESTORED] $typeLabel : $($Operation.OldPath)"
            return 'AlreadyRestored'
        }

        # Both source and target exist: do not overwrite anything.
        Write-Host -ForegroundColor Yellow "[CONFLICT] $typeLabel target already exists:"
        Write-Host -ForegroundColor Yellow "           Current : $($Operation.CurrentPath)"
        Write-Host -ForegroundColor Yellow "           Target  : $($Operation.OldPath)"
        return 'Conflict'
    }

    if (-not (Test-Path -LiteralPath $Operation.CurrentPath)) {
        Write-Host -ForegroundColor Yellow "[NOT FOUND] $typeLabel expected at: $($Operation.CurrentPath)"
        return 'NotFound'
    }

    $action = "Restore $typeLabel name '$($Operation.NewName)' -> '$($Operation.OldName)'"
    if ($PSCmdlet.ShouldProcess($Operation.CurrentPath, $action)) {
        try {
            Rename-Item -LiteralPath $Operation.CurrentPath -NewName $Operation.OldName -ErrorAction Stop
            Write-Host -ForegroundColor Green "[RESTORED] $($Operation.CurrentPath) -> $($Operation.OldName)"
            return 'Restored'
        }
        catch {
            Write-Host -ForegroundColor Red "[ERROR] $($Operation.CurrentPath)"
            Write-Host -ForegroundColor Red "        $($_.Exception.Message)"
            return 'Error'
        }
    }

    return 'Preview'
}

$ChangelogFile = Select-ChangelogFile

try {
    $RenameOperations = @(Get-RenameOperations -Path $ChangelogFile)
}
catch {
    Write-Host -ForegroundColor Red "`nUnable to read changelog file: $($_.Exception.Message)"
    exit 1
}

if ($RenameOperations.Count -eq 0) {
    Write-Host -ForegroundColor Yellow "`nNo 'Renamed file' or 'Renamed directory' entries were found in the selected changelog."
    exit
}

$OriginalSourceRoot = Get-OriginalSourceRoot -ChangelogFile $ChangelogFile -Operations $RenameOperations
if ([string]::IsNullOrWhiteSpace($OriginalSourceRoot)) {
    Write-Host -ForegroundColor Red "`nUnable to determine the original source directory from the changelog."
    exit 1
}

$SuggestedSourceFolder = [System.IO.Path]::GetDirectoryName($ChangelogFile)
$SourceFolder = Select-SourceFolder -InitialDirectory $SuggestedSourceFolder

# Rebase every logged path from the original source location to the source directory
# selected above. This allows restoring names after the whole directory tree was moved.
try {
    foreach ($operation in $RenameOperations) {
        $rebasedOldPath = Convert-ToCurrentSourcePath `
            -LoggedPath $operation.OldPath `
            -OriginalSourceRoot $OriginalSourceRoot `
            -CurrentSourceRoot $SourceFolder

        $rebasedParent = [System.IO.Path]::GetDirectoryName($rebasedOldPath.TrimEnd([char[]]'\/'))
        if ([string]::IsNullOrWhiteSpace($rebasedParent)) {
            throw "Unable to determine parent path for '$rebasedOldPath'."
        }

        $operation.OldPath = $rebasedOldPath
        $operation.CurrentPath = Join-Path -Path $rebasedParent -ChildPath $operation.NewName
    }
}
catch {
    Write-Host -ForegroundColor Red "`nUnable to map changelog paths to selected source directory: $($_.Exception.Message)"
    exit 1
}

$FileOperations = @(
    $RenameOperations |
        Where-Object Type -eq 'file' |
        Sort-Object LineNumber -Descending
)

$DirectoryOperations = @(
    $RenameOperations |
        Where-Object Type -eq 'directory' |
        Sort-Object @{ Expression = 'Depth'; Descending = $true }, @{ Expression = 'LineNumber'; Descending = $true }
)

Write-Host -ForegroundColor Cyan "`n================ RESTORE PLAN ================"
Write-Host "Changelog               : $ChangelogFile"
Write-Host "Original source root    : $OriginalSourceRoot"
Write-Host "Current source directory: $SourceFolder"
Write-Host "File rename entries     : $($FileOperations.Count)"
Write-Host "Directory rename entries: $($DirectoryOperations.Count)"
Write-Host "Total rename entries   : $($RenameOperations.Count)"
Write-Host -ForegroundColor Cyan "==============================================`n"

$stats = @{
    Restored        = 0
    Preview         = 0
    AlreadyRestored = 0
    Conflict        = 0
    NotFound        = 0
    Error           = 0
}

# Restore file names first. The original script renames directories before files,
# so the file log paths point to the renamed directory names that currently exist.
foreach ($operation in $FileOperations) {
    $result = Restore-RenameOperation -Operation $operation
    $stats[$result]++
}

# Restore directory names afterwards, deepest/reverse operations first so that
# parent renames do not invalidate paths of child entries still waiting to be restored.
foreach ($operation in $DirectoryOperations) {
    $result = Restore-RenameOperation -Operation $operation
    $stats[$result]++
}

Write-Host -ForegroundColor Cyan "`n================ RESTORE SUMMARY ================"
Write-Host "Restored          : $($stats.Restored)"
Write-Host "Previewed         : $($stats.Preview)"
Write-Host "Already restored  : $($stats.AlreadyRestored)"
Write-Host "Conflicts         : $($stats.Conflict)"
Write-Host "Not found         : $($stats.NotFound)"
Write-Host "Errors            : $($stats.Error)"
Write-Host -ForegroundColor Cyan "=================================================`n"

if ($WhatIfPreference) {
    Write-Host -ForegroundColor Yellow 'This was a WhatIf preview. No rename operations were performed.'
}
