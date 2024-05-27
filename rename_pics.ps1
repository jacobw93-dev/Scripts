$Host.UI.RawUI.WindowTitle = "Batch rename images"
$Host.UI.RawUI.ForegroundColor = "White"
$Host.PrivateData.ProgressBackgroundColor = 'Yellow'
$Host.PrivateData.ProgressForegroundColor = 'Black'
$PSStyle.Progress.View = 'Minimal'

$fileTypes = @('.jpeg', '.jpg', '.png')
$excludedFileTypes = @('.!qb', '.part', '.zip', '.rar')
$CompressedFileTypes = @('.zip', '.rar')
$regex_str = '[^0-9A-Za-z\.]+';
$Date = Get-Date -format "yyyyMMdd_HHmmss"
$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$LowQualityName = 'LQ'
$ContactSheetsName = 'CS'
$ExcludedFolderNames = @($LowQualityName, $ContactSheetsName)

Add-Type -AssemblyName System.Windows.Forms
Set-ItemProperty $key Hidden 1
Set-ItemProperty $key ShowSuperHidden 1
# Stop-Process -processname explorer

function SelectInputFolder {
	$FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{
		SelectedPath = 'D:\Downloads\Pics\'
		Description  = "Select a directory containing images"
	}

	if ($FolderBrowser.ShowDialog() -eq 'OK') {
		$InputFolder = $FolderBrowser.SelectedPath
		Write-Host -ForegroundColor Green "`nSelected folder:"
		Write-Host "$InputFolder"
		return $InputFolder
	}
	else {
		Write-Host -ForegroundColor Red "`nUser cancelled the operation."
		Pause
		Exit
	}
}
$InputFolder = SelectInputFolder

Set-ItemProperty $key Hidden 0
Set-ItemProperty $key ShowSuperHidden 0
# Stop-Process -processname explorer
$changelog_FullName = "$InputFolder" + '\' + "changelog_" + ((Get-Item -Path $InputFolder).BaseName -Replace $regex_str, "_") + "_" + $Date + ".txt"

# determine whether to rename subfolders of the previously specified $InputFolder directory. In case of option [1] the script should rename the folders inside the given folder, otherwise [2] only their subfolders.

function RenameMode {
	$answer = $null
	while (@("1", "2") -notcontains $answer) {
		Write-Host -ForegroundColor Green "`nShould I swap file names in first or second level subdirectories? `n1 (First Level), 2 (Second Level)"
		$answer = Read-Host
		$answer = $answer.ToUpper().Trim();
		Switch ($answer) {
			"1" { $RenMode = 0 }
			"2" { $RenMode = 1 }
		}
		If (@("1", "2") -notcontains $answer) { Write-Host "Enter the correct value"; pause }
	}
	return $RenMode
}
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

function ExtractArchivesOnly {
	$Chosen = Get-UserChoice -Question "Should I extract archives only?"
	return $Chosen
}

function ChangeFoldersNames {
	$Chosen = Get-UserChoice -Question "Should I swap directory names?"
	return $Chosen
}

function MoveLQandCSImages {
	$Chosen = Get-UserChoice -Question "Should I move low quality and contact sheet images to separate directory?"
	return $Chosen
}

function ShutdownComputer {
	$Chosen = Get-UserChoice -Question "Should I shutdown computer after script completion?"
	return $Chosen
}

function Is-Numeric ($Value) {
	return $Value -match "^[\d\.]+$"
}

function SetFolderNumerator {
	$defaultValue = 1
	do {
		Write-Host -ForegroundColor Green "`nSpecify the number from which to start numbering the directories (default: $defaultValue)"
		$Number_from = Read-Host
		if ($Number_from -eq "") {
			$Number_from = $defaultValue 
			Write-Host $Number_from
		}
		$Number_result = Is-Numeric $Number_from
		if (-not $Number_result) {
			Write-Host -ForegroundColor Red "`nInvalid input. Please enter a valid number." ; pause
		}
	} while ($Number_result -eq $False)
	$Number_from = [int]$Number_from
	return $Number_from
}


