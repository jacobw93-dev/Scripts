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
Write-Host "Changelog              : $ChangelogFile"
Write-Host "File rename entries    : $($FileOperations.Count)"
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
