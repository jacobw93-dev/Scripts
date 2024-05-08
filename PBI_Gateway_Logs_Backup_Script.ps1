cls
hostname

$Days = 7

# Define arrays for source and target folders
$Sourcefolders = @("\\VSSAPMSG01S\Users\svc_MSDataGatewaySbx\AppData\Local\Microsoft\On-premises data gateway\",
                  "\\VSSAPMSG01P\Users\svc_MSDataGateway\AppData\Local\Microsoft\On-premises data gateway\")
$Targetfolders = @("D:\XJAKA1108\PBI_Gateway_VSSAPMSG01S\",
                  "D:\XJAKA1108\PBI_Gateway_VSSAPMSG01P\")

# Function to perform the file copy operations
function CopyFiles($Sourcefolder, $Targetfolder) {
    $LogFilesSize = "{0:N2} GB" -f ((Get-ChildItem -Path $Sourcefolder -Recurse | Measure-Object -Property Length -Sum).Sum / 1GB)
    Write-Host "`n$LogFilesSize`n" -ForegroundColor Yellow
    
    $query = Get-ChildItem $Sourcefolder -Recurse -Exclude "Spooler" | Where-Object {($_.LastWriteTime -gt [datetime]::Now.AddDays(-$Days)) -and ($_.FullName -notlike "*\Spooler\*")}
    $query | ForEach-Object {
        $sourcePath = $_.FullName
        $relativePath = $sourcePath.Substring($Sourcefolder.Length)
        $destinationPath = Join-Path -Path $Targetfolder -ChildPath $relativePath
        $targetDirectory = Split-Path -Path $destinationPath -Parent
        if (-not (Test-Path -Path $targetDirectory -PathType Container)) {
            New-Item -Path $targetDirectory -ItemType Directory -Verbose
        }
        $destinationFile = Join-Path -Path $targetDirectory -ChildPath $_.Name
        Copy-Item $sourcePath -Destination $destinationFile -Force -Verbose
    }
}


# Loop through source and target folders
for ($i = 0; $i -lt $Sourcefolders.Count; $i++) {
    CopyFiles $Sourcefolders[$i] $Targetfolders[$i]
}
