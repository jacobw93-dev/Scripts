#requires -Version 7.0
<#+
.SYNOPSIS
    Unified GUI for the original rename_pics image workflow and Mass File Renamer functionality.
.DESCRIPTION
    Provides two GUI workflows:
      1. Picture Workflow - the original rename_pics archive/image/folder processing pipeline.
      2. Mass Rename      - previewable, filterable general-purpose file/folder renaming with undo.

    The script intentionally does not embed SMTP credentials. Optional e-mail notification uses
    environment variables for non-secret SMTP settings and Windows Credential Manager target 'rename_pics_smtp' for credentials.
#>

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:AppName = 'Picture & Mass File Renamer'
$script:Version = '2.3.0'
$script:PictureProgressBar = $null
$script:PictureProgressLabel = $null
$script:ScriptPath = $MyInvocation.MyCommand.Path
$script:ScriptDir = if ($script:ScriptPath) { [System.IO.Path]::GetDirectoryName($script:ScriptPath) } else { $null }
if (-not $script:ScriptDir) { $script:ScriptDir = (Get-Location).Path }

# Original rename_pics defaults
$script:ImageFileTypes = @('.jpeg', '.jpg', '.png')
$script:ExcludedFileTypes = @('.!qb', '.part', '.zip', '.rar', '.7z')
$script:CompressedFileTypes = @('.zip', '.rar', '.7z')
$script:NameSanitizeRegex = '[^0-9A-Za-z\.]+'
$script:LowQualityFolderName = 'LQ'
$script:ContactSheetsFolderName = 'CS'
$script:ExcludedFolderNames = @($script:LowQualityFolderName, $script:ContactSheetsFolderName)

# Mass Renamer persistence/output locations
$script:MassRoot = Join-Path $script:ScriptDir 'Resources\MassRenamer'
$script:MassSettingsFile = Join-Path $script:MassRoot 'Settings.json'
$script:MassSimulationDir = Join-Path $script:MassRoot 'Simulations'
$script:MassExecutedDir = Join-Path $script:MassRoot 'Executed Renames'
$script:MassUndoneDir = Join-Path $script:MassRoot 'Undone Renames'
foreach ($path in @($script:MassRoot, $script:MassSimulationDir, $script:MassExecutedDir, $script:MassUndoneDir)) {
    if (-not (Test-Path -LiteralPath $path)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
}

# Picture Workflow preview/execution/undo persistence
$script:PictureRoot = Join-Path $script:ScriptDir 'Resources\PictureWorkflow'
$script:PicturePreviewDir = Join-Path $script:PictureRoot 'Previews'
$script:PictureExecutedDir = Join-Path $script:PictureRoot 'Executed Runs'
$script:PictureUndoneDir = Join-Path $script:PictureRoot 'Undone Runs'
$script:PictureBackupDir = Join-Path $script:PictureRoot 'Undo Data'
foreach ($path in @($script:PictureRoot, $script:PicturePreviewDir, $script:PictureExecutedDir, $script:PictureUndoneDir, $script:PictureBackupDir)) {
    if (-not (Test-Path -LiteralPath $path)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
}

function Show-ErrorMessage {
    param([Parameter(Mandatory)][string]$Message, [string]$Title = 'Error')
    [void][System.Windows.Forms.MessageBox]::Show($Message, $Title, 'OK', 'Error')
}

function Show-InfoMessage {
    param([Parameter(Mandatory)][string]$Message, [string]$Title = 'Information')
    [void][System.Windows.Forms.MessageBox]::Show($Message, $Title, 'OK', 'Information')
}

function Confirm-Action {
    param([Parameter(Mandatory)][string]$Message, [string]$Title = 'Confirm')
    return ([System.Windows.Forms.MessageBox]::Show($Message, $Title, 'YesNo', 'Warning') -eq 'Yes')
}

function Select-Folder {
    param(
        [string]$Description = 'Select a directory',
        [string]$SelectedPath = ''
    )
    $dialog = [System.Windows.Forms.FolderBrowserDialog]::new()
    $dialog.Description = $Description
    if ($SelectedPath -and (Test-Path -LiteralPath $SelectedPath -PathType Container)) {
        $dialog.SelectedPath = $SelectedPath
    }
    try {
        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            return $dialog.SelectedPath
        }
        return $null
    }
    finally { $dialog.Dispose() }
}

function Get-RelativePathSafe {
    param([string]$BasePath, [string]$Path)
    try { return [System.IO.Path]::GetRelativePath($BasePath, $Path) }
    catch { return $Path }
}

function Write-ChangeLogEntry {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Message
    )
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    "$timestamp; $Message" | Out-File -LiteralPath $Path -Append -Encoding utf8
}

function Get-NaturalSortKey {
    param([Parameter(ValueFromPipeline)][string]$Value)
    process {
        [regex]::Replace($Value, '\d+', { param($m) $m.Value.PadLeft(100, '0') })
    }
}

function Get-PictureParentFolders {
    param(
        [Parameter(Mandatory)][string]$InputFolder,
        [Parameter(Mandatory)][ValidateSet(0,1)][int]$RenameMode
    )
    $depth = if ($RenameMode -eq 0) { 1 } else { 2 }
    Get-ChildItem -LiteralPath $InputFolder -Directory -Recurse | Where-Object {
        $relative = Get-RelativePathSafe -BasePath $InputFolder -Path $_.FullName
        $parts = $relative -split '[\\/]'
        $parts.Count -eq $depth -and $_.Name -notin $script:ExcludedFolderNames -and
        (Get-ChildItem -LiteralPath $_.FullName -File -Recurse | Where-Object { $_.Extension -notin $script:ExcludedFileTypes } | Select-Object -First 1)
    }
}

function Remove-UnwantedPictureItems {
    param(
        [Parameter(Mandatory)][string]$InputFolder,
        [Parameter(Mandatory)][string]$ChangeLog
    )
    $filesToDelete = Get-ChildItem -LiteralPath $InputFolder -File -Recurse | Where-Object {
        $_.Extension -notin $script:ExcludedFileTypes -and
        $_.Extension -notin $script:ImageFileTypes -and
        $_.Name -notlike '*changelog*' -and
        $_.Extension -ne '.txt'
    }
    foreach ($file in $filesToDelete) {
        try {
            $old = $file.FullName
            Remove-Item -LiteralPath $old -Force
            Write-ChangeLogEntry -Path $ChangeLog -Message ("Deleted file: '{0}'" -f $old)
        }
        catch {
            Write-ChangeLogEntry -Path $ChangeLog -Message ("ERROR deleting file: '{0}'; {1}" -f $file.FullName, $_.Exception.Message)
        }
    }

    # Remove empty directories deepest-first.
    Get-ChildItem -LiteralPath $InputFolder -Directory -Recurse |
        Sort-Object { $_.FullName.Length } -Descending |
        Where-Object { -not (Get-ChildItem -LiteralPath $_.FullName -Force | Select-Object -First 1) } |
        ForEach-Object {
            try {
                $old = $_.FullName
                Remove-Item -LiteralPath $old -Force
                Write-ChangeLogEntry -Path $ChangeLog -Message ("Deleted empty directory: '{0}'" -f $old)
            }
            catch {
                Write-ChangeLogEntry -Path $ChangeLog -Message ("ERROR deleting empty directory: '{0}'; {1}" -f $_.FullName, $_.Exception.Message)
            }
        }
}

function Expand-PictureArchives {
    param(
        [Parameter(Mandatory)][string]$InputFolder,
        [Parameter(Mandatory)][string]$ChangeLog,
        [Parameter(Mandatory)][hashtable]$Stats
    )
    $archives = @(Get-ChildItem -LiteralPath $InputFolder -File -Recurse | Where-Object { $_.Extension -in $script:CompressedFileTypes })
    $Stats.ArchivesFound = $archives.Count
    if ($archives.Count -eq 0) { return }

    $expand7Zip = Get-Command Expand-7Zip -ErrorAction SilentlyContinue
    $stageStart = Get-Date
    $archiveIndex = 0
    foreach ($archive in $archives) {
        $archiveIndex++
        Update-PictureWorkflowProgress -Activity 'Extracting archives' -CurrentOperation $archive.FullName -Current $archiveIndex -Total $archives.Count -Id 2 -ParentId 1
        try {
            $newName = (($archive.Name -replace $script:NameSanitizeRegex, '.') -replace '^\.+', '')
            $newBaseName = (($archive.BaseName -replace $script:NameSanitizeRegex, '.') -replace '^\.+', '')
            $renamedArchive = Join-Path $archive.DirectoryName $newName
            if ($archive.Name -cne $newName) {
                Rename-Item -LiteralPath $archive.FullName -NewName $newName -ErrorAction Stop
            }
            $targetPath = Join-Path $archive.DirectoryName $newBaseName

            if ($expand7Zip) {
                Expand-7Zip -ArchiveFileName $renamedArchive -TargetPath $targetPath
            }
            elseif ([System.IO.Path]::GetExtension($renamedArchive) -ieq '.zip') {
                Expand-Archive -LiteralPath $renamedArchive -DestinationPath $targetPath -Force
            }
            else {
                throw "Expand-7Zip is required for '$([System.IO.Path]::GetExtension($renamedArchive))' archives. Install/import 7Zip4Powershell or process this archive manually."
            }

            Remove-Item -LiteralPath $renamedArchive -Force
            $Stats.ArchivesExtracted++
            Write-ChangeLogEntry -Path $ChangeLog -Message ("Extracted archive:'{0}';'{1}'" -f $renamedArchive, $targetPath)
        }
        catch {
            $Stats.Errors++
            $Stats.ErrorDetails.Add("Archive '$($archive.FullName)': $($_.Exception.Message)") | Out-Null
            Write-ChangeLogEntry -Path $ChangeLog -Message ("ERROR extracting archive: '{0}'; {1}" -f $archive.FullName, $_.Exception.Message)
        }
    }
}

function Move-PictureLeafFolders {
    param(
        [Parameter(Mandatory)][string]$InputFolder,
        [Parameter(Mandatory)][int]$RenameMode,
        [Parameter(Mandatory)][string]$ChangeLog,
        [Parameter(Mandatory)][hashtable]$Stats
    )
    $parents = @(Get-PictureParentFolders -InputFolder $InputFolder -RenameMode $RenameMode)
    foreach ($parent in $parents) {
        $leafFolders = @(Get-ChildItem -LiteralPath $parent.FullName -Directory -Recurse | Where-Object {
            (Get-ChildItem -LiteralPath $_.FullName -File | Select-Object -First 1) -and
            -not (Get-ChildItem -LiteralPath $_.FullName -Directory | Select-Object -First 1)
        })
        foreach ($leaf in $leafFolders) {
            try {
                $destinationName = "$($leaf.Parent.Name) - $($leaf.Name)"
                $destination = Join-Path $parent.Parent.FullName $destinationName
                if (Test-Path -LiteralPath $destination) {
                    throw "Destination already exists: $destination"
                }
                $old = $leaf.FullName
                Move-Item -LiteralPath $old -Destination $destination -ErrorAction Stop
                Write-ChangeLogEntry -Path $ChangeLog -Message ("Moved directory:'{0}';'{1}'" -f $old, $destination)
            }
            catch {
                $Stats.Errors++
                $Stats.ErrorDetails.Add("Move directory '$($leaf.FullName)': $($_.Exception.Message)") | Out-Null
                Write-ChangeLogEntry -Path $ChangeLog -Message ("ERROR moving directory: '{0}'; {1}" -f $leaf.FullName, $_.Exception.Message)
            }
        }
    }
}

function Move-LowQualityAndContactSheets {
    param(
        [Parameter(Mandatory)][string]$InputFolder,
        [Parameter(Mandatory)][int]$RenameMode,
        [Parameter(Mandatory)][string]$ChangeLog,
        [Parameter(Mandatory)][hashtable]$Stats
    )
    $parents = @(Get-PictureParentFolders -InputFolder $InputFolder -RenameMode $RenameMode)
    $pictures = @($parents | ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -File -Recurse } | Where-Object { $_.Extension -in $script:ImageFileTypes })
    foreach ($picture in $pictures) {
        $image = $null
        try {
            $image = [System.Drawing.Image]::FromFile($picture.FullName)
            $width = $image.Width
            $height = $image.Height
            $aspectRatio = if ($width -gt 0) { $height / $width } else { 0 }
            $image.Dispose(); $image = $null

            $isLowQuality = (($width -lt 900 -and $height -lt 900) -or ($picture.Name -match '(?i)cover'))
            $isContactSheet = (($aspectRatio -ge 2) -or ($picture.Name -match '(?i)contactsheet|(?:^|[_\-. ])cs(?:[_\-. ]|$)'))
            if (-not $isLowQuality -and -not $isContactSheet) { continue }

            $category = if ($isLowQuality) { $script:LowQualityFolderName } else { $script:ContactSheetsFolderName }
            $destinationFolder = Join-Path $picture.Directory.Parent.FullName $category
            $destinationFolder = Join-Path $destinationFolder $picture.Directory.Name
            if (-not (Test-Path -LiteralPath $destinationFolder)) { New-Item -ItemType Directory -Path $destinationFolder -Force | Out-Null }
            $destinationFile = Join-Path $destinationFolder $picture.Name
            $old = $picture.FullName
            Move-Item -LiteralPath $old -Destination $destinationFile -Force -ErrorAction Stop
            if ($isLowQuality) { $Stats.LowQualityMoved++ } else { $Stats.ContactSheetsMoved++ }
            Write-ChangeLogEntry -Path $ChangeLog -Message ("Moved file:'{0}';'{1}'" -f $old, $destinationFile)
        }
        catch {
            if ($image) { $image.Dispose() }
            $Stats.Errors++
            $Stats.ErrorDetails.Add("Image '$($picture.FullName)': $($_.Exception.Message)") | Out-Null
            Write-ChangeLogEntry -Path $ChangeLog -Message ("ERROR processing image: '{0}'; {1}" -f $picture.FullName, $_.Exception.Message)
        }
    }
}

function Get-PictureFolderPrefix {
    param([AllowEmptyString()][string]$Prefix = 'Set')

    $value = if ([string]::IsNullOrWhiteSpace($Prefix)) { 'Set' } else { $Prefix.Trim() }
    if ($value.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -ge 0) {
        throw "Folder rename prefix contains invalid Windows filename characters: '$value'"
    }
    return $value
}

function Rename-PictureFolders {
    param(
        [Parameter(Mandatory)][string]$InputFolder,
        [Parameter(Mandatory)][int]$RenameMode,
        [Parameter(Mandatory)][int]$StartNumber,
        [string]$Prefix = 'Set',
        [Parameter(Mandatory)][string]$ChangeLog,
        [Parameter(Mandatory)][hashtable]$Stats
    )
    $Prefix = Get-PictureFolderPrefix -Prefix $Prefix
    $folders = @(Get-PictureParentFolders -InputFolder $InputFolder -RenameMode $RenameMode | Sort-Object FullName)
    $currentParent = $null
    $number = $StartNumber
    foreach ($folder in $folders) {
        try {
            if ($currentParent -ne $folder.Parent.FullName) {
                $currentParent = $folder.Parent.FullName
                $number = $StartNumber
            }
            $folderCount = @(Get-ChildItem -LiteralPath $folder.Parent.FullName -Directory).Count
            $padding = [Math]::Max(1, $folderCount.ToString().Length)
            $newName = "$($folder.Parent.Name) - $Prefix $($number.ToString().PadLeft($padding, '0'))"
            $targetPath = Join-Path $folder.Parent.FullName $newName
            $old = $folder.FullName
            if ($old -cne $targetPath) {
                if (Test-Path -LiteralPath $targetPath) {
                    $tempName = "__renamepics_$([guid]::NewGuid().ToString('N'))"
                    Rename-Item -LiteralPath $old -NewName $tempName -ErrorAction Stop
                    Rename-Item -LiteralPath (Join-Path $folder.Parent.FullName $tempName) -NewName $newName -ErrorAction Stop
                }
                else {
                    Rename-Item -LiteralPath $old -NewName $newName -ErrorAction Stop
                }
                $Stats.FoldersRenamed++
                Write-ChangeLogEntry -Path $ChangeLog -Message ("Renamed directory: '{0}';'{1}'" -f $old, $newName)
            }
            $number++
        }
        catch {
            $Stats.Errors++
            $Stats.ErrorDetails.Add("Rename directory '$($folder.FullName)': $($_.Exception.Message)") | Out-Null
            Write-ChangeLogEntry -Path $ChangeLog -Message ("ERROR renaming directory: '{0}'; {1}" -f $folder.FullName, $_.Exception.Message)
        }
    }
}

