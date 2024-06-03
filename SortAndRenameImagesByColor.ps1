Clear-Host

# Path to the ImageMagick executable
$magickPath = "C:\Program Files\ImageMagick-7.1.1-Q16-HDRI\magick.exe"

# Array of valid image extensions
$validExtensions = @(".jpg", ".jpeg", ".png", ".bmp")

# Function to get the dominant color of an image in HSV format
function Get-DominantColorHSV {
    param (
        [string]$imagePath
    )
    
    try {
        # Define the arguments for the ImageMagick command
        $arguments = "`"$imagePath`" -resize 128x128 -scale 100x100 -colorspace HSL txt:-"

        # Start the ImageMagick process and capture the output
        $process = Start-Process -FilePath $magickPath -ArgumentList $arguments -NoNewWindow -PassThru -RedirectStandardOutput "output.txt" -RedirectStandardError "error.txt"
        $process.WaitForExit()

        # Read the output from the file
        $output = Get-Content "output.txt" -Raw
        
        # Output the content for debugging
        Write-Host "ImageMagick output for $imagePath`:`n$output"
        
        # Adjust the regex to correctly capture the HSL values
        if ($output -match "hsl\((\d+),(\d+%),(\d+%)\)") {
            return [PSCustomObject]@{
                H = [int]$matches[1]
                S = [int]$matches[2].TrimEnd('%')
                L = [int]$matches[3].TrimEnd('%')
            }
        } else {
            Write-Host "Failed to match color data in output for $imagePath."
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

# Get all image files in the directory with valid extensions
$imageFiles = Get-ChildItem -Path $imageDirectory -File | Where-Object { $_.Extension -in $validExtensions }

# Process each image
foreach ($image in $imageFiles) {
    $dominantColor = Get-DominantColorHSV -imagePath $image.FullName
    if ($dominantColor) {
        Write-Host "Processed image: $($image.FullName), Color: H=$($dominantColor.H), S=$($dominantColor.S), L=$($dominantColor.L)"
    } else {
        Write-Host "Failed to process image: $($image.FullName)"
    }
}

# Sort images by their dominant color (Lightness, then Hue)
$sortedImages = $imageColors | Sort-Object -Property @{Expression={$_.Color.L}; Ascending=$false}, @{Expression={$_.Color.H}; Ascending=$true}

# Generate a unique random hex string for this run
$randomHex = -join (Get-Random -Count 6 -InputObject (48..57 + 97..102) | ForEach-Object {[char]$_})

# Rename sorted images
$counter = 1
foreach ($image in $sortedImages) {
    $newName = "H{1}_S{2}_L{3}_{5}_{0:D4}{4}" -f $counter, $image.Color.H, $image.Color.S, $image.Color.L, [System.IO.Path]::GetExtension($image.Path), $randomHex
    $newPath = Join-Path -Path $imageDirectory -ChildPath $newName
    Rename-Item -Path $image.Path -NewName $newPath -Verbose
    # Write-Host "Renamed $($image.Path) to $newPath"
    $counter++
}

# Clean up temporary file
Remove-Item "output.txt" -Verbose

# Calculate elapsed time
$elapsedTime = (Get-Date) - $startTime

# Format elapsed time as HH:MM:ss
$elapsedTimeFormatted = "{0:HH\:mm\:ss}" -f [datetime]$elapsedTime.Ticks
Write-Output "Elapsed time: $elapsedTimeFormatted"