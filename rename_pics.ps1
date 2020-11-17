$Host.UI.RawUI.WindowTitle = "Bulk_rename_files_v3"
$Input= Read-Host "Podaj nazwe sciezki (domyslnie: G:\Mój dysk\.Private\Pics)"
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
  $subfolders = Get-ChildItem $item.FullName -Directory

  foreach ($folder in $subfolders) {
    RenameFolderAndSubFolders $folder 1
  }

  while ($true){
        try {
            Write-Output "Renaming: $($item.FullName)"
			$NewName = $item.Parent.Name + ' - ' + $number
            Rename-Item $item.FullName -NewName $NewName -ErrorAction Stop
            return
        }
        catch {}
        $number++
    }
}

Get-ChildItem .\*\* -Directory  | Where-Object { $_.name -Match $_.Parent.Name } | sort-object { [regex]::Replace($_, '\d+', { $args[0].Value.PadLeft(20) }) } | % { RenameFolderAndSubFolders -item $_ -number 1 }

$Folder = dir -LiteralPath . -Recurse -Directory | sort-object { [regex]::Replace($_, '\d+', { $args[0].Value.PadLeft(20) }) } ;
          
Foreach ($dir In $Folder) 
    {
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