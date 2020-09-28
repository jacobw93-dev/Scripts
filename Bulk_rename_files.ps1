cd D:\Downloads\ ;
$target_path = (Get-Location).path + '\' + 'Porn';
$ext = '.mp4';
$ext_mask = '*' + $ext;
$filter_mask = '*xxx*';
$array_ext = @('*.txt','*.nfo','*.exe');
$regex_str1 = '[^0-9A-Za-z\.\[\]]';
$regex_str2 = '\.+';

if(!(Test-Path $target_path)) {
    
    mkdir $target_path

}

dir -Directory -filter $filter_mask | move-item -Destination $target_path;
cd $target_path    

$filesandfolders = Get-ChildItem -recurse | Where-Object {$_.name -match $regex_str1} 
$filesandfolders | Where-Object {!$_.PsIscontainer}  |  foreach {
    $New=$_.name -Replace $regex_str1,"."
    Rename-Item -Literalpath $_.Fullname -newname $New -passthru
}
$filesandfolders | Where-Object {$_.PsIscontainer}  |  foreach {
    $New=$_.name -Replace $regex_str1,"."
    Rename-Item -Literalpath $_.Fullname -newname $New -passthru
}

$Folder = dir -Recurse -Directory -filter $filter_mask ;
          
Foreach ($dir In $Folder) 
    {
    $Count = Get-ChildItem -File -LiteralPath $dir -Filter $ext_mask | Measure-Object | %{$_.Count}
   
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
                if ($Count > 1 )
                    { $replace  = $split[0] -Replace $split[0],($newdir + $i + $ext) }
                else
                    { $replace  = $split[0] -Replace $split[0],($dir.name + $ext) }
 
            # Trim spaces and rename the file 
            $image_string = $file.fullname.ToString().Trim() 
            #"$split[0] renamed to $replace" 
            Rename-Item -LiteralPath "$image_string" "$replace" ;
            $i++ 
            } 
        } 
    }

dir -Recurse -Directory -filter $filter_mask | dir -Recurse -File -filter $ext_mask | Move-Item -Destination .\ ;
dir -Recurse -file -filter $filter_mask | Rename-item -NewName {$_.Name -replace "$regex_str2","."} ;
for($i=0;$i -le 2;$i++){dir -Recurse -Directory -filter $filter_mask | dir -Recurse -File -Filter $($array_ext[$i]) | Remove-Item};
ls -Directory -filter $filter_mask| where { -NOT $_.GetFiles()} | Remove-Item;

start . ;
cd \ ;
exit