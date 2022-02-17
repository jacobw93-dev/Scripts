$Host.UI.RawUI.WindowTitle = "Batch rename images"
$Host.PrivateData.ProgressBackgroundColor='Green'
$Host.PrivateData.ProgressForegroundColor='Black'

$fileTypes = @('.jpeg','.jpg','.png')
$excludedFileTypes = @('.!qb','.part')
$regex_str1 = '[^0-9A-Za-z\.]';
$regex_str2 = '\.+';
$Date = Get-Date -format "yyyyMMdd_HHmm"

Add-Type -AssemblyName System.Windows.Forms
$FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{
    SelectedPath = 'D:\Downloads\Pics\'
	Description = "Wybierz katalog zawierajacy zdjecia"
}

[void]$FolderBrowser.ShowDialog()
$FolderBrowser.SelectedPath
$InputFolder = $FolderBrowser.SelectedPath;
$changelog_FullName = "$InputFolder" + '\' + "changelog_" + (((Get-Item -Path $InputFolder).BaseName -Replace $regex_str1,"_") -Replace $regex_str2,"_") + "_" + $Date + ".txt"


cd -LiteralPath "$InputFolder" ;

Get-ChildItem -LiteralPath $InputFolder -Directory | ? { !(gci -LiteralPath $_ -file -recurse | where-object {$_.extension -in $excludedFileTypes}) } | gci -File -Recurse | where-Object {$_.extension -notin $fileTypes} | Remove-Item ;
ls -Directory -Recurse | where { -NOT $_.GetFiles() -and -not $_.GetDirectories()} | Remove-Item ;

# ustalenie czy maja byc zmienione nazwy podfolderow wskazanego wczesniej katalogu $InputFolder. W przypadku opcji [1] skrypt powinien zmienic nazwy folderow wewnatrz zadanego katalogu, w przeciwnym wypadku [2] tylko ich podfoldery.

function RenameMode {
	$answer = $null
	while (@("1","2") -notcontains $answer)
	{
		$answer = Read-Host "`nCzy zamienic nazwy plikow w podkatalogach pierwszego czy drugiego poziomu? `n1 (Pierwszy poziom), 2 (Drugi Poziom)"
		$answer = $answer.ToUpper().Trim();
		Switch ($answer)
		{
			1 {$RenMode = "0"}
			2 {$RenMode = "1"}
		}
		If (@("1","2") -notcontains $answer) {Write-Host "Wprowadz prawidlowa wartosc"; pause}
    }
	return $RenMode
}

function RenameFolderAndSubFolders {
  param($item, $number)
  $subfolders = Get-ChildItem -LiteralPath $item.FullName -Directory

  foreach ($folder in $subfolders) {
    RenameFolderAndSubFolders $folder 1
	Write-Output "Renaming: $($item.FullName)"
  }

  while ($true){
        try {
			$Current_timestamp = Get-Date -format "yyyyMMdd_HHmmss"
			$NewName = $item.Parent.Name + ' - Set ' + ($number.ToString().PadLeft(3,'0'))
            Rename-Item -LiteralPath $item.FullName -NewName $NewName -ErrorAction Stop
			Write-Output $("$Current_timestamp;'{0}';'{1}' " -f $item.FullName,$NewName) | Out-File -Encoding UTF8 -FilePath ($changelog_FullName) -Append;
            return
        }
        catch {}
        $number++
    }
}

<# Currently not being used

function RenameFilesRecursive {
  param($item, $number)
  $Files = Get-ChildItem -LiteralPath $item.FullName -File -Recurse

  foreach ($file in $Files) {
    RenameFilesRecursive $file 1
  }

  while ($true){
        try {
			Write-Output "Renaming: $($item.FullName)"
			$NewName = $item.Parent.Name + '-' + ($number.ToString().PadLeft(3,'0')) + '.' + $item.extension
			$NewName = ($NewName -Replace $regex_str1,".") -Replace $regex_str2,".";
            Rename-Item -LiteralPath $item.FullName -NewName $NewName -ErrorAction Stop;
            return
        }
        catch {}
        $number++
    }
}
#>

function ChangeFoldersNames
{
	$answer = $null
	while (@("t","n") -notcontains $answer)
	{
		$answer = Read-Host "`nCzy zamienic nazwy katalogow? T (Tak), N (Nie)"
		$answer = $answer.ToLower().Trim();
		Switch ($answer)
		{
			t {$Chosen = "1"}
			n {$Chosen = "0"}
		}
		If (@("t","n") -notcontains $answer) {Write-Host "Wprowadz prawidlowa wartosc"; pause}
    }
	return $Chosen
}

function SetFolderNumerator
{
	$Number_from = Read-Host "`nPodaj liczbe od ktorej zaczac numerowanie katalogow"
	$Number_result = Is-Numeric $Number_from
	while ($Number_result -eq $False)
	{
		If ($Number_result -eq $False) {Write-Host "Wprowadz prawidlowa wartosc"; pause}
		$Number_from = Read-Host "`nPodaj liczbe od ktorej zaczac numerowanie katalogow"
		$Number_result = Is-Numeric $Number_from
	}
	$Number_from = [int]$Number_from
	return $Number_from
}

