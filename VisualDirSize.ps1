[Console]::InputEncoding = [System.Text.Encoding]::GetEncoding("Windows-1250")

# Set file paths
$inputFile = "I:\.ignore\Visual dir size\Visual Directory Size Report - Order By Name.html"
$inputFile2 = "I:\.ignore\Visual dir size\Visual Directory Size Report - Order By Size.html"
$headTagFile = "I:\.ignore\Visual dir size\head_tag.txt"
$middlePartFile = "I:\.ignore\Visual dir size\middle_part.txt"
$endPartFile = "I:\.ignore\Visual dir size\end_part.txt"
$outputFile = "I:\.ignore\Visual dir size\Visual Directory Size Report.html"

# Read input file as a single string with new lines and spaces preserved
# $content = Get-Content -Path $inputFile -Raw -Encoding Default

# Read input file as a single string with new lines and spaces preserved, specifying the correct encoding (Windows-1250)
$content = [System.IO.File]::ReadAllText($inputFile, [System.Text.Encoding]::GetEncoding("Windows-1250"))
$regex = "\d(?=(\d{3})+(?!\d))"
# Loop through all lines beginning with line number 7 till the end and replace "((?<=\d)\d{3}(?=\D|(?:\d{3})*(?:\D|$)))" with " $1"
$lines = $content -split "`n"
for ($i = 6; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match $regex) {
        $lines[$i] = [regex]::Replace($lines[$i], $regex, '$& ')
    }
}
$content = $lines -join "`n"

# Replace "<html>[\s\S]*?<body>" with content of file head_tag.txt
$headTagContent = Get-Content -Path $headTagFile -Raw
$content = $content -replace "<html>[\s\S]*?<body>", $headTagContent

# Replace "<p.*?</tr>" with content of file middle_part.txt
$middlePartContent = Get-Content -Path $middlePartFile -Raw
$content = $content -replace "<p.*?</tr>", $middlePartContent

# Loop through lines which begins with "<tr>" and ends with "</tr>" and replace "<tr><td>" with "<tr><td /><td>"
$lines = $content -split "`n"
for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -like "<tr>*" -and $lines[$i] -like "*</tr>*") {
        $lines[$i] = $lines[$i] -replace "<tr><td>", "<tr><td /><td>"
    }
}
$content = $lines -join "`n"

# Replace "</BODY>[\s\S]*?</HTML>" with content of file end_part.txt
$endPartContent = Get-Content -Path $endPartFile -Raw
$content = $content -replace "</BODY>[\s\S]*?</HTML>", $endPartContent

# Save output to file as UTF-8 without BOM and force overwrite
Set-Content -Path $outputFile -Value $content -Encoding UTF8 -Force

Remove-Item $inputFile -Verbose

# Remove inputFile2 if it exists
if (Test-Path $inputFile2 -PathType Leaf) {
    Remove-Item $inputFile2 -Force -Verbose
}

# Define arrays for input and output file paths
$inputImagePaths = @(
    "I:\.ignore\Visual dir size\Visual Directory Size Report - Order By Name.jpg",
    "I:\.ignore\Visual dir size\Visual Directory Size Report - Order By Size.jpg"
)

$outputImagePaths = @(
    "I:\.ignore\Visual dir size\Visual Directory Size Report - Order By Name.png",
    "I:\.ignore\Visual dir size\Visual Directory Size Report - Order By Size.png"
)

$backgroundColorToRemove = "#000000" # Black color
$colorDifferenceThreshold = 10

# Path to ImageMagick executable
$magickPath = "C:\Program Files\ImageMagick-7.1.1-Q16-HDRI\magick.exe"

# Loop through each pair of input and output paths
for ($i = 0; $i -lt $inputImagePaths.Length; $i++) {
    $inputImagePath = $inputImagePaths[$i]
    $outputImagePath = $outputImagePaths[$i]

    # Construct the ImageMagick arguments
    $arguments = "convert `"${inputImagePath}`" -fuzz $colorDifferenceThreshold% -transparent ${backgroundColorToRemove} `"${outputImagePath}`""

    # Execute the command
    try {
        # Execute the command and wait for it to finish
        $process = Start-Process -FilePath $magickPath -ArgumentList $arguments -NoNewWindow -PassThru
        $process.WaitForExit()

        # Remove the processed input file
        Remove-Item -Path $inputImagePath -ErrorAction Stop -Verbose

    }
    catch {
        Write-Error "Failed to process $inputImagePath`: $_"
    }

}

$SourcePath = "I:\.ignore\Visual dir size\"
$SourcePattern = "Visual Directory Size Report*"

$TargetDirectories = @('G:\Mój dysk\.Private\Pics\Visual dir size\','C:\Users\jacob\Documents\GitHub\Reports\Visual dir size\')

foreach ($TargetDirectory in $TargetDirectories) {
    Get-ChildItem -Path $SourcePath -Filter $SourcePattern | ForEach-Object {
        Copy-Item -Path $($_.FullName) -Destination ($TargetDirectory) -Verbose -Force
    }
}

pause