function Rename-PictureFiles {
    param(
        [Parameter(Mandatory)][string]$InputFolder,
        [Parameter(Mandatory)][string]$ChangeLog,
        [Parameter(Mandatory)][hashtable]$Stats
    )
    # Include the selected source directory itself. The previous implementation only
    # enumerated child directories, so images stored directly in $InputFolder were skipped.
    $folders = @(
        Get-Item -LiteralPath $InputFolder
        Get-ChildItem -LiteralPath $InputFolder -Directory -Recurse |
            Where-Object { $_.Name -notin $script:ExcludedFolderNames }
    ) | Sort-Object { Get-NaturalSortKey $_.FullName }
    $Stats.FilesFound = @($folders | ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -File } | Where-Object { $_.Extension -in $script:ImageFileTypes }).Count

    foreach ($folder in $folders) {
        $files = @(Get-ChildItem -LiteralPath $folder.FullName -File | Where-Object { $_.Extension -in $script:ImageFileTypes } | Sort-Object { Get-NaturalSortKey $_.Name })
        if ($files.Count -eq 0) { continue }
        $padding = [Math]::Max(1, $files.Count.ToString().Length)
        $counter = 1
        foreach ($file in $files) {
            try {
                $extension = $file.Extension
                $newName = "$($folder.Name)_$($counter.ToString().PadLeft($padding, '0'))$extension"
                $newName = (($newName -replace $script:NameSanitizeRegex, '.') -replace '\.+', '.') -replace '^\.+', ''
                $target = Join-Path $file.DirectoryName $newName
                $old = $file.FullName
                if ($old -cne $target) {
                    if (Test-Path -LiteralPath $target) {
                        $tempName = "__renamepics_$([guid]::NewGuid().ToString('N'))$extension"
                        Rename-Item -LiteralPath $old -NewName $tempName -ErrorAction Stop
                        Rename-Item -LiteralPath (Join-Path $file.DirectoryName $tempName) -NewName $newName -ErrorAction Stop
                    }
                    else {
                        Rename-Item -LiteralPath $old -NewName $newName -ErrorAction Stop
                    }
                    $Stats.FilesRenamed++
                    Write-ChangeLogEntry -Path $ChangeLog -Message ("Renamed file: '{0}';'{1}'" -f $old, $newName)
                }
            }
            catch {
                $Stats.Errors++
                $Stats.ErrorDetails.Add("Rename file '$($file.FullName)': $($_.Exception.Message)") | Out-Null
                Write-ChangeLogEntry -Path $ChangeLog -Message ("ERROR renaming file: '{0}'; {1}" -f $file.FullName, $_.Exception.Message)
            }
            $counter++
        }
    }
}

function Get-WindowsGenericCredential {
    param(
        [Parameter(Mandatory)][string]$Target
    )

    if (-not ('RenamePics.CredentialManager.NativeMethods' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace RenamePics.CredentialManager
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    internal struct CREDENTIAL
    {
        public UInt32 Flags;
        public UInt32 Type;
        public IntPtr TargetName;
        public IntPtr Comment;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
        public UInt32 CredentialBlobSize;
        public IntPtr CredentialBlob;
        public UInt32 Persist;
        public UInt32 AttributeCount;
        public IntPtr Attributes;
        public IntPtr TargetAlias;
        public IntPtr UserName;
    }

    internal static class NativeMethods
    {
        [DllImport("advapi32.dll", EntryPoint = "CredReadW", CharSet = CharSet.Unicode, SetLastError = true)]
        internal static extern bool CredRead(string target, UInt32 type, UInt32 reservedFlag, out IntPtr credentialPtr);

        [DllImport("advapi32.dll", SetLastError = true)]
        internal static extern void CredFree(IntPtr buffer);
    }

    public static class CredentialReader
    {
        private const UInt32 CRED_TYPE_GENERIC = 1;

        public static string[] ReadGeneric(string target)
        {
            IntPtr credentialPtr;
            if (!NativeMethods.CredRead(target, CRED_TYPE_GENERIC, 0, out credentialPtr))
            {
                return null;
            }

            try
            {
                CREDENTIAL credential = (CREDENTIAL)Marshal.PtrToStructure(credentialPtr, typeof(CREDENTIAL));
                string userName = credential.UserName == IntPtr.Zero ? null : Marshal.PtrToStringUni(credential.UserName);
                string password = null;

                if (credential.CredentialBlob != IntPtr.Zero && credential.CredentialBlobSize > 0)
                {
                    password = Marshal.PtrToStringUni(credential.CredentialBlob, (int)credential.CredentialBlobSize / 2);
                }

                return new string[] { userName, password };
            }
            finally
            {
                NativeMethods.CredFree(credentialPtr);
            }
        }
    }
}
'@
    }

    $values = [RenamePics.CredentialManager.CredentialReader]::ReadGeneric($Target)
    if (-not $values -or $values.Count -lt 2 -or [string]::IsNullOrWhiteSpace($values[0]) -or [string]::IsNullOrEmpty($values[1])) {
        return $null
    }

    $securePassword = ConvertTo-SecureString $values[1] -AsPlainText -Force
    $credential = [pscredential]::new($values[0], $securePassword)
    $values[1] = $null

    return $credential
}


function Get-RenamePicsEnvironmentValue {
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$DefaultValue = $null
    )

    foreach ($target in @('Process', 'User', 'Machine')) {
        try {
            $value = [Environment]::GetEnvironmentVariable($Name, [EnvironmentVariableTarget]::$target)
        }
        catch {
            $value = $null
        }

        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return [pscustomobject]@{
                Value  = $value
                Source = $target
            }
        }
    }

    return [pscustomobject]@{
        Value  = $DefaultValue
        Source = if ($null -ne $DefaultValue) { 'Default' } else { 'NotConfigured' }
    }
}

function Send-PictureWorkflowEmail {
    param(
        [Parameter(Mandatory)][hashtable]$Stats,
        [Parameter(Mandatory)][string]$InputFolder,
        [Parameter(Mandatory)][string]$ChangeLog,
        [Parameter(Mandatory)][TimeSpan]$Runtime
    )

    $credentialTarget = 'rename_pics_smtp'

    $smtpToSetting     = Get-RenamePicsEnvironmentValue -Name 'RENAME_PICS_SMTP_TO'
    $smtpServerSetting = Get-RenamePicsEnvironmentValue -Name 'RENAME_PICS_SMTP_SERVER' -DefaultValue 'smtp.gmail.com'
    $smtpPortSetting   = Get-RenamePicsEnvironmentValue -Name 'RENAME_PICS_SMTP_PORT' -DefaultValue '587'

    $smtpTo = [string]$smtpToSetting.Value
    $smtpServer = [string]$smtpServerSetting.Value

    $smtpPort = 587
    if (-not [int]::TryParse([string]$smtpPortSetting.Value, [ref]$smtpPort)) {
        Write-ChangeLogEntry -Path $ChangeLog -Message ("E-mail notification skipped: RENAME_PICS_SMTP_PORT value '{0}' is invalid." -f $smtpPortSetting.Value)
        return
    }

    if ([string]::IsNullOrWhiteSpace($smtpTo)) {
        Write-ChangeLogEntry -Path $ChangeLog -Message 'E-mail notification skipped: RENAME_PICS_SMTP_TO is not configured in Process, User, or Machine environment scope.'
        return
    }

    Write-ChangeLogEntry -Path $ChangeLog -Message ("SMTP configuration resolved: TO={0} ({1}), SERVER={2} ({3}), PORT={4} ({5})." -f $smtpTo, $smtpToSetting.Source, $smtpServer, $smtpServerSetting.Source, $smtpPort, $smtpPortSetting.Source)

    try {
        $credential = Get-WindowsGenericCredential -Target $credentialTarget
    }
    catch {
        Write-ChangeLogEntry -Path $ChangeLog -Message ("E-mail notification skipped: unable to read Windows Credential Manager target '{0}': {1}" -f $credentialTarget, $_.Exception.Message)
        return
    }

    if (-not $credential) {
        Write-ChangeLogEntry -Path $ChangeLog -Message ("E-mail notification skipped: Windows Credential Manager target '{0}' was not found or is incomplete." -f $credentialTarget)
        return
    }

    $smtpUser = $credential.UserName
    if ([string]::IsNullOrWhiteSpace($smtpUser)) {
        Write-ChangeLogEntry -Path $ChangeLog -Message ("E-mail notification skipped: Windows Credential Manager target '{0}' contains no username." -f $credentialTarget)
        return
    }

    $body = @"
The rename_pics workflow is complete.

Input path               : $InputFolder
Files found              : $($Stats.FilesFound)
Files renamed            : $($Stats.FilesRenamed)
Folders renamed          : $($Stats.FoldersRenamed)
Archives found           : $($Stats.ArchivesFound)
Archives extracted       : $($Stats.ArchivesExtracted)
Low-quality images moved : $($Stats.LowQualityMoved)
Contact sheets moved     : $($Stats.ContactSheetsMoved)
Errors                    : $($Stats.Errors)
Runtime                   : $([string]::Format('{0:hh\:mm\:ss}', $Runtime))
"@

    $mailMessage = $null
    $smtpClient = $null
    $sendSucceeded = $false
    $sendError = $null

    try {
        # System.Net.Mail.Attachment keeps the changelog file open until the
        # MailMessage is disposed. Do not write to the changelog while the
        # attachment is still attached/open.
        $mailMessage = New-Object System.Net.Mail.MailMessage
        $mailMessage.From = $smtpUser
        [void]$mailMessage.To.Add($smtpTo)
        $mailMessage.Subject = 'rename_pics execution complete'
        $mailMessage.Body = $body

        if (Test-Path -LiteralPath $ChangeLog -PathType Leaf) {
            [void]$mailMessage.Attachments.Add((New-Object System.Net.Mail.Attachment($ChangeLog)))
        }

        $smtpClient = New-Object System.Net.Mail.SmtpClient($smtpServer, $smtpPort)
        $smtpClient.EnableSsl = $true
        $smtpClient.UseDefaultCredentials = $false
        $smtpClient.DeliveryMethod = [System.Net.Mail.SmtpDeliveryMethod]::Network
        $smtpClient.Timeout = 30000
        $smtpClient.Credentials = New-Object System.Net.NetworkCredential(
            $smtpUser,
            $credential.GetNetworkCredential().Password
        )

        $smtpClient.Send($mailMessage)
        $sendSucceeded = $true
    }
    catch {
        $errorMessages = [System.Collections.Generic.List[string]]::new()
        $exception = $_.Exception
        while ($exception) {
            if (-not [string]::IsNullOrWhiteSpace($exception.Message)) {
                $errorMessages.Add($exception.Message)
            }
            $exception = $exception.InnerException
        }
        $sendError = $errorMessages -join ' --> '
    }
    finally {
        # Dispose MailMessage first; this also disposes its Attachment objects
        # and releases the changelog file handle.
        if ($mailMessage) { $mailMessage.Dispose() }
        if ($smtpClient) { $smtpClient.Dispose() }
        $credential = $null
    }

    # Only touch the changelog after all mail/attachment handles are released.
    if ($sendSucceeded) {
        Write-ChangeLogEntry -Path $ChangeLog -Message ("Notification e-mail sent to '{0}' using SMTP server '{1}:{2}' and Credential Manager target '{3}'." -f $smtpTo, $smtpServer, $smtpPort, $credentialTarget)
    }
    else {
        Write-ChangeLogEntry -Path $ChangeLog -Message ("ERROR sending notification e-mail via {0}:{1}: {2}" -f $smtpServer, $smtpPort, $sendError)
    }
}

function Invoke-PictureWorkflow {
    param(
        [Parameter(Mandatory)][string]$InputFolder,
        [Parameter(Mandatory)][ValidateSet(0,1)][int]$RenameMode,
        [Parameter(Mandatory)][bool]$ExtractArchivesOnly,
        [Parameter(Mandatory)][bool]$RenameFolders,
        [Parameter(Mandatory)][bool]$MoveLqCs,
        [Parameter(Mandatory)][int]$FolderStartNumber,
        [string]$FolderPrefix = 'Set',
        [Parameter(Mandatory)][bool]$ShutdownAfter,
        [Parameter(Mandatory)][System.Windows.Forms.TextBox]$OutputBox
    )
    if (-not (Test-Path -LiteralPath $InputFolder -PathType Container)) { throw "Input folder does not exist: $InputFolder" }
    $date = Get-Date -Format 'yyyyMMdd_HHmmss'
    $safeBase = ((Get-Item -LiteralPath $InputFolder).BaseName -replace $script:NameSanitizeRegex, '_')
    $changeLog = Join-Path $InputFolder "changelog_${safeBase}_${date}.txt"
    $stats = @{
        FilesFound = 0; FilesRenamed = 0; FoldersRenamed = 0; ArchivesFound = 0; ArchivesExtracted = 0
        LowQualityMoved = 0; ContactSheetsMoved = 0; Errors = 0
        ErrorDetails = [System.Collections.Generic.List[string]]::new()
    }
    $start = Get-Date
    $OutputBox.AppendText("Starting picture workflow...`r`nChangelog: $changeLog`r`n`r`n")
    [System.Windows.Forms.Application]::DoEvents()

    Expand-PictureArchives -InputFolder $InputFolder -ChangeLog $changeLog -Stats $stats
    if ($ExtractArchivesOnly) {
        $runtime = (Get-Date) - $start
        $OutputBox.AppendText("Archive-only mode complete.`r`n")
        Send-PictureWorkflowEmail -Stats $stats -InputFolder $InputFolder -ChangeLog $changeLog -Runtime $runtime
        return @{ Stats = $stats; ChangeLog = $changeLog; Runtime = $runtime }
    }

    Remove-UnwantedPictureItems -InputFolder $InputFolder -ChangeLog $changeLog
    Move-PictureLeafFolders -InputFolder $InputFolder -RenameMode $RenameMode -ChangeLog $changeLog -Stats $stats
    Remove-UnwantedPictureItems -InputFolder $InputFolder -ChangeLog $changeLog
    if ($MoveLqCs) { Move-LowQualityAndContactSheets -InputFolder $InputFolder -RenameMode $RenameMode -ChangeLog $changeLog -Stats $stats }
    Remove-UnwantedPictureItems -InputFolder $InputFolder -ChangeLog $changeLog
    if ($RenameFolders) { Rename-PictureFolders -InputFolder $InputFolder -RenameMode $RenameMode -StartNumber $FolderStartNumber -Prefix $FolderPrefix -ChangeLog $changeLog -Stats $stats }
    Remove-UnwantedPictureItems -InputFolder $InputFolder -ChangeLog $changeLog
    Rename-PictureFiles -InputFolder $InputFolder -ChangeLog $changeLog -Stats $stats
    Remove-UnwantedPictureItems -InputFolder $InputFolder -ChangeLog $changeLog

    $runtime = (Get-Date) - $start
    "`nProcess time: $([string]::Format('{0:hh\:mm\:ss}', $runtime)) (hh:mm:ss)" | Out-File -LiteralPath $changeLog -Append -Encoding utf8
    Send-PictureWorkflowEmail -Stats $stats -InputFolder $InputFolder -ChangeLog $changeLog -Runtime $runtime
    if ($ShutdownAfter) { Stop-Computer }
    return @{ Stats = $stats; ChangeLog = $changeLog; Runtime = $runtime }
}

