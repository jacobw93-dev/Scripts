$Host.UI.RawUI.WindowTitle = "Batch rename images"
#$Host.PrivateData.ProgressBackgroundColor = 'Red'
#$Host.PrivateData.ProgressForegroundColor = 'Black'

$fileTypes = @('.jpeg', '.jpg', '.png')
$excludedFileTypes = @('.!qb', '.part', '.zip', '.rar')
$CompressedFileTypes = @('.zip')
$regex_str = '[^0-9A-Za-z\.]+';
$Date = Get-Date -format "yyyyMMdd_HHmmss"
$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'

Add-Type -AssemblyName System.Windows.Forms
Set-ItemProperty $key Hidden 1
Set-ItemProperty $key ShowSuperHidden 1
#Stop-Process -processname explorer

$FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{
	SelectedPath = 'D:\Downloads\Pics\'
	Description  = "Select a directory containing images"
}


if ($FolderBrowser.ShowDialog() -eq 'OK') {
	$InputFolder = $FolderBrowser.SelectedPath
	Write-Host "Selected folder: $InputFolder"
}
else {
	Write-Host "User cancelled the operation."
	Pause
	Exit
}

Set-ItemProperty $key Hidden 0
Set-ItemProperty $key ShowSuperHidden 0
#Stop-Process -processname explorer
$changelog_FullName = "$InputFolder" + '\' + "changelog_" + ((Get-Item -Path $InputFolder).BaseName -Replace $regex_str, "_") + "_" + $Date + ".txt"


cd -LiteralPath "$InputFolder" ;
Get-ChildItem -LiteralPath $InputFolder -Directory | ? { !(gci -LiteralPath $_ -file -recurse | where-object { $_.extension -in $excludedFileTypes }) } | gci -File -Recurse | where-Object { $_.extension -notin $fileTypes } | Remove-Item ;


ls  $InputFolder -Directory -Recurse | where { -NOT $_.GetFiles() -and -not $_.GetDirectories() } | Remove-Item ;

# determine whether to rename subfolders of the previously specified $InputFolder directory. In case of option [1] the script should rename the folders inside the given folder, otherwise [2] only their subfolders.

function RenameMode {
	$answer = $null
	while (@("1", "2") -notcontains $answer) {
		$answer = Read-Host "`nShould I swap file names in first or second level subdirectories? `n1 (First Level), 2 (Second Level)"
		$answer = $answer.ToUpper().Trim();
		Switch ($answer) {
			1 { $RenMode = "0" }
			2 { $RenMode = "1" }
		}
		If (@("1", "2") -notcontains $answer) { Write-Host "Enter the correct value"; pause }
	}
	return $RenMode
}

function RenameFolderAndSubFolders {
	param($item, $number)
	$subfolders = Get-ChildItem -LiteralPath $item.FullName -Directory -Force
  
	$myChangeLog = [System.Collections.Generic.List[object]]::new()

	foreach ($folder in $subfolders) {
		RenameFolderAndSubFolders $folder $number
	}
	while ($true) {
		try {
			$Current_timestamp = Get-Date -format "yyyyMMdd_HHmmss"
			$NewName = $item.Parent.Name + ' - Set ' + ($number.ToString().PadLeft(3, '0'))
			Rename-Item -LiteralPath $item.FullName -NewName $NewName -ErrorAction Stop
			$logEntry = $("$Current_timestamp;'{0}';'{1}' " -f $item.FullName, $NewName)
			$myChangeLog.Add($logEntry) | Out-Null
			return
		}
		catch {}
		$number++
	}

	$myChangeLog | Out-File -Encoding UTF8 -FilePath ($changelog_FullName) -Append;
}

function ExtractArchivesOnly {
	$answer = $null
	while (@("y", "n") -notcontains $answer) {
		$answer = Read-Host "`nShould I extract archives only? Y (Yes), N (No)"
		$answer = $answer.ToLower().Trim();
		Switch ($answer) {
			y { $Chosen = "1" }
			n { $Chosen = "0" }
		}
		If (@("y", "n") -notcontains $answer) { Write-Host "Enter the correct value"; pause }
	}
	return $Chosen
}

