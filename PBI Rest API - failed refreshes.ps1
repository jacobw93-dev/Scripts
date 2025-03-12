[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Define workspace ID
$workspaceId = "<Your_workspaceID>"

# Define credentials
$tenantId = "<Your_tenantID>"
$clientId = "<Your_clientID>"
$clientSecret = "<Your_clientSecret>"

# Import Power BI Module
# Import-Module MicrosoftPowerBIMgmt

# Authenticate using a service principal
Write-Host "Connecting to Power BI using service principal..."
$secureSecret = ConvertTo-SecureString $clientSecret -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ($clientId, $secureSecret)

try {
    Connect-PowerBIServiceAccount -ServicePrincipal -TenantId $tenantId -Credential $credential
    Write-Host "Successfully authenticated."
}
catch {
    Write-Host "Failed to authenticate: $($_.Exception.Message)"
    exit
}


# Get all datasets in the workspace
try {
    Write-Host "Fetching datasets..."
    $datasets = Get-PowerBIDataset -WorkspaceId $workspaceId | Where-Object { $_.IsRefreshable -eq $true }
    Write-Host "Successfully retrieved datasets."
}
catch {
    Write-Host "Failed to fetch datasets: $($_.Exception.Message)"
    exit
}

# Initialize failed refresh storage
$failedRefreshes = @()

# Iterate over each dataset and get failed refresh history
foreach ($dataset in $datasets) {
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

# Export results to CSV
$desktopPath = [System.Environment]::GetFolderPath('Desktop')
$defaultOutputPath = "$desktopPath\PowerBI - failed refreshes.csv"

# Prompt user for the output file path, using the default if no input is given
Write-Host "`nEnter the output file path (default: $defaultOutputPath)"
Write-Host -ForegroundColor Green "`nkeep blank to use default path"
$outputPath = Read-Host

# If no path is entered, use the default path
if (-not $outputPath) {
	Write-Host -ForegroundColor Red "Provided path does not exist, reverting to default path"
    $outputPath = $defaultOutputPath
}

$failedRefreshes | Export-Csv -Path $outputPath -NoTypeInformation
Write-Host "Failed refresh history exported to $outputPath"
pause
