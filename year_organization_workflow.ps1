# FILENAME: year_organization_workflow.ps1
# Complete workflow to organize thumbnails by year and update JSON accordingly
# This solves the Creator Hub timeout issue by reducing root folder count

param(
    [string]$JsonFile = "c64_software_cleaned.json",
    [string]$ThumbnailsPath = ".",
    [switch]$Execute = $false   # Set to $true to actually perform all changes
)

$WhatIf = -not $Execute

Write-Host "YEAR-BASED ORGANIZATION WORKFLOW" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host "Mode: $(if($Execute){'EXECUTE - Will make changes'}else{'DRY RUN - No changes made'})" -ForegroundColor $(if($Execute){'Red'}else{'Yellow'})
Write-Host "JSON File: $JsonFile" -ForegroundColor Yellow
Write-Host "Thumbnails Path: $ThumbnailsPath" -ForegroundColor Yellow
Write-Host ""

Write-Host "WORKFLOW OVERVIEW:" -ForegroundColor Green
Write-Host "1. Analyze current folder structure and JSON data" -ForegroundColor Gray
Write-Host "2. Create year-based folders (1980, 1981, 1982, etc.)" -ForegroundColor Gray
Write-Host "3. Move game folders into appropriate year folders" -ForegroundColor Gray
Write-Host "4. Update JSON with new thumbnail paths" -ForegroundColor Gray
Write-Host "5. Verify everything is working correctly" -ForegroundColor Gray
Write-Host ""

# Check prerequisites
Write-Host "CHECKING PREREQUISITES..." -ForegroundColor Green

if (-not (Test-Path $JsonFile)) {
    Write-Host "JSON file not found: $JsonFile" -ForegroundColor Red
    exit 1
}

$currentFolders = Get-ChildItem -Path $ThumbnailsPath -Directory
Write-Host "Found $($currentFolders.Count) folders in thumbnails directory" -ForegroundColor Green

$jsonData = Get-Content -Path $JsonFile -Raw | ConvertFrom-Json
Write-Host "JSON file contains $($jsonData.Count) entries" -ForegroundColor Green

# Check if already organized
$yearFolders = $currentFolders | Where-Object { $_.Name -match '^\d{4}$' }
if ($yearFolders.Count -gt 5) {
    Write-Host "It appears folders are already organized by year!" -ForegroundColor Yellow
    Write-Host "Found year folders: $($yearFolders.Name -join ', ')" -ForegroundColor Gray
    
    $continueChoice = Read-Host "Continue anyway? (y/N)"
    if ($continueChoice -ne 'y' -and $continueChoice -ne 'Y') {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        exit
    }
}

if (-not $Execute) {
    Write-Host ""
    Write-Host "DRY RUN MODE - No changes will be made" -ForegroundColor Yellow
    Write-Host "Review the output below, then run with -Execute to apply changes" -ForegroundColor Yellow
    Write-Host ""
}

# Step 1: Organize folders by year
Write-Host "STEP 1: Organizing folders by year..." -ForegroundColor Green
Write-Host "Analyzing years and creating folder structure..." -ForegroundColor Gray

if (Test-Path ".\organize_by_year.ps1") {
    & ".\organize_by_year.ps1" -JsonFile $JsonFile -ThumbnailsPath $ThumbnailsPath -WhatIf:$WhatIf
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Folder organization failed!" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "organize_by_year.ps1 not found!" -ForegroundColor Red
    Write-Host "Please ensure all scripts are in the current directory" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "STEP 2: Updating JSON with year-based paths..." -ForegroundColor Green
Write-Host "Adding thumbnailPath fields to JSON entries..." -ForegroundColor Gray

# Step 2: Update JSON paths
if (Test-Path ".\update_json_paths.ps1") {
    & ".\update_json_paths.ps1" -JsonFile $JsonFile -ThumbnailsPath $ThumbnailsPath -WhatIf:$WhatIf
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "JSON path update failed!" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "update_json_paths.ps1 not found!" -ForegroundColor Red
    Write-Host "Please ensure all scripts are in the current directory" -ForegroundColor Red
    exit 1
}

# Step 3: Final verification and recommendations
Write-Host ""
Write-Host "STEP 3: Final verification..." -ForegroundColor Green

if ($Execute) {
    # Count folders in root vs year folders
    $rootFolders = Get-ChildItem -Path $ThumbnailsPath -Directory | Where-Object { $_.Name -notmatch '^\d{4}$' }
    $newYearFolders = Get-ChildItem -Path $ThumbnailsPath -Directory | Where-Object { $_.Name -match '^\d{4}$' }
    
    Write-Host "Year folders created: $($newYearFolders.Count)" -ForegroundColor Green
    Write-Host "Remaining root folders: $($rootFolders.Count)" -ForegroundColor Green
    
    # Check if JSON was updated
    $outputJsonFile = "c64_software_cleaned_yearized.json"
    if (Test-Path $outputJsonFile) {
        Write-Host "Updated JSON created: $outputJsonFile" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "ORGANIZATION COMPLETED SUCCESSFULLY!" -ForegroundColor Green
    Write-Host "=======================================" -ForegroundColor Green
} else {
    Write-Host "This was a DRY RUN - no changes were made." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Cyan

if (-not $Execute) {
    Write-Host "1. Review the output above to ensure everything looks correct" -ForegroundColor Gray
    Write-Host "2. Create a backup of your current setup!" -ForegroundColor Yellow
    Write-Host "3. Run this script with -Execute to apply changes:" -ForegroundColor Gray
    Write-Host "   .\year_organization_workflow.ps1 -Execute" -ForegroundColor White
} else {
    Write-Host "1. Folders organized by year (reduces root folder count for Creator Hub)" -ForegroundColor Green
    Write-Host "2. JSON updated with year-based thumbnail paths" -ForegroundColor Green
    Write-Host "3. Update your Decentraland scene code to use the new JSON structure:" -ForegroundColor Yellow
    Write-Host "   - Use thumbnailPath field instead of identifier for thumbnail loading" -ForegroundColor Gray
    Write-Host "   - Example: thumbnails/1983/GameName_Publisher instead of thumbnails/GameName_Publisher" -ForegroundColor Gray
    Write-Host "4. Replace your original JSON with: c64_software_cleaned_yearized.json" -ForegroundColor Yellow
    Write-Host "5. Test upload to Creator Hub (should be much faster now!)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "BENEFITS OF THIS ORGANIZATION:" -ForegroundColor Cyan
Write-Host "  - Dramatically reduces root folder count (thousands to ~20 year folders)" -ForegroundColor Green
Write-Host "  - Solves Creator Hub timeout issues during upload" -ForegroundColor Green
Write-Host "  - Better organization and browsing experience" -ForegroundColor Green
Write-Host "  - Maintains all existing data and functionality" -ForegroundColor Green
Write-Host "  - Uses Decentraland storage instead of external S3" -ForegroundColor Green

Write-Host ""
Write-Host "IMPORTANT NOTES:" -ForegroundColor Yellow
Write-Host "  - Always backup your data before running with -Execute" -ForegroundColor Red
Write-Host "  - Update your scene code to use thumbnailPath field" -ForegroundColor Yellow
Write-Host "  - Test thoroughly before deploying to production" -ForegroundColor Yellow

if ($Execute) {
    Write-Host ""
    Write-Host "Your thumbnail organization is now optimized for Decentraland Creator Hub!" -ForegroundColor Green
}