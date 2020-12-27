$Host.UI.RawUI.WindowTitle = "Bulk_rename_files_v4"
$Input = Read-Host "Podaj nazwe sciezki (domyslnie: G:\Mój dysk\.Private\Pics)"
$Number_from = Read-Host "Podaj liczbe od ktorej zaczac numerowanie katalogow"
$Number_from = [int]$Number_from
If ($Input -eq '') {$Input = 'G:\Mój dysk\.Private\Pics'}

cd -LiteralPath "$Input" ;
echo $Input;
pause;
$fileTypes = @('.jpg','.png')
$regex_str1 = '[^0-9A-Za-z\.]';
$regex_str2 = '\.+';
$Date = Get-Date -format "yyyyMMdd_HHmm"

#gci .\*\*\*\* -File | Move-Item -Destination { $_.Directory.Parent.FullName }
#ls -Directory -recurse | Where { ( -not $_.GetDirectories()) -and ( -not $_.GetFiles()) } | sort Name | Remove-Item;
#gci .\*\* -Directory  | Rename-Item -NewName { "temp_" + $_.Parent.Name + $_.Name }
#gci .\*\* -Directory | Where-Object { $_.name -Match $_.Parent.Name } | sort Name | Rename-Item -NewName { "temp_"  + $_.Name }
#gci .\*\* -Directory | Rename-Item -NewName { "temp_"  + $_.Parent.Name + $_.Name }
#$Folder = gci .\*\* -Directory | sort Name


function RenameFolderAndSubFolders {
  param($item, $number)
  $subfolders = Get-ChildItem -LiteralPath $item.FullName -Directory

  foreach ($folder in $subfolders) {
    RenameFolderAndSubFolders $folder 1
  }

  while ($true){
        try {            
			$NewName = $item.Parent.Name + ' - ' + $number
            Rename-Item -LiteralPath $item.FullName -NewName $NewName -ErrorAction Stop
            return
        }
        catch {}
        $number++
    }
}

Get-ChildItem -LiteralPath $Input -Directory  | sort-object { [regex]::Replace($_, '\d+', { $args[0].Value.PadLeft(20) }) } | % { RenameFolderAndSubFolders -item $_ -number $Number_from }
# Where-Object { $_.name -Match $_.Parent.Name }
cls
$Folder = dir -LiteralPath . -Recurse -Directory | sort-object { [regex]::Replace($_, '\d+', { $args[0].Value.PadLeft(20) }) } ;

$folder_counter = (dir -LiteralPath . -Recurse -Directory).Count
$k = 0
$file_counter = (Get-ChildItem -Recurse -Directory -LiteralPath "$Input" | Get-ChildItem -File | where-object {$_.extension -in $fileTypes}).Count
$l = 0
          
Foreach ($dir In $Folder) 
    {
	$k++
	$percent_folder = [math]::Round($k / $folder_counter * 100)
	Write-Progress -Id 1 -activity "Folder Progress Bar" -CurrentOperation "Current directory: '$dir'" -Status "Processing $k of $folder_counter ($percent_folder%)"  -PercentComplete $percent_folder
	$current_dir = (Get-Location).path + '\' + $dir;
   
    # Set default value for addition to file name 
    $counter = 1 
    $newdir = $dir.name + "." 
    # Search for the files set in the filter
    $files = Get-ChildItem -LiteralPath $dir.fullname -File | where-object {$_.extension -in $fileTypes} | sort-object { [regex]::Replace($_, '\d+', { $args[0].Value.PadLeft(20) }) }
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
            # Split the name and rename it to the parent folder 
            $split    = $file.name.split($extension)
			$zero = If ( $counter -le 9) { "00" } ElseIf ( $counter -le 99){ "0" } Else { "" }
			$replace  = $split[0] -Replace $split[0],($newdir + $zero + $counter + $extension)
			# Trim spaces and rename the file 
            $image_string = $file.fullname.ToString().Trim()
            #"$split[0] renamed to $replace"
			$replace = ($replace -Replace $regex_str1,".") -Replace $regex_str2,".";
            Rename-Item  -LiteralPath "$image_string" "$replace";

            Write-Output $("$Current_timestamp - Renamed '{0}' to '{1}' " -f $image_string,$replace) | Out-File -FilePath ("$Input" + '\' + "changelog_" + $Date + ".txt") -Append;
            
            $counter++ 
            } 
        }
    }

cd -LiteralPath $Input;
explorer . ;