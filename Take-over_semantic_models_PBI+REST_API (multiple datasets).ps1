param
(
    [parameter(Mandatory = $true)] [String] $sptenantid,
    [parameter(Mandatory = $true)] [String] $spclientid,
    [parameter(Mandatory = $true)] [String] $spsecret,
    [parameter(Mandatory = $true)] [String] $pbiworkspacename
)

# ==============================================================================
# STEP 1: Validate and import required modules
# ==============================================================================
Write-Host "Checking required Power BI modules..."
$requiredModules = @("MicrosoftPowerBIMgmt.Profile", "MicrosoftPowerBIMgmt.Workspaces")

foreach ($module in $requiredModules) {
    if (Get-Module -ListAvailable -Name $module) {
        Write-Host "  [OK] Module '$module' is already installed"
    }
    else {
        Write-Host "  [INSTALLING] Module '$module' not found, installing..."
        Install-Module -Name $module -Verbose -Scope CurrentUser -Force
        Write-Host "  [OK] Module '$module' installed successfully"
    }
}

# ==============================================================================
# STEP 2: Authenticate with service principal
# ==============================================================================
Write-Host "Building up credentials of service principal..."
$spsecretsecurestring = ConvertTo-SecureString $spsecret -AsPlainText -Force
$spcredentials = New-Object -TypeName PSCredential -ArgumentList $spclientid, $spsecretsecurestring

Write-Host "Logging in to Power BI with service principal..."
Connect-PowerBIServiceAccount -ServicePrincipal -Credential $spcredentials -Environment Public -Tenant $sptenantid

# ==============================================================================
# STEP 3: Resolve workspace
# ==============================================================================
Write-Host "Retrieving Power BI workspace: '$pbiworkspacename'..."
$workspace = Get-PowerBIWorkspace -Name $pbiworkspacename

if (-not $workspace) {
    Write-Error "Workspace '$pbiworkspacename' not found. Exiting."
    exit 1
}
Write-Host "  [OK] Workspace found (ID: $($workspace.id))"

# ==============================================================================
# STEP 4: Retrieve all datasets in the workspace
# ==============================================================================
Write-Host "Retrieving all datasets from workspace '$pbiworkspacename'..."
$datasets = Invoke-PowerBIRestMethod -Url "groups/$($workspace.id)/datasets" -Method Get | ConvertFrom-Json

if (-not $datasets.value -or $datasets.value.Count -eq 0) {
    Write-Warning "No datasets found in workspace '$pbiworkspacename'. Exiting."
    exit 0
}
Write-Host "  [OK] Found $($datasets.value.Count) dataset(s)"

# ==============================================================================
# STEP 5: Retrieve OAuth2 access token for credential update
# ==============================================================================
Write-Host "Retrieving OAuth2 access token..."
$accesstoken = Invoke-RestMethod `
    -Uri "https://login.microsoftonline.com/$($sptenantid)/oauth2/token" `
    -Body "grant_type=client_credentials&client_id=$($spclientid)&client_secret=$($spsecret)&resource=https://database.windows.net/" `
    -ContentType "application/x-www-form-urlencoded" `
    -Method POST
Write-Host "  [OK] Access token retrieved"

# ==============================================================================
# STEP 6: Retrieve all gateways accessible by the service principal
# ==============================================================================
Write-Host "Retrieving accessible gateways..."
try {
    $gateways = Invoke-PowerBIRestMethod -Url "gateways" -Method GET | ConvertFrom-Json
}
catch {
    Write-Error "Could not retrieve gateways: $_"
    exit 1
}

if (-not $gateways.value -or $gateways.value.Count -eq 0) {
    Write-Error "No gateways found for the service principal. Exiting."
    exit 1
}
Write-Host "  [OK] Found $($gateways.value.Count) gateway(s)"