function ExtractArchives {
	$myChangeLog = [System.Collections.Generic.List[object]]::new()
	$Archives = Get-ChildItem -LiteralPath "$InputFolder" -file -Recurse | where-object { $_.extension -in $CompressedFileTypes } ;
	$Total_archives_count = (Get-ChildItem $InputFolder -file -Recurse | where-object { $_.extension -in $CompressedFileTypes } ).Count
	$archives_counter = 0

	Foreach ($Archive In $Archives) {
		$Current_timestamp = Get-Date -format "yyyyMMdd_HHmmss"
		$archives_counter++
		$percent_Archive = [math]::Round($archives_counter / $Total_archives_count * 100)
		Write-Progress -activity "Total Extraction Progress" -CurrentOperation "Current file: '$Archive'" -Status "Processing $archives_counter of $Total_archives_count ($percent_Archive%)" -PercentComplete $percent_Archive
		$NewName = ($Archive.Name -Replace $regex_str, ".");
		$NewBaseName = ($Archive.Name -Replace $regex_str, ".");
		$NewFullName = ($Archive.FullName -Replace [regex]::Escape($Archive.Name), $NewName);
		$TargetPath = ($Archive.FullName -Replace [regex]::Escape($Archive.BaseName), $NewBaseName).trimend($Archive.Extension);
		Rename-Item -LiteralPath $Archive.FullName -NewName $NewName;
		# Expand-Archive -LiteralPath $NewFullName -DestinationPath $TargetPath -Force
		Expand-7Zip -ArchiveFileName $NewFullName -TargetPath $TargetPath
		Remove-Item -LiteralPath $NewFullName
		$logEntry = $("$Current_timestamp; Extracted archive:'{0}';'{1}' " -f $NewFullName, $TargetPath)
		$myChangeLog.Add($logEntry) | Out-Null
	}
	# return $Total_archives_count
	$myChangeLog | Out-File -Encoding UTF8 -FilePath ($changelog_FullName) -Append;
}

function CleanFilesandFolders {
	Get-ChildItem -LiteralPath $InputFolder -File -Recurse | Where-Object {
		$_.extension -notin $excludedFileTypes -and
		$_.extension -notin $fileTypes -and
		$_.Name -notlike '*changelog*' -and
		$_.Extension -ne '.txt' } | Remove-Item -Verbose
	Get-ChildItem $InputFolder -Directory -Recurse | Where-Object { -NOT $_.GetFiles() -and -not $_.GetDirectories() } | Remove-Item -Verbose ;
}

$Total_archives_count = (Get-ChildItem $InputFolder -file -Recurse | where-object { $_.extension -in $CompressedFileTypes } ).Count
$Archives_count = $Total_archives_count
If ( $Total_archives_count -ge 1 ) {
	$ArchivesOnly = ExtractArchivesOnly
	If ( $ArchivesOnly -eq "1" ) {
		$startTime = Get-Date
		ExtractArchives
		$endTime = Get-Date
		$processTime = $endTime - $startTime
		$processTimeFormatted = '{0:hh\:mm\:ss}' -f $processTime
		Write-Host "Process time: $processTimeFormatted (hh:mm:ss)"
		pause
		exit
	}
}

$RenMode = RenameMode
$Choose = ChangeFoldersNames
$MoveLQCS = MoveLQandCSImages
$QuitPC = ShutdownComputer

If ( $Choose -eq "1" ) { $FolderNumerator = SetFolderNumerator }
If ( $Total_archives_count -ge 1 ) { ExtractArchives }

# Start time
$startTime = Get-Date

CleanFilesandFolders
	