# ----------------------------- Mass Renamer ----------------------------------

function Get-DefaultMassSettings {
    [ordered]@{
        TargetDirectory = ''
        DrillDownFolders = $false
        IncludeFileNames = $true
        IncludeFolderNames = $false
        IncludeExtensions = $true
        FormatTitles = $false
        CaseSensitive = $false
        MustContain = ''
        Action = 'Replace Characters:'
        Word1 = ''
        Word2 = ''
    }
}

function Load-MassSettings {
    $settings = Get-DefaultMassSettings
    if (Test-Path -LiteralPath $script:MassSettingsFile) {
        try {
            $loaded = Get-Content -LiteralPath $script:MassSettingsFile -Raw | ConvertFrom-Json
            foreach ($key in @($settings.Keys)) {
                if ($null -ne $loaded.PSObject.Properties[$key]) { $settings[$key] = $loaded.$key }
            }
        }
        catch { }
    }
    return $settings
}

function Save-MassSettings {
    param([Parameter(Mandatory)][hashtable]$Settings)
    $Settings | ConvertTo-Json | Set-Content -LiteralPath $script:MassSettingsFile -Encoding utf8
}

function Test-MassRenameParameters {
    param([hashtable]$Settings)
    $invalidChars = '["*:<>?/\\{|}]+'
    if (-not (Test-Path -LiteralPath $Settings.TargetDirectory -PathType Container)) { return 'Invalid target directory.' }
    $action = [string]$Settings.Action

    if ($action -eq 'Replace Characters:') {
        if ([string]::IsNullOrEmpty($Settings.Word1)) { return 'Replace Characters requires Parameter 1.' }
    }
    elseif ($action -eq 'Insert at Position:') {
        if ($Settings.Word1 -notmatch '^\d+$') { return 'Insert at Position requires a numeric Parameter 1.' }
    }
    elseif ($action -eq 'Append Beginning:') {
        if ([string]::IsNullOrEmpty($Settings.Word2)) { return 'Append Beginning requires Parameter 2.' }
    }
    elseif ($action -eq 'Append End:') {
        if ([string]::IsNullOrEmpty($Settings.Word2)) { return 'Append End requires Parameter 2.' }
    }
    elseif ($action -eq 'Append After:') {
        if ([string]::IsNullOrEmpty($Settings.Word1) -or [string]::IsNullOrEmpty($Settings.Word2)) { return 'Append After requires both parameters.' }
    }
    elseif ($action -eq 'Append Before:') {
        if ([string]::IsNullOrEmpty($Settings.Word1) -or [string]::IsNullOrEmpty($Settings.Word2)) { return 'Append Before requires both parameters.' }
    }
    elseif ($action -eq 'Replace Beginning Characters:') {
        if ([string]::IsNullOrEmpty($Settings.Word1)) { return 'Replace Beginning Characters requires Parameter 1.' }
    }
    elseif ($action -eq 'Replace End Characters:') {
        if ([string]::IsNullOrEmpty($Settings.Word1)) { return 'Replace End Characters requires Parameter 1.' }
    }
    elseif ($action -eq 'Delete Everything After:') {
        if ([string]::IsNullOrEmpty($Settings.Word1)) { return 'Delete Everything After requires Parameter 1.' }
    }
    elseif ($action -eq 'Delete Everything Before:') {
        if ([string]::IsNullOrEmpty($Settings.Word1)) { return 'Delete Everything Before requires Parameter 1.' }
    }
    foreach ($value in @($Settings.Word1, $Settings.Word2)) {
        if ($value -and $value -match $invalidChars -and $Settings.Action -notin @('Replace Non-Latin Characters:')) { return 'A rename parameter contains a character invalid in Windows names.' }
    }
    if (-not $Settings.IncludeFileNames -and -not $Settings.IncludeFolderNames) { return 'Enable file names, folder names, or both.' }
    return $null
}

function Format-MassTitle {
    param([string]$Text)
    $result = (Get-Culture).TextInfo.ToTitleCase($Text.ToLower())
    $lowerWords = @('and','as','but','for','if','nor','or','so','yet','a','an','the','at','by','in','of','off','on','per','to','up','via','aka','is','it')
    foreach ($word in $lowerWords) {
        $title = (Get-Culture).TextInfo.ToTitleCase($word)
        $result = $result -replace "\s$([regex]::Escape($title))\s", " $word "
    }
    $result = $result -replace '\bViii\b','VIII' -replace '\bVii\b','VII' -replace '\bIii\b','III' -replace '\bVi\b','VI' -replace '\bIv\b','IV' -replace '\bIx\b','IX' -replace '\bIi\b','II' -replace '\bVip\b','VIP' -replace '\bTv\b','TV'
    return $result
}

function Invoke-MassNameTransform {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][hashtable]$Settings
    )

    $newName = $Name
    $w1 = [string]$Settings.Word1
    $w2 = [string]$Settings.Word2
    $comparison = if ($Settings.CaseSensitive) {
        [System.StringComparison]::Ordinal
    }
    else {
        [System.StringComparison]::OrdinalIgnoreCase
    }

    $action = [string]$Settings.Action

    if ($action -eq 'Replace Characters:') {
        if ($Settings.CaseSensitive) {
            $newName = $newName -creplace [regex]::Escape($w1), $w2
        }
        else {
            $newName = $newName -replace [regex]::Escape($w1), $w2
        }
    }
    elseif ($action -eq 'Append Beginning:') {
        $newName = $w2 + $newName
    }
    elseif ($action -eq 'Append End:') {
        $newName = $newName + $w2
    }
    elseif ($action -eq 'Append After:') {
        $index = $newName.IndexOf($w1, $comparison)
        if ($index -ge 0) {
            $index += $w1.Length
            $newName = $newName.Insert($index, $w2)
        }
    }
    elseif ($action -eq 'Append Before:') {
        $index = $newName.IndexOf($w1, $comparison)
        if ($index -ge 0) {
            $newName = $newName.Insert($index, $w2)
        }
    }
    elseif ($action -eq 'Replace Beginning Characters:') {
        $pattern = '^' + [regex]::Escape($w1)
        if ($Settings.CaseSensitive) {
            $newName = $newName -creplace $pattern, $w2
        }
        else {
            $newName = $newName -replace $pattern, $w2
        }
    }
    elseif ($action -eq 'Replace End Characters:') {
        $pattern = [regex]::Escape($w1) + '$'
        if ($Settings.CaseSensitive) {
            $newName = $newName -creplace $pattern, $w2
        }
        else {
            $newName = $newName -replace $pattern, $w2
        }
    }
    elseif ($action -eq 'Delete Everything After:') {
        $index = $newName.IndexOf($w1, $comparison)
        if ($index -ge 0) {
            $newName = $newName.Substring(0, $index + $w1.Length)
        }
    }
    elseif ($action -eq 'Delete Everything Before:') {
        $index = $newName.IndexOf($w1, $comparison)
        if ($index -ge 0) {
            $newName = $newName.Substring($index)
        }
    }
    elseif ($action -eq 'Insert at Position:') {
        $position = [int]$w1
        if ($position -le $newName.Length) {
            $newName = $newName.Insert($position, $w2)
        }
    }
    elseif ($action -eq 'Replace Non-Latin Characters:') {
        $newName = $newName -replace '[^\u0000-\u007F]', $w2
    }
    elseif ($action -eq 'To Lower Case:') {
        $newName = $newName.ToLower()
    }
    elseif ($action -eq 'To Upper Case:') {
        $newName = $newName.ToUpper()
    }
    elseif ($action -eq 'AddSpaceBetweenCamelCase:') {
        $newName = $newName -creplace '(?<=[a-z0-9])(?=[A-Z])', ' '
    }
    else {
        throw "Unsupported action: $action"
    }

    if ($Settings.FormatTitles) {
        $newName = Format-MassTitle -Text $newName
    }

    return $newName
}