# ==============================================================================
# STEP 7: Process each dataset
# ==============================================================================
foreach ($dataset in $datasets.value) {
    Write-Host ""
    Write-Host "============================================================"
    Write-Host "Processing dataset: '$($dataset.name)' (ID: $($dataset.id))"
    Write-Host "============================================================"

    # --- 7a: Take over the dataset -------------------------------------------
    Write-Host "  Taking over dataset..."
    try {
        Invoke-PowerBIRestMethod `
            -Url "groups/$($workspace.id)/datasets/$($dataset.id)/Default.TakeOver" `
            -Method POST | Out-Null
        Write-Host "  [OK] Took over dataset '$($dataset.name)'"
    }
    catch {
        Write-Warning "  [SKIP] Could not take over dataset '$($dataset.name)': $_"
        continue
    }

    # --- 7b: Retrieve dataset datasources (connection details) ----------------
    Write-Host "  Retrieving dataset datasources..."
    try {
        $datasetDatasources = Invoke-PowerBIRestMethod `
            -Url "groups/$($workspace.id)/datasets/$($dataset.id)/datasources" `
            -Method GET | ConvertFrom-Json
    }
    catch {
        Write-Warning "  [SKIP] Could not retrieve datasources for dataset '$($dataset.name)': $_"
        continue
    }

    if (-not $datasetDatasources.value -or $datasetDatasources.value.Count -eq 0) {
        Write-Warning "  [SKIP] No datasources found for dataset '$($dataset.name)'"
        continue
    }
    Write-Host "  [OK] Found $($datasetDatasources.value.Count) datasource(s) in dataset"

    # --- 7c: Match dataset datasources to gateway datasources -----------------
    Write-Host "  Matching against gateway datasources..."
    $bindingMap = @{}

    # Helper function to safely parse connectionDetails regardless of type
    function Resolve-ConnectionDetails {
        param ($connectionDetails)
        if ($null -eq $connectionDetails) { return $null }
        if ($connectionDetails -is [string]) {
            try   { return $connectionDetails | ConvertFrom-Json }
            catch { return $null }
        }
        # Already a PSCustomObject — return as-is
        return $connectionDetails
    }

    foreach ($gateway in $gateways.value) {
        try {
            $gatewayDatasources = Invoke-PowerBIRestMethod `
                -Url "gateways/$($gateway.id)/datasources" `
                -Method GET | ConvertFrom-Json
        }
        catch {
            Write-Warning "  [WARN] Could not retrieve datasources for gateway '$($gateway.id)': $_"
            continue
        }

        foreach ($gds in $gatewayDatasources.value) {
            foreach ($ds in $datasetDatasources.value) {
                $gwConn = Resolve-ConnectionDetails $gds.connectionDetails
                $dsConn = Resolve-ConnectionDetails $ds.connectionDetails

                if ($null -eq $gwConn -or $null -eq $dsConn) { continue }

                # Match on server+database (SQL-type) or path (file-based)
                $isMatch = (
                    ($gwConn.server   -and $dsConn.server   -and $gwConn.server   -eq $dsConn.server) -and
                    ($gwConn.database -and $dsConn.database -and $gwConn.database -eq $dsConn.database)
                ) -or (
                    ($gwConn.path     -and $dsConn.path     -and $gwConn.path     -eq $dsConn.path)
                )

                if ($isMatch) {
                    if (-not $bindingMap.ContainsKey($gateway.id)) {
                        $bindingMap[$gateway.id] = [System.Collections.Generic.List[string]]::new()
                    }
                    if (-not $bindingMap[$gateway.id].Contains($gds.id)) {
                        $bindingMap[$gateway.id].Add($gds.id)
                    }
                }
            }
        }
    }
    
        # Optional: dump connection details for diagnostics if no match found
    if ($bindingMap.Count -eq 0) {
        Write-Warning "  [SKIP] No matching gateway datasources found for dataset '$($dataset.name)'"
        Write-Host "  [DEBUG] Dataset connection details:"
        foreach ($ds in $datasetDatasources.value) {
            $dsConn = Resolve-ConnectionDetails $ds.connectionDetails
            Write-Host "    datasourceType: $($ds.datasourceType) | server: $($dsConn.server) | database: $($dsConn.database) | path: $($dsConn.path)"
        }
        continue
    }
    # --- 7d: Bind dataset to matched gateway(s) -------------------------------
    foreach ($gatewayId in $bindingMap.Keys) {
        $datasourceIds = $bindingMap[$gatewayId]

        Write-Host "  Binding to gateway '$gatewayId' with datasource(s): $($datasourceIds -join ', ')..."

        $bindBody = [PSCustomObject]@{
            gatewayObjectId     = $gatewayId
            datasourceObjectIds = @($datasourceIds)
        }

        try {
            Invoke-PowerBIRestMethod `
                -Url "groups/$($workspace.id)/datasets/$($dataset.id)/Default.BindToGateway" `
                -Body ($bindBody | ConvertTo-Json -Depth 10) `
                -Method POST | Out-Null
            Write-Host "  [OK] Bound dataset '$($dataset.name)' to gateway '$gatewayId'"
        }
        catch {
            Write-Warning "  [WARN] Could not bind dataset '$($dataset.name)' to gateway '$gatewayId': $_"
        }
    }

    # --- 7e: Retrieve bound gateway datasources for credential update ---------
    Write-Host "  Retrieving bound gateway datasources..."
    try {
        $boundGateway = Invoke-PowerBIRestMethod `
            -Url "groups/$($workspace.id)/datasets/$($dataset.id)/Default.GetBoundGatewayDataSources" `
            -Method GET | ConvertFrom-Json
    }
    catch {
        Write-Warning "  [SKIP] Could not retrieve bound gateway datasources for dataset '$($dataset.name)': $_"
        continue
    }

    if (-not $boundGateway.value -or $boundGateway.value.Count -eq 0) {
        Write-Warning "  [SKIP] No bound gateway datasources found for dataset '$($dataset.name)'"
        continue
    }

    # --- 7f: Update credentials on each bound datasource ---------------------
    foreach ($datasource in $boundGateway.value) {
        Write-Host "  Updating credentials for gateway '$($datasource.gatewayId)' / datasource '$($datasource.id)'..."

        $credBody = [PSCustomObject]@{
            credentialDetails = [PSCustomObject]@{
                credentialType      = "OAuth2"
                credentials         = '{"credentialData":[{"name":"accessToken","value":"' + $accesstoken.access_token + '"}]}'
                encryptedConnection = "Encrypted"
                encryptionAlgorithm = "None"
                privacyLevel        = "None"
            }
        }

        try {
            Invoke-PowerBIRestMethod `
                -Url "https://api.powerbi.com/v1.0/myorg/gateways/$($datasource.gatewayId)/datasources/$($datasource.id)" `
                -Body ($credBody | ConvertTo-Json -Depth 10) `
                -Method PATCH | Out-Null
            Write-Host "  [OK] Updated credentials for datasource '$($datasource.id)'"
        }
        catch {
            Write-Warning "  [WARN] Could not update credentials for datasource '$($datasource.id)': $_"
        }
    }
}

Write-Host ""
Write-Host "============================================================"
Write-Host "Finished processing all datasets in workspace '$pbiworkspacename'"
Write-Host "============================================================"