$Host.UI.RawUI.WindowTitle = "Bulk_rename_files"
$Input= Read-Host "Podaj nazwe sciezki (domyslnie: G:\Mój dysk\.Private\Pics)"
If ($Input -eq '') {$Input = 'G:\Mój dysk\.Private\Pics'}

cd -LiteralPath "$Input" ;
echo $Input;
pause;
$fileTypes = @('.jpg','.png')
$regex_str1 = '[^0-9A-Za-z\.]';
$regex_str2 = '\.+';


$Folder = dir -LiteralPath . -Recurse -Directory | sort Name ;
          
Foreach ($dir In $Folder) 
    {
	$current_dir = (Get-Location).path + '\' + $dir;
   
    # Set default value for addition to file name 
    $counter = 1 
    $newdir = $dir.name + "." 
    # Search for the files set in the filter
    $files = Get-ChildItem -LiteralPath $dir.fullname -File | where-object {$_.extension -in $fileTypes} | sort Name
    echo $files
    pause
    Foreach ($file In $files) 
        { 
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
            $counter++ 
            } 
        }
    }

cd -LiteralPath $Input;
explorer . ;