function ChangeFoldersNames {
	$answer = $null
	while (@("y", "n") -notcontains $answer) {
		$answer = Read-Host "`nShould I swap directory names? Y (Yes), N (No)"
		$answer = $answer.ToLower().Trim();
		Switch ($answer) {
			y { $Chosen = "1" }
			n { $Chosen = "0" }
		}
		If (@("y", "n") -notcontains $answer) { Write-Host "Enter the correct value"; pause }
	}
	return $Chosen
}

function SetFolderNumerator {
	$defaultValue = 1
	$Number_from = Read-Host "`nSpecify the number from which to start numbering the directories (default: $defaultValue)"
	if ($Number_from -eq "") { $Number_from = $defaultValue }
	$Number_result = Is-Numeric $Number_from
	while ($Number_result -eq $False) {
		$Number_from = Read-Host "`nSpecify the number from which to start numbering the directories (default: $defaultValue)"
		if ($Number_from -eq "") { $Number_from = $defaultValue }
		$Number_result = Is-Numeric $Number_from
	}
	$Number_from = [int]$Number_from
	return $Number_from
}

function Is-Numeric ($Value) {
	return $Value -match "^[\d\.]+$"
}

function ExtractArchives {
	$Archives = ls -LiteralPath "$InputFolder" -file -Recurse | where-object { $_.extension -in $CompressedFileTypes } ;
	$Archive_counter = (gci $InputFolder -file -Recurse | where-object { $_.extension -in $CompressedFileTypes } ).Count
	$k = 0

	Foreach ($Archive In $Archives) {
		$k++
		$percent_Archive = [math]::Round($k / $Archive_counter * 100)
		Write-Progress -Id 1  -activity "Total Progress Bar" -CurrentOperation "Current file: '$Archive'" -Status "Processing $k of $Archive_counter ($percent_Archive%)"  -PercentComplete $percent_Archive
		$NewName = ($Archive.Name -Replace $regex_str, ".");
		$NewBaseName = ($Archive.Name -Replace $regex_str, ".");
		$NewFullName = ($Archive.FullName -Replace [regex]::Escape($Archive.Name), $NewName);
		$TargetPath = ($Archive.FullName -Replace [regex]::Escape($Archive.BaseName), $NewBaseName).trimend($Archive.Extension);
		Rename-Item  -LiteralPath $Archive.FullName -NewName $NewName;
		Expand-Archive -LiteralPath $NewFullName -DestinationPath $TargetPath -Force
		Remove-Item -LiteralPath $NewFullName
	}
}

$Archive_counter = (gci $InputFolder -file -Recurse | where-object { $_.extension -in $CompressedFileTypes } ).Count
If ( $Archive_counter -ge 1 ) {
	$ArchivesOnly = ExtractArchivesOnly
	If ( $ArchivesOnly -eq "1" ) { ExtractArchives; start . ; exit }
}
$RenMode = RenameMode
$Choose = ChangeFoldersNames
If ( $Choose -eq "1" ) { $FolderNumerator = SetFolderNumerator }
If ( $Archive_counter -ge 1 ) { ExtractArchives }
	
# Get list of parent folders in root path
Switch ($RenMode) {
	"0" { $ParentFolders = Get-ChildItem -LiteralPath $InputFolder -Directory -Name -Recurse | Where-Object { ($_ -split '[/\\]').Count -eq 1 } | Get-Item -LiteralPath { "$InputFolder\$_" } | ? { (gci -LiteralPath $_.FullName -file -recurse | where-object { $_.extension -notin $excludedFileTypes }) } }
	"1" { $ParentFolders = Get-ChildItem -LiteralPath $InputFolder -Directory -Name -Recurse | Where-Object { ($_ -split '[/\\]').Count -eq 2 } | Get-Item -LiteralPath { "$InputFolder\$_" } | ? { (gci -LiteralPath $_.FullName -file -recurse | where-object { $_.extension -notin $excludedFileTypes }) } }
}

