$folder = Read-Host "Podaj nazwe sciezki: "

$image = New-Object -ComObject Wia.ImageFile

$counter = (Get-ChildItem $folder -directory -recurse | Get-ChildItem -filter *.jpg).Count
$i = 0

$pictures = Get-ChildItem $folder -directory -recurse | Get-ChildItem -filter *.jpg | ForEach-Object {
	
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
		rename-item -LiteralPath $_.FullName $_.Name.Replace(".jpg", "_portrait.jpg")
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