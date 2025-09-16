[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Define log file
$CurrentDate = Get-Date -format "yyyyMMdd_HHmmss"
$OutputDirectory = 'C:\PowershellScript\PBI - failed refreshes'
$LogFile = "$OutputDirectory\script_log_$CurrentDate.log"
    
# Check if directory exists, if not, create it
if (!(Test-Path -Path $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force
}

# Function for logging
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $logEntry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $logEntry
    if ($Level -eq "ERROR") {
        Write-Host $logEntry -ForegroundColor Red
    }
    else {
        Write-Host $logEntry
    }
}

function Convert-SecureStringToPlainText {
    param([Parameter(Mandatory = $true)] $SecureOrPlain)

    if ($null -eq $SecureOrPlain) { return $null }

    if ($SecureOrPlain -is [string]) {
        return $SecureOrPlain
    }

    if ($SecureOrPlain -is [System.Security.SecureString]) {
        try {
            $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureOrPlain)
            try {
                $plain = [Runtime.InteropServices.Marshal]::PtrToStringUni($bstr)
            }
            finally {
                [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
            }
            return $plain
        }
        catch {
            Write-Log "Failed converting SecureString to plain text: $($_.Exception.Message)"  -Level "ERROR"
            return $null
        }
    }

    try { return [string]$SecureOrPlain } catch { return $null }
}

function Get-BytesForAesKey {
    param(
        [Parameter(Mandatory = $true)][string]$KeyString
    )
    # Return a byte[] and the bit-length (KeySize) that should be used by AES.
    # Behavior:
    #  - If KeyString UTF8 length is exactly 16/24/32 bytes => use directly (128/192/256)
    #  - Otherwise compute SHA256 and use first 16 bytes (128-bit), per requested AES parameters.
    $keyBytes = [System.Text.Encoding]::UTF8.GetBytes($KeyString)
    if ($keyBytes.Length -in 16, 24, 32) {
        $keySizeBits = $keyBytes.Length * 8
        return , @($keyBytes, $keySizeBits)
    }
    else {
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try {
            $fullHash = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($KeyString))
            # Use first 16 bytes -> 128-bit key (to match your requested KeySize = 128)
            $keyBytes128 = New-Object byte[] 16
            [Array]::Copy($fullHash, 0, $keyBytes128, 0, 16)
            $keySizeBits = 128
            return , @($keyBytes128, $keySizeBits)
        }
        finally {
            $sha.Dispose()
        }
    }
}

function Get-ClientSecretFromCredentialManager {
    param(
        [string]$AESKeyTarget = "PBIAppAESKey",
        [string]$EncryptedSecretTarget = "PBIAppEncryptedSecret",
        [bool]$AllowPlainFallback = $false
    )

    try { Import-Module CredentialManager -ErrorAction Stop } catch {
        Write-Log "CredentialManager module not available: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }

    $keyCred = Get-StoredCredential -Target $AESKeyTarget -ErrorAction SilentlyContinue
    $secretCred = Get-StoredCredential -Target $EncryptedSecretTarget -ErrorAction SilentlyContinue

    if (-not $keyCred -or -not $secretCred) {
        Write-Log "Missing credentials: AESKeyTarget='$AESKeyTarget' or EncryptedSecretTarget='$EncryptedSecretTarget'." -Level "ERROR"
        return $null
    }

    $aesKeyRaw = Convert-SecureStringToPlainText $keyCred.Password
    $encRaw = Convert-SecureStringToPlainText $secretCred.Password

    if (-not $aesKeyRaw) { Write-Log "AES key empty after conversion." -Level "ERROR"; return $null }
    if (-not $encRaw) { Write-Log "Encrypted secret empty after conversion." -Level "ERROR"; return $null }

    # Clean and normalize base64
    $clean = $encRaw.Trim()
    $clean = $clean -replace '[\r\n\s]+', ''        # remove whitespace/newlines
    $clean = $clean.Trim('"').Trim("'")           # remove any surrounding quotes

    $encryptedBytes = $null
    try {
        $encryptedBytes = [Convert]::FromBase64String($clean)
    }
    catch {
        # attempt to pad base64 string to multiple of 4
        try {
            $pad = 4 - ($clean.Length % 4)
            if ($pad -gt 0 -and $pad -lt 4) { $clean = $clean + ('=' * $pad) }
            $encryptedBytes = [Convert]::FromBase64String($clean)
        }
        catch {
            if ($AllowPlainFallback) {
                Write-Log "Encrypted secret is not valid Base64 � returning stored value as plaintext (fallback enabled)." -Level "ERROR"
                return $encRaw
            }
            else {
                Write-Log "Encrypted secret is not valid Base64 and fallback disabled." -Level "ERROR"
                return $null
            }
        }
    }

    # derive key bytes & key size bits consistently
    $result = Get-BytesForAesKey -KeyString $aesKeyRaw
    $keyBytes = $result[0]
    $keySizeBits = [int]$result[1]

    try {
        $aesProv = New-Object System.Security.Cryptography.AesCryptoServiceProvider
        $aesProv.Mode = [System.Security.Cryptography.CipherMode]::CBC
        $aesProv.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
        $aesProv.KeySize = $keySizeBits
        $aesProv.Key = $keyBytes
        $aesProv.IV = [byte[]]::new(16)

        $decryptor = $aesProv.CreateDecryptor()
        try {
            $plainBytes = $decryptor.TransformFinalBlock($encryptedBytes, 0, $encryptedBytes.Length)
            $plainText = [System.Text.Encoding]::UTF8.GetString($plainBytes)
            Write-Log "Decrypted client secret successfully." -Level "ERROR"
            return $plainText
        }
        finally {
            if ($decryptor -and $decryptor.GetType().GetMethod("Dispose")) { $decryptor.Dispose() } 2>$null
        }
    }
    catch {
        Write-Log "AES decryption failed: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
    finally {
        if ($aesProv) { $aesProv.Dispose() }
    }
}

$clientSecret = Get-ClientSecretFromCredentialManager -AESKeyTarget "PBIAppAESKey" -EncryptedSecretTarget "PBIAppEncryptedSecret" -AllowPlainFallback $false
if (-not $clientSecret) {
    Write-Log "Cannot obtain client secret. Exiting." -Level "ERROR"
    exit 1
}

# If you need as SecureString / PSCredential
$secureSecret = ConvertTo-SecureString $clientSecret -AsPlainText -Force
# Example: $credential = New-Object System.Management.Automation.PSCredential ($clientId, $secureSecret)
# Note: ensure $clientId is defined where you use this.

# Define workspace IDs as an array
$workspaceIds = @(
    "removed_for_security_purpose"
)

# Define credentials
$tenantId = "removed_for_security_purpose"
$clientId = "removed_for_security_purpose"

# Authenticate using a service principal
Write-Log "Connecting to Power BI using service principal..."
$credential = New-Object System.Management.Automation.PSCredential ($clientId, $secureSecret)

try {
    Connect-PowerBIServiceAccount -ServicePrincipal -TenantId $tenantId -Credential $credential
    Write-Log "Successfully authenticated."
}
catch {
    Write-Log "Failed to authenticate: $($_.Exception.Message)" -Level "ERROR"
    exit
}

# Initialize a hashtable to store datasets for each workspace
$workspaceDatasets = @{}

# Loop through each workspace ID
foreach ($workspaceId in $workspaceIds) {
    try {
        Write-Log "Fetching datasets for Workspace ID: $workspaceId..."
        $datasets = Get-PowerBIDataset -WorkspaceId $workspaceId | Where-Object { $_.IsRefreshable -eq $true }
        $workspaceDatasets[$workspaceId] = $datasets
        Write-Log "Successfully retrieved datasets for Workspace ID: $workspaceId."
    }
    catch {
        Write-Log "Failed to fetch datasets for Workspace ID: $workspaceId - $($_.Exception.Message)" -Level "ERROR"
    }
}

# Initialize failed refresh storage
$failedRefreshes = @()

# Iterate over each dataset and get failed refresh history
foreach ($workspace in $workspaceDatasets.Keys) {
    foreach ($dataset in $workspaceDatasets[$workspace]) {
        Write-Log "Fetching refresh history for dataset ID: $($dataset.Id)..."

        try {
            $refreshHistoryUrl = "groups/$workspaceId/datasets/$($dataset.id)/refreshes"
            $refreshHistoryJSON = Invoke-PowerBIRestMethod -Url $refreshHistoryUrl -Method Get
            $refreshHistory = $refreshHistoryJSON | ConvertFrom-Json

            $currentDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd")

            $todayRefreshes = $refreshHistory.value | Where-Object {
                ($_.endTime -as [datetime]).ToString("yyyy-MM-dd") -eq $currentDate
            }

            $latestRefresh = $todayRefreshes | Sort-Object -Property endTime -Descending | Select-Object -First 1

            if ($latestRefresh -and $latestRefresh.status -eq "Failed") {
                $errorCode = "Unknown"
                $errorDescription = "No details available"

                if ($latestRefresh.serviceExceptionJson) {
                    try {
                        $errorDetails = $latestRefresh.serviceExceptionJson | ConvertFrom-Json
                        $errorCode = $errorDetails.errorCode
                        $errorDescription = $errorDetails.errorDescription
                    }
                    catch {
                        $errorDescription = "Error parsing JSON"
                        Write-Log "Error parsing JSON for dataset $($dataset.Id)" -Level "ERROR"
                    }
                }

                $failedRefreshes += [PSCustomObject]@{
                    DatasetID        = $dataset.Id
                    DatasetName      = $dataset.Name
                    StartTime        = $latestRefresh.startTime
                    EndTime          = $latestRefresh.endTime
                    ErrorCode        = $errorCode
                    ErrorDescription = $errorDescription
                    RequestID        = $latestRefresh.requestId
                    RefreshType      = $latestRefresh.refreshType
                }
                Write-Log "Failed refresh detected for dataset: $($dataset.Name) ($($dataset.Id))" -Level "ERROR"
            }
        }
        catch {
            Write-Log "Error fetching refresh history for dataset $($dataset.Id) - $($_.Exception.Message)" -Level "ERROR"
        }
    }
}

$currentDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd")
$failedRefreshesToday = $failedRefreshes | Where-Object {
    ($_.EndTime -as [datetime]).ToString("yyyy-MM-dd") -eq $currentDate
}

if ($failedRefreshesToday.Count -gt 0) {
    if (!(Get-Module -ListAvailable -Name ImportExcel)) {
        Install-Module -Name ImportExcel -Scope CurrentUser -Force
        Write-Log "ImportExcel module installed."
    }
    Import-Module ImportExcel

    $CurrentDate = Get-Date -format "yyyyMMdd_HHmmss"
    $outputFileName = "PowerBI-failed refreshes_$CurrentDate.xlsx"

    $OutputPath = "$OutputDirectory\$outputFileName"
    $failedRefreshesToday | Export-Excel -Path $OutputPath -WorksheetName "Failed Refreshes" -AutoSize
    Write-Log "Failed refresh history exported to $OutputPath"

    $recipients = @("removed_for_security_purpose")
    $today = Get-Date -Format "yyyy/MM/dd"

    $sendMailMessageSplat = @{
        From        = 'removed_for_security_purpose'
        To          = $recipients
        Subject     = "Power BI - failed refreshes - $today"
        Body        = "PFA - failed refreshes report"
        Attachments = $OutputPath
        Priority    = 'High'
        SmtpServer  = 'removed_for_security_purpose'
    }

    try {
        Send-MailMessage @sendMailMessageSplat
        Write-Log "Email sent with the failed refreshes report."
    }
    catch {
        Write-Log "Failed to send email: $($_.Exception.Message)" -Level "ERROR"
    }
}
else {
    Write-Log "No failed refreshes found for today. Email will not be sent."
}
