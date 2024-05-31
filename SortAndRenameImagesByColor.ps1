# Path to the ImageMagick executable
$magickPath = "C:\Program Files\ImageMagick-7.1.1-Q16-HDRI\magick.exe"

# Function to get the dominant color of an image in HSV format
function Get-DominantColorHSV {
    param (
        [string]$imagePath
    )
    
    try {
        # Define the arguments for the ImageMagick command
        $arguments = "`"$imagePath`" -resize 16x16 -scale 10x10 -colorspace HSL txt:-"

        # Start the ImageMagick process and capture the output
        $process = Start-Process -FilePath $magickPath -ArgumentList $arguments -NoNewWindow -PassThru -RedirectStandardOutput "output.txt" -RedirectStandardError "error.txt"
        $process.WaitForExit()

        # Read the output from the file
        $output = Get-Content "output.txt" -Raw
        
        if ($output -match "\((\d+),(\d+),(\d+)\)") {
            return [PSCustomObject]@{
                H = [int]$matches[1]
                S = [int]$matches[2]
                L = [int]$matches[3]
            }
        } else {
            Write-Host "Failed to match color data in output."
            Write-Host "Output:`n$output"
        }
    } catch {
        Write-Host "Error occurred: $_"
    }
    
    return $null
}




# Prompt the user for the directory containing the images
$imageDirectory = Read-Host "Please enter the path to the directory containing your images"

# Validate if the directory exists
if (-Not (Test-Path -Path $imageDirectory)) {
    Write-Output "The directory '$imageDirectory' does not exist. Please provide a valid directory."
    exit
}

# Array of valid image extensions
$validExtensions = @(".jpg", ".jpeg", ".png", ".bmp")

# Get all image files in the directory with valid extensions
$imageFiles = Get-ChildItem -Path $imageDirectory -File | Where-Object { $_.Extension -in $validExtensions } | sort-object { [regex]::Replace($_, '\d+', { $args[0].Value.PadLeft(100) }) } 

# Create a list to store image paths and their dominant colors
$imageColors = @()

# Process each image
foreach ($image in $imageFiles) {
    $dominantColor = Get-DominantColorHSV -imagePath $image.FullName
    if ($dominantColor) {
        $imageColors += [PSCustomObject]@{Path=$image.FullName; Color=$dominantColor}
    }
}

# Sort images by their dominant color (Lightness, then Hue)
$sortedImages = $imageColors | Sort-Object -Property @{Expression={$_.Color.L}; Ascending=$false}, @{Expression={$_.Color.H}; Ascending=$true}

# Rename sorted images
$counter = 1
foreach ($image in $sortedImages) {
    $newName = "H{1}_S{2}_L{3}_{0:D4}{4}" -f $counter, $image.Color.H, $image.Color.S, $image.Color.L, [System.IO.Path]::GetExtension($image.Path)
    $newPath = Join-Path -Path $imageDirectory -ChildPath $newName
    Rename-Item -Path $image.Path -NewName $newPath -Verbose
    $counter++
}

Write-Output "Images have been sorted and renamed based on their dominant HSV color."

# Clean up temporary file
Remove-Item "output.txt"