function Is-Numeric ($Value) {
    return $Value -match "^[\d\.]+$"
}

$RenMode = RenameMode

$Choose = ChangeFoldersNames
If ( $Choose -eq "1" )
	{
		$FolderNumerator = SetFolderNumerator
		
		Switch ($RenMode)
		{
			"0" {Get-ChildItem -LiteralPath $InputFolder -Directory | ? { !(gci -LiteralPath $_ -file -recurse | where-object {$_.extension -in $excludedFileTypes}) } | sort-object { [regex]::Replace($_, '\d+', { $args[0].Value.PadLeft(50) }) } | % { RenameFolderAndSubFolders -item $_ -number $FolderNumerator}}
			"1" {Get-ChildItem -LiteralPath $InputFolder -Directory | gci -Directory | ? { !(gci -LiteralPath $_.FullName -file -recurse | where-object {$_.extension -in $excludedFileTypes}) } | sort-object { [regex]::Replace($_, '\d+', { $args[0].Value.PadLeft(50) }) } | % { RenameFolderAndSubFolders -item $_ -number $FolderNumerator}}
		}
	}






# Get list of parent folders in root path
Switch ($RenMode)
		{
			"0" {$ParentFolders = Get-ChildItem -LiteralPath $InputFolder -Directory | ? { !(gci -LiteralPath $_ -file -recurse | where-object {$_.extension -in $excludedFileTypes}) }}
			"1" {$ParentFolders = Get-ChildItem -LiteralPath $InputFolder -Directory | gci -Directory | ? { !(gci -LiteralPath $_.FullName -file -recurse | where-object {$_.extension -in $excludedFileTypes}) }}
		}

# For each parent folder get all files recursively and move to parent, append number to file to avoid collisions
ForEach ($Parent in $ParentFolders) {
    Get-ChildItem -Path ($Parent.FullName + '\*\*\') -Recurse | Where {!$_.PSIsContainer} | ForEach {
        $FileInc = 1
        Do {
            If ($FileInc -eq 1) {$MovePath = Join-Path -Path $Parent.FullName -ChildPath $_.Name}
            Else {$MovePath = Join-Path -Path $Parent.FullName -ChildPath "$($_.BaseName)($FileInc)$($_.Extension)"}
            $FileInc++
        }
        While (Test-Path -Path $MovePath -PathType Leaf)
        Move-Item -Path $_.FullName -Destination $MovePath
    }
}


$Folder = dir -LiteralPath . -Recurse -Directory | sort-object { [regex]::Replace($_, '\d+', { $args[0].Value.PadLeft(50) }) } ;
$folder_counter = (dir -LiteralPath . -Recurse -Directory).Count
$k = 0
$file_counter = (Get-ChildItem -Recurse -Directory -LiteralPath "$InputFolder" | Get-ChildItem -File | where-object {$_.extension -in $fileTypes}).Count
$l = 0

Foreach ($dir In $Folder)
    {
	$k++
	$percent_folder = [math]::Round($k / $folder_counter * 100)
	Write-Progress -Id 1 -activity "Folder Progress Bar" -CurrentOperation "Current directory: '$dir'" -Status "Processing $k of $folder_counter ($percent_folder%)"  -PercentComplete $percent_folder
	$current_dir = (Get-Location).path + '\' + $dir;

    # Set default value for addition to file name
    $counter = 1
    $newdir = $dir.name
    # Search for the files set in the filter
    $files = Get-ChildItem -LiteralPath $dir.fullname -File | where-object {$_.extension -in $fileTypes} | sort-object { [regex]::Replace($_, '\d+', { $args[0].Value.PadLeft(50) }) }
    Foreach ($file In $files)
        {
        $Current_timestamp = Get-Date -format "yyyyMMdd_HHmmss"
		$extension = $file.Extension
        # Check if a file exists
        If ($file)
            {
			$l++
			$percent_file = [math]::Round($l / $file_counter * 100)
			Write-Progress -Id 2  -activity "Total Progress Bar" -CurrentOperation "Current file: '$file'" -Status "Processing $l of $file_counter ($percent_file%)"  -PercentComplete $percent_file
			$replace  = $newdir + "_" + $zero + ($counter.ToString().PadLeft(3,'0')) + "." + $extension
			# Trim spaces and rename the file
            $image_string = $file.fullname.ToString().Trim()
            #"$split[0] renamed to $replace"
			$replace = ($replace -Replace $regex_str1,".") -Replace $regex_str2,".";
            Rename-Item  -LiteralPath "$image_string" "$replace";

            Write-Output $("$Current_timestamp;'{0}';'{1}'" -f $image_string,$replace) | Out-File -Encoding UTF8 -FilePath ($changelog_FullName) -Append;

            $counter++
            }
        }
    }

ls -Directory -Recurse | where { -NOT $_.GetFiles() -and -not $_.GetDirectories()} | Remove-Item ;

explorer . ;