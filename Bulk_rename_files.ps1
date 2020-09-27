cd D:\Downloads\ ;
$target_path = 'New_Folder';
$ext = '.mp4';
$ext_mask = '*' + $ext;
$filter_mask = '*xyz*';
$array_ext = @('*.txt','*.nfo','*.exe');
$regex_str1 = '[^0-9A-Za-z\.\[\]]';
$regex_str2 = '\.+';
$target_path = (Get-Location).path + '\' + $target_path;

if(!(Test-Path $target_path))
{
    New-Item -Path $target_path -ItemType Directory -PathType Container -Force | Out-Null
}


dir -Directory -filter $filter_mask | move-item -Destination $target_path;
cd $target_path;

Function renameFiles_with_counter
{
    # Loop through all directories 
          
    Foreach ($dir In $Folder) 
    { 
    # Set default value for addition to file name 
    $i = 1 
    $newdir = $dir.name + "_" 
    # Search for the files set in the filter
    $files = Get-ChildItem -LiteralPath $dir.fullname -Filter $ext_mask -Recurse
    Foreach ($file In $files) 
        { 
        # Check if a file exists 
        If ($file) 
            { 
            # Split the name and rename it to the parent folder 
            $split    = $file.name.split($ext) 
            $replace  = $split[0] -Replace $split[0],($newdir + $i + $ext) 
 
            # Trim spaces and rename the file 
            $image_string = $file.fullname.ToString().Trim() 
            #"$split[0] renamed to $replace" 
            Rename-Item -LiteralPath "$image_string" "$replace" 
            $i++ 
            } 
        } 
    }
}

Function renameFiles
{
    # Loop through all directories 
          
    Foreach ($dir In $Folder) 
    { 

    $newdir = $dir.name + "_" 
    $files = Get-ChildItem -LiteralPath $dir.fullname -Filter $ext_mask -Recurse
    Foreach ($file In $files) 
        { 
        # Check if a file exists 
        If ($file) 
            { 
            # Split the name and rename it to the parent folder 
            $split    = $file.name.split($ext) 
            $replace  = $split[0] -Replace $split[0],($newdir + $ext) 
 
            # Trim spaces and rename the file 
            $image_string = $file.fullname.ToString().Trim() 
            #"$split[0] renamed to $replace" 
            Rename-Item -LiteralPath "$image_string" "$replace" 
            } 
        } 
    }
}


$List = dir -Recurse -Directory -filter $filter_mask ;
ForEach($Folder in $List)
{
   $Count = Get-ChildItem -File -LiteralPath $Folder -Filter $ext_mask | Measure-Object | %{$_.Count}
   if ($Count > 1 )
   { renameFiles_with_counter } else
   {renameFiles
   }
}

dir -Recurse -Directory -filter $filter_mask | dir -Recurse -File -filter $ext_mask | Move-Item -Destination .\  -force;
dir -Recurse -file -filter $filter_mask | Rename-item -NewName {$_.Name -replace "$regex_str1","."} ;
dir -Recurse -file -filter $filter_mask | Rename-item -NewName {$_.Name -replace "$regex_str2","."} ;
for($i=0;$i -le 2;$i++){dir -Recurse -Directory -filter $filter_mask | dir -Recurse -File -Filter $($array_ext[$i]) | Remove-Item;}
ls -Directory -filter $filter_mask| where { -NOT $_.GetFiles()} | Remove-Item;
start . ;
exit
