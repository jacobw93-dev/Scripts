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
    Write-Host "Moved mouse to position: ($x, $y)"

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
    Write-Host "Sent key: $key"
}

# Main loop to perform actions every 10 seconds
while ($true) {
    Move-RandomMouse
    Start-Sleep -Seconds 5
    Send-RandomKey
    Start-Sleep -Seconds 5
}
