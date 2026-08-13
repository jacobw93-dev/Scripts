# ---------------------------------------------------------------------------
# SAPADM password expiration notification
# ---------------------------------------------------------------------------

$UserName            = 'sapadm'
$ServerName          = $env:COMPUTERNAME

# Send notification when password expires within this many days
$NotifyBeforeDays    = 3

# Do NOT send notification if password was changed within this many days
$RecentlyChangedDays = 3

# Mail configuration
$MailFrom            = 'noreply@humio.com'
$MailTo              = @(
    'jeuc@dsb.dk',
    'NOHO@dsb.dk',
    'xalind@dsb.dk',
    'xjaka@dsb.dk'
)
$SmtpServer          = 'mailhub.dsb.dk'

# Log configuration
$LogDirectory        = 'C:\PowershellScript\logs'
$TimeStamp           = Get-Date -Format 'yyyyMMdd_HHmmss'
$LogFile             = Join-Path $LogDirectory "sapadm_password_check_$TimeStamp.log"


# ---------------------------------------------------------------------------
# Logging function
# ---------------------------------------------------------------------------

function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    $LogTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $LogLine = "[$LogTime] $Message"

    Add-Content -Path $LogFile -Value $LogLine
    Write-Host $LogLine
}


# ---------------------------------------------------------------------------
# Create log directory if necessary
# ---------------------------------------------------------------------------

if (-not (Test-Path -Path $LogDirectory)) {
    New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null
}

# Create the log file
New-Item -Path $LogFile -ItemType File -Force | Out-Null


try {

    Write-Log "============================================================"
    Write-Log "Starting sapadm password expiration check."
    Write-Log "Computer: $ServerName"
    Write-Log "User: $UserName"
    Write-Log "Notification threshold: $NotifyBeforeDays day(s)"
    Write-Log "Recently changed threshold: $RecentlyChangedDays day(s)"
    Write-Log "============================================================"


    # -----------------------------------------------------------------------
    # Get local user information
    # -----------------------------------------------------------------------

    $User = Get-LocalUser -Name $UserName -ErrorAction Stop

    $PasswordLastSet = $User.PasswordLastSet
    $PasswordExpires = $User.PasswordExpires

    Write-Log "Account enabled: $($User.Enabled)"
    Write-Log "Password last changed: $PasswordLastSet"
    Write-Log "Password expiration date: $PasswordExpires"


    # -----------------------------------------------------------------------
    # Validate password expiration information
    # -----------------------------------------------------------------------

    if ($null -eq $PasswordExpires) {

        Write-Log "Password expiration date is not defined."
        Write-Log "The account may have 'Password never expires' configured."
        Write-Log "No notification will be sent."

        exit 0
    }


    $Now = Get-Date

    $DaysSincePasswordChange = if ($PasswordLastSet) {
        [math]::Floor(($Now - $PasswordLastSet).TotalDays)
    }
    else {
        $null
    }

    $DaysUntilExpiration = [math]::Ceiling(
        ($PasswordExpires - $Now).TotalDays
    )


    Write-Log "Days since password change: $DaysSincePasswordChange"
    Write-Log "Days until password expiration: $DaysUntilExpiration"


    # -----------------------------------------------------------------------
    # Check whether password was changed recently
    # -----------------------------------------------------------------------

    if (
        $PasswordLastSet -and
        $PasswordLastSet -ge $Now.AddDays(-$RecentlyChangedDays)
    ) {

        Write-Log "Password was changed recently."
        Write-Log "PasswordLastSet: $PasswordLastSet"
        Write-Log "No email notification will be sent."

        exit 0
    }


    # -----------------------------------------------------------------------
    # Check expiration threshold
    # -----------------------------------------------------------------------

    if (
        $DaysUntilExpiration -ge 0 -and
        $DaysUntilExpiration -le $NotifyBeforeDays
    ) {

        $ExpiryDateFormatted = $PasswordExpires.ToString(
            'yyyy-MM-dd HH:mm:ss'
        )

        $Subject = "Warning! Password for user $UserName on $ServerName expires in $DaysUntilExpiration day(s)"

        $Body = @"
Warning: local user password expiration

Server:                 $ServerName
User:                   $UserName
Password last changed:  $PasswordLastSet
Password expires:       $ExpiryDateFormatted
Days until expiration:  $DaysUntilExpiration

The password for the local user '$UserName' on server '$ServerName' will expire in $DaysUntilExpiration day(s).

Please change the password before the expiration date.
"@

        Write-Log "Password is within the expiration notification threshold."
        Write-Log "Sending email notification."
        Write-Log "Subject: $Subject"

        Send-MailMessage `
            -From $MailFrom `
            -To $MailTo `
            -Subject $Subject `
            -Body $Body `
            -SmtpServer $SmtpServer `
            -ErrorAction Stop

        Write-Log "Email notification successfully sent."
    }
    elseif ($DaysUntilExpiration -lt 0) {

        Write-Log "Password has already expired $([math]::Abs($DaysUntilExpiration)) day(s) ago."

        # No notification here because the requested logic is for
        # upcoming expiration. This can be changed if required.
    }
    else {

        Write-Log "Password does not expire within the next $NotifyBeforeDays day(s)."
        Write-Log "No email notification required."
    }


    Write-Log "Password expiration check completed successfully."
}
catch {

    Write-Log "ERROR: $($_.Exception.Message)"
    Write-Log "Script execution failed."

    exit 1
}