function Convert-MassPathToProjectedPath {
    param(
        [Parameter(Mandatory)][string]$Path,
        [object[]]$DirectoryPlan = @()
    )
    $best = $null
    foreach ($entry in @($DirectoryPlan)) {
        $old = ([string]$entry.OldPath).TrimEnd([char[]]'\/')
        if ($Path -ieq $old -or $Path.StartsWith($old + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
            if (-not $best -or $old.Length -gt ([string]$best.OldPath).TrimEnd([char[]]'\/').Length) { $best = $entry }
        }
    }
    if (-not $best) { return $Path }
    $oldRoot = ([string]$best.OldPath).TrimEnd([char[]]'\/')
    $suffix = $Path.Substring($oldRoot.Length).TrimStart([char[]]'\/')
    if ([string]::IsNullOrWhiteSpace($suffix)) { return [string]$best.NewPath }
    return Join-Path ([string]$best.NewPath) $suffix
}

function Get-MassRenamePlan {
    param([Parameter(Mandatory)][hashtable]$Settings)
    $errorText = Test-MassRenameParameters -Settings $Settings
    if ($errorText) { throw $errorText }
    $target = (Get-Item -LiteralPath $Settings.TargetDirectory).FullName
    $items = [System.Collections.Generic.List[object]]::new()
    $directoryPlan = [System.Collections.Generic.List[object]]::new()

    if ($Settings.IncludeFolderNames) {
        $folders = if ($Settings.DrillDownFolders) { @(Get-ChildItem -LiteralPath $target -Directory -Recurse) } else { @(Get-ChildItem -LiteralPath $target -Directory) }
        $folders = @($folders | Sort-Object { ($_.FullName -split '[\\/]').Count }, FullName)
        foreach ($folder in $folders) {
            if ($Settings.MustContain) {
                $matched = if ($Settings.CaseSensitive) { $folder.Name.Contains($Settings.MustContain, [StringComparison]::Ordinal) } else { $folder.Name.Contains($Settings.MustContain, [StringComparison]::OrdinalIgnoreCase) }
                if (-not $matched) { continue }
            }
            $newLeaf = Invoke-MassNameTransform -Name $folder.Name -Settings $Settings
            if ([string]::IsNullOrWhiteSpace($newLeaf)) { continue }
            $projectedParent = Convert-MassPathToProjectedPath -Path $folder.Parent.FullName -DirectoryPlan @($directoryPlan)
            $finalPath = Join-Path $projectedParent $newLeaf
            $immediatePath = Join-Path $folder.Parent.FullName $newLeaf
            if ($folder.FullName -cne $finalPath) {
                $entry = [pscustomobject]@{
                    Type='Directory'; OldPath=$folder.FullName; NewPath=$finalPath; ImmediateNewPath=$immediatePath
                    NewLeaf=$newLeaf; Depth=($folder.FullName -split '[\\/]').Count
                }
                $directoryPlan.Add($entry) | Out-Null
                $items.Add($entry) | Out-Null
            }
        }
    }

    if ($Settings.IncludeFileNames) {
        $files = if ($Settings.DrillDownFolders) { @(Get-ChildItem -LiteralPath $target -File -Recurse) } else { @(Get-ChildItem -LiteralPath $target -File) }
        foreach ($file in $files) {
            if ($Settings.MustContain) {
                $matched = if ($Settings.CaseSensitive) { $file.Name.Contains($Settings.MustContain, [StringComparison]::Ordinal) } else { $file.Name.Contains($Settings.MustContain, [StringComparison]::OrdinalIgnoreCase) }
                if (-not $matched) { continue }
            }
            if ($Settings.IncludeExtensions) {
                $newLeaf = Invoke-MassNameTransform -Name $file.Name -Settings $Settings
            }
            else {
                $newBase = Invoke-MassNameTransform -Name $file.BaseName -Settings $Settings
                $newLeaf = $newBase + $file.Extension
            }
            if ([string]::IsNullOrWhiteSpace($newLeaf)) { continue }
            $projectedParent = Convert-MassPathToProjectedPath -Path $file.DirectoryName -DirectoryPlan @($directoryPlan)
            $finalPath = Join-Path $projectedParent $newLeaf
            $immediatePath = Join-Path $file.DirectoryName $newLeaf
            if ($file.FullName -cne $finalPath) {
                $items.Add([pscustomobject]@{
                    Type='File'; OldPath=$file.FullName; NewPath=$finalPath; ImmediateNewPath=$immediatePath
                    NewLeaf=$newLeaf; Depth=($file.FullName -split '[\\/]').Count
                }) | Out-Null
            }
        }
    }
    return @($items)
}

function New-MassOutputFile {
    param([string]$Type, [string]$Directory)
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    Join-Path $Directory "$Type`_$timestamp.json"
}

function Format-MassPlanPreview {
    param([object[]]$Plan, [int]$Limit = 0)
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("$($Plan.Count) change(s) found.")
    [void]$sb.AppendLine('')
    $display = if ($Limit -gt 0) { @($Plan | Select-Object -First $Limit) } else { @($Plan) }
    $n = 0
    foreach ($item in $display) {
        $n++
        [void]$sb.AppendLine("[$($item.Type)] #$n")
        [void]$sb.AppendLine("OLD: $($item.OldPath)")
        [void]$sb.AppendLine("NEW: $($item.NewPath)")
        [void]$sb.AppendLine('')
    }
    if ($Limit -gt 0 -and $Plan.Count -gt $Limit) { [void]$sb.AppendLine("Showing $Limit of $($Plan.Count) changes.") }
    return $sb.ToString()
}

function Update-MassRenameProgress {
    param(
        [Parameter(Mandatory)][string]$Activity,
        [string]$CurrentOperation = '',
        [int]$Current = 0,
        [int]$Total = 0,
        [datetime]$StartTime = [datetime]::MinValue
    )
    $percent = if ($Total -gt 0) { [Math]::Min(100,[Math]::Max(0,[Math]::Round(($Current / $Total) * 100))) } else { 0 }
    $status = if ($Total -gt 0) { "Processing $Current of $Total ($percent%)" } else { $CurrentOperation }
    $etaText = $null
    if ($StartTime -ne [datetime]::MinValue -and $Current -gt 0 -and $Total -ge $Current) {
        $elapsed = (Get-Date) - $StartTime
        $averageSeconds = $elapsed.TotalSeconds / $Current
        $remainingSeconds = [Math]::Max(0,($Total - $Current) * $averageSeconds)
        $remaining = [TimeSpan]::FromSeconds($remainingSeconds)
        $estimatedCompletion = (Get-Date).AddSeconds($remainingSeconds)
        $eh = ([string][int][Math]::Floor($elapsed.TotalHours)).PadLeft(2,'0')
        $rh = ([string][int][Math]::Floor($remaining.TotalHours)).PadLeft(2,'0')
        $elapsedText = $eh + ':' + ([string]$elapsed.Minutes).PadLeft(2,'0') + ':' + ([string]$elapsed.Seconds).PadLeft(2,'0')
        $remainingText = $rh + ':' + ([string]$remaining.Minutes).PadLeft(2,'0') + ':' + ([string]$remaining.Seconds).PadLeft(2,'0')
        $etaText = "Elapsed $elapsedText | Remaining $remainingText | ETA $($estimatedCompletion.ToString('HH:mm:ss'))"
        $status += " | $etaText"
    }
    $wp = @{Id=20;Activity=$Activity;Status=$status;PercentComplete=$percent}
    if (-not [string]::IsNullOrWhiteSpace($CurrentOperation)) { $wp.CurrentOperation=$CurrentOperation }
    Write-Progress @wp

    $now = Get-Date
    $due = (-not $script:MassLastGuiRefresh) -or (($now - $script:MassLastGuiRefresh).TotalMilliseconds -ge 500) -or ($Total -gt 0 -and $Current -ge $Total)
    if ($due) {
        if ($script:MassProgressBar -and -not $script:MassProgressBar.IsDisposed) { $script:MassProgressBar.Value=$percent }
        if ($etaText -and $script:MassEtaLabel -and -not $script:MassEtaLabel.IsDisposed -and $script:MassEtaLabel.Text -ne $etaText) { $script:MassEtaLabel.Text=$etaText }
        if ($script:MassProgressLabel -and -not $script:MassProgressLabel.IsDisposed) {
            $label = if ($Total -gt 0) { "$Activity - Processing $Current of $Total ($percent%)" } else { $Activity }
            if (-not [string]::IsNullOrWhiteSpace($CurrentOperation)) { $label += " - $CurrentOperation" }
            if ($script:MassProgressLabel.Text -ne $label) { $script:MassProgressLabel.Text=$label }
        }
        $script:MassLastGuiRefresh=$now
        [System.Windows.Forms.Application]::DoEvents()
    }
}

function Complete-MassRenameProgress {
    Write-Progress -Id 20 -Completed -ErrorAction SilentlyContinue
    if ($script:MassProgressBar -and -not $script:MassProgressBar.IsDisposed) { $script:MassProgressBar.Value=100 }
    if ($script:MassEtaLabel -and -not $script:MassEtaLabel.IsDisposed) { $script:MassEtaLabel.Text='' }
    if ($script:MassProgressLabel -and -not $script:MassProgressLabel.IsDisposed) { $script:MassProgressLabel.Text='Mass Rename complete.' }
    $script:MassLastGuiRefresh=$null
    [System.Windows.Forms.Application]::DoEvents()
}

function Send-MassRenameEmail {
    param(
        [Parameter(Mandatory)][string]$TargetDirectory,
        [Parameter(Mandatory)][string]$ExecutionLog,
        [Parameter(Mandatory)][int]$Total,
        [Parameter(Mandatory)][int]$Succeeded,
        [Parameter(Mandatory)][int]$Failed,
        [Parameter(Mandatory)][TimeSpan]$Runtime
    )
    $credentialTarget='rename_pics_smtp'
    $smtpToSetting=Get-RenamePicsEnvironmentValue -Name 'RENAME_PICS_SMTP_TO'
    $smtpServerSetting=Get-RenamePicsEnvironmentValue -Name 'RENAME_PICS_SMTP_SERVER' -DefaultValue 'smtp.gmail.com'
    $smtpPortSetting=Get-RenamePicsEnvironmentValue -Name 'RENAME_PICS_SMTP_PORT' -DefaultValue '587'
    $smtpTo=[string]$smtpToSetting.Value; $smtpServer=[string]$smtpServerSetting.Value; $smtpPort=587
    if ([string]::IsNullOrWhiteSpace($smtpTo) -or -not [int]::TryParse([string]$smtpPortSetting.Value,[ref]$smtpPort)) { return 'E-mail notification skipped: SMTP environment configuration is incomplete or invalid.' }
    try { $credential=Get-WindowsGenericCredential -Target $credentialTarget } catch { return "E-mail notification skipped: unable to read Credential Manager target '$credentialTarget': $($_.Exception.Message)" }
    if (-not $credential -or [string]::IsNullOrWhiteSpace($credential.UserName)) { return "E-mail notification skipped: Credential Manager target '$credentialTarget' is missing or incomplete." }
    $mail=$null;$client=$null;$attachment=$null
    try {
        $mail=New-Object System.Net.Mail.MailMessage
        $mail.From=$credential.UserName
        $mail.To.Add($smtpTo)
        $mail.Subject='Mass Rename execution complete'
        $runtimeText=([string][int][Math]::Floor($Runtime.TotalHours)).PadLeft(2,'0') + ':' + ([string]$Runtime.Minutes).PadLeft(2,'0') + ':' + ([string]$Runtime.Seconds).PadLeft(2,'0')
        $mail.Body="Mass Rename is complete.`r`n`r`nTarget directory : $TargetDirectory`r`nOperations       : $Total`r`nSucceeded        : $Succeeded`r`nFailed           : $Failed`r`nRuntime          : $runtimeText`r`nExecution log    : $ExecutionLog"
        if (Test-Path -LiteralPath $ExecutionLog) { $attachment=New-Object System.Net.Mail.Attachment($ExecutionLog);[void]$mail.Attachments.Add($attachment) }
        $client=New-Object System.Net.Mail.SmtpClient($smtpServer,$smtpPort)
        $client.EnableSsl=$true;$client.UseDefaultCredentials=$false;$client.Timeout=30000
        $client.Credentials=New-Object System.Net.NetworkCredential($credential.UserName,$credential.GetNetworkCredential().Password)
        $client.Send($mail)
        return "Notification e-mail sent to '$smtpTo'."
    }
    catch {
        $messages=[System.Collections.Generic.List[string]]::new();$e=$_.Exception
        while($e){if($e.Message){$messages.Add($e.Message)};$e=$e.InnerException}
        return "E-mail notification failed: $($messages -join ' --> ')"
    }
    finally { if($mail){$mail.Dispose()};if($client){$client.Dispose()};$credential=$null }
}

function Invoke-MassRenamePlan {
    param(
        [Parameter(Mandatory)][object[]]$Plan,
        [string]$TargetDirectory = ''
    )
    if ($Plan.Count -eq 0) { return $null }
    $logFile = New-MassOutputFile -Type 'Executed_Renames' -Directory $script:MassExecutedDir
    $records = [System.Collections.Generic.List[object]]::new()
    $ordered = @($Plan | Where-Object Type -eq 'File') + @($Plan | Where-Object Type -eq 'Directory' | Sort-Object Depth -Descending)
    $start=Get-Date;$index=0
    try {
        foreach ($item in $ordered) {
            $index++
            Update-MassRenameProgress -Activity 'Mass Rename' -CurrentOperation $item.OldPath -Current $index -Total $ordered.Count -StartTime $start
            $status='Skipped';$errorMessage=$null
            try {
                if (-not (Test-Path -LiteralPath $item.OldPath)) { throw "Source no longer exists: $($item.OldPath)" }
                $immediateTarget = if ($item.PSObject.Properties['ImmediateNewPath']) { [string]$item.ImmediateNewPath } else { Join-Path ([System.IO.Path]::GetDirectoryName($item.OldPath.TrimEnd([char[]]'\/'))) $item.NewLeaf }
                if ((Test-Path -LiteralPath $immediateTarget) -and ($item.OldPath -cne $immediateTarget)) { throw "Target already exists: $immediateTarget" }
                if ($item.OldPath -ieq $immediateTarget -and $item.OldPath -cne $immediateTarget) {
                    $parent=[System.IO.Path]::GetDirectoryName($item.OldPath.TrimEnd([char[]]'\/'))
                    $tempLeaf="__massrename_$([guid]::NewGuid().ToString('N'))"
                    if($item.Type -eq 'File'){$tempLeaf += [System.IO.Path]::GetExtension($item.OldPath)}
                    Rename-Item -LiteralPath $item.OldPath -NewName $tempLeaf -ErrorAction Stop
                    Rename-Item -LiteralPath (Join-Path $parent $tempLeaf) -NewName $item.NewLeaf -ErrorAction Stop
                } else { Rename-Item -LiteralPath $item.OldPath -NewName $item.NewLeaf -ErrorAction Stop }
                $status='Rename Success'
            } catch { $status='Rename Failed';$errorMessage=$_.Exception.Message }
            $records.Add([pscustomobject]@{Timestamp=(Get-Date).ToString('o');Type=$item.Type;OldPath=$item.OldPath;NewPath=$item.NewPath;NewLeaf=$item.NewLeaf;Status=$status;Error=$errorMessage})|Out-Null
        }
    }
    finally { Complete-MassRenameProgress }
    $records | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $logFile -Encoding utf8
    $runtime=(Get-Date)-$start
    $ok=@($records|Where-Object Status -eq 'Rename Success').Count;$failed=@($records|Where-Object Status -eq 'Rename Failed').Count
    $mailStatus=Send-MassRenameEmail -TargetDirectory $TargetDirectory -ExecutionLog $logFile -Total $records.Count -Succeeded $ok -Failed $failed -Runtime $runtime
    return [pscustomobject]@{LogFile=$logFile;Records=@($records);Runtime=$runtime;Succeeded=$ok;Failed=$failed;MailStatus=$mailStatus}
}

function Undo-LatestMassRenames {
    $latest = Get-ChildItem -LiteralPath $script:MassExecutedDir -File -Filter '*.json' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $latest) { throw 'No executed Mass Rename log is available to undo.' }
    $records = @(Get-Content -LiteralPath $latest.FullName -Raw | ConvertFrom-Json)
    $undoFile = New-MassOutputFile -Type 'Undone_Renames' -Directory $script:MassUndoneDir
    $undoRecords = [System.Collections.Generic.List[object]]::new()
    $successful = @($records | Where-Object Status -eq 'Rename Success')
    [array]::Reverse($successful)
    $pathMappings=[System.Collections.Generic.List[object]]::new()
    foreach ($record in $successful) {
        $status='Skipped';$errorMessage=$null
        try {
            $currentPath=Convert-MassPathToProjectedPath -Path ([string]$record.NewPath) -DirectoryPlan @($pathMappings)
            if (-not (Test-Path -LiteralPath $currentPath)) { throw "Current renamed path not found: $currentPath" }
            $oldTarget=Convert-MassPathToProjectedPath -Path ([string]$record.OldPath) -DirectoryPlan @($pathMappings)
            if (Test-Path -LiteralPath $oldTarget) { throw "Original path already exists: $oldTarget" }
            $oldLeaf=[System.IO.Path]::GetFileName(([string]$record.OldPath).TrimEnd([char[]]'\/'))
            Rename-Item -LiteralPath $currentPath -NewName $oldLeaf -ErrorAction Stop
            $restoredPath=Join-Path ([System.IO.Path]::GetDirectoryName($currentPath.TrimEnd([char[]]'\/'))) $oldLeaf
            $status='Undo Success'
            if ($record.Type -eq 'Directory') { $pathMappings.Add([pscustomobject]@{OldPath=[string]$record.NewPath;NewPath=$restoredPath})|Out-Null }
        } catch { $status='Undo Failed';$errorMessage=$_.Exception.Message }
        $undoRecords.Add([pscustomobject]@{Timestamp=(Get-Date).ToString('o');OldPath=$record.NewPath;NewPath=$record.OldPath;Status=$status;Error=$errorMessage})|Out-Null
    }
    $undoRecords|ConvertTo-Json -Depth 4|Set-Content -LiteralPath $undoFile -Encoding utf8
    Move-Item -LiteralPath $latest.FullName -Destination ($latest.FullName+'.undone') -Force
    return $undoFile
}

# ----------------------- Picture Workflow Preview / Undo ----------------------

function New-PictureOperation {
    param(
        [Parameter(Mandatory)][string]$Type,
        [string]$OldPath,
        [string]$NewPath,
        [string]$BackupPath,
        [string]$Details,
        [string]$Status = 'Planned'
    )
    [pscustomobject][ordered]@{
        Type       = $Type
        OldPath    = $OldPath
        NewPath    = $NewPath
        BackupPath = $BackupPath
        Details    = $Details
        Status     = $Status
        Error      = $null
    }
}

function Get-PicturePreviewPlan {
    param(
        [Parameter(Mandatory)][string]$InputFolder,
        [Parameter(Mandatory)][ValidateSet(0,1)][int]$RenameMode,
        [Parameter(Mandatory)][bool]$ExtractArchivesOnly,
        [Parameter(Mandatory)][bool]$RenameFolders,
        [Parameter(Mandatory)][bool]$MoveLqCs,
        [Parameter(Mandatory)][int]$FolderStartNumber,
        [string]$FolderPrefix = 'Set'
    )
    if (-not (Test-Path -LiteralPath $InputFolder -PathType Container)) { throw "Input folder does not exist: $InputFolder" }

    $FolderPrefix = Get-PictureFolderPrefix -Prefix $FolderPrefix

    $plan = [System.Collections.Generic.List[object]]::new()
    $archives = @(Get-ChildItem -LiteralPath $InputFolder -File -Recurse | Where-Object { $_.Extension -in $script:CompressedFileTypes })
    foreach ($archive in $archives) {
        $newName = (($archive.Name -replace $script:NameSanitizeRegex, '.') -replace '^\.+', '')
        $newBaseName = (($archive.BaseName -replace $script:NameSanitizeRegex, '.') -replace '^\.+', '')
        $processedArchive = Join-Path $archive.DirectoryName $newName
        $targetPath = Join-Path $archive.DirectoryName $newBaseName
        $details = if (Test-Path -LiteralPath $targetPath) { 'BLOCKED: extraction target already exists; execution will skip this archive to preserve safe undo.' } else { 'Archive contents are not inspected during preview; operations created from extracted contents cannot be predicted until execution.' }
        $plan.Add((New-PictureOperation -Type 'ExtractArchive' -OldPath $archive.FullName -NewPath $targetPath -Details $details)) | Out-Null
        if ($archive.FullName -cne $processedArchive) {
            $plan.Add((New-PictureOperation -Type 'SanitizeArchiveName' -OldPath $archive.FullName -NewPath $processedArchive -Details 'Temporary execution name; undo restores the original archive name.')) | Out-Null
        }
    }

    if ($ExtractArchivesOnly) { return $plan }

    $filesToDelete = @(Get-ChildItem -LiteralPath $InputFolder -File -Recurse | Where-Object {
        $_.Extension -notin $script:ExcludedFileTypes -and
        $_.Extension -notin $script:ImageFileTypes -and
        $_.Name -notlike '*changelog*' -and
        $_.Extension -ne '.txt'
    })
    foreach ($file in $filesToDelete) {
        $plan.Add((New-PictureOperation -Type 'StageDeleteFile' -OldPath $file.FullName -Details 'Will be moved to the run backup area, not permanently deleted.')) | Out-Null
    }

    $emptyDirs = @(Get-ChildItem -LiteralPath $InputFolder -Directory -Recurse |
        Sort-Object { $_.FullName.Length } -Descending |
        Where-Object { -not (Get-ChildItem -LiteralPath $_.FullName -Force | Select-Object -First 1) })
    foreach ($dir in $emptyDirs) {
        $plan.Add((New-PictureOperation -Type 'RemoveEmptyDirectory' -OldPath $dir.FullName -Details 'Undo recreates the directory if it is still absent.')) | Out-Null
    }

    $parents = @(Get-PictureParentFolders -InputFolder $InputFolder -RenameMode $RenameMode)
    foreach ($parent in $parents) {
        $leafFolders = @(Get-ChildItem -LiteralPath $parent.FullName -Directory -Recurse | Where-Object {
            (Get-ChildItem -LiteralPath $_.FullName -File | Select-Object -First 1) -and
            -not (Get-ChildItem -LiteralPath $_.FullName -Directory | Select-Object -First 1)
        })
        foreach ($leaf in $leafFolders) {
            $destinationName = "$($leaf.Parent.Name) - $($leaf.Name)"
            $destination = Join-Path $parent.Parent.FullName $destinationName
            $details = if (Test-Path -LiteralPath $destination) { 'BLOCKED: destination already exists.' } else { 'Directory move.' }
            $plan.Add((New-PictureOperation -Type 'MoveDirectory' -OldPath $leaf.FullName -NewPath $destination -Details $details)) | Out-Null
        }
    }

    if ($MoveLqCs) {
        $pictures = @($parents | ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -File -Recurse } | Where-Object { $_.Extension -in $script:ImageFileTypes })
        foreach ($picture in $pictures) {
            $image = $null
            try {
                $image = [System.Drawing.Image]::FromFile($picture.FullName)
                $width = $image.Width; $height = $image.Height
                $aspectRatio = if ($width -gt 0) { $height / $width } else { 0 }
                $image.Dispose(); $image = $null
                $isLowQuality = (($width -lt 900 -and $height -lt 900) -or ($picture.Name -match '(?i)cover'))
                $isContactSheet = (($aspectRatio -ge 2) -or ($picture.Name -match '(?i)contactsheet|(?:^|[_\-. ])cs(?:[_\-. ]|$)'))
                if (-not $isLowQuality -and -not $isContactSheet) { continue }
                $category = if ($isLowQuality) { $script:LowQualityFolderName } else { $script:ContactSheetsFolderName }
                $destinationFolder = Join-Path (Join-Path $picture.Directory.Parent.FullName $category) $picture.Directory.Name
                $destinationFile = Join-Path $destinationFolder $picture.Name
                $plan.Add((New-PictureOperation -Type 'MoveFile' -OldPath $picture.FullName -NewPath $destinationFile -Details "$category classification based on current file location.")) | Out-Null
            }
            catch {
                if ($image) { $image.Dispose() }
                $plan.Add((New-PictureOperation -Type 'PreviewError' -OldPath $picture.FullName -Details $_.Exception.Message -Status 'Error')) | Out-Null
            }
        }
    }

    if ($RenameFolders) {
        $folders = @(Get-PictureParentFolders -InputFolder $InputFolder -RenameMode $RenameMode | Sort-Object FullName)
        $currentParent = $null; $number = $FolderStartNumber
        foreach ($folder in $folders) {
            if ($currentParent -ne $folder.Parent.FullName) { $currentParent = $folder.Parent.FullName; $number = $FolderStartNumber }
            $folderCount = @(Get-ChildItem -LiteralPath $folder.Parent.FullName -Directory).Count
            $padding = [Math]::Max(1, $folderCount.ToString().Length)
            $newName = "$($folder.Parent.Name) - $FolderPrefix $($number.ToString().PadLeft($padding, '0'))"
            $targetPath = Join-Path $folder.Parent.FullName $newName
            if ($folder.FullName -cne $targetPath) {
                $plan.Add((New-PictureOperation -Type 'RenameDirectory' -OldPath $folder.FullName -NewPath $targetPath -Details 'Calculated from the current pre-execution layout.')) | Out-Null
            }
            $number++
        }
    }

    # Use the same folder set as execution: source directory + eligible descendants.
    # For preview, project each current folder path through planned RenameDirectory operations
    # so file names inherit the folder name that will exist when Rename-PictureFiles runs.
    $directoryRenameMap = @(
        $plan | Where-Object { $_.Type -eq 'RenameDirectory' -and $_.OldPath -and $_.NewPath } |
            Sort-Object { $_.OldPath.Length } -Descending
    )

    $foldersForFiles = @(
        Get-Item -LiteralPath $InputFolder
        Get-ChildItem -LiteralPath $InputFolder -Directory -Recurse |
            Where-Object { $_.Name -notin $script:ExcludedFolderNames }
    ) | Sort-Object { Get-NaturalSortKey $_.FullName }
    foreach ($folder in $foldersForFiles) {
        $files = @(Get-ChildItem -LiteralPath $folder.FullName -File | Where-Object { $_.Extension -in $script:ImageFileTypes } | Sort-Object { Get-NaturalSortKey $_.Name })
        if ($files.Count -eq 0) { continue }

        $projectedFolderPath = $folder.FullName
        foreach ($rename in $directoryRenameMap) {
            $oldFolderPath = $rename.OldPath.TrimEnd('\\')
            if ($projectedFolderPath -ieq $oldFolderPath) {
                $projectedFolderPath = $rename.NewPath
                break
            }
            $prefix = $oldFolderPath + '\\'
            if ($projectedFolderPath.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                $relativePart = $projectedFolderPath.Substring($prefix.Length)
                $projectedFolderPath = Join-Path $rename.NewPath $relativePart
                break
            }
        }

        $projectedFolderName = [System.IO.Path]::GetFileName($projectedFolderPath.TrimEnd('\\'))
        $padding = [Math]::Max(1, $files.Count.ToString().Length); $counter = 1
        foreach ($file in $files) {
            $newName = "$projectedFolderName`_$($counter.ToString().PadLeft($padding, '0'))$($file.Extension)"
            $newName = (($newName -replace $script:NameSanitizeRegex, '.') -replace '\.+', '.') -replace '^\.+', ''
            $target = Join-Path $projectedFolderPath $newName
            if ($file.FullName -cne $target) {
                $details = if ($projectedFolderPath -cne $folder.FullName) {
                    'Calculated using the planned parent-directory rename.'
                }
                else {
                    'Calculated from the current pre-execution layout.'
                }
                $plan.Add((New-PictureOperation -Type 'RenameFile' -OldPath $file.FullName -NewPath $target -Details $details)) | Out-Null
            }
            $counter++
        }
    }
    return $plan
}

