$Host.UI.RawUI.WindowTitle = "Bulk_rename_files"

Add-Type -AssemblyName System.Windows.Forms
$FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{
    SelectedPath = 'D:\Downloads'
	Description = "Wybierz katalog zrodlowy"
}
 
[void]$FolderBrowser.ShowDialog()
$FolderBrowser.SelectedPath
If ($FolderBrowser.SelectedPath -eq "") {Exit}
$source_folder = $FolderBrowser.SelectedPath;

Add-Type -AssemblyName System.Windows.Forms
$FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{
    SelectedPath = 'D:\Downloads\Videos'
	Description = "Wybierz katalog docelowy"
}
 
[void]$FolderBrowser.ShowDialog()
$FolderBrowser.SelectedPath
If ($FolderBrowser.SelectedPath -eq "") {Exit}
$output_folder = $FolderBrowser.SelectedPath;
# $input_ext = Read-Host -Prompt "`nPodaj nazwę rozszerzenia dla plików do przetworzenia, np. 'mp4'`n";
#$ext = '.' + $input_ext;
#$file_filter = '*' + $ext;
$fileTypes = @('.mp4','.mov','.mkv','.wmv')
$dir_filter = "";
while ($dir_filter -eq "")
{
$dir_filter = Read-Host -Prompt "Podaj maskę dla katalogów do przetworzenia `n";
$dir_filter = $dir_filter.Trim();
If ($dir_filter -eq "") {Write-Host "Wprowadź prawidłową wartość"; pause}
}
$dir_filter = '*' + $dir_filter + '*';
$regex_str1 = '[^0-9A-Za-z\.]';
$regex_str2 = '\.+';
$regex_str3 = '(\d{3,4}p).*'

cd $source_folder
dir . -Directory -filter $dir_filter | ? { !(gci -LiteralPath $_ -file -recurse -filter '*.!qb') } | move-item -Destination $output_folder;
cd $output_folder    

$filesandfolders = Get-ChildItem -recurse | Where-Object { $_.name -match $regex_str1} 
$filesandfolders | Where-Object {$_.PsIscontainer}  |  foreach {
    $New=(($_.name -Replace $regex_str1,".") -Replace $regex_str2,".") -Replace $regex_str3,'$1';
    Rename-Item  -Literalpath $_.Fullname -newname $New -passthru
}
$filesandfolders = Get-ChildItem -recurse | Where-Object { $_.name -match $regex_str1}
$filesandfolders | Where-Object {!$_.PsIscontainer}  |  foreach {
    $New=($_.name -Replace $regex_str1,".") -Replace $regex_str2,".";
    Rename-Item  -Literalpath $_.Fullname -newname $New -passthru
}

$Folder = dir -Recurse -Directory -filter $dir_filter ;
          
Foreach ($dir In $Folder) 
    {
	$current_dir = (Get-Location).path + '\' + $dir;
    $Count = Get-ChildItem -File -LiteralPath $current_dir | where-object {$_.extension -in $fileTypes} | Measure-Object | %{$_.Count}
   
    # Set default value for addition to file name 
    $i = 1 
    $newdir = $dir.name + "." 
    # Search for the files set in the filter
    $files = Get-ChildItem -LiteralPath $dir.fullname -Recurse -File | where-object {$_.extension -in $fileTypes}
    Foreach ($file In $files) 
        { 
        # Check if a file exists 
        If ($file) 
            { 
            # Split the name and rename it to the parent folder 
            $split    = $file.name.split($file.extension)
                if ( $Count -gt 1 )
                    { $replace  = $split[0] -Replace $split[0],($newdir + $i + $file.extension) }
                else
					{ $replace  = $split[0] -Replace $split[0],($dir.name + $file.extension) }
			# Trim spaces and rename the file 
            $image_string = $file.fullname.ToString().Trim() 
            #"$split[0] renamed to $replace" 
            Rename-Item  -LiteralPath "$image_string" "$replace";
            $i++ 
            } 
        }
	if ( $Count -eq 1 )
		{ dir -LiteralPath $current_dir -Recurse -File | where-object {$_.extension -in $fileTypes} | Move-Item -Destination $output_folder }
	
    }

dir -Recurse -Directory -filter $dir_filter | dir -Recurse -File | where-object {$_.extension -notin $fileTypes} | Remove-Item;
ls -Directory -filter $dir_filter -recurse | where { -NOT $_.GetFiles() -and -not $_.GetDirectories()} | Remove-Item;

start . ;
pause
#exit