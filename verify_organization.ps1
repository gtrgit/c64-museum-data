# FILENAME: verify_organization.ps1
# Check what actually happened during the organization process

param(
    [string]$ThumbnailsPath = "..\thumbnails-deduped"
)

Write-Host "=== ORGANIZATION VERIFICATION ===" -ForegroundColor Cyan
Write-Host "Checking: $ThumbnailsPath" -ForegroundColor Yellow

# Check if path exists
if (-not (Test-Path $ThumbnailsPath)) {
    Write-Host "Path not found: $ThumbnailsPath" -ForegroundColor Red
    exit 1
}

# Get all directories
$allDirs = Get-ChildItem -Path $ThumbnailsPath -Directory
Write-Host "`nTotal directories found: $($allDirs.Count)" -ForegroundColor Green

# Check for year folders
$yearFolders = $allDirs | Where-Object { $_.Name -match '^\d{4}$' }
Write-Host "Year folders found: $($yearFolders.Count)" -ForegroundColor $(if($yearFolders.Count -gt 0){'Green'}else{'Red'})

if ($yearFolders.Count -gt 0) {
    Write-Host "`nYear folders:" -ForegroundColor Yellow
    $yearFolders | Sort-Object Name | ForEach-Object {
        $subDirCount = (Get-ChildItem -Path $_.FullName -Directory -ErrorAction SilentlyContinue).Count
        Write-Host "  $($_.Name): $subDirCount game folders" -ForegroundColor Gray
    }
} else {
    Write-Host "No year folders found - organization didn't complete" -ForegroundColor Red
}

# Sample of non-year folders
$nonYearFolders = $allDirs | Where-Object { $_.Name -notmatch '^\d{4}$' }
Write-Host "`nNon-year folders (game folders): $($nonYearFolders.Count)" -ForegroundColor Yellow

if ($nonYearFolders.Count -gt 0) {
    Write-Host "Sample game folders still in root:" -ForegroundColor Gray
    $nonYearFolders | Select-Object -First 10 | ForEach-Object {
        Write-Host "  - $($_.Name)" -ForegroundColor Gray
    }
    if ($nonYearFolders.Count -gt 10) {
        Write-Host "  ... and $($nonYearFolders.Count - 10) more" -ForegroundColor Gray
    }
}

# Check logs for clues
Write-Host "`nChecking for log files..." -ForegroundColor Cyan
$logFiles = Get-ChildItem -Path "." -Filter "*organization*.log" | Sort-Object LastWriteTime -Descending
if ($logFiles.Count -gt 0) {
    $latestLog = $logFiles[0]
    Write-Host "Latest log file: $($latestLog.Name)" -ForegroundColor Green
    Write-Host "Log location: $($latestLog.FullName)" -ForegroundColor Gray
    
    # Show last few lines of log
    $logContent = Get-Content -Path $latestLog.FullName -Tail 10
    Write-Host "`nLast 10 lines of log:" -ForegroundColor Yellow
    $logContent | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
} else {
    Write-Host "No organization log files found" -ForegroundColor Yellow
}

Write-Host "`n=== DIAGNOSIS ===" -ForegroundColor Cyan
if ($yearFolders.Count -eq 0) {
    Write-Host "ISSUE: No year folders were created" -ForegroundColor Red
    Write-Host "This means the script ran in WhatIf mode or failed to execute moves" -ForegroundColor Yellow
} elseif ($nonYearFolders.Count -gt 1000) {
    Write-Host "ISSUE: Most folders are still in root directory" -ForegroundColor Red
    Write-Host "Organization may have started but not completed" -ForegroundColor Yellow
} else {
    Write-Host "SUCCESS: Organization appears to have worked!" -ForegroundColor Green
}

Write-Host "`n=== NEXT STEPS ===" -ForegroundColor Cyan
if ($yearFolders.Count -eq 0) {
    Write-Host "1. Run organize_by_year.ps1 directly with -WhatIf:`$false" -ForegroundColor Gray
    Write-Host "2. Check the log files for error messages" -ForegroundColor Gray
    Write-Host "3. Verify folder permissions in the thumbnails directory" -ForegroundColor Gray
} else {
    Write-Host "1. Organization successful - proceed with JSON update" -ForegroundColor Gray
    Write-Host "2. Test the new structure in Creator Hub" -ForegroundColor Gray
}