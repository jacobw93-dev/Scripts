# Set file paths
$inputFile = "I:\.ignore\Visual dir size\Visual Directory Size Report - Order By Name.html"
$headTagFile = "I:\.ignore\Visual dir size\head_tag.txt"
$middlePartFile = "I:\.ignore\Visual dir size\middle_part.txt"
$endPartFile = "I:\.ignore\Visual dir size\end_part.txt"
$outputFile = "I:\.ignore\Visual dir size\Visual Directory Size Report - output.html"

# Read input file as a single string with new lines and spaces preserved
$content = Get-Content -Path $inputFile -Raw

# Convert file encoding to UTF8-BOM
$content = [System.Text.Encoding]::UTF8.GetBytes($content)
$content = [System.Text.Encoding]::UTF8.GetPreamble() + $content
$content = [System.Text.Encoding]::UTF8.GetString($content)

# Loop through all lines beginning with line number 7 till the end and replace "((?<=\d)\d{3}(?=\D|(?:\d{3})*(?:\D|$)))" with " $1"
$lines = $content -split "`n"
for ($i = 6; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match "((?<=\d)\d{3}(?=\D|(?:\d{3})*(?:\D|$)))") {
        $lines[$i] = $lines[$i] -replace "((?<=\d)\d{3}(?=\D|(?:\d{3})*(?:\D|$)))", " $($Matches[0])"
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

# Save output to file
Set-Content -Path $outputFile -Value $content -Encoding UTF8

pause