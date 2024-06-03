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
        $arguments = "`"$imagePath`" -resize 128x128 -scale 20x20 -colorspace HSL txt:-"

        # Start the ImageMagick process and capture the output
        $process = Start-Process -FilePath $magickPath -ArgumentList $arguments -NoNewWindow -PassThru -RedirectStandardOutput "output.txt" -RedirectStandardError "error.txt"
        $process.WaitForExit()

        # Read the output from the file
        $output = Get-Content "output.txt" -Raw
        
        # Output the content for debugging
        Write-Host "ImageMagick output for $imagePath`:`n$output"

        # Initialize accumulators for H, S, and L values
        $hValues = @()
        $sValues = @()
        $lValues = @()

        # Adjust the regex to correctly capture the HSL values
        $output -match "hsl\((\d+(\.\d+)?),(\d+(\.\d+)?%)?,(\d+(\.\d+)?%)?\)" | ForEach-Object {
            $hValues += [decimal]$matches[1]
            $sValues += [decimal]$matches[3].TrimEnd('%')
            $lValues += [decimal]$matches[5].TrimEnd('%')
        }

        # Calculate the average H, S, and L values
        if ($hValues.Count -gt 0) {
            $avgH = ($hValues | Measure-Object -Average).Average
            $avgS = ($sValues | Measure-Object -Average).Average
            $avgL = ($lValues | Measure-Object -Average).Average
            return [PSCustomObject]@{
                H = [Math]::Round($avgH, 2)
                S = [Math]::Round($avgS, 2)
                L = [Math]::Round($avgL, 2)

            }
        }
        else {
            Write-Host "No color data matched in output for $imagePath."
            Write-Host "Output:`n$output"
        }
    }
    catch {
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

# Start timing
$startTime = Get-Date

# Process each image with progress bar
$imageColors = @()
$totalImages = $imageFiles.Count
$processedImages = 0
$progressIndex = 0

foreach ($image in $imageFiles) {
    $processedImages++
    $dominantColor = Get-DominantColorHSV -imagePath $image.FullName
    if ($dominantColor) {
        $imageColors += [PSCustomObject]@{Path = $image.FullName; Color = $dominantColor }
        Write-Host "Processed image: $($image.FullName), Color: H=$($dominantColor.H), S=$($dominantColor.S), L=$($dominantColor.L)"
    }
    else {
        Write-Host "Failed to process image: $($image.FullName)"
    }
    $progressIndex = [math]::Floor(($processedImages / $totalImages) * 100)
    $elapsedTime = (Get-Date) - $startTime
    $estimatedRemaining = ($elapsedTime.TotalSeconds / $processedImages) * ($totalImages - $processedImages)
    Write-Progress -Activity "Processing Images" -Status "Processed $processedImages of $totalImages images" -PercentComplete $progressIndex -SecondsRemaining $estimatedRemaining
}

# Sort images by their dominant color (Lightness, then Hue)
$sortedImages = $imageColors | Sort-Object -Property @{Expression = { $_.Color.L }; Ascending = $false }, @{Expression = { $_.Color.H }; Ascending = $true }

# Generate a unique random hex string for this run
$randomHex = -join (Get-Random -Count 6 -InputObject (48..57 + 97..102) | ForEach-Object { [char]$_ })

# Rename sorted images with progress bar
$totalImages = $sortedImages.Count
$renamedImages = 0
$progressIndex = 0

$counter = 1
foreach ($image in $sortedImages) {
    $renamedImages++
    $newName = "H{1}_S{2}_L{3}_{5}_{0:D4}{4}" -f $counter, $image.Color.H, $image.Color.S, $image.Color.L, [System.IO.Path]::GetExtension($image.Path), $randomHex
    $newPath = Join-Path -Path $imageDirectory -ChildPath $newName
    Rename-Item -Path $image.Path -NewName $newPath -Verbose
    $counter++

    $progressIndex = [math]::Floor(($renamedImages / $totalImages) * 100)
    $elapsedTime = (Get-Date) - $startTime
    $estimatedRemaining = ($elapsedTime.TotalSeconds / ($totalImages + $processedImages)) * ($totalImages - $renamedImages)
    Write-Progress -Activity "Renaming Images" -Status "Renamed $renamedImages of $totalImages images" -PercentComplete $progressIndex -SecondsRemaining $estimatedRemaining
}

# Clean up temporary file
Remove-Item "output.txt" -Verbose

# Calculate total elapsed time
$elapsedTime = (Get-Date) - $startTime

# Format elapsed time as HH:MM:ss
$elapsedTimeFormatted = "{0:HH\:mm\:ss}" -f [datetime]$elapsedTime.Ticks
Write-Output "Elapsed time: $elapsedTimeFormatted"
Write-Output "Completed processing images."