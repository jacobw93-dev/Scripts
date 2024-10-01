Clear-Host

# Path to the ImageMagick executable
$magickPath = "C:\Program Files\ImageMagick-7.1.1-Q16-HDRI\magick.exe"

# Array of valid image extensions
$validExtensions = @(".jpg", ".jpeg", ".png", ".bmp")

# Function to get the dominant color of an image in HSV format
function Get-DominantColorHSV {
    param (
        [string]$imagePath
    )
    
    try {
        # Define the arguments for the ImageMagick command
        $arguments = "`"$imagePath`" -resize 32x32 -scale 10x10 -colorspace HSL txt:-"

        # Start the ImageMagick process and capture the output
        $process = Start-Process -FilePath $magickPath -ArgumentList $arguments -NoNewWindow -PassThru -RedirectStandardOutput "output.txt" -RedirectStandardError "error.txt"
        $process.WaitForExit()

        # Read the output from the file
        $output = Get-Content "output.txt" -Raw
        
        # Output the content for debugging
        Write-Host "ImageMagick output for $imagePath`:`n$output"

        # Initialize accumulators for H, S, and L values
        $hValues = @()
        $sValues = @()
        $lValues = @()

        # Adjust the regex to correctly capture the HSL values
        $output -match "hsl\((\d+(\.\d+)?),(\d+(\.\d+)?%)?,(\d+(\.\d+)?%)?\)" | ForEach-Object {
            $hValues += [decimal]$matches[1]
            $sValues += [decimal]$matches[3].TrimEnd('%')
            $lValues += [decimal]$matches[5].TrimEnd('%')
        }

        # Calculate the average H, S, and L values
        if ($hValues.Count -gt 0) {
            $avgH = ($hValues | Measure-Object -Average).Average
            $avgS = ($sValues | Measure-Object -Average).Average
            $avgL = ($lValues | Measure-Object -Average).Average
            return [PSCustomObject]@{
                H = [Math]::Round($avgH, 3)
                S = [Math]::Round($avgS, 3)
                L = [Math]::Round($avgL, 3)

            }
        }
        else {
            Write-Host "No color data matched in output for $imagePath."
            Write-Host "Output:`n$output"
        }
    }
    catch {
        Write-Host "Error occurred: $_"
    }
    
    return $null
}

# Prompt the user for the directory containing the images
$imageDirectory = Read-Host "Please enter the path to the directory containing your images"

# Validate if the directory exists
if (-Not (Test-Path -Path $imageDirectory)) {
    Write-Output "The directory '$imageDirectory' does not exist. Please provide a valid directory."
    exit
}

# Get all image files in the directory with valid extensions
$imageFiles = Get-ChildItem -Path $imageDirectory -File | Where-Object { $_.Extension -in $validExtensions }

# Start timing
$startTime = Get-Date

# Process each image with progress bar
$imageColors = @()
$totalImages = $imageFiles.Count
$processedImages = 0
$progressIndex = 0

foreach ($image in $imageFiles) {
    $processedImages++
    $dominantColor = Get-DominantColorHSV -imagePath $image.FullName
    if ($dominantColor) {
        $imageColors += [PSCustomObject]@{Path = $image.FullName; Color = $dominantColor }
        Write-Host "Processed image: $($image.FullName), Color: H=$($dominantColor.H), S=$($dominantColor.S), L=$($dominantColor.L)"
    }
    else {
        Write-Host "Failed to process image: $($image.FullName)"
    }
    $progressIndex = [math]::Floor(($processedImages / $totalImages) * 100)
    $elapsedTime = (Get-Date) - $startTime
    $estimatedRemaining = ($elapsedTime.TotalSeconds / $processedImages) * ($totalImages - $processedImages)
    Write-Progress -Activity "Processing Images" -Status "Processed $processedImages of $totalImages images" -PercentComplete $progressIndex -SecondsRemaining $estimatedRemaining
}

