# FILENAME: complete_cleanup.ps1
# Complete C64 Museum Cleanup Workflow
# This script runs both folder and JSON deduplication

param(
    [string]$FolderPath = ".",
    [string]$JsonFile = "c64_software_cleaned.json",
    [int]$FolderWordCount = 4,  # For folders: a8b_Ghostbusters_1984_Activision
    [int]$JsonWordCount = 3,    # For JSON: msdos_Pac-Man_1983
    [switch]$Execute = $false   # Set to $true to actually perform cleanup
)

$WhatIf = -not $Execute

Write-Host "🎮 C64 Museum Complete Cleanup Workflow" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "Mode: $(if($Execute){'EXECUTE - Will make changes'}else{'DRY RUN - No changes made'})" -ForegroundColor $(if($Execute){'Red'}else{'Yellow'})
Write-Host ""

# Step 1: Clean duplicate folders
Write-Host "📁 STEP 1: Cleaning duplicate folders..." -ForegroundColor Green
Write-Host "Folder Path: $FolderPath"
Write-Host "Using first $FolderWordCount words for grouping"
Write-Host ""

if (Test-Path ".\remove_duplicates.ps1") {
    & ".\remove_duplicates.ps1" -FolderPath $FolderPath -WordCount $FolderWordCount -WhatIf:$WhatIf
} else {
    Write-Host "❌ remove_duplicates.ps1 not found!" -ForegroundColor Red
    Write-Host "Please ensure the folder cleanup script is in the current directory" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "📄 STEP 2: Cleaning duplicate JSON entries..." -ForegroundColor Green
Write-Host "JSON File: $JsonFile"
Write-Host "Using first $JsonWordCount words for grouping"
Write-Host ""

# Step 2: Clean duplicate JSON entries
if (Test-Path $JsonFile) {
    if (Test-Path ".\clean_json_duplicates.ps1") {
        & ".\clean_json_duplicates.ps1" -JsonFile $JsonFile -WordCount $JsonWordCount -WhatIf:$WhatIf
    } else {
        Write-Host "❌ clean_json_duplicates.ps1 not found!" -ForegroundColor Red
        Write-Host "Please ensure the JSON cleanup script is in the current directory" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "⚠️ JSON file not found: $JsonFile" -ForegroundColor Yellow
    Write-Host "Skipping JSON cleanup step" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "✅ CLEANUP WORKFLOW COMPLETED" -ForegroundColor Green
Write-Host "=============================" -ForegroundColor Green

if (-not $Execute) {
    Write-Host ""
    Write-Host "This was a DRY RUN - no changes were made." -ForegroundColor Yellow
    Write-Host "To execute the cleanup, run:" -ForegroundColor Yellow
    Write-Host ".\complete_cleanup.ps1 -Execute" -ForegroundColor White
    Write-Host ""
    Write-Host "Or run individual steps:" -ForegroundColor Yellow
    Write-Host "  .\remove_duplicates.ps1 -WordCount $FolderWordCount -WhatIf:`$false" -ForegroundColor White
    Write-Host "  .\clean_json_duplicates.ps1 -WordCount $JsonWordCount -WhatIf:`$false" -ForegroundColor White
} else {
    Write-Host ""
    Write-Host "🎉 All cleanup operations completed successfully!" -ForegroundColor Green
    Write-Host "Your Decentraland scene should now load much faster!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Summary of changes:" -ForegroundColor Cyan
    Write-Host "  Duplicate folders removed from filesystem" -ForegroundColor Gray
    Write-Host "  Duplicate entries removed from JSON database" -ForegroundColor Gray
    Write-Host "  Empty planes in Decentraland should be eliminated" -ForegroundColor Gray
    Write-Host "  Creator Hub should no longer time out" -ForegroundColor Gray
}

Write-Host ""
Write-Host "💡 Tips:" -ForegroundColor Cyan
Write-Host "  Check the generated log files for detailed information" -ForegroundColor Gray
Write-Host "  Keep backups of your original files before running with -Execute" -ForegroundColor Gray
Write-Host "  You can adjust WordCount parameters if needed" -ForegroundColor Gray