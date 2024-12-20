# Default variables
$pathsFile = "paths.txt"
$ffmpeg_qv = 24
$dest_dir = "E:\.ignore\Videos\Compressed"


function Get-UserChoice {
    param(
        [string]$Question
    )

    $answer = $null
    while (@("y", "n") -notcontains $answer) {
        Write-Host -ForegroundColor Green "`n$Question Y (Yes), N (No)"
        $answer = Read-Host
        $answer = $answer.ToLower().Trim()
        switch ($answer) {
            y { $Chosen = "1" }
            n { $Chosen = "0" }
        }
        if (@("y", "n") -notcontains $answer) { Write-Host -ForegroundColor Red "Enter the correct value"; pause }
    }
    return $Chosen
}

function ShutdownComputer {
    $Chosen = Get-UserChoice -Question "Should I shutdown computer after script completion?"
    return $Chosen
}

$QuitPC = ShutdownComputer


# Function to check if a file is locked by another process
function Is-FileLocked {
    param (
        [string]$filePath
    )
    try {
        $fileStream = [System.IO.File]::Open($filePath, 'Open', 'ReadWrite', 'None')
        if ($fileStream) {
            $fileStream.Close()
            return $false
        }
    } catch {
        return $true
    }
}

function Process-Videos {
    param (
        [string]$directory
    )
    Write-Output "Changing to directory $directory"
    Set-Location $directory

    # Get the video files
    $videoFiles = Get-ChildItem -Recurse -Include *.avi, *.flv, *.m2ts, *.mkv, *.mov, *.mp4, *.mpg, *.mts, *.ts, *.wmv
    $totalFiles = $videoFiles.Count
    $i = 0

    # Progress bar
    $progress = @{
        Activity        = "Processing Videos"
        Status          = "Processing"
        PercentComplete = 0
    }

	foreach ($file in $videoFiles) {
		$i++
		$progress.PercentComplete = [math]::Round(($i / $totalFiles) * 100)
		Write-Progress @progress

		$inputFile = $file.FullName
		$outputFileName = $($file.BaseName) + "_CRF" + $ffmpeg_qv + "_HEVC.mp4"
		$outputFile = Join-Path $dest_dir $outputFileName
		Write-Output "Processing $inputFile"

		# Get the size of the source file
		$inputFileSize = (Get-Item -LiteralPath $inputFile).Length

		# Run ffmpeg and capture the exit code
		$process = Start-Process -NoNewWindow -Wait -FilePath "ffmpeg" -ArgumentList @(
			"-hwaccel auto",
			"-i `"$inputFile`"",
			"-pix_fmt p010le",
			"-map 0:v",
			"-map 0:a",
			"-map_metadata 0",
			"-c:v hevc_nvenc",
			"-rc constqp",
			"-qp $ffmpeg_qv",
			"-b:v 0K",
			"-c:a aac",
			"-b:a 384k",
			"-movflags +faststart",
			"-movflags use_metadata_tags",
			"`"$outputFile`""
		) -PassThru

		# Wait for the process to exit and get the exit code
		$process.WaitForExit()
		$exitCode = $process.ExitCode

		if ($exitCode -eq 0 -and (Test-Path -LiteralPath $outputFile)) {
			# Get the size of the output file
			$outputFileSize = (Get-Item -LiteralPath $outputFile).Length

			if ($outputFileSize -lt $inputFileSize) {
				Write-Output "Compression successful. Deleting source file: $inputFile"
				try {
					Remove-Item -LiteralPath $inputFile -Force
				} catch {
					Write-Output "Failed to delete source file: $inputFile. Error: $_"
				}
			} else {
				Write-Output "Output file size is greater than or equal to source file. Deleting output file: $outputFile"
				try {
					Remove-Item -LiteralPath $outputFile -Force
				} catch {
					Write-Output "Failed to delete output file: $outputFile. Error: $_"
				}
			}
		} else {
			Write-Output "Compression failed for $inputFile. Removing incomplete output file: $outputFile"
			if (Test-Path -LiteralPath $outputFile) {
				try {
					Remove-Item -LiteralPath $outputFile -Force
				} catch {
					Write-Output "Failed to delete output file: $outputFile. Error: $_"
				}
			}
		}
	}
}


# Check if paths file exists and iterate through it
if (Test-Path $pathsFile) {
    Get-Content $pathsFile | ForEach-Object {
        Process-Videos -directory $_
    }
}
else {
    # Paths file doesn't exist, process current directory
    Process-Videos -directory (Get-Location)
}

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


if ($QuitPC -eq 1) {
    # Shut down the computer
    shutdown -s -f -t 60
}