function Format-PicturePreview {
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Plan)
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('================ PICTURE WORKFLOW PREVIEW ================') | Out-Null
    $lines.Add("Planned/discovered operations: $($Plan.Count)") | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('NOTE: This is a non-destructive discovery preview. Archive contents are not extracted, and later-stage paths can change after earlier moves/renames. Execution recalculates each stage against the actual filesystem.') | Out-Null
    $lines.Add('') | Out-Null
    foreach ($op in $Plan) {
        if ($op.Type -eq 'RenameFile' -and $op.NewPath) {
            $oldLeaf = [System.IO.Path]::GetFileName($op.OldPath)
            $newLeaf = [System.IO.Path]::GetFileName($op.NewPath)
            $lines.Add("[RenameFile] $oldLeaf -> $newLeaf") | Out-Null
            $lines.Add("    $($op.OldPath) -> $($op.NewPath)") | Out-Null
        }
        else {
            $arrow = if ($op.NewPath) { " -> $($op.NewPath)" } else { '' }
            $lines.Add("[$($op.Type)] $($op.OldPath)$arrow") | Out-Null
        }
        if ($op.Details) { $lines.Add("    $($op.Details)") | Out-Null }
        $lines.Add('') | Out-Null
    }
    $lines.Add('==========================================================') | Out-Null
    return ($lines -join "`r`n")
}

function New-PictureExecutionContext {
    param([Parameter(Mandatory)][string]$InputFolder)
    $batchId = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
    $backupRoot = Join-Path $script:PictureBackupDir $batchId
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    return @{
        BatchId     = $batchId
        InputFolder = $InputFolder
        BackupRoot  = $backupRoot
        Operations  = [System.Collections.Generic.List[object]]::new()
    }
}

function Add-PictureExecutedOperation {
    param(
        [Parameter(Mandatory)][hashtable]$Context,
        [Parameter(Mandatory)][string]$Type,
        [string]$OldPath,
        [string]$NewPath,
        [string]$BackupPath,
        [string]$Details
    )
    $Context.Operations.Add([pscustomobject][ordered]@{
        Sequence   = $Context.Operations.Count + 1
        Type       = $Type
        OldPath    = $OldPath
        NewPath    = $NewPath
        BackupPath = $BackupPath
        Details    = $Details
        Timestamp  = (Get-Date).ToString('o')
        Status     = 'Success'
        Error      = $null
    }) | Out-Null
}

function Save-PictureExecutionLog {
    param([Parameter(Mandatory)][hashtable]$Context, [Parameter(Mandatory)][hashtable]$Stats, [Parameter(Mandatory)][string]$ChangeLog)
    $path = Join-Path $script:PictureExecutedDir ("picture_{0}.json" -f $Context.BatchId)
    [ordered]@{
        Version     = 1
        BatchId     = $Context.BatchId
        Created     = (Get-Date).ToString('o')
        InputFolder = $Context.InputFolder
        ChangeLog   = $ChangeLog
        BackupRoot  = $Context.BackupRoot
        Stats       = $Stats
        Operations  = @($Context.Operations)
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $path -Encoding utf8
    return $path
}

function Move-PictureItemToBackup {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$InputFolder,
        [Parameter(Mandatory)][string]$BackupRoot,
        [Parameter(Mandatory)][string]$Category
    )
    $relative = Get-RelativePathSafe -BasePath $InputFolder -Path $Path
    $backupPath = Join-Path (Join-Path $BackupRoot $Category) $relative
    $parent = [System.IO.Path]::GetDirectoryName($backupPath)
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    if (Test-Path -LiteralPath $backupPath) { throw "Backup collision: $backupPath" }
    Move-Item -LiteralPath $Path -Destination $backupPath -ErrorAction Stop
    return $backupPath
}

function Update-PictureWorkflowProgress {
    param(
        [Parameter(Mandatory)][string]$Activity,
        [string]$CurrentOperation = '',
        [int]$Current = 0,
        [int]$Total = 0,
        [int]$Id = 1,
        [int]$ParentId = -1,
        [datetime]$StartTime = [datetime]::MinValue
    )

    $percent = if ($Total -gt 0) { [Math]::Min(100, [Math]::Max(0, [Math]::Round(($Current / $Total) * 100))) } else { 0 }
    $status = if ($Total -gt 0) { "Processing $Current of $Total ($percent%)" } else { $CurrentOperation }

    $etaText = $null
    if ($StartTime -ne [datetime]::MinValue -and $Current -gt 0 -and $Total -ge $Current) {
        $elapsed = (Get-Date) - $StartTime
        $averageSeconds = $elapsed.TotalSeconds / $Current
        $remainingSeconds = [Math]::Max(0, ($Total - $Current) * $averageSeconds)
        $remaining = [TimeSpan]::FromSeconds($remainingSeconds)
        $estimatedCompletion = (Get-Date).AddSeconds($remainingSeconds)
        $elapsedHours = [string][int][Math]::Floor($elapsed.TotalHours)
        $elapsedText = $elapsedHours.PadLeft(2,'0') + ':' + ([string]$elapsed.Minutes).PadLeft(2,'0') + ':' + ([string]$elapsed.Seconds).PadLeft(2,'0')
        $remainingHours = [string][int][Math]::Floor($remaining.TotalHours)
        $remainingText = $remainingHours.PadLeft(2,'0') + ':' + ([string]$remaining.Minutes).PadLeft(2,'0') + ':' + ([string]$remaining.Seconds).PadLeft(2,'0')
        $etaText = "Elapsed $elapsedText | Remaining $remainingText | ETA $($estimatedCompletion.ToString('HH:mm:ss'))"
        $status += " | $etaText"
    }

    $params = @{
        Id              = $Id
        Activity        = $Activity
        Status          = $status
        PercentComplete = $percent
    }
    if ($ParentId -ge 0) { $params.ParentId = $ParentId }
    if (-not [string]::IsNullOrWhiteSpace($CurrentOperation)) { $params.CurrentOperation = $CurrentOperation }
    Write-Progress @params

    # Throttle GUI updates to reduce flicker during fast-running stages.
    $now = Get-Date
    $guiRefreshDue = (-not $script:PictureLastGuiRefresh) -or (($now - $script:PictureLastGuiRefresh).TotalMilliseconds -ge 500) -or ($Current -ge $Total -and $Total -gt 0)

    if ($guiRefreshDue) {
        if ($script:PictureProgressBar -and -not $script:PictureProgressBar.IsDisposed) {
            $script:PictureProgressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Continuous
            $script:PictureProgressBar.Value = $percent
        }
        if ($etaText -and $script:PictureEtaLabel -and -not $script:PictureEtaLabel.IsDisposed) {
            if ($script:PictureEtaLabel.Text -ne $etaText) { $script:PictureEtaLabel.Text = $etaText }
        }
        if ($script:PictureProgressLabel -and -not $script:PictureProgressLabel.IsDisposed) {
            $labelText = if ($Total -gt 0) { "$Activity - Processing $Current of $Total ($percent%)" } else { $Activity }
            if (-not [string]::IsNullOrWhiteSpace($CurrentOperation)) { $labelText += " - $CurrentOperation" }
            if ($script:PictureProgressLabel.Text -ne $labelText) { $script:PictureProgressLabel.Text = $labelText }
        }
        $script:PictureLastGuiRefresh = $now
        [System.Windows.Forms.Application]::DoEvents()
    }
}

function Complete-PictureWorkflowProgress {
    Write-Progress -Id 3 -Completed -ErrorAction SilentlyContinue
    Write-Progress -Id 2 -Completed -ErrorAction SilentlyContinue
    Write-Progress -Id 1 -Completed -ErrorAction SilentlyContinue
    if ($script:PictureProgressBar -and -not $script:PictureProgressBar.IsDisposed) { $script:PictureProgressBar.Value = 100 }
    if ($script:PictureEtaLabel -and -not $script:PictureEtaLabel.IsDisposed) { $script:PictureEtaLabel.Text = '' }
    if ($script:PictureProgressLabel -and -not $script:PictureProgressLabel.IsDisposed) { $script:PictureProgressLabel.Text = 'Picture Workflow complete.' }
    $script:PictureLastGuiRefresh = $null
    [System.Windows.Forms.Application]::DoEvents()
}

function Remove-UnwantedPictureItemsTransactional {
    param([string]$InputFolder,[string]$ChangeLog,[hashtable]$Context,[hashtable]$Stats)
    $filesToDelete = @(Get-ChildItem -LiteralPath $InputFolder -File -Recurse | Where-Object {
        $_.Extension -notin $script:ExcludedFileTypes -and $_.Extension -notin $script:ImageFileTypes -and $_.Name -notlike '*changelog*' -and $_.Extension -ne '.txt'
    })
    $emptyDirs = @(Get-ChildItem -LiteralPath $InputFolder -Directory -Recurse | Sort-Object { $_.FullName.Length } -Descending | Where-Object { -not (Get-ChildItem -LiteralPath $_.FullName -Force | Select-Object -First 1) })
    $total = $filesToDelete.Count + $emptyDirs.Count
    $current = 0
    $stageStart = Get-Date

    foreach ($file in $filesToDelete) {
        $current++
        Update-PictureWorkflowProgress -Activity 'Cleaning source tree' -CurrentOperation $file.FullName -Current $current -Total $total -Id 2 -ParentId 1
        try {
            $old = $file.FullName
            $backup = Move-PictureItemToBackup -Path $old -InputFolder $InputFolder -BackupRoot $Context.BackupRoot -Category 'DeletedFiles'
            Add-PictureExecutedOperation -Context $Context -Type 'StageDeleteFile' -OldPath $old -BackupPath $backup
            Write-ChangeLogEntry -Path $ChangeLog -Message ("Staged deleted file for undo: '{0}';'{1}'" -f $old, $backup)
        } catch { $Stats.Errors++; $Stats.ErrorDetails.Add("Delete '$($file.FullName)': $($_.Exception.Message)")|Out-Null; Write-ChangeLogEntry -Path $ChangeLog -Message ("ERROR staging deleted file: '{0}'; {1}" -f $file.FullName,$_.Exception.Message) }
    }
    foreach ($dir in $emptyDirs) {
        $current++
        Update-PictureWorkflowProgress -Activity 'Cleaning source tree' -CurrentOperation $dir.FullName -Current $current -Total $total -Id 2 -ParentId 1
        try { $old=$dir.FullName; Remove-Item -LiteralPath $old -Force; Add-PictureExecutedOperation -Context $Context -Type 'RemoveEmptyDirectory' -OldPath $old; Write-ChangeLogEntry -Path $ChangeLog -Message ("Deleted empty directory: '{0}'" -f $old) }
        catch { $Stats.Errors++; $Stats.ErrorDetails.Add("Delete directory '$($dir.FullName)': $($_.Exception.Message)")|Out-Null; Write-ChangeLogEntry -Path $ChangeLog -Message ("ERROR deleting empty directory: '{0}'; {1}" -f $dir.FullName,$_.Exception.Message) }
    }
    Write-Progress -Id 2 -Completed -ErrorAction SilentlyContinue
}

