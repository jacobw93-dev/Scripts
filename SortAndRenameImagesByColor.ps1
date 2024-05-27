param (
    [Parameter(Mandatory = $false)]
    [string]$ImageDirectory
)

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

# If ImageDirectory was not passed as input parameter, ask interactively
if ([string]::IsNullOrWhiteSpace($ImageDirectory)) {
    $ImageDirectory = Read-Host "Please enter the path to the directory containing your images"
}

# Remove possible surrounding quotes and resolve full path
$ImageDirectory = $ImageDirectory.Trim('"')

# Validate if the directory exists
if (-not (Test-Path -LiteralPath $ImageDirectory -PathType Container)) {
    Write-Host "The directory '$ImageDirectory' does not exist. Please provide a valid directory." -ForegroundColor Red
    exit 1
}

# Normalize path
$ImageDirectory = (Resolve-Path -LiteralPath $ImageDirectory).Path

# Get all image files in the directory with valid extensions
$imageFiles = Get-ChildItem -Path $ImageDirectory -File | Where-Object { $_.Extension -in $validExtensions }

# Start timing
$startTime = Get-Date

# Process each image with progress bar
$imageColors = @()
$totalImages = $imageFiles.Count
$processedImages = 0
$progressIndex = 0

if ($totalImages -gt 0) {
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
		$newPath = Join-Path -Path $ImageDirectory -ChildPath $newName
		Rename-Item -Path $image.Path -NewName $newPath -Verbose
		$counter++

		$progressIndex = [math]::Floor(($renamedImages / $totalImages) * 100)
		$elapsedTime = (Get-Date) - $startTime
		$estimatedRemaining = ($elapsedTime.TotalSeconds / ($totalImages + $processedImages)) * ($totalImages - $renamedImages)
		Write-Progress -Activity "Renaming Images" -Status "Renamed $renamedImages of $totalImages images" -PercentComplete $progressIndex -SecondsRemaining $estimatedRemaining
	}
} else {
    Write-Host "No images found to rename." -ForegroundColor Yellow
}

# Clean up temporary file (only if it exists)
if (Test-Path "output.txt") {
    Remove-Item "output.txt" -Verbose
}

# Calculate total elapsed time
$elapsedTime = (Get-Date) - $startTime

# Format elapsed time as HH:MM:ss
$elapsedTimeFormatted = "{0:HH\:mm\:ss}" -f [datetime]$elapsedTime.Ticks
Write-Output "Elapsed time: $elapsedTimeFormatted"
Write-Output "Completed processing images."

# SMTP configuration and credentials
# Non-secret SMTP settings are read from environment variables.
$smtpServer = if ($env:RENAME_PICS_SMTP_SERVER) { $env:RENAME_PICS_SMTP_SERVER } else { "smtp.gmail.com" }
$smtpPort = if ($env:RENAME_PICS_SMTP_PORT) { [int]$env:RENAME_PICS_SMTP_PORT } else { 587 }
$smtpTo = $env:RENAME_PICS_SMTP_TO
$credentialTarget = "rename_pics_smtp"

if ([string]::IsNullOrWhiteSpace($smtpTo)) {
    throw "RENAME_PICS_SMTP_TO environment variable is not configured."
}

if (-not ("RenamePics.CredentialManager.CredentialReader" -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace RenamePics.CredentialManager
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    internal struct CREDENTIAL
    {
        public UInt32 Flags;
        public UInt32 Type;
        public IntPtr TargetName;
        public IntPtr Comment;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
        public UInt32 CredentialBlobSize;
        public IntPtr CredentialBlob;
        public UInt32 Persist;
        public UInt32 AttributeCount;
        public IntPtr Attributes;
        public IntPtr TargetAlias;
        public IntPtr UserName;
    }

    internal static class NativeMethods
    {
        [DllImport("advapi32.dll", EntryPoint = "CredReadW", CharSet = CharSet.Unicode, SetLastError = true)]
        internal static extern bool CredRead(string target, UInt32 type, UInt32 reservedFlag, out IntPtr credentialPtr);

        [DllImport("advapi32.dll", SetLastError = true)]
        internal static extern void CredFree(IntPtr buffer);
    }

    public static class CredentialReader
    {
        private const UInt32 CRED_TYPE_GENERIC = 1;

        public static string[] ReadGeneric(string target)
        {
            IntPtr credentialPtr;
            if (!NativeMethods.CredRead(target, CRED_TYPE_GENERIC, 0, out credentialPtr))
                return null;

            try
            {
                CREDENTIAL credential = (CREDENTIAL)Marshal.PtrToStructure(credentialPtr, typeof(CREDENTIAL));
                string userName = credential.UserName == IntPtr.Zero ? null : Marshal.PtrToStringUni(credential.UserName);
                string password = null;

                if (credential.CredentialBlob != IntPtr.Zero && credential.CredentialBlobSize > 0)
                    password = Marshal.PtrToStringUni(credential.CredentialBlob, (int)credential.CredentialBlobSize / 2);

                return new string[] { userName, password };
            }
            finally
            {
                NativeMethods.CredFree(credentialPtr);
            }
        }
    }
}
'@
}

$storedCredential = [RenamePics.CredentialManager.CredentialReader]::ReadGeneric($credentialTarget)
if (-not $storedCredential -or $storedCredential.Count -lt 2 -or [string]::IsNullOrWhiteSpace($storedCredential[0]) -or [string]::IsNullOrEmpty($storedCredential[1])) {
    throw "Windows Credential Manager target '$credentialTarget' was not found or is incomplete."
}

$smtpUser = $storedCredential[0]
$decryptedPassword = $storedCredential[1]
$smtpFrom = $smtpUser

# Send email notification
$messageSubject = "Script execution is complete"
$ScriptName = $MyInvocation.MyCommand.Name
$messageBody = "The `"$ScriptName`" script execution is complete."

# Create the MailMessage object
$mailMessage = New-Object system.net.mail.mailmessage
$mailMessage.From = $smtpFrom
$mailMessage.To.Add($smtpTo)
$mailMessage.Subject = $messageSubject
$mailMessage.Body = $messageBody

# Configure the SMTP client
$smtpClient = New-Object system.net.mail.smtpclient($smtpServer, $smtpPort)
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
