# Default variables
$pathsFile = "paths.txt"
$ffmpeg_qv = 24
$dest_dir = "F:\.ignore\Videos\Compressed"

# Execution statistics
$scriptStartTime = Get-Date
$script:PathsProcessed = 0
$script:ProcessedPaths = [System.Collections.Generic.List[string]]::new()
$script:FilesFound = 0
$script:FilesConverted = 0
$script:ConversionErrors = 0
$script:FilesNotSmaller = 0
$script:SourceDeleteErrors = 0
$script:FailedFiles = [System.Collections.Generic.List[string]]::new()


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
	}
 catch {
		return $true
	}
}

function Process-Videos {
	param (
		[string]$directory
	)
	Write-Output "Changing to directory $directory"
	$script:PathsProcessed++
	$script:ProcessedPaths.Add($directory)
	try {
		Set-Location -LiteralPath $directory -ErrorAction Stop
	}
	catch {
		$script:ConversionErrors++
		$script:FailedFiles.Add("PATH ERROR: $directory - $($_.Exception.Message)")
		Write-Output "Failed to access directory $directory. Error: $_"
		return
	}

	# Get the video files
	$videoFiles = Get-ChildItem -Recurse -Include *.avi, *.flv, *.m2ts, *.mkv, *.mov, *.mp4, *.mpg, *.mts, *.ts, *.wmv
	$totalFiles = $videoFiles.Count
	$script:FilesFound += $totalFiles
	$i = 0

	# Progress bar
	$progress = @{
		Activity        = "Processing Videos"
		Status          = "Processing"
		PercentComplete = 0
	}

	foreach ($file in $videoFiles) {
		$i++
		if ($totalFiles -gt 0) { $progress.PercentComplete = [math]::Round(($i / $totalFiles) * 100) }
		Write-Progress @progress

		$inputFile = $file.FullName
		# Build relative path from the root directory passed to Process-Videos
		$relativePath = $file.DirectoryName.Substring($directory.Length).TrimStart('\', '/')
    
		# Full output directory path preserving structure
		$outputDir = Join-Path $dest_dir $relativePath
    
		# Ensure directory exists
		if (-not (Test-Path $outputDir)) {
			New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
		}
		$outputFileName = $($file.BaseName) + "_CRF" + $ffmpeg_qv + "_HEVC.mp4"
		$outputFile = Join-Path $outputDir $outputFileName
		Write-Output "Processing $inputFile"

		# Get the size of the source file
		$inputFileSize = (Get-Item -LiteralPath $inputFile).Length

		# Run ffmpeg and capture the exit code
		try {
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
			) -PassThru -ErrorAction Stop

			$process.WaitForExit()
			$exitCode = $process.ExitCode
		}
		catch {
			$exitCode = -1
			Write-Output "Failed to start/run ffmpeg for $inputFile. Error: $_"
		}

		if ($exitCode -eq 0 -and (Test-Path -LiteralPath $outputFile)) {
			# Get the size of the output file
			$outputFileSize = (Get-Item -LiteralPath $outputFile).Length

			if ($outputFileSize -lt $inputFileSize) {
				$script:FilesConverted++
				Write-Output "Compression successful. Deleting source file: $inputFile"
				try {
					Remove-Item -LiteralPath $inputFile -Force -ErrorAction Stop
				}
				catch {
					$script:SourceDeleteErrors++
					Write-Output "Failed to delete source file: $inputFile. Error: $_"
				}
			}
			else {
				$script:FilesNotSmaller++
				Write-Output "Output file size is greater than or equal to source file. Deleting output file: $outputFile"
				try {
					Remove-Item -LiteralPath $outputFile -Force
				}
				catch {
					Write-Output "Failed to delete output file: $outputFile. Error: $_"
				}
			}
		}
		else {
			$script:ConversionErrors++
			$script:FailedFiles.Add("$inputFile (ffmpeg exit code: $exitCode)")
			Write-Output "Compression failed for $inputFile. Removing incomplete output file: $outputFile"
			if (Test-Path -LiteralPath $outputFile) {
				try {
					Remove-Item -LiteralPath $outputFile -Force
				}
				catch {
					Write-Output "Failed to delete output file: $outputFile. Error: $_"
				}
			}
		}
	}
}