# Get list of parent folders in root path
function get-ParentFolders {
	param(
		[string]$InputValueString,
		[string]$RenModeString,
		[string]$InputFolder,
		[string[]]$excludedFileTypes
	)
	$InputValue = [int]$InputValueString
	$RenMode = [int]$RenModeString
	Switch ($RenMode) {
		0 { $ParentFolders = Get-ChildItem -LiteralPath $InputFolder -Directory -Name -Recurse | Where-Object { ($_ -split '[/\\]').Count -eq $InputValue } | Get-Item -LiteralPath { "$InputFolder\$_" } | Where-Object { (Get-ChildItem -LiteralPath $_.FullName -file -recurse | where-object { $_.extension -notin $excludedFileTypes }) } }
		1 { $ParentFolders = Get-ChildItem -LiteralPath $InputFolder -Directory -Name -Recurse | Where-Object { ($_ -split '[/\\]').Count -eq ($InputValue + 1) } | Get-Item -LiteralPath { "$InputFolder\$_" } | Where-Object { (Get-ChildItem -LiteralPath $_.FullName -file -recurse | where-object { $_.extension -notin $excludedFileTypes }) } }
	}
	return $ParentFolders
}

$ParentFolders = get-ParentFolders -InputValueString "1" -RenModeString $RenMode -InputFolder $InputFolder -excludedFileTypes $excludedFileTypes

