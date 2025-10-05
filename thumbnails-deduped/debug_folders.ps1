# FILENAME: debug_folders.ps1
# Debug Folder Contents - Find out what's actually in your directory

Write-Host "=== FOLDER DEBUG INFORMATION ===" -ForegroundColor Cyan
Write-Host "Current Directory: $(Get-Location)" -ForegroundColor Yellow

# Count all directories
$allDirs = Get-ChildItem -Directory
Write-Host "`nTotal directories found: $($allDirs.Count)" -ForegroundColor Green

# Show first 20 folder names to see the pattern
Write-Host "`n=== FIRST 20 FOLDER NAMES ===" -ForegroundColor Yellow
$allDirs | Select-Object -First 20 | ForEach-Object { 
    Write-Host "  $($_.Name)" -ForegroundColor Gray 
}

# Test different naming patterns (just for analysis)
Write-Host "`n=== NAMING PATTERN ANALYSIS ===" -ForegroundColor Yellow

$patterns = @{
    "*_*_*_*" = "4+ words with underscores"
    "*_*_*" = "3+ words with underscores" 
    "*_*" = "2+ words with underscores"
    "*-*" = "Contains hyphens"
    "* *" = "Contains spaces"
    "*" = "All folders"
}

foreach ($pattern in $patterns.Keys) {
    $count = (Get-ChildItem -Directory | Where-Object { $_.Name -like $pattern }).Count
    Write-Host "  Pattern '$pattern': $count folders" -ForegroundColor Gray
}

# Check for subdirectories that might contain the folders
Write-Host "`n=== CHECKING FOR SUBDIRECTORIES ===" -ForegroundColor Yellow
$subdirs = Get-ChildItem -Directory | Where-Object { 
    (Get-ChildItem -Path $_.FullName -Directory -ErrorAction SilentlyContinue).Count -gt 100 
}

if ($subdirs.Count -gt 0) {
    Write-Host "Found subdirectories with many folders:" -ForegroundColor Green
    foreach ($subdir in $subdirs) {
        $subFolderCount = (Get-ChildItem -Path $subdir.FullName -Directory -ErrorAction SilentlyContinue).Count
        Write-Host "  $($subdir.Name): $subFolderCount folders" -ForegroundColor Gray
    }
} else {
    Write-Host "No subdirectories with large numbers of folders found" -ForegroundColor Gray
}

# Show sample of actual folder names to identify pattern
Write-Host "`n=== SAMPLE FOLDER NAMES (to identify pattern) ===" -ForegroundColor Yellow
$allDirs | Get-Random -Count 10 | ForEach-Object { 
    Write-Host "  $($_.Name)" -ForegroundColor Gray 
}

Write-Host "`n=== NEXT STEPS ===" -ForegroundColor Cyan
Write-Host "1. Look at the folder names above to identify the correct pattern" -ForegroundColor Gray
Write-Host "2. If folders are in subdirectories, navigate there first" -ForegroundColor Gray
Write-Host "3. Update the script with the correct naming pattern" -ForegroundColor Gray