# Sort images by their dominant color (Lightness, then Hue)
$sortedImages = $imageColors | Sort-Object -Property @{Expression = { $_.Color.L }; Ascending = $false }, @{Expression = { $_.Color.H }; Ascending = $true }

# Generate a unique random hex string for this run
$randomHex = -join (Get-Random -Count 6 -InputObject (48..57 + 97..102) | ForEach-Object { [char]$_ })

# Rename sorted images with progress bar
$totalImages = $sortedImages.Count
$renamedImages = 0
$progressIndex = 0

$counter = 1
foreach ($image in $sortedImages) {
    $renamedImages++
    $newName = "H{1}_S{2}_L{3}_{5}_{0:D4}{4}" -f $counter, $image.Color.H, $image.Color.S, $image.Color.L, [System.IO.Path]::GetExtension($image.Path), $randomHex
    $newPath = Join-Path -Path $imageDirectory -ChildPath $newName
    Rename-Item -Path $image.Path -NewName $newPath -Verbose
    $counter++

    $progressIndex = [math]::Floor(($renamedImages / $totalImages) * 100)
    $elapsedTime = (Get-Date) - $startTime
    $estimatedRemaining = ($elapsedTime.TotalSeconds / ($totalImages + $processedImages)) * ($totalImages - $renamedImages)
    Write-Progress -Activity "Renaming Images" -Status "Renamed $renamedImages of $totalImages images" -PercentComplete $progressIndex -SecondsRemaining $estimatedRemaining
}

# Clean up temporary file
Remove-Item "output.txt" -Verbose

# Calculate total elapsed time
$elapsedTime = (Get-Date) - $startTime

# Format elapsed time as HH:MM:ss
$elapsedTimeFormatted = "{0:HH\:mm\:ss}" -f [datetime]$elapsedTime.Ticks
Write-Output "Elapsed time: $elapsedTimeFormatted"
Write-Output "Completed processing images."

# SMTP server credentials
$smtpUser = "pshscript@gmail.com"
$smtpPass = "5KeHjRKRAjsJESrlm0fKqg=="

# Send email notification
$smtpServer = "smtp.gmail.com"
$smtpFrom = $smtpUser
$smtpTo = "jacob.w93@gmail.com"
$messageSubject = "Script execution is complete"
$ScriptName = $MyInvocation.MyCommand.Name
$messageBody = "The `"$ScriptName`" script execution is complete."

# Define the key (16 bytes for 128-bit key)
$key = "5243428937038590"  # 16 characters

# Define the encrypted password
$encryptedPassword = $smtpPass

# Convert the key and encrypted password to byte arrays
$keyBytes = [System.Text.Encoding]::UTF8.GetBytes($key)
$encryptedBytes = [Convert]::FromBase64String($encryptedPassword)

# Create AES encryption provider
$aesProvider = New-Object System.Security.Cryptography.AesCryptoServiceProvider
$aesProvider.KeySize = 128
$aesProvider.Key = $keyBytes

# Set padding mode to None
$aesProvider.Padding = [System.Security.Cryptography.PaddingMode]::None

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

# Create a secure string for the password
$securePass = ConvertTo-SecureString $decryptedPassword -AsPlainText -Force

# Create a credential object
$credential = New-Object System.Management.Automation.PSCredential ($smtpUser, $securePass)

# Create the MailMessage object
$mailMessage = New-Object system.net.mail.mailmessage
$mailMessage.From = $smtpFrom
$mailMessage.To.Add($smtpTo)
$mailMessage.Subject = $messageSubject
$mailMessage.Body = $messageBody

# Configure the SMTP client
$smtpClient = New-Object system.net.mail.smtpclient($smtpServer, 587)
$smtpClient.EnableSsl = $true
$smtpClient.Credentials = New-Object System.Net.NetworkCredential($smtpUser, $decryptedPassword)

# Send the email
try {
    $smtpClient.Send($mailMessage)
    Write-Host "Email sent successfully."
}
catch {
    Write-Host "Failed to send email: $_"
}