# For each parent folder get all folders recursively and move to parent
ForEach ($Parent in $ParentFolders) {
	ls -LiteralPath ($Parent.FullName) -Directory -Recurse | where { $_.GetFiles() -and -not $_.GetDirectories() } | ForEach-Object {
		$n = ($Parent.Parent.FullName + '\' + $_.Parent.BaseName + ' - ' + $_.BaseName );
		Move-Item -LiteralPath $_.FullName -Destination $n -verbose
	}
}

ls  $InputFolder -Directory -Recurse | where { -NOT $_.GetFiles() -and -not $_.GetDirectories() } | Remove-Item ;

If ( $Choose -eq "1" ) {
		
	Switch ($RenMode) {
		"0" { Get-ChildItem -LiteralPath $InputFolder -Directory -Name -Recurse | Where-Object { ($_ -split '[/\\]').Count -eq 1 } | Get-Item -LiteralPath { "$InputFolder\$_" } | ? { (gci -LiteralPath $_.FullName -file -recurse | where-object { $_.extension -notin $excludedFileTypes }) }  | sort-object { [regex]::Replace($_, '\d+', { $args[0].Value.PadLeft(100) }) } | % { RenameFolderAndSubFolders -item $_ -number $FolderNumerator } }
		"1" { Get-ChildItem -LiteralPath $InputFolder -Directory -Name -Recurse | Where-Object { ($_ -split '[/\\]').Count -eq 1 } | Get-Item -LiteralPath { "$InputFolder\$_" } | ? { (gci -LiteralPath $_.FullName -file -recurse | where-object { $_.extension -notin $excludedFileTypes }) }  | sort-object { [regex]::Replace($_, '\d+', { $args[0].Value.PadLeft(100) }) } | % { RenameFolderAndSubFolders -item $_ -number $FolderNumerator } }
	}

}

$Folder = dir -LiteralPath . -Recurse -Directory | sort-object { [regex]::Replace($_, '\d+', { $args[0].Value.PadLeft(50) }) } ;
$folder_counter = (dir -LiteralPath . -Recurse -Directory).Count
$k = 0
$file_counter = (Get-ChildItem -Recurse -Directory -LiteralPath "$InputFolder" | Get-ChildItem -File | where-object { $_.extension -in $fileTypes }).Count
$l = 0


$myChangeLog = [System.Collections.Generic.List[object]]::new()
  
Foreach ($dir In $Folder) {
	$k++
	$percent_folder = [math]::Round($k / $folder_counter * 100)
	Write-Progress -Id 1 -activity "Folder Progress Bar" -CurrentOperation "Current directory: '$dir'" -Status "Processing $k of $folder_counter ($percent_folder%)"  -PercentComplete $percent_folder
	$current_dir = (Get-Location).path + '\' + $dir;

	# Set default value for addition to file name
	$counter = 1
	$newdir = $dir.name
	# Search for the files set in the filter
	$files = Get-ChildItem -LiteralPath $dir.fullname -File | where-object { $_.extension -in $fileTypes } | sort-object { [regex]::Replace($_, '\d+', { $args[0].Value.PadLeft(50) }) }
	Foreach ($file In $files) {
		$Current_timestamp = Get-Date -format "yyyyMMdd_HHmmss"
		$extension = $file.Extension
		# Check if a file exists
		If ($file) {
			$l++
			$percent_file = [math]::Round($l / $file_counter * 100)
			Write-Progress -Id 2  -activity "Total Progress Bar" -CurrentOperation "Current file: '$file'" -Status "Processing $l of $file_counter ($percent_file%)"  -PercentComplete $percent_file
			$replace = $newdir + "_" + $zero + ($counter.ToString().PadLeft(3, '0')) + "." + $extension
			# Trim spaces and rename the file
			$image_string = $file.fullname.ToString().Trim()
			#"$split[0] renamed to $replace"
			$replace = (($replace -Replace $regex_str, ".") -replace '\.+', '.');
			Rename-Item  -LiteralPath "$image_string" "$replace";

			$logEntry = $("$Current_timestamp;'{0}';'{1}'" -f $image_string, $replace)
			$myChangeLog.Add($logEntry) | Out-Null

			$counter++
		}
	}
}

$myChangeLog | Out-File -Encoding UTF8 -FilePath ($changelog_FullName) -Append;

ls $InputFolder -Directory -Recurse | where { -NOT $_.GetFiles() -and -not $_.GetDirectories() } | Remove-Item ;