function Expand-PictureArchivesTransactional {
    param([string]$InputFolder,[string]$ChangeLog,[hashtable]$Stats,[hashtable]$Context)
    $archives = @(Get-ChildItem -LiteralPath $InputFolder -File -Recurse | Where-Object { $_.Extension -in $script:CompressedFileTypes })
    $Stats.ArchivesFound = $archives.Count
    $expand7Zip = Get-Command Expand-7Zip -ErrorAction SilentlyContinue
    foreach ($archive in $archives) {
        $originalPath = $archive.FullName; $renamedArchive = $null; $targetPath = $null
        try {
            $newName=(($archive.Name -replace $script:NameSanitizeRegex,'.') -replace '^\.+',''); $newBaseName=(($archive.BaseName -replace $script:NameSanitizeRegex,'.') -replace '^\.+','')
            $renamedArchive=Join-Path $archive.DirectoryName $newName; $targetPath=Join-Path $archive.DirectoryName $newBaseName
            if (Test-Path -LiteralPath $targetPath) { throw "Extraction target already exists; archive skipped to preserve safe undo: $targetPath" }
            if ($originalPath -cne $renamedArchive) { Rename-Item -LiteralPath $originalPath -NewName $newName -ErrorAction Stop }
            if ($expand7Zip) { Expand-7Zip -ArchiveFileName $renamedArchive -TargetPath $targetPath }
            elseif ([System.IO.Path]::GetExtension($renamedArchive) -ieq '.zip') { Expand-Archive -LiteralPath $renamedArchive -DestinationPath $targetPath -Force }
            else { throw "Expand-7Zip is required for '$([System.IO.Path]::GetExtension($renamedArchive))' archives." }
            $backup = Move-PictureItemToBackup -Path $renamedArchive -InputFolder $InputFolder -BackupRoot $Context.BackupRoot -Category 'Archives'
            Add-PictureExecutedOperation -Context $Context -Type 'ExtractArchive' -OldPath $originalPath -NewPath $targetPath -BackupPath $backup -Details $renamedArchive
            $Stats.ArchivesExtracted++; Write-ChangeLogEntry -Path $ChangeLog -Message ("Extracted archive:'{0}';'{1}' (archive retained for undo at '{2}')" -f $originalPath,$targetPath,$backup)
        } catch {
            # The extraction target was guaranteed not to exist before this operation. If a later
            # step fails (for example, staging the archive in the undo area), remove the newly
            # created extraction directory so a failed archive operation does not become partial.
            if ($targetPath -and (Test-Path -LiteralPath $targetPath)) { try { Remove-Item -LiteralPath $targetPath -Recurse -Force -ErrorAction SilentlyContinue } catch {} }
            if ($renamedArchive -and $renamedArchive -cne $originalPath -and (Test-Path -LiteralPath $renamedArchive) -and -not (Test-Path -LiteralPath $originalPath)) { try { Rename-Item -LiteralPath $renamedArchive -NewName ([System.IO.Path]::GetFileName($originalPath)) -ErrorAction SilentlyContinue } catch {} }
            $Stats.Errors++;$Stats.ErrorDetails.Add("Archive '$originalPath': $($_.Exception.Message)")|Out-Null;Write-ChangeLogEntry -Path $ChangeLog -Message ("ERROR extracting archive: '{0}'; {1}" -f $originalPath,$_.Exception.Message)
        }
    }
    Write-Progress -Id 2 -Completed -ErrorAction SilentlyContinue
}

function Move-PictureLeafFoldersTransactional {
    param([string]$InputFolder,[int]$RenameMode,[string]$ChangeLog,[hashtable]$Stats,[hashtable]$Context)
    $parents=@(Get-PictureParentFolders -InputFolder $InputFolder -RenameMode $RenameMode)
    $leafItems = [System.Collections.Generic.List[object]]::new()
    foreach($parent in $parents){
        $leafFolders=@(Get-ChildItem -LiteralPath $parent.FullName -Directory -Recurse|Where-Object{(Get-ChildItem -LiteralPath $_.FullName -File|Select-Object -First 1)-and -not(Get-ChildItem -LiteralPath $_.FullName -Directory|Select-Object -First 1)})
        foreach($leaf in $leafFolders){$leafItems.Add([pscustomobject]@{Parent=$parent;Leaf=$leaf})}
    }
    $stageStart=Get-Date
    $index=0
    foreach($item in $leafItems){
        $index++
        $parent=$item.Parent;$leaf=$item.Leaf
        Update-PictureWorkflowProgress -Activity 'Moving leaf folders' -CurrentOperation $leaf.FullName -Current $index -Total $leafItems.Count -Id 2 -ParentId 1
        try{$destination=Join-Path $parent.Parent.FullName "$($leaf.Parent.Name) - $($leaf.Name)";if(Test-Path -LiteralPath $destination){throw "Destination already exists: $destination"};$old=$leaf.FullName;Move-Item -LiteralPath $old -Destination $destination -ErrorAction Stop;Add-PictureExecutedOperation -Context $Context -Type 'MoveDirectory' -OldPath $old -NewPath $destination;Write-ChangeLogEntry -Path $ChangeLog -Message ("Moved directory:'{0}';'{1}'" -f $old,$destination)}catch{$Stats.Errors++;$Stats.ErrorDetails.Add("Move directory '$($leaf.FullName)': $($_.Exception.Message)")|Out-Null;Write-ChangeLogEntry -Path $ChangeLog -Message ("ERROR moving directory: '{0}'; {1}" -f $leaf.FullName,$_.Exception.Message)}
    }
    Write-Progress -Id 2 -Completed -ErrorAction SilentlyContinue
}

function Move-LowQualityAndContactSheetsTransactional {
    param([string]$InputFolder,[int]$RenameMode,[string]$ChangeLog,[hashtable]$Stats,[hashtable]$Context)
    $parents=@(Get-PictureParentFolders -InputFolder $InputFolder -RenameMode $RenameMode);$pictures=@($parents|ForEach-Object{Get-ChildItem -LiteralPath $_.FullName -File -Recurse}|Where-Object{$_.Extension -in $script:ImageFileTypes})
    $stageStart=Get-Date;$pictureIndex=0
    foreach($picture in $pictures){
        $pictureIndex++
        Update-PictureWorkflowProgress -Activity 'Classifying LQ / contact sheets' -CurrentOperation $picture.FullName -Current $pictureIndex -Total $pictures.Count -Id 2 -ParentId 1 -StartTime $stageStart
        $image=$null;try{$image=[System.Drawing.Image]::FromFile($picture.FullName);$w=$image.Width;$h=$image.Height;$ratio=if($w -gt 0){$h/$w}else{0};$image.Dispose();$image=$null;$isLq=(($w -lt 900 -and $h -lt 900)-or($picture.Name -match '(?i)cover'));$isCs=(($ratio -ge 2)-or($picture.Name -match '(?i)contactsheet|(?:^|[_\-. ])cs(?:[_\-. ]|$)'));if(-not $isLq -and -not $isCs){continue};$category=if($isLq){$script:LowQualityFolderName}else{$script:ContactSheetsFolderName};$destFolder=Join-Path (Join-Path $picture.Directory.Parent.FullName $category) $picture.Directory.Name;if(-not(Test-Path -LiteralPath $destFolder)){New-Item -ItemType Directory -Path $destFolder -Force|Out-Null;Add-PictureExecutedOperation -Context $Context -Type 'CreateDirectory' -NewPath $destFolder};$dest=Join-Path $destFolder $picture.Name;if(Test-Path -LiteralPath $dest){throw "Destination already exists: $dest"};$old=$picture.FullName;Move-Item -LiteralPath $old -Destination $dest -ErrorAction Stop;Add-PictureExecutedOperation -Context $Context -Type 'MoveFile' -OldPath $old -NewPath $dest;if($isLq){$Stats.LowQualityMoved++}else{$Stats.ContactSheetsMoved++};Write-ChangeLogEntry -Path $ChangeLog -Message ("Moved file:'{0}';'{1}'" -f $old,$dest)}catch{if($image){$image.Dispose()};$Stats.Errors++;$Stats.ErrorDetails.Add("Image '$($picture.FullName)': $($_.Exception.Message)")|Out-Null;Write-ChangeLogEntry -Path $ChangeLog -Message ("ERROR processing image: '{0}'; {1}" -f $picture.FullName,$_.Exception.Message)}
    }
    Write-Progress -Id 2 -Completed -ErrorAction SilentlyContinue
}

function Rename-PictureFoldersTransactional {
    param([string]$InputFolder,[int]$RenameMode,[int]$StartNumber,[string]$Prefix='Set',[string]$ChangeLog,[hashtable]$Stats,[hashtable]$Context)
    $Prefix=Get-PictureFolderPrefix -Prefix $Prefix
    $folders=@(Get-PictureParentFolders -InputFolder $InputFolder -RenameMode $RenameMode|Sort-Object FullName)
    $currentParent=$null
    $number=$StartNumber
    $folderIndex=0
    $stageStart=Get-Date
    foreach($folder in $folders){
        $folderIndex++
        Update-PictureWorkflowProgress -Activity 'Renaming folders' -CurrentOperation $folder.FullName -Current $folderIndex -Total $folders.Count -Id 2 -ParentId 1 -StartTime $stageStart
        try{
            if($currentParent -ne $folder.Parent.FullName){$currentParent=$folder.Parent.FullName;$number=$StartNumber}
            $count=@(Get-ChildItem -LiteralPath $folder.Parent.FullName -Directory).Count
            $padding=[Math]::Max(1,$count.ToString().Length)
            $newName="$($folder.Parent.Name) - $Prefix $($number.ToString().PadLeft($padding,'0'))"
            $target=Join-Path $folder.Parent.FullName $newName
            $old=$folder.FullName
            if($old -cne $target){
                if($old -ieq $target){
                    $tempName="__renamepics_$([guid]::NewGuid().ToString('N'))"
                    Rename-Item -LiteralPath $old -NewName $tempName -ErrorAction Stop
                    Rename-Item -LiteralPath (Join-Path $folder.Parent.FullName $tempName) -NewName $newName -ErrorAction Stop
                }elseif(Test-Path -LiteralPath $target){
                    throw "Destination already exists: $target"
                }else{
                    Rename-Item -LiteralPath $old -NewName $newName -ErrorAction Stop
                }
                Add-PictureExecutedOperation -Context $Context -Type 'RenameDirectory' -OldPath $old -NewPath $target
                $Stats.FoldersRenamed++
                Write-ChangeLogEntry -Path $ChangeLog -Message ("Renamed directory: '{0}';'{1}'" -f $old,$newName)
            }
            $number++
        }catch{
            $Stats.Errors++
            $Stats.ErrorDetails.Add("Rename directory '$($folder.FullName)': $($_.Exception.Message)")|Out-Null
            Write-ChangeLogEntry -Path $ChangeLog -Message ("ERROR renaming directory: '{0}'; {1}" -f $folder.FullName,$_.Exception.Message)
        }
    }
    Write-Progress -Id 2 -Completed -ErrorAction SilentlyContinue
}

function Rename-PictureFilesTransactional {
    param([string]$InputFolder,[string]$ChangeLog,[hashtable]$Stats,[hashtable]$Context)
    # Include $InputFolder itself so files stored directly in the selected source are renamed.
    $folders=@(Get-Item -LiteralPath $InputFolder;Get-ChildItem -LiteralPath $InputFolder -Directory -Recurse|Where-Object{$_.Name -notin $script:ExcludedFolderNames})|Sort-Object{Get-NaturalSortKey $_.FullName}
    $Stats.FilesFound=@($folders|ForEach-Object{Get-ChildItem -LiteralPath $_.FullName -File}|Where-Object{$_.Extension -in $script:ImageFileTypes}).Count
    $totalFileIndex=0
    $stageStart=Get-Date
    foreach($folder in $folders){
        $files=@(Get-ChildItem -LiteralPath $folder.FullName -File|Where-Object{$_.Extension -in $script:ImageFileTypes}|Sort-Object{Get-NaturalSortKey $_.Name})
        if($files.Count -eq 0){continue}
        $padding=[Math]::Max(1,$files.Count.ToString().Length)
        $counter=1
        $folderFileIndex=0
        $folderStageStart=Get-Date
        foreach($file in $files){
            $totalFileIndex++
            $folderFileIndex++
            Update-PictureWorkflowProgress -Activity 'Renaming files' -CurrentOperation $file.FullName -Current $totalFileIndex -Total $Stats.FilesFound -Id 2 -ParentId 1 -StartTime $stageStart
            Update-PictureWorkflowProgress -Activity 'Current folder' -CurrentOperation $folder.FullName -Current $folderFileIndex -Total $files.Count -Id 3 -ParentId 2
            try{
                $newName="$($folder.Name)_$($counter.ToString().PadLeft($padding,'0'))$($file.Extension)"
                $newName=(($newName -replace $script:NameSanitizeRegex,'.') -replace '\.+','.') -replace '^\.+',''
                $target=Join-Path $file.DirectoryName $newName
                $old=$file.FullName
                if($old -cne $target){
                    if($old -ieq $target){
                        $tempName="__renamepics_$([guid]::NewGuid().ToString('N'))$($file.Extension)"
                        Rename-Item -LiteralPath $old -NewName $tempName -ErrorAction Stop
                        Rename-Item -LiteralPath (Join-Path $file.DirectoryName $tempName) -NewName $newName -ErrorAction Stop
                    }elseif(Test-Path -LiteralPath $target){
                        throw "Destination already exists: $target"
                    }else{
                        Rename-Item -LiteralPath $old -NewName $newName -ErrorAction Stop
                    }
                    Add-PictureExecutedOperation -Context $Context -Type 'RenameFile' -OldPath $old -NewPath $target
                    $Stats.FilesRenamed++
                    Write-ChangeLogEntry -Path $ChangeLog -Message ("Renamed file: '{0}';'{1}'" -f $old,$newName)
                }
            }catch{
                $Stats.Errors++
                $Stats.ErrorDetails.Add("Rename file '$($file.FullName)': $($_.Exception.Message)")|Out-Null
                Write-ChangeLogEntry -Path $ChangeLog -Message ("ERROR renaming file: '{0}'; {1}" -f $file.FullName,$_.Exception.Message)
            }
            $counter++
        }
        Write-Progress -Id 3 -Completed -ErrorAction SilentlyContinue
    }
    Write-Progress -Id 2 -Completed -ErrorAction SilentlyContinue
}

