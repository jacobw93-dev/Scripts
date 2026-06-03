param
(
    [parameter(Mandatory = $true)] [String] $sptenantid,
    [parameter(Mandatory = $true)] [String] $spclientid,
    [parameter(Mandatory = $true)] [String] $spsecret
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
# STEP 3: Resolve Enterprise Application Object ID via Microsoft Graph API
#         This is the identifier the gateway API expects for service principals —
#         it is different from both the client ID and the app registration object ID
# ==============================================================================
Write-Host "Resolving Enterprise Application Object ID via Graph API..."
try {
    $graphToken = Invoke-RestMethod `
        -Uri "https://login.microsoftonline.com/$sptenantid/oauth2/v2.0/token" `
        -Method POST `
        -ContentType "application/x-www-form-urlencoded" `
        -Body "grant_type=client_credentials&client_id=$spclientid&client_secret=$spsecret&scope=https://graph.microsoft.com/.default" `
        -ErrorAction Stop

    $spDetails = Invoke-RestMethod `
        -Uri "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=appId eq '$spclientid'" `
        -Headers @{ Authorization = "Bearer $($graphToken.access_token)" } `
        -Method GET `
        -ErrorAction Stop

    $spenterpriseobjid = $spDetails.value[0].id
    Write-Host "  [OK] Enterprise Application Object ID resolved: $spenterpriseobjid"
}
catch {
    Write-Error "Could not resolve Enterprise Application Object ID: $_"
    exit 1
}

# ==============================================================================
# STEP 4: Retrieve all gateways
# ==============================================================================
Write-Host "Retrieving all gateways..."
try {
    $gateways = Invoke-PowerBIRestMethod -Url "gateways" -Method GET -ErrorAction Stop | ConvertFrom-Json
}
catch {
    Write-Error "Could not retrieve gateways: $_"
    exit 1
}

if (-not $gateways.value -or $gateways.value.Count -eq 0) {
    Write-Warning "No gateways found. Exiting."
    exit 0
}
Write-Host "  [OK] Found $($gateways.value.Count) gateway(s)"

# ==============================================================================
# STEP 5: Process each gateway
# ==============================================================================
foreach ($gateway in $gateways.value) {
    Write-Host ""
    Write-Host "============================================================"
    Write-Host "Processing gateway: '$($gateway.name)' (ID: $($gateway.id))"
    Write-Host "============================================================"

    # --- 5a: Add service principal as gateway user ---------------------------
    Write-Host "  Adding service principal as gateway user..."

    $gatewayUserBody = [PSCustomObject]@{
        identifier           = $spenterpriseobjid
        principalType        = "App"
        gatewayPrincipalType = "User"
    }

    try {
        Invoke-PowerBIRestMethod `
            -Url "gateways/$($gateway.id)/users" `
            -Body ($gatewayUserBody | ConvertTo-Json -Depth 10) `
            -Method POST `
            -ErrorAction Stop | Out-Null
        Write-Host "  [OK] Added service principal as user on gateway '$($gateway.name)'"
    }
    catch {
        Write-Warning "  [WARN] Could not add service principal to gateway '$($gateway.name)': $_"
    }

    # --- 5b: Retrieve all datasources on this gateway ------------------------
    Write-Host "  Retrieving datasources for gateway '$($gateway.name)'..."
    try {
        $datasources = Invoke-PowerBIRestMethod `
            -Url "gateways/$($gateway.id)/datasources" `
            -Method GET `
            -ErrorAction Stop | ConvertFrom-Json
    }
    catch {
        Write-Warning "  [SKIP] Could not retrieve datasources for gateway '$($gateway.name)': $_"
        continue
    }

    if (-not $datasources.value -or $datasources.value.Count -eq 0) {
        Write-Warning "  [SKIP] No datasources found on gateway '$($gateway.name)'"
        continue
    }
    Write-Host "  [OK] Found $($datasources.value.Count) datasource(s)"

    # --- 5c: Add service principal as user on each datasource ----------------
    foreach ($datasource in $datasources.value) {
        Write-Host "  Processing datasource '$($datasource.datasourceName)' (Type: $($datasource.datasourceType), ID: $($datasource.id))..."

        $datasourceUserBody = [PSCustomObject]@{
            identifier            = $spenterpriseobjid
            principalType         = "App"
            datasourceAccessRight = "Read"
        }

        try {
            Invoke-PowerBIRestMethod `
                -Url "gateways/$($gateway.id)/datasources/$($datasource.id)/users" `
                -Body ($datasourceUserBody | ConvertTo-Json -Depth 10) `
                -Method POST `
                -ErrorAction Stop | Out-Null
            Write-Host "  [OK] Added service principal to datasource '$($datasource.datasourceName)'"
        }
        catch {
            $errorMessage = $_.ToString()
            if ($errorMessage -match "DMTS_PrincipalsAreInvalidError") {
                Write-Warning "  [SKIP] Datasource '$($datasource.datasourceName)' (Type: $($datasource.datasourceType)) does not support user assignment via API"
            }
            else {
                Write-Warning "  [WARN] Could not add service principal to datasource '$($datasource.datasourceName)': $errorMessage"
            }
        }
    }

    # --- 5d: Verify service principal appears in each datasource user list ---
    Write-Host ""
    Write-Host "  Verifying service principal assignment on gateway '$($gateway.name)'..."

    foreach ($datasource in $datasources.value) {
        try {
            $users = Invoke-PowerBIRestMethod `
                -Url "gateways/$($gateway.id)/datasources/$($datasource.id)/users" `
                -Method GET `
                -ErrorAction Stop | ConvertFrom-Json

            $spFound = $users.value | Where-Object { $_.identifier -eq $spenterpriseobjid }
            if ($spFound) {
                Write-Host "  [CONFIRMED] '$($datasource.datasourceName)' — service principal present (access: $($spFound.datasourceAccessRight))"
            }
            else {
                Write-Warning "  [NOT FOUND] '$($datasource.datasourceName)' — service principal not in users list"
            }
        }
        catch {
            Write-Warning "  [WARN] Could not verify users for datasource '$($datasource.datasourceName)': $_"
        }
    }
}

Write-Host ""
Write-Host "============================================================"
Write-Host "Finished processing all gateways and datasources"
Write-Host "============================================================"