# Check if paths file exists and iterate through it
if (Test-Path $pathsFile) {
	Get-Content $pathsFile | ForEach-Object {
		$path = $_.Trim()

		# Skip empty lines and commented-out paths
		if ([string]::IsNullOrWhiteSpace($path) -or $path.StartsWith('#')) {
			return
		}

		Process-Videos -directory $path
	}
}
else {
	# Paths file doesn't exist, process current directory
	Process-Videos -directory (Get-Location)
}

# SMTP configuration and Windows Credential Manager credentials
$credentialTarget = 'rename_pics_smtp'

function Get-Crf24EnvironmentValue {
	param(
		[Parameter(Mandatory)][string]$Name,
		[string]$DefaultValue = $null
	)

	foreach ($target in @('Process', 'User', 'Machine')) {
		try {
			$value = [Environment]::GetEnvironmentVariable($Name, [EnvironmentVariableTarget]::$target)
		}
		catch {
			$value = $null
		}

		if (-not [string]::IsNullOrWhiteSpace($value)) {
			return $value
		}
	}

	return $DefaultValue
}

function Get-WindowsGenericCredential {
	param([Parameter(Mandatory)][string]$Target)

	if (-not ('Crf24.CredentialManager.CredentialReader' -as [type])) {
		Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace Crf24.CredentialManager
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

	$values = [Crf24.CredentialManager.CredentialReader]::ReadGeneric($Target)
	if (-not $values -or $values.Count -lt 2 -or [string]::IsNullOrWhiteSpace($values[0]) -or [string]::IsNullOrEmpty($values[1])) {
		return $null
	}

	$securePassword = ConvertTo-SecureString $values[1] -AsPlainText -Force
	$credential = [pscredential]::new($values[0], $securePassword)
	$values[1] = $null
	return $credential
}

$smtpServer = Get-Crf24EnvironmentValue -Name 'RENAME_PICS_SMTP_SERVER' -DefaultValue 'smtp.gmail.com'
$smtpPort = [int](Get-Crf24EnvironmentValue -Name 'RENAME_PICS_SMTP_PORT' -DefaultValue '587')
$smtpTo = Get-Crf24EnvironmentValue -Name 'RENAME_PICS_SMTP_TO'

$credential = Get-WindowsGenericCredential -Target $credentialTarget
if (-not $credential) {
	throw "Windows Credential Manager target '$credentialTarget' was not found or is incomplete."
}

$smtpUser = $credential.UserName
$smtpFrom = $smtpUser
$decryptedPassword = $credential.GetNetworkCredential().Password

# Send email notification
$ScriptName = $MyInvocation.MyCommand.Name
$scriptEndTime = Get-Date
$scriptDuration = $scriptEndTime - $scriptStartTime
$durationText = if ($scriptDuration.TotalHours -ge 1) {
	"{0:hh\:mm\:ss}" -f $scriptDuration
} else {
	"{0:mm\:ss}" -f $scriptDuration
}

$conversionStatus = if ($script:ConversionErrors -eq 0) { "No conversion errors detected" } else { "$($script:ConversionErrors) conversion/path error(s) detected" }
$processedPathsText = if ($script:ProcessedPaths.Count -gt 0) {
	"`r`nProcessed paths:`r`n- " + ($script:ProcessedPaths -join "`r`n- ")
} else { "" }

$failedFilesText = if ($script:FailedFiles.Count -gt 0) {
	"`r`nFailed items:`r`n- " + ($script:FailedFiles -join "`r`n- ")
} else { "" }

$messageSubject = "Script execution is complete - `"$ScriptName`""
$messageBody = @"
The `"$ScriptName`" script execution is complete.

Summary:
- Started:              $($scriptStartTime.ToString('yyyy-MM-dd HH:mm:ss'))
- Finished:             $($scriptEndTime.ToString('yyyy-MM-dd HH:mm:ss'))
- Total runtime:        $durationText
- Paths processed:      $($script:PathsProcessed)
- Video files found:    $($script:FilesFound)
- Files converted:      $($script:FilesConverted)
- Files not kept because output was not smaller: $($script:FilesNotSmaller)
- Conversion errors:    $($script:ConversionErrors)
- Source delete errors: $($script:SourceDeleteErrors)
- Conversion status:    $conversionStatus
$processedPathsText
$failedFilesText
"@

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


if ($QuitPC -eq 1) {
	# Shut down the computer
	shutdown -s -f -t 60
}