function Invoke-PictureWorkflow {
    param([string]$InputFolder,[ValidateSet(0,1)][int]$RenameMode,[bool]$ExtractArchivesOnly,[bool]$RenameFolders,[bool]$MoveLqCs,[int]$FolderStartNumber,[string]$FolderPrefix='Set',[bool]$ShutdownAfter,[System.Windows.Forms.TextBox]$OutputBox)
    if(-not(Test-Path -LiteralPath $InputFolder -PathType Container)){throw "Input folder does not exist: $InputFolder"}
    $date=Get-Date -Format 'yyyyMMdd_HHmmss'
    $safeBase=((Get-Item -LiteralPath $InputFolder).BaseName -replace $script:NameSanitizeRegex,'_')
    $changeLog=Join-Path $InputFolder "changelog_${safeBase}_${date}.txt"
    $stats=@{FilesFound=0;FilesRenamed=0;FoldersRenamed=0;ArchivesFound=0;ArchivesExtracted=0;LowQualityMoved=0;ContactSheetsMoved=0;Errors=0;ErrorDetails=[System.Collections.Generic.List[string]]::new()}
    $context=New-PictureExecutionContext -InputFolder $InputFolder
    $start=Get-Date
    $OutputBox.AppendText("Starting picture workflow...`r`nChangelog: $changeLog`r`nTransaction: $($context.BatchId)`r`n`r`n")
    [System.Windows.Forms.Application]::DoEvents()

    try {
        Update-PictureWorkflowProgress -Activity 'Picture Workflow' -CurrentOperation 'Extracting archives' -Current 1 -Total 7 -Id 1
        Expand-PictureArchivesTransactional -InputFolder $InputFolder -ChangeLog $changeLog -Stats $stats -Context $context

        if(-not $ExtractArchivesOnly){
            Update-PictureWorkflowProgress -Activity 'Picture Workflow' -CurrentOperation 'Cleaning source tree' -Current 2 -Total 7 -Id 1
            Remove-UnwantedPictureItemsTransactional -InputFolder $InputFolder -ChangeLog $changeLog -Context $context -Stats $stats

            Update-PictureWorkflowProgress -Activity 'Picture Workflow' -CurrentOperation 'Moving leaf folders' -Current 3 -Total 7 -Id 1
            Move-PictureLeafFoldersTransactional -InputFolder $InputFolder -RenameMode $RenameMode -ChangeLog $changeLog -Stats $stats -Context $context
            Remove-UnwantedPictureItemsTransactional -InputFolder $InputFolder -ChangeLog $changeLog -Context $context -Stats $stats

            Update-PictureWorkflowProgress -Activity 'Picture Workflow' -CurrentOperation 'Classifying LQ / contact sheets' -Current 4 -Total 7 -Id 1
            if($MoveLqCs){Move-LowQualityAndContactSheetsTransactional -InputFolder $InputFolder -RenameMode $RenameMode -ChangeLog $changeLog -Stats $stats -Context $context}
            Remove-UnwantedPictureItemsTransactional -InputFolder $InputFolder -ChangeLog $changeLog -Context $context -Stats $stats

            Update-PictureWorkflowProgress -Activity 'Picture Workflow' -CurrentOperation 'Renaming folders' -Current 5 -Total 7 -Id 1
            if($RenameFolders){Rename-PictureFoldersTransactional -InputFolder $InputFolder -RenameMode $RenameMode -StartNumber $FolderStartNumber -Prefix $FolderPrefix -ChangeLog $changeLog -Stats $stats -Context $context}
            Remove-UnwantedPictureItemsTransactional -InputFolder $InputFolder -ChangeLog $changeLog -Context $context -Stats $stats

            Update-PictureWorkflowProgress -Activity 'Picture Workflow' -CurrentOperation 'Renaming files' -Current 6 -Total 7 -Id 1
            Rename-PictureFilesTransactional -InputFolder $InputFolder -ChangeLog $changeLog -Stats $stats -Context $context
            Remove-UnwantedPictureItemsTransactional -InputFolder $InputFolder -ChangeLog $changeLog -Context $context -Stats $stats
        }

        Update-PictureWorkflowProgress -Activity 'Picture Workflow' -CurrentOperation 'Finalizing logs and notification' -Current 7 -Total 7 -Id 1
        $runtime=(Get-Date)-$start
        "`nProcess time: $([string]::Format('{0:hh\:mm\:ss}',$runtime)) (hh:mm:ss)"|Out-File -LiteralPath $changeLog -Append -Encoding utf8
        $executionLog=Save-PictureExecutionLog -Context $context -Stats $stats -ChangeLog $changeLog
        Send-PictureWorkflowEmail -Stats $stats -InputFolder $InputFolder -ChangeLog $changeLog -Runtime $runtime
        if($ShutdownAfter -and $stats.Errors -eq 0){Stop-Computer}
        return @{Stats=$stats;ChangeLog=$changeLog;Runtime=$runtime;ExecutionLog=$executionLog;BatchId=$context.BatchId}
    }
    finally {
        Complete-PictureWorkflowProgress
    }
}

function Undo-LatestPictureWorkflow {
    $latest=Get-ChildItem -LiteralPath $script:PictureExecutedDir -File -Filter '*.json' -ErrorAction SilentlyContinue|Sort-Object LastWriteTime -Descending|Select-Object -First 1
    if(-not $latest){throw 'No Picture Workflow execution is available to undo.'}
    $batch=Get-Content -LiteralPath $latest.FullName -Raw|ConvertFrom-Json;$results=[System.Collections.Generic.List[object]]::new();$ops=@($batch.Operations)|Sort-Object Sequence -Descending
    foreach($op in $ops){$status='Restored';$err=$null;try{switch($op.Type){
        'RenameFile' { if(Test-Path -LiteralPath $op.NewPath){if(Test-Path -LiteralPath $op.OldPath){throw "Original path already exists: $($op.OldPath)"};$p=[System.IO.Path]::GetDirectoryName($op.OldPath);if($p -and -not(Test-Path -LiteralPath $p)){New-Item -ItemType Directory -Path $p -Force|Out-Null};Move-Item -LiteralPath $op.NewPath -Destination $op.OldPath -ErrorAction Stop}else{$status='Skipped - current path missing'} }
        'MoveFile' { if(Test-Path -LiteralPath $op.NewPath){if(Test-Path -LiteralPath $op.OldPath){throw "Original path already exists: $($op.OldPath)"};$p=[System.IO.Path]::GetDirectoryName($op.OldPath);if($p -and -not(Test-Path -LiteralPath $p)){New-Item -ItemType Directory -Path $p -Force|Out-Null};Move-Item -LiteralPath $op.NewPath -Destination $op.OldPath -ErrorAction Stop}else{$status='Skipped - current path missing'} }
        'RenameDirectory' { if(Test-Path -LiteralPath $op.NewPath){if(Test-Path -LiteralPath $op.OldPath){throw "Original path already exists: $($op.OldPath)"};$p=[System.IO.Path]::GetDirectoryName($op.OldPath);if($p -and -not(Test-Path -LiteralPath $p)){New-Item -ItemType Directory -Path $p -Force|Out-Null};Move-Item -LiteralPath $op.NewPath -Destination $op.OldPath -ErrorAction Stop}else{$status='Skipped - current path missing'} }
        'MoveDirectory' { if(Test-Path -LiteralPath $op.NewPath){if(Test-Path -LiteralPath $op.OldPath){throw "Original path already exists: $($op.OldPath)"};$p=[System.IO.Path]::GetDirectoryName($op.OldPath);if($p -and -not(Test-Path -LiteralPath $p)){New-Item -ItemType Directory -Path $p -Force|Out-Null};Move-Item -LiteralPath $op.NewPath -Destination $op.OldPath -ErrorAction Stop}else{$status='Skipped - current path missing'} }
        'CreateDirectory' { if(Test-Path -LiteralPath $op.NewPath){if(Get-ChildItem -LiteralPath $op.NewPath -Force|Select-Object -First 1){$status='Skipped - directory not empty'}else{Remove-Item -LiteralPath $op.NewPath -Force}}else{$status='Already absent'} }
        'RemoveEmptyDirectory' { if(-not(Test-Path -LiteralPath $op.OldPath)){New-Item -ItemType Directory -Path $op.OldPath -Force|Out-Null}else{$status='Already exists'} }
        'StageDeleteFile' { if(Test-Path -LiteralPath $op.BackupPath){if(Test-Path -LiteralPath $op.OldPath){throw "Restore target already exists: $($op.OldPath)"};$p=[System.IO.Path]::GetDirectoryName($op.OldPath);if($p -and -not(Test-Path -LiteralPath $p)){New-Item -ItemType Directory -Path $p -Force|Out-Null};Move-Item -LiteralPath $op.BackupPath -Destination $op.OldPath -ErrorAction Stop}else{$status='Skipped - backup missing'} }
        'ExtractArchive' { if(Test-Path -LiteralPath $op.NewPath){Remove-Item -LiteralPath $op.NewPath -Recurse -Force -ErrorAction Stop};if(Test-Path -LiteralPath $op.BackupPath){if(Test-Path -LiteralPath $op.OldPath){throw "Archive restore target already exists: $($op.OldPath)"};$p=[System.IO.Path]::GetDirectoryName($op.OldPath);if($p -and -not(Test-Path -LiteralPath $p)){New-Item -ItemType Directory -Path $p -Force|Out-Null};Move-Item -LiteralPath $op.BackupPath -Destination $op.OldPath -ErrorAction Stop}else{$status='Skipped - archive backup missing'} }
        default { $status="Skipped - unsupported operation $($op.Type)" }
    }}catch{$status='Error';$err=$_.Exception.Message};$results.Add([pscustomobject]@{Sequence=$op.Sequence;Type=$op.Type;OldPath=$op.OldPath;NewPath=$op.NewPath;Status=$status;Error=$err})|Out-Null}
    $undoPath=Join-Path $script:PictureUndoneDir ("undo_{0}_{1}.json" -f $batch.BatchId,(Get-Date -Format 'yyyyMMdd_HHmmss'))
    [ordered]@{BatchId=$batch.BatchId;UndoTime=(Get-Date).ToString('o');SourceExecutionLog=$latest.FullName;Results=@($results)}|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $undoPath -Encoding utf8
    Rename-Item -LiteralPath $latest.FullName -NewName ($latest.Name + '.undone') -Force
    if($batch.BackupRoot -and(Test-Path -LiteralPath $batch.BackupRoot)){if(-not(Get-ChildItem -LiteralPath $batch.BackupRoot -Recurse -Force|Select-Object -First 1)){Remove-Item -LiteralPath $batch.BackupRoot -Recurse -Force}}
    return $undoPath
}


# ------------------------------- GUI -----------------------------------------

function New-Label { param([string]$Text,[int]$X,[int]$Y,[int]$W=180,[int]$H=24) $c=[System.Windows.Forms.Label]::new();$c.Text=$Text;$c.AutoSize=$false;$c.SetBounds($X,$Y,$W,$H);$c.TextAlign='MiddleRight';return $c }
function New-TextBox { param([int]$X,[int]$Y,[int]$W=450,[string]$Text='') $c=[System.Windows.Forms.TextBox]::new();$c.SetBounds($X,$Y,$W,24);$c.Text=$Text;return $c }
function New-Button { param([string]$Text,[int]$X,[int]$Y,[int]$W=100,[int]$H=28) $c=[System.Windows.Forms.Button]::new();$c.Text=$Text;$c.SetBounds($X,$Y,$W,$H);return $c }
function New-CheckBox { param([string]$Text,[int]$X,[int]$Y,[bool]$Checked=$false,[int]$W=0) $c=[System.Windows.Forms.CheckBox]::new();$c.Text=$Text;$c.AutoSize=$true;$c.Location=[System.Drawing.Point]::new($X,$Y);if($W -gt 0){$c.MaximumSize=[System.Drawing.Size]::new($W,0)};$c.Checked=$Checked;return $c }