# For each parent folder get all folders recursively and move to parent
$myChangeLog = [System.Collections.Generic.List[object]]::new()
ForEach ($Parent in $ParentFolders) {
	Get-ChildItem -LiteralPath ($Parent.FullName) -Directory -Recurse | Where-Object { $_.GetFiles() -and -not $_.GetDirectories() } | ForEach-Object {
		$Current_timestamp = Get-Date -format "yyyyMMdd_HHmmss"
		$n = ($Parent.Parent.FullName + '\' + $_.Parent.BaseName + ' - ' + $_.BaseName );
		Move-Item -LiteralPath $_.FullName -Destination $n -verbose
		$logEntry = $("$Current_timestamp; Moved directory:'{0}';'{1}' " -f $_.FullName, $n)
		$myChangeLog.Add($logEntry) | Out-Null	
	}
}
$myChangeLog | Out-File -Encoding UTF8 -FilePath ($changelog_FullName) -Append;

CleanFilesandFolders

Write-Host "`nStart time: $startTime"

# Get all images with width and height less than 900 px and move them to separate folder
Add-Type -AssemblyName System.Drawing
$myChangeLog = [System.Collections.Generic.List[object]]::new()
$ParentFolders = get-ParentFolders -InputValueString "1" -RenModeString $RenMode -InputFolder $InputFolder -excludedFileTypes $excludedFileTypes | where-object { $_.Name -notin $ExcludedFolderNames }

If ( ($MoveLQCS -eq "1") -and (($ParentFolders).Count -ge 1)) {
	$i = 0
	$j = 0
	$k = 0
	$pictures = Get-ChildItem -LiteralPath ($ParentFolders.FullName) -recurse -file | where-object { $_.extension -in $fileTypes }
	$pictures_Count = $pictures.Count
	$pictures_Count_formatted = "{0:N0}" -f $pictures_Count
	$pictures_Count_formatted = $pictures_Count_formatted -replace ",", " "

	$startTime = Get-Date

	ForEach ($picture in $pictures) {
		$Current_timestamp = Get-Date -format "yyyyMMdd_HHmmss"
		$j++
		
		$j_formatted = "{0:N0}" -f $j
		$j_formatted = $j_formatted -replace ",", " "

		$percent = [math]::Round($j / $pictures_Count * 100)

		# Calculate elapsed time and estimated remaining time
		$elapsedTime = (Get-Date) - $startTime
		$estimatedTotalTime = $elapsedTime.TotalSeconds / $j * $pictures_Count
		$estimatedRemainingTime = [TimeSpan]::FromSeconds($estimatedTotalTime - $elapsedTime.TotalSeconds)

		Write-Progress -Id 1 -Activity "Time remaining" -Status ("Estimated time remaining: {0:hh\:mm\:ss} [hh:mm:ss]" -f $estimatedRemainingTime)
		Write-Progress -Id 2 -parentId 1 -Activity "Analyzing images..." -CurrentOperation "Current file: `"$($picture.Name)`", directory: `"$($picture.Directory.Name)`"" -Status "Processing $j_formatted of $pictures_Count_formatted ($percent%)" -PercentComplete $percent
		Write-Progress -Id 3 -parentId 2 -Activity "Moving LQ images..." -Status "Found $i LQ images"
		Write-Progress -Id 4 -parentId 2 -Activity "Moving CS images..." -Status "Found $k CS images"
		try {
			$Image = [System.Drawing.Image]::FromFile($picture.FullName)
			$Width = $Image.Width
			$Height = $Image.Height
			$AspectRatio = $Height / $Width
			$Image.Dispose()

			# Define conditions
			$IsLowQuality = ($Width -lt 900 -and $Height -lt 900)
			$IsContactSheet = ($AspectRatio -ge 2) -or ($picture.Name -match "contactsheet|cs")
			# Check if width is zero to prevent division by zero
			if ($IsLowQuality) {
				$i++
				$destinationFolder = $picture.Directory.Parent.FullName + '\' + $LowQualityName;
				$destinationFile = $destinationFolder + '\' + $picture.Directory.Name + '_' + $picture.Name;
				if (-not (Test-Path -Path $destinationFolder -PathType Container)) {
					New-Item -Path $destinationFolder -ItemType Directory
				}
				Move-Item -LiteralPath $picture.FullName $destinationFile -Force
				$logEntry = $("$Current_timestamp; Moved file:'{0}';'{1}' " -f $picture.FullName, $destinationFile)
				$myChangeLog.Add($logEntry) | Out-Null
			}
			elseif ($IsContactSheet) {
				$k++
				$destinationFolder = $picture.Directory.Parent.FullName + '\' + $ContactSheetsName;
				$destinationFile = $destinationFolder + '\' + $picture.Directory.Name + '_' + $picture.Name;
				if (-not (Test-Path -Path $destinationFolder -PathType Container)) {
					New-Item -Path $destinationFolder -ItemType Directory
				}
				Move-Item -LiteralPath $picture.FullName $destinationFile -Force
				$logEntry = $("$Current_timestamp; Moved file:'{0}';'{1}' " -f $picture.FullName, $destinationFile)
				$myChangeLog.Add($logEntry) | Out-Null
			}
			$image.Dispose()
		}
		catch {
			$LogEntry = "Error processing $($File.FullName): $_"
			$myChangeLog.Add($logEntry) | Out-Null
		}
	}
}
CleanFilesandFolders

$LQImages_counter = $i
$CSImages_counter = $k
$myChangeLog | Out-File -Encoding UTF8 -FilePath ($changelog_FullName) -Append;

# Rename Folders
If ( $Choose -eq "1" ) {
		
	$ParentFolders = get-ParentFolders -InputValueString "1" -RenModeString $RenMode -InputFolder $InputFolder -excludedFileTypes $excludedFileTypes | where-object { $_.Name -notin $ExcludedFolderNames }
	$myChangeLog = [System.Collections.Generic.List[object]]::new()
	$number = $FolderNumerator
	
	foreach ($folder in $ParentFolders) {
		if ( ($previousfolder.Parent.FullName) -ne ($folder.Parent.FullName) ) { $number = $FolderNumerator }
		try {
			$folder_count = (Get-ChildItem $folder.Parent.FullName -Directory).Count
			$PaddingLength = $folder_count.ToString().Length
			$Current_timestamp = Get-Date -format "yyyyMMdd_HHmmss"
			$tempName = ($number.ToString().PadLeft($PaddingLength, '0'))
			$NewName = $folder.Parent.Name + ' - Set ' + $tempName
			Rename-Item -LiteralPath $($folder.FullName) -NewName $tempName -Force -Verbose -ErrorAction SilentlyContinue
			Rename-Item -LiteralPath ($($folder.Parent.FullName) + "\" + $tempName) -NewName $NewName -Force -Verbose -ErrorAction SilentlyContinue
			$logEntry = $("$Current_timestamp; Renamed directory: '{0}';'{1}' " -f $folder.FullName, $NewName)
			$myChangeLog.Add($logEntry) | Out-Null
		}
		catch {}
		$number++
		$previousfolder = $folder
	}
		
	$myChangeLog | Out-File -Encoding UTF8 -FilePath ($changelog_FullName) -Append;

}
CleanFilesandFolders

$Folders = Get-ChildItem -LiteralPath $InputFolder -Recurse -Directory | where-object { $_.Name -notin $ExcludedFolderNames } | sort-object { [regex]::Replace($_, '\d+', { $args[0].Value.PadLeft(100) }) } ;
$Total_folder_count = (Get-ChildItem -LiteralPath $InputFolder -Recurse -Directory).Count
$dir_counter = 0
$Total_files_count = (Get-ChildItem -Recurse -Directory -LiteralPath "$InputFolder" | Get-ChildItem -File | where-object { $_.extension -in $fileTypes }).Count
$Total_files_count_formatted = "{0:N0}" -f $Total_files_count
$Total_files_count_formatted = $Total_files_count_formatted -replace ",", " "
$Total_files_counter = 0

# $startTime_ProgressBar = get-date

$myChangeLog = [System.Collections.Generic.List[object]]::new()
 
Foreach ($dir In $Folders) {
	$dir_counter++
	$Total_dir_complete = [math]::Round($dir_counter / $Total_folder_count * 100)
	Write-Progress -Id 3 -parentId 1 -activity "Total Directories" -CurrentOperation "Current directory: '$dir'" -Status "Processing $dir_counter of $Total_folder_count ($Total_dir_complete%)" -PercentComplete $Total_dir_complete
	# Set default value for addition to file name
	$counter = 1
	$newdir = $dir.name
	# Search for the files set in the filter
	$files = Get-ChildItem -LiteralPath $dir.fullname -File | where-object { $_.extension -in $fileTypes } | sort-object { [regex]::Replace($_, '\d+', { $args[0].Value.PadLeft(100) }) }
	$files_count = ($files).Count
	$PaddingLength = $files_count.ToString().Length
	$dir_files_counter = 0
	Foreach ($file In $files) {
		$Current_timestamp = Get-Date -format "yyyyMMdd_HHmmss"
		$extension = $file.Extension
		# Check if a file exists
		If ($file) {
			$Total_files_counter++
			$dir_files_counter++
			$Total_files_counter_formatted = "{0:N0}" -f $Total_files_counter
			$Total_files_counter_formatted = $Total_files_counter_formatted -replace ",", " "
			$Total_complete = [math]::Round($Total_files_counter / $Total_files_count * 100)
			$elapsedTime = $(get-date) - $startTime 
			$estimatedTotalSeconds = $Total_files_count / $Total_files_counter * $elapsedTime.TotalSeconds 
			$estimatedTotalSecondsTS = [TimeSpan]::FromSeconds($estimatedTotalSeconds)
			$estimatedCompletionTime = $startTime + $estimatedTotalSecondsTS
			$estimatedCompletionTime = Get-Date -Date $estimatedCompletionTime -Format "yyyy/MM/dd HH:mm:ss"
			Write-Progress -Id 1 -activity "Estimated Completion Time" -Status "Estimated Completion Time = $estimatedCompletionTime"
			Write-Progress -Id 2 -parentId 1 -activity "Total Files" -CurrentOperation "Current file: '$file'" -Status "Processing $Total_files_counter_formatted of $Total_files_count_formatted ($Total_complete%)" -PercentComplete $Total_complete
			$Folder_Complete = [math]::Round($dir_files_counter / $files_count * 100)
			Write-Progress -Id 4 -parentId 3 -activity "Current Folder Files" -CurrentOperation "Current file: '$file'" -Status "Processing $dir_files_counter of $files_count ($Folder_Complete%)" -PercentComplete $Folder_Complete
			$temporary = ($counter.ToString().PadLeft($PaddingLength, '0')) + "." + $extension
			$replace = $newdir + "_" + $temporary
			# Trim spaces and rename the file
			$image_string = $file.fullname.ToString().Trim()
			# "$split[0] renamed to $replace"
			$replace = (($replace -Replace $regex_str, ".") -replace '\.+', '.');
			Rename-Item -LiteralPath "$image_string" "$temporary";
			Rename-Item -LiteralPath ($($file.DirectoryName) + "\" + $temporary) "$replace";
			$logEntry = $("$Current_timestamp; Renamed file: '{0}';'{1}'" -f $image_string, $replace)
			$myChangeLog.Add($logEntry) | Out-Null
			$counter++
		}
	}
}

$myChangeLog | Out-File -Encoding UTF8 -FilePath ($changelog_FullName) -Append;

CleanFilesandFolders

# End time
$endTime = Get-Date

# Calculate process time
$processTime = $endTime - $startTime

# Format process time
$processTimeFormatted = '{0:hh\:mm\:ss}' -f $processTime

clear-host

# Write process time to console
Write-Host -ForegroundColor Green "Process time: $processTimeFormatted (hh:mm:ss)"
"`nProcess time: $processTimeFormatted (hh:mm:ss)" | Out-File -Encoding UTF8 -FilePath ($changelog_FullName) -Append;

# SMTP server credentials
$smtpUser = "my.0wn.n0tificati0n@outlook.com"
$smtpPass = "2mXorOPE9C0BcG9SZGfjP8FuSzh75Jc9GdP9L2uzMbQ="

# Send email notification
$smtpServer = "smtp-mail.outlook.com"
$smtpFrom = $smtpUser
$smtpTo = "jacob.w93@gmail.com"
$messageSubject = "Script execution is complete"
$messageBody = "The `"rename_pics.ps1`" script execution for input folder `"$InputFolder`" is complete. Please find attached changelog if the size is less than 20 MB."

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

# Path to the log file
$logFile = "$changelog_FullName"

# Check if the log file size is less than 20 MB (20 * 1024 * 1024 bytes)
if ((Get-Item $logFile).Length -lt 20MB) {
	# Attach the log file if it is less than 20 MB
	Send-MailMessage -From $smtpFrom -To $smtpTo -Subject $messageSubject -Body $messageBody -Attachments $logFile -SmtpServer $smtpServer -Credential $credential -UseSsl -Port 587
}
else {
	# Send email without attachment
	Send-MailMessage -From $smtpFrom -To $smtpTo -Subject $messageSubject -Body $messageBody -SmtpServer $smtpServer -Credential $credential -UseSsl -Port 587
}

$q = 0
Write-Host -ForegroundColor Blue "Press 'Q' to exit."
while ($true) {
	Write-Progress -Id 1 -activity "Estimated Completion Time" -Status "$estimatedCompletionTime" -PercentComplete 100
	Write-Progress -Id 2 -parentId 1 -activity "Total Directories" -Status "$Total_folder_count" -PercentComplete 100
	Write-Progress -Id 3 -parentId 1 -activity "Total Files" -Status "$Total_files_count" -PercentComplete 100
	if ($Archives_count -gt 0) { Write-Progress -Id 4 -parentId 1 -activity "Total Extraction Progress" -Status "$Archives_count" -PercentComplete 100 }
	if ($LQImages_counter -gt 0) { Write-Progress -Id 5 -parentId 4 -Activity "Total found LQ images..." -Status "$LQImages_counter" -PercentComplete 100 }
	if ($CSImages_counter -gt 0) { Write-Progress -Id 6 -parentId 4 -Activity "Total found CS images..." -Status "$CSImages_counter" -PercentComplete 100 }
	# Write-Progress -Id 6 -parentId 5 -activity "Current Folder Files" -Status "Completed" -PercentComplete 100
	Start-Sleep -Milliseconds 250

	# Check if 'Q' key is pressed
	if ([Console]::KeyAvailable) {
		$key = [Console]::ReadKey($true)
		if ($key.Key -eq 'Q') {
			break
		}
	}
	if (($q -eq 0) -and ($QuitPC -eq 1)) {
		# Shut down the computer
		shutdown -s -f -t 60
	}
	$q++
}