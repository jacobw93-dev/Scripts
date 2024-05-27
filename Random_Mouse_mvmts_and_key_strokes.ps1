# Load necessary .NET assemblies for mouse and keyboard actions
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Function to move the mouse to a random position on the screen
function Move-RandomMouse {
    $screenWidth = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width
    $screenHeight = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height
    $random = New-Object System.Random
    $x = $random.Next(0, $screenWidth)
    $y = $random.Next(0, $screenHeight)
    [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point($x, $y)
    Write-Host -ForegroundColor Green "Moved mouse to position:"
    Write-Host -ForegroundColor Yellow "($x, $y)"

    # Stroke "Ctrl" key twice
    [System.Windows.Forms.SendKeys]::SendWait("^")
    Start-Sleep -Milliseconds 100
    [System.Windows.Forms.SendKeys]::SendWait("^")
}

# Function to simulate random key presses
function Send-RandomKey {
    $random = New-Object System.Random
    $keys = [System.Windows.Forms.Keys].GetEnumValues()
    $key = $keys[$random.Next(0, $keys.Length)]
    [System.Windows.Forms.SendKeys]::SendWait("$($key.ToString()) ")
    Write-Host -ForegroundColor Green "Sent key:"
    Write-Host -ForegroundColor Yellow "$key"
}

# Ask the user if they want to proceed with the shutdown
$shutdownProceed = $false
do {
    Write-Host -ForegroundColor Green "Do you want to proceed with the shutdown? (Y/N): "
    $response = Read-Host

    if ($response -match '^[Yy]$') {
        $shutdownProceed = $true
        $validInput = $true
    }
    elseif ($response -match '^[Nn]$') {
        $shutdownProceed = $false
        $validInput = $true
    }
    else {
        Write-Host "Invalid input. Please enter Y or N."
        $validInput = $false
    }
} while (-not $validInput)

# If the user chose not to proceed with the shutdown, exit the script
if (-not $shutdownProceed) {
    $TimeOut = 86400
}
else {
    # Prompt the user for the timeout value and validate the input
    do {
        Write-Host -ForegroundColor Green "Please enter the timeout value (e.g., 1H, 30M, 45S): "
        $timeoutInput = Read-Host

        if ($timeoutInput -match '^\d+[HhMmSs]$') {
            $unit = $timeoutInput[-1].ToString().ToUpper()
            $value = [int]$timeoutInput.Substring(0, $timeoutInput.Length - 1)

            switch ($unit) {
                'H' { $TimeOut = $value * 3600 }
                'M' { $TimeOut = $value * 60 }
                'S' { $TimeOut = $value }
            }

            $validInput = $true
        }
        else {
            Write-Host "Invalid input. Please enter a valid timeout value (e.g., 1H, 30M, 45S)."
            $validInput = $false
        }
    } while (-not $validInput)
}

# Calculate the end time based on the current time and the timeout value
$endTime = (Get-Date).AddSeconds($TimeOut)

# Main loop to perform actions until the timeout period elapses
$paused = $false

while ((Get-Date) -lt $endTime) {

    if (-not $paused) {
        clear-host
        Write-Host -ForegroundColor Blue "Press 'P' to pause."
        $interval = Get-Random -Minimum 5 -Maximum 10
        Write-Host -ForegroundColor Red "Shutdown at`: $endTime"
        Write-Host -ForegroundColor Green "Break time interval:"
        Write-Host -ForegroundColor Yellow "$interval (seconds)"
        Move-RandomMouse
        Start-Sleep -Seconds $interval
        Send-RandomKey
        Start-Sleep -Seconds $interval
    }
    else {
        clear-host
        Write-Host -ForegroundColor Blue "Paused. Press 'P' again to resume."
        Start-Sleep -Seconds 1
    }

    # Check if 'P' key is pressed
    if ([Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true)
        if ($key.Key -eq 'P') {
            $paused = -not $paused
            if ($paused) {
                clear-host
                Write-Host -ForegroundColor Red "Paused. Press 'P' again to resume."
                Start-Sleep -Seconds 1
            }
            else {
                Write-Host -ForegroundColor Green "Resumed."
            }
            # Adding a short sleep to debounce the key press
            Start-Sleep -Milliseconds 500
        }
    }

    Start-Sleep -Milliseconds 100 # To reduce CPU usage
}

# Shutdown the system with the specified timeout
shutdown -s -f -t 30