function Show-MainGui {
    $settings = Load-MassSettings
    $form = [System.Windows.Forms.Form]::new()
    $form.Text = "$script:AppName v$script:Version"
    $form.StartPosition = 'CenterScreen'
    $form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi
    $form.AutoScaleDimensions = [System.Drawing.SizeF]::new(96.0,96.0)
    $form.Font = [System.Drawing.SystemFonts]::MessageBoxFont
    $form.Size = [System.Drawing.Size]::new(1180, 840)
    $form.MinimumSize = [System.Drawing.Size]::new(1080, 760)

    $tabs = [System.Windows.Forms.TabControl]::new()
    $tabs.Dock = 'Fill'
    $form.Controls.Add($tabs)

    # Picture Workflow tab
    $picTab = [System.Windows.Forms.TabPage]::new('Picture Workflow')
    $tabs.TabPages.Add($picTab)

    # Use a docked two-region layout so the preview/output area always consumes
    # all remaining tab space when the application window is resized.
    $picControls = [System.Windows.Forms.Panel]::new()
    $picControls.Dock = [System.Windows.Forms.DockStyle]::Top
    $picControls.Height = 337
    $picTab.Controls.Add($picControls)

    $picOutputPanel = [System.Windows.Forms.Panel]::new()
    $picOutputPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $picOutputPanel.Padding = [System.Windows.Forms.Padding]::new(20, 8, 20, 20)
    $picTab.Controls.Add($picOutputPanel)
    $picOutputPanel.BringToFront()

    $y=20
    $picControls.Controls.Add((New-Label 'Source directory:' 20 $y 180))
    $picPath = New-TextBox 210 $y 650
    $picControls.Controls.Add($picPath)
    $picBrowse = New-Button 'Browse...' 870 ($y-2) 90
    $picBrowse.Add_Click({ $p=Select-Folder -Description 'Select a directory containing images' -SelectedPath $picPath.Text; if($p){$picPath.Text=$p} })
    $picControls.Controls.Add($picBrowse)
    $y+=40
    $picControls.Controls.Add((New-Label 'Directory level:' 20 $y 180))
    $picLevel=[System.Windows.Forms.ComboBox]::new();$picLevel.SetBounds(210,$y,280,24);$picLevel.DropDownStyle='DropDownList';[void]$picLevel.Items.Add('Level 1 - folders directly under source');[void]$picLevel.Items.Add('Level 2 - their subfolders');$picLevel.SelectedIndex=0;$picControls.Controls.Add($picLevel)
    $y+=38
    $picExtractOnly=New-CheckBox 'Extract archives only' 210 $y $false;$picControls.Controls.Add($picExtractOnly)
    $y+=30
    $picRenameFolders=New-CheckBox 'Rename folders to "<Parent> - <Prefix> NN"' 210 $y $false 365;$picControls.Controls.Add($picRenameFolders)
    $picControls.Controls.Add((New-Label 'Prefix:' 575 $y 55))
    $picPrefix=New-TextBox 630 $y 90 'Set';$picControls.Controls.Add($picPrefix)
    $picControls.Controls.Add((New-Label 'Start number:' 735 $y 95))
    $picStart=[System.Windows.Forms.NumericUpDown]::new();$picStart.SetBounds(835,$y,80,24);$picStart.Minimum=1;$picStart.Maximum=99999;$picStart.Value=1;$picControls.Controls.Add($picStart)
    $y+=30
    $picMoveLqCs=New-CheckBox 'Move low-quality / contact-sheet images to LQ and CS folders' 210 $y $false 500;$picControls.Controls.Add($picMoveLqCs)
    $y+=30
    $picShutdown=New-CheckBox 'Shut down computer after successful workflow completion' 210 $y $false 450;$picControls.Controls.Add($picShutdown)
    $y+=42
    $picPreview=New-Button 'Preview' 210 $y 110 32;$picControls.Controls.Add($picPreview)
    $picRun=New-Button 'Run Picture Workflow' 330 $y 180 32;$picRun.Enabled=$true;$picControls.Controls.Add($picRun)
    $picUndo=New-Button 'Undo Latest' 520 $y 120 32;$picControls.Controls.Add($picUndo)
    $picOpenLog=New-Button 'Open latest changelog' 650 $y 170 32;$picOpenLog.Enabled=$false;$picControls.Controls.Add($picOpenLog)
    $y+=42
    $picEtaLabel=[System.Windows.Forms.Label]::new();$picEtaLabel.SetBounds(210,$y,760,20);$picEtaLabel.Text='';$picEtaLabel.AutoEllipsis=$true;$picControls.Controls.Add($picEtaLabel)
    $y+=22
    $picProgressLabel=[System.Windows.Forms.Label]::new();$picProgressLabel.SetBounds(210,$y,760,20);$picProgressLabel.Text='Ready';$picProgressLabel.AutoEllipsis=$true;$picControls.Controls.Add($picProgressLabel)
    $y+=22
    $picProgress=[System.Windows.Forms.ProgressBar]::new();$picProgress.SetBounds(210,$y,760,18);$picProgress.Minimum=0;$picProgress.Maximum=100;$picProgress.Value=0;$picProgress.Style=[System.Windows.Forms.ProgressBarStyle]::Continuous;$picControls.Controls.Add($picProgress)
    $script:PictureEtaLabel=$picEtaLabel;$script:PictureProgressLabel=$picProgressLabel;$script:PictureProgressBar=$picProgress;$script:PictureLastGuiRefresh=$null

    $picOutput=[System.Windows.Forms.TextBox]::new()
    $picOutput.Dock=[System.Windows.Forms.DockStyle]::Fill
    $picOutput.Multiline=$true
    $picOutput.ReadOnly=$true
    $picOutput.ScrollBars=[System.Windows.Forms.ScrollBars]::Vertical
    $picOutput.WordWrap=$true
    $picOutput.Font=[System.Drawing.Font]::new('Consolas',9.0)
    $picOutputPanel.Controls.Add($picOutput)
    $script:LatestPictureLog=$null;$script:CurrentPicturePreviewSignature=$null;$script:CurrentPicturePreviewFile=$null
    $getPictureSettings = {
        [ordered]@{InputFolder=$picPath.Text;RenameMode=$picLevel.SelectedIndex;ExtractArchivesOnly=$picExtractOnly.Checked;RenameFolders=$picRenameFolders.Checked;MoveLqCs=$picMoveLqCs.Checked;FolderStartNumber=[int]$picStart.Value;FolderPrefix=(Get-PictureFolderPrefix -Prefix $picPrefix.Text);ShutdownAfter=$picShutdown.Checked}
    }
    $getPictureSignature = { param($Settings) ($Settings | ConvertTo-Json -Compress) }
    $picOpenLog.Add_Click({ if($script:LatestPictureLog -and (Test-Path -LiteralPath $script:LatestPictureLog)){Invoke-Item -LiteralPath $script:LatestPictureLog} })
    $picPreview.Add_Click({
        try {
            $settings=&$getPictureSettings
            if(-not (Test-Path -LiteralPath $settings.InputFolder -PathType Container)){throw 'Select a valid source directory.'}
            $picPreview.Enabled=$false;$picRun.Enabled=$false;$picOutput.Clear();[System.Windows.Forms.Application]::DoEvents()
            $plan=@(Get-PicturePreviewPlan -InputFolder $settings.InputFolder -RenameMode $settings.RenameMode -ExtractArchivesOnly $settings.ExtractArchivesOnly -RenameFolders $settings.RenameFolders -MoveLqCs $settings.MoveLqCs -FolderStartNumber $settings.FolderStartNumber -FolderPrefix $settings.FolderPrefix)
            $picOutput.Text=Format-PicturePreview -Plan $plan
            $previewPath=Join-Path $script:PicturePreviewDir ("picture_preview_{0}.json" -f (Get-Date -Format 'yyyyMMdd_HHmmss_fff'))
            [ordered]@{Created=(Get-Date).ToString('o');Settings=$settings;Operations=$plan}|ConvertTo-Json -Depth 7|Set-Content -LiteralPath $previewPath -Encoding utf8
            $script:CurrentPicturePreviewFile=$previewPath;$script:CurrentPicturePreviewSignature=&$getPictureSignature $settings;$picRun.Enabled=$true
            $picOutput.AppendText("`r`nPreview file: $previewPath`r`n")
        } catch { Show-ErrorMessage -Message $_.Exception.Message } finally { $picPreview.Enabled=$true;$picRun.Enabled=$true }
    })
    $picRun.Add_Click({
        try {
            $settings=&$getPictureSettings
            if(-not (Test-Path -LiteralPath $settings.InputFolder -PathType Container)){throw 'Select a valid source directory.'}
            $warning = "Execute the Picture Workflow?`r`n`r`nPreview is optional. Deleted files and processed archives will be staged in the undo backup so the latest run can be reversed."
            if(-not (Confirm-Action -Message $warning -Title 'Run Picture Workflow')){return}
            $picRun.Enabled=$false;$picPreview.Enabled=$false;$picOutput.AppendText("`r`nStarting execution...`r`n");[System.Windows.Forms.Application]::DoEvents()
            $result=Invoke-PictureWorkflow -InputFolder $settings.InputFolder -RenameMode $settings.RenameMode -ExtractArchivesOnly $settings.ExtractArchivesOnly -RenameFolders $settings.RenameFolders -MoveLqCs $settings.MoveLqCs -FolderStartNumber $settings.FolderStartNumber -FolderPrefix $settings.FolderPrefix -ShutdownAfter $settings.ShutdownAfter -OutputBox $picOutput
            $script:LatestPictureLog=$result.ChangeLog;$picOpenLog.Enabled=$true;$script:CurrentPicturePreviewSignature=$null
            $s=$result.Stats
            $picOutput.AppendText("`r`n================ EXECUTION SUMMARY ================`r`nFiles found              : $($s.FilesFound)`r`nFiles renamed            : $($s.FilesRenamed)`r`nFolders renamed          : $($s.FoldersRenamed)`r`nArchives found/extracted : $($s.ArchivesFound) / $($s.ArchivesExtracted)`r`nLow-quality moved        : $($s.LowQualityMoved)`r`nContact sheets moved     : $($s.ContactSheetsMoved)`r`nErrors                    : $($s.Errors)`r`nRuntime                   : $([string]::Format('{0:hh\:mm\:ss}',$result.Runtime))`r`nChangelog                 : $($result.ChangeLog)`r`nTransaction log           : $($result.ExecutionLog)`r`n===================================================`r`n")
            $picUndo.Enabled=$true
            if($s.Errors -eq 0){Show-InfoMessage -Message 'Picture Workflow completed successfully. The latest run can be undone from this tab.' -Title 'Complete'}else{Show-InfoMessage -Message "Picture Workflow completed with $($s.Errors) error(s). Review the changelog before using Undo Latest." -Title 'Complete with errors'}
        } catch { Show-ErrorMessage -Message $_.Exception.Message } finally { $picPreview.Enabled=$true;$picRun.Enabled=$true }
    })
    $picUndo.Add_Click({
        try {
            if(-not(Confirm-Action -Message 'Undo the latest Picture Workflow run? This reverses recorded renames/moves, restores staged deletions and archives, and removes extraction directories created by that run.' -Title 'Undo Picture Workflow')){return}
            $picUndo.Enabled=$false;$picRun.Enabled=$false;[System.Windows.Forms.Application]::DoEvents()
            $undoLog=Undo-LatestPictureWorkflow
            $picOutput.Text="Latest Picture Workflow run undo completed.`r`nUndo log: $undoLog`r`n`r`nReview the undo log for any skipped/conflicting items."
            $script:CurrentPicturePreviewSignature=$null
            Show-InfoMessage -Message 'Latest Picture Workflow undo completed. Review the undo log for any skipped or conflicting items.' -Title 'Undo complete'
        } catch { Show-ErrorMessage -Message $_.Exception.Message } finally { $picRun.Enabled=$true;$picUndo.Enabled=[bool](Get-ChildItem -LiteralPath $script:PictureExecutedDir -File -Filter '*.json' -ErrorAction SilentlyContinue|Select-Object -First 1) }
    })
    $picUndo.Enabled=[bool](Get-ChildItem -LiteralPath $script:PictureExecutedDir -File -Filter '*.json' -ErrorAction SilentlyContinue|Select-Object -First 1)

    # Mass Rename tab
    $massTab=[System.Windows.Forms.TabPage]::new('Mass Rename');$tabs.TabPages.Add($massTab)
    $massControls=[System.Windows.Forms.Panel]::new();$massControls.Dock=[System.Windows.Forms.DockStyle]::Top;$massControls.Height=315;$massTab.Controls.Add($massControls)
    $massOutputPanel=[System.Windows.Forms.Panel]::new();$massOutputPanel.Dock=[System.Windows.Forms.DockStyle]::Fill;$massOutputPanel.Padding=[System.Windows.Forms.Padding]::new(20,8,20,20);$massTab.Controls.Add($massOutputPanel);$massOutputPanel.BringToFront()
    $y=18
    $massControls.Controls.Add((New-Label 'Root directory:' 20 $y 190));$massPath=New-TextBox 220 $y 690 ([string]$settings.TargetDirectory);$massControls.Controls.Add($massPath);$massBrowse=New-Button 'Browse...' 925 ($y-2) 90;$massBrowse.Add_Click({$p=Select-Folder -Description 'Select Mass Rename root directory' -SelectedPath $massPath.Text;if($p){$massPath.Text=$p}});$massControls.Controls.Add($massBrowse)
    $y+=36
    $massDrill=New-CheckBox 'Drill into subfolders' 220 $y ([bool]$settings.DrillDownFolders);$massControls.Controls.Add($massDrill)
    $massFiles=New-CheckBox 'Include file names' 430 $y ([bool]$settings.IncludeFileNames);$massControls.Controls.Add($massFiles)
    $massFolders=New-CheckBox 'Include folder names' 635 $y ([bool]$settings.IncludeFolderNames);$massControls.Controls.Add($massFolders)
    $y+=32
    $massExt=New-CheckBox 'Include file extensions in transformation' 220 $y ([bool]$settings.IncludeExtensions);$massControls.Controls.Add($massExt)
    $massTitle=New-CheckBox 'Format titles automatically' 560 $y ([bool]$settings.FormatTitles);$massControls.Controls.Add($massTitle)
    $massCase=New-CheckBox 'Case sensitive' 815 $y ([bool]$settings.CaseSensitive);$massControls.Controls.Add($massCase)
    $y+=36;$massControls.Controls.Add((New-Label 'File/folder must contain:' 20 $y 190));$massContain=New-TextBox 220 $y 300 ([string]$settings.MustContain);$massControls.Controls.Add($massContain)
    $y+=34;$massControls.Controls.Add((New-Label 'Action:' 20 $y 190));$massAction=[System.Windows.Forms.ComboBox]::new();$massAction.SetBounds(220,$y,300,24);$massAction.DropDownStyle='DropDownList';$actions=@('Replace Characters:','Append Beginning:','Append End:','Append After:','Append Before:','Replace Beginning Characters:','Replace End Characters:','Delete Everything After:','Delete Everything Before:','Insert at Position:','Replace Non-Latin Characters:','To Lower Case:','To Upper Case:','AddSpaceBetweenCamelCase:');foreach($a in $actions){[void]$massAction.Items.Add($a)};$massAction.SelectedItem=[string]$settings.Action;if($massAction.SelectedIndex -lt 0){$massAction.SelectedIndex=0};$massControls.Controls.Add($massAction)
    $massControls.Controls.Add((New-Label 'Parameter 1:' 535 $y 100));$massW1=New-TextBox 640 $y 160 ([string]$settings.Word1);$massControls.Controls.Add($massW1);$massControls.Controls.Add((New-Label 'Parameter 2:' 805 $y 100));$massW2=New-TextBox 910 $y 130 ([string]$settings.Word2);$massControls.Controls.Add($massW2)
    $y+=42;$previewBtn=New-Button 'Preview' 220 $y 110 30;$executeBtn=New-Button 'Perform Renames' 340 $y 140 30;$executeBtn.Enabled=$true;$showBtn=New-Button 'Show List' 490 $y 110 30;$showBtn.Enabled=$false;$undoBtn=New-Button 'Undo Latest' 610 $y 120 30;$massControls.Controls.AddRange(@($previewBtn,$executeBtn,$showBtn,$undoBtn))
    $y+=38
    $massEta=[System.Windows.Forms.Label]::new();$massEta.SetBounds(220,$y,820,20);$massEta.Text='';$massEta.AutoEllipsis=$true;$massControls.Controls.Add($massEta)
    $y+=22
    $massStatus=[System.Windows.Forms.Label]::new();$massStatus.SetBounds(220,$y,820,20);$massStatus.Text='Ready';$massStatus.AutoEllipsis=$true;$massControls.Controls.Add($massStatus)
    $y+=22
    $massProgress=[System.Windows.Forms.ProgressBar]::new();$massProgress.SetBounds(220,$y,820,18);$massProgress.Minimum=0;$massProgress.Maximum=100;$massProgress.Value=0;$massProgress.Style=[System.Windows.Forms.ProgressBarStyle]::Continuous;$massControls.Controls.Add($massProgress)
    $script:MassEtaLabel=$massEta;$script:MassProgressLabel=$massStatus;$script:MassProgressBar=$massProgress;$script:MassLastGuiRefresh=$null

    $massPreview=[System.Windows.Forms.TextBox]::new();$massPreview.Dock=[System.Windows.Forms.DockStyle]::Fill;$massPreview.Multiline=$true;$massPreview.ReadOnly=$true;$massPreview.ScrollBars=[System.Windows.Forms.ScrollBars]::Vertical;$massPreview.WordWrap=$true;$massPreview.Font=[System.Drawing.Font]::new('Consolas',9.0);$massOutputPanel.Controls.Add($massPreview)
    $script:CurrentMassPlan=@();$script:CurrentMassSimulation=$null;$script:LatestMassExecuted=$null

    $getMassSettings = { @{TargetDirectory=$massPath.Text;DrillDownFolders=$massDrill.Checked;IncludeFileNames=$massFiles.Checked;IncludeFolderNames=$massFolders.Checked;IncludeExtensions=$massExt.Checked;FormatTitles=$massTitle.Checked;CaseSensitive=$massCase.Checked;MustContain=$massContain.Text;Action=[string]$massAction.SelectedItem;Word1=$massW1.Text;Word2=$massW2.Text} }
    $updateParamVisibility = {
        $action=[string]$massAction.SelectedItem
        $uses1=$action -in @('Replace Characters:','Append After:','Append Before:','Replace Beginning Characters:','Replace End Characters:','Delete Everything After:','Delete Everything Before:','Insert at Position:')
        $uses2=$action -in @('Replace Characters:','Append Beginning:','Append End:','Append After:','Append Before:','Replace Beginning Characters:','Replace End Characters:','Insert at Position:','Replace Non-Latin Characters:')
        $massW1.Enabled=$uses1;$massW2.Enabled=$uses2
    }
    $massAction.Add_SelectedIndexChanged({&$updateParamVisibility});&$updateParamVisibility

    $previewBtn.Add_Click({
        try{
            $s=&$getMassSettings;Save-MassSettings -Settings $s;$plan=@(Get-MassRenamePlan -Settings $s);$script:CurrentMassPlan=$plan;$massPreview.Text=Format-MassPlanPreview -Plan $plan
            if($script:CurrentMassSimulation -and(Test-Path -LiteralPath $script:CurrentMassSimulation)){Remove-Item -LiteralPath $script:CurrentMassSimulation -Force}
            if($plan.Count -gt 0){$sim=New-MassOutputFile -Type 'Simulation' -Directory $script:MassSimulationDir;$plan|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $sim -Encoding utf8;$script:CurrentMassSimulation=$sim;$showBtn.Enabled=$true}else{$showBtn.Enabled=$false}
        }catch{Show-ErrorMessage -Message $_.Exception.Message}
    })
    $showBtn.Add_Click({if($script:CurrentMassSimulation -and(Test-Path -LiteralPath $script:CurrentMassSimulation)){Invoke-Item -LiteralPath $script:CurrentMassSimulation}})
    $executeBtn.Add_Click({
        try{
            $s=&$getMassSettings;Save-MassSettings -Settings $s;$plan=@(Get-MassRenamePlan -Settings $s)
            if($plan.Count -eq 0){throw 'No matching rename operations were found with the current settings.'}
            if(-not(Confirm-Action -Message "Perform $($plan.Count) rename operation(s)?`r`n`r`nPreview is optional; this plan was recalculated from the current settings." -Title 'Perform Renames')){return}
            $executeBtn.Enabled=$false;$previewBtn.Enabled=$false;$massPreview.AppendText("`r`nStarting Mass Rename execution...`r`n");[System.Windows.Forms.Application]::DoEvents()
            $result=Invoke-MassRenamePlan -Plan $plan -TargetDirectory $s.TargetDirectory;$script:LatestMassExecuted=$result.LogFile
            $massPreview.AppendText("`r`n================ EXECUTION SUMMARY ================`r`nOperations : $($plan.Count)`r`nSucceeded  : $($result.Succeeded)`r`nFailed     : $($result.Failed)`r`nRuntime    : $($result.Runtime)`r`nLog        : $($result.LogFile)`r`nMail       : $($result.MailStatus)`r`n===================================================`r`n")
            $undoBtn.Enabled=$true
        }catch{Show-ErrorMessage -Message $_.Exception.Message}finally{$executeBtn.Enabled=$true;$previewBtn.Enabled=$true}
    })
    $undoBtn.Add_Click({
        try{if(-not(Confirm-Action -Message 'Undo the latest successfully executed Mass Rename batch?' -Title 'Undo Renames')){return};$log=Undo-LatestMassRenames;$massPreview.Text="Latest Mass Rename batch was reversed.`r`n`r`nUndo log: $log"}
        catch{Show-ErrorMessage -Message $_.Exception.Message}
        finally{$executeBtn.Enabled=$true;$undoBtn.Enabled=[bool](Get-ChildItem -LiteralPath $script:MassExecutedDir -File -Filter '*.json' -ErrorAction SilentlyContinue|Select-Object -First 1)}
    })
    $undoBtn.Enabled=[bool](Get-ChildItem -LiteralPath $script:MassExecutedDir -File -Filter '*.json' -ErrorAction SilentlyContinue|Select-Object -First 1)


    [void]$form.ShowDialog()
}

Show-MainGui
