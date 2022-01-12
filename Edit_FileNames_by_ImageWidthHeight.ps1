$Host.UI.RawUI.WindowTitle = "Edit_FileNames_by_ImageWidthHeight"
$Host.PrivateData.ProgressBackgroundColor='Green'
$Host.PrivateData.ProgressForegroundColor='Black'

Add-Type -AssemblyName System.Windows.Forms
$FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{
    SelectedPath = 'D:\Downloads\Pics'
	Description = "Wybierz katalog zrodlowy"
}
 
[void]$FolderBrowser.ShowDialog()
$FolderBrowser.SelectedPath
If ($FolderBrowser.SelectedPath -eq "") {Exit}
$folder = $FolderBrowser.SelectedPath;

$fileTypes = @('.jpg','.jpeg','.png')

$image = New-Object -ComObject Wia.ImageFile

$counter = (Get-ChildItem $folder -recurse  | where-object {$_.extension -in $fileTypes}).Count
$i = 0

$pictures = Get-ChildItem $folder -recurse  | where-object {$_.extension -in $fileTypes} | ForEach-Object {
	
    $image.LoadFile($_.fullname)
    $size = $image.Width.ToString() + 'x' + $image.Height.ToString()

    $i++
	$percent = $i / $counter * 100  
    Write-Progress -Activity 'Progress bar' -Status "Processing $_" -PercentComplete $percent


    $orientation = $image.Properties | ? {$_.name -eq 'Orientation'} | % {$_.value}
    if ($orientation -eq 6) {
        $rotated = $true
    } else {
        $rotated = $false
    }

    $heightGtWidth = if ([int]$image.Height.ToString() -gt [int]$image.Width.ToString()) {
        $true
		rename-item -LiteralPath $_.FullName $_.Name.Replace($_.extension, (".portrait" + $_.extension))
    } else {
        $false
    }

    [pscustomobject]@{
        Fullname = $_.FullName
		Name =  $_.Name
        Size = $size
        Rotated = $rotated
        HeightGtWidth = $heightGtWidth
    }
	
	
}

#$pictures | where HeightGtWidth -eq $true