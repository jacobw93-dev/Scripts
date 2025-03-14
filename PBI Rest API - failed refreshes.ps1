[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Define workspace IDs as an array
$workspaceIds = @(
    "removed_for_security_purpose"
)

# Define credentials
$tenantId = "removed_for_security_purpose"
$clientId = "removed_for_security_purpose"
$clientSecret = "removed_for_security_purpose"

# Define the key (16 bytes for 128-bit key)
$key = "removed_for_security_purpose"  # 16 characters

# Define the encrypted password
$encryptedPassword = $clientSecret

# Convert the key and encrypted password to byte arrays
$keyBytes = [System.Text.Encoding]::UTF8.GetBytes($key)
$encryptedBytes = [Convert]::FromBase64String($encryptedPassword)

# Create AES encryption provider
$aesProvider = New-Object System.Security.Cryptography.AesCryptoServiceProvider
$aesProvider.KeySize = 128
$aesProvider.Key = $keyBytes

# Set padding mode to None
$aesProvider.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7

# Set decryption mode to CBC (Cipher Block Chaining)
$aesProvider.Mode = [System.Security.Cryptography.CipherMode]::CBC

# Set the IV (Initialization Vector) to zeros
$aesProvider.IV = [byte[]]::new(16)  # 16 bytes for 128-bit IV

# Create decryptor
$decryptor = $aesProvider.CreateDecryptor()

# Decrypt the password
try {
	$decryptedBytes = $decryptor.TransformFinalBlock($encryptedBytes, 0, $encryptedBytes.Length)
    
	# Convert decrypted bytes to string
	$decryptedPassword = [System.Text.Encoding]::UTF8.GetString($decryptedBytes)
}
catch {
	Write-Host "Decryption failed: $_"
}

# Import Power BI Module
# Import-Module MicrosoftPowerBIMgmt

# Authenticate using a service principal
Write-Host "Connecting to Power BI using service principal..."
$secureSecret = ConvertTo-SecureString $decryptedPassword -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ($clientId, $secureSecret)

try {
    Connect-PowerBIServiceAccount -ServicePrincipal -TenantId $tenantId -Credential $credential
    Write-Host "Successfully authenticated."
}
catch {
    Write-Host "Failed to authenticate: $($_.Exception.Message)"
    exit
}


# Initialize a hashtable to store datasets for each workspace
$workspaceDatasets = @{}

# Loop through each workspace ID
foreach ($workspaceId in $workspaceIds) {
    try {
        Write-Host "Fetching datasets for Workspace ID: $workspaceId..."
        $datasets = Get-PowerBIDataset -WorkspaceId $workspaceId | Where-Object { $_.IsRefreshable -eq $true }
        
        # Store datasets in the hashtable with workspace ID as the key
        $workspaceDatasets[$workspaceId] = $datasets
        Write-Host "Successfully retrieved datasets for Workspace ID: $workspaceId."
    }
    catch {
        Write-Host "Failed to fetch datasets for Workspace ID: $workspaceId - $($_.Exception.Message)"
    }
}

# Initialize failed refresh storage
$failedRefreshes = @()

# Iterate over each dataset and get failed refresh history
foreach ($workspace in $workspaceDatasets.Keys) {
    foreach ($dataset in $workspaceDatasets[$workspace]) {
        Write-Host "Fetching refresh history for dataset ID: $($dataset.Id)"

        try {
            # Use the REST API to fetch refresh history
            $refreshHistoryUrl = "groups/$workspaceId/datasets/$($dataset.id)/refreshes"
            $refreshHistoryJSON = Invoke-PowerBIRestMethod -Url $refreshHistoryUrl -Method Get
            $refreshHistory = $refreshHistoryJSON | ConvertFrom-Json

            # Process each refresh entry
            foreach ($refresh in $refreshHistory.value) {
                if ($refresh.status -eq "Failed" -or $refresh.refreshAttempts) {

                    # Default RequestID from top-level refresh
                    $requestID = $refresh.requestId
                    $refreshType = $refresh.refreshType  # Capturing refreshType here

                    # Check for refresh attempts (nested errors)
                    if ($refresh.refreshAttempts) {
                        foreach ($attempt in $refresh.refreshAttempts) {
                            if ($attempt.serviceExceptionJson) {
                                try {
                                    # Convert the stringified JSON to an object
                                    $errorDetails = $attempt.serviceExceptionJson | ConvertFrom-Json

                                    # Parse the error details
                                    $errorCode = $errorDetails.errorCode
                                    $errorDescription = $errorDetails.errorDescription
                                }
                                catch {
                                    $errorCode = "Unknown"
                                    $errorDescription = "Error parsing JSON"
                                }

                                # Add to the list of failed refreshes
                                $failedRefreshes += [PSCustomObject]@{
                                    DatasetID        = $dataset.Id
                                    DatasetName      = $dataset.Name
                                    StartTime        = $attempt.startTime
                                    EndTime          = $attempt.endTime
                                    ErrorCode        = $errorCode
                                    ErrorDescription = $errorDescription
                                    RequestID        = $requestID  # Use top-level RequestID if missing
                                    RefreshType      = $refreshType # Add refreshType
                                    AttemptID        = $attempt.attemptId
                                }
                            }
                        }
                    }
                    else {
                        # Single-level failure case (when no refreshAttempts exist)
                        if ($refresh.serviceExceptionJson) {
                            try {
                                # Convert the stringified JSON to an object
                                $errorDetails = $refresh.serviceExceptionJson | ConvertFrom-Json

                                # Parse the error details
                                $errorCode = $errorDetails.errorCode
                                $errorDescription = $errorDetails.errorDescription
                            }
                            catch {
                                $errorCode = "Unknown"
                                $errorDescription = "Error parsing JSON"
                            }

                            # Add to the list of failed refreshes
                            $failedRefreshes += [PSCustomObject]@{
                                DatasetID        = $dataset.Id
                                DatasetName      = $dataset.Name
                                StartTime        = $refresh.startTime
                                EndTime          = $refresh.endTime
                                ErrorCode        = $errorCode
                                ErrorDescription = $errorDescription
                                RequestID        = $requestID
                                RefreshType      = $refreshType
                                AttemptID        = $null  # No attempt ID for top-level
                            }
                        }
                    }
                }
            }
        }
        catch {
            Write-Host "Error fetching refresh history for dataset $($dataset.Id) - $($_.Exception.Message)"
        }
    }
}

$currentDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd")

$failedRefreshesToday = $failedRefreshes | Where-Object {
    ($_.EndTime -as [datetime]).ToString("yyyy-MM-dd") -eq $currentDate
}

# Check if there are any failed refreshes before proceeding
if ($failedRefreshesToday.Count -gt 0) {

    # Export results to CSV
    $CurrentDate = Get-Date -format "yyyyMMdd_HHmmss"
    $outputFileName = "PowerBI-failed refreshes_$CurrentDate.csv"

    $OutputDirectory = 'C:\PowershellScript\PBI - failed refreshes'

    # Check if directory exists, if not, create it
    if (!(Test-Path -Path $OutputDirectory)) {
        New-Item -ItemType Directory -Path $OutputDirectory -Force
    }

    # Set the output path
    $OutputPath = "$OutputDirectory\$outputFileName"

    $failedRefreshesToday | Export-Csv -Encoding UTF8 -Path $outputPath -NoTypeInformation
    Write-Host "Failed refresh history exported to $outputPath"

    $recipients = @("removed_for_security_purpose")
    $today = Get-Date -Format "yyyy/MM/dd"

    $sendMailMessageSplat = @{
        From        = 'removed_for_security_purpose'
        To          = $recipients
        Subject     = "Power BI - failed refreshes - $today"
        Body        = "PFA - failed refreshes report"
        Attachments = $outputPath
        Priority    = 'High'
        SmtpServer  = 'removed_for_security_purpose'
    }

    Send-MailMessage @sendMailMessageSplat
    Write-Host "Email sent with the failed refreshes report."
}
else {
    Write-Host "No failed refreshes found for today. Email will not be sent."
}