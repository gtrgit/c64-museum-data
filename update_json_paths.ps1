# FILENAME: update_json_paths.ps1
# Update JSON to include year-based thumbnail paths
# Adds a 'thumbnailPath' field with the year-based folder structure

param(
    [string]$JsonFile = "c64_software_cleaned.json",
    [string]$OutputFile = "",  # If empty, will use input filename with "_yearized" suffix
    [string]$ThumbnailsPath = ".",
    [switch]$WhatIf = $true    # Set to $false to actually save the updated file
)

Write-Host "=== UPDATE JSON WITH YEAR-BASED PATHS ===" -ForegroundColor Cyan
Write-Host "Input JSON: $JsonFile" -ForegroundColor Yellow
Write-Host "WhatIf Mode: $WhatIf" -ForegroundColor Yellow

# Set output filename if not provided
if ([string]::IsNullOrEmpty($OutputFile)) {
    $fileInfo = Get-Item $JsonFile
    $OutputFile = Join-Path $fileInfo.DirectoryName "$($fileInfo.BaseName)_yearized$($fileInfo.Extension)"
}
Write-Host "Output JSON: $OutputFile" -ForegroundColor Yellow

# Check if JSON file exists
if (-not (Test-Path $JsonFile)) {
    Write-Host "❌ JSON file not found: $JsonFile" -ForegroundColor Red
    exit 1
}

# Read JSON data
try {
    Write-Host "`nReading JSON data..." -ForegroundColor Cyan
    $jsonContent = Get-Content -Path $JsonFile -Raw -Encoding UTF8
    $gameEntries = $jsonContent | ConvertFrom-Json
    Write-Host "Found $($gameEntries.Count) JSON entries" -ForegroundColor Green
} catch {
    Write-Host "❌ Error reading JSON: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Function to extract year from date string
function Get-YearFromDate {
    param([string]$DateString)
    
    if ([string]::IsNullOrEmpty($DateString)) {
        return "Unknown"
    }
    
    try {
        # Handle ISO format: "1983-01-01T00:00:00Z"
        if ($DateString -match '(\d{4})-\d{2}-\d{2}') {
            return $matches[1]
        }
        
        # Handle just year: "1983"
        if ($DateString -match '^\d{4}$') {
            return $DateString
        }
        
        # Try to parse as DateTime
        $parsedDate = [DateTime]::Parse($DateString)
        return $parsedDate.Year.ToString()
    } catch {
        return "Unknown"
    }
}

# Verify year-based folders exist
Write-Host "`nVerifying year-based folder structure..." -ForegroundColor Cyan
$yearFolders = Get-ChildItem -Path $ThumbnailsPath -Directory | Where-Object { $_.Name -match '^\d{4}$' }
Write-Host "Found year folders: $($yearFolders.Count)" -ForegroundColor Green
$yearFolders | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Gray }

if ($yearFolders.Count -eq 0) {
    Write-Host "⚠️ No year-based folders found! Run organize_by_year.ps1 first." -ForegroundColor Yellow
    exit 1
}

# Update JSON entries with thumbnail paths
Write-Host "`nUpdating JSON entries with year-based paths..." -ForegroundColor Cyan
$updatedEntries = @()
$pathStats = @{
    "Updated" = 0
    "Unknown Year" = 0
    "Missing Folder" = 0
    "No Change" = 0
}

foreach ($entry in $gameEntries) {
    $updatedEntry = $entry | ConvertTo-Json -Depth 100 | ConvertFrom-Json  # Deep copy
    
    if ($entry.identifier) {
        $year = Get-YearFromDate -DateString $entry.date
        
        if ($year -eq "Unknown") {
            # Can't determine year, leave as-is but add warning
            $updatedEntry | Add-Member -NotePropertyName "thumbnailPath" -NotePropertyValue $entry.identifier -Force
            $updatedEntry | Add-Member -NotePropertyName "pathWarning" -NotePropertyValue "Year could not be determined from date" -Force
            $pathStats["Unknown Year"]++
        } else {
            # Check if year folder and game folder exist
            $yearFolderPath = Join-Path $ThumbnailsPath $year
            $gameFolderPath = Join-Path $yearFolderPath $entry.identifier
            
            if (Test-Path $gameFolderPath) {
                # Perfect - year-based path exists
                $thumbnailPath = "$year/$($entry.identifier)"
                $updatedEntry | Add-Member -NotePropertyName "thumbnailPath" -NotePropertyValue $thumbnailPath -Force
                $pathStats["Updated"]++
            } elseif (Test-Path (Join-Path $ThumbnailsPath $entry.identifier)) {
                # Folder exists in root but not moved yet
                $updatedEntry | Add-Member -NotePropertyName "thumbnailPath" -NotePropertyValue $entry.identifier -Force
                $updatedEntry | Add-Member -NotePropertyName "pathWarning" -NotePropertyValue "Folder not yet moved to year-based structure" -Force
                $pathStats["No Change"]++
            } else {
                # Folder doesn't exist anywhere
                $thumbnailPath = "$year/$($entry.identifier)"
                $updatedEntry | Add-Member -NotePropertyName "thumbnailPath" -NotePropertyValue $thumbnailPath -Force
                $updatedEntry | Add-Member -NotePropertyName "pathWarning" -NotePropertyValue "Thumbnail folder not found" -Force
                $pathStats["Missing Folder"]++
            }
        }
    } else {
        # No identifier, can't create path
        $updatedEntry | Add-Member -NotePropertyName "pathWarning" -NotePropertyValue "No identifier in JSON entry" -Force
        $pathStats["Unknown Year"]++
    }
    
    $updatedEntries += $updatedEntry
}

# Show statistics
Write-Host "`n=== PATH UPDATE STATISTICS ===" -ForegroundColor Yellow
$pathStats.Keys | ForEach-Object {
    Write-Host "  $($_): $($pathStats[$_])" -ForegroundColor Gray
}

# Show examples of updated entries
Write-Host "`n=== SAMPLE UPDATED ENTRIES ===" -ForegroundColor Yellow
$updatedEntries | Where-Object { $_.thumbnailPath -and $_.thumbnailPath -match '\d{4}/' } | Select-Object -First 5 | ForEach-Object {
    Write-Host "  $($_.identifier) → $($_.thumbnailPath)" -ForegroundColor Gray
}

# Show warnings if any
$entriesWithWarnings = $updatedEntries | Where-Object { $_.pathWarning }
if ($entriesWithWarnings.Count -gt 0) {
    Write-Host "`n=== ENTRIES WITH WARNINGS ===" -ForegroundColor Yellow
    $entriesWithWarnings | Select-Object -First 10 | ForEach-Object {
        Write-Host "  $($_.identifier): $($_.pathWarning)" -ForegroundColor Yellow
    }
    if ($entriesWithWarnings.Count -gt 10) {
        Write-Host "  ... and $($entriesWithWarnings.Count - 10) more with warnings" -ForegroundColor Gray
    }
}

# Ask for confirmation if not in WhatIf mode
if (-not $WhatIf) {
    Write-Host "`nWARNING: This will create a new JSON file with updated paths!" -ForegroundColor Red
    $confirmation = Read-Host "Type 'SAVE' to confirm you want to proceed"
    if ($confirmation -ne 'SAVE') {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        exit
    }
}

# Save updated JSON
if (-not $WhatIf) {
    try {
        Write-Host "`nSaving updated JSON..." -ForegroundColor Cyan
        $updatedJson = $updatedEntries | ConvertTo-Json -Depth 100 -Compress:$false
        [System.IO.File]::WriteAllText($OutputFile, $updatedJson, [System.Text.UTF8Encoding]::new($false))
        Write-Host "✓ Updated JSON saved to: $OutputFile" -ForegroundColor Green
        
        # Verify the output
        $verifyContent = Get-Content -Path $OutputFile -Raw | ConvertFrom-Json
        Write-Host "✓ Verification: Output file contains $($verifyContent.Count) entries" -ForegroundColor Green
    } catch {
        Write-Host "❌ Error saving file: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# Summary
Write-Host "`n=== SUMMARY ===" -ForegroundColor Green
Write-Host "Total entries: $($gameEntries.Count)" -ForegroundColor Cyan
Write-Host "Successfully updated with year paths: $($pathStats['Updated'])" -ForegroundColor Green
Write-Host "Entries with warnings: $(($pathStats['Unknown Year'] + $pathStats['Missing Folder'] + $pathStats['No Change']))" -ForegroundColor Yellow

if ($WhatIf) {
    Write-Host "`nThis was a DRY RUN - no JSON file was created." -ForegroundColor Yellow
    Write-Host "To create the updated JSON, run:" -ForegroundColor Yellow
    Write-Host ".\update_json_paths.ps1 -WhatIf:`$false" -ForegroundColor White
} else {
    Write-Host "`nJSON path update completed!" -ForegroundColor Green
    Write-Host "New field added: 'thumbnailPath' contains year-based paths" -ForegroundColor Cyan
    Write-Host "Replace your original JSON with: $OutputFile" -ForegroundColor Cyan
}

# Create log file
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$logFile = "json_path_update_$timestamp.log"

$logContent = @"
JSON Path Update Log
Generated: $(Get-Date)
WhatIf Mode: $WhatIf

Input File: $JsonFile
Output File: $OutputFile
Thumbnails Path: $ThumbnailsPath

Total entries: $($gameEntries.Count)
Updated with year paths: $($pathStats['Updated'])
Unknown year: $($pathStats['Unknown Year'])
Missing folders: $($pathStats['Missing Folder'])
No change needed: $($pathStats['No Change'])

Year folders found: $($yearFolders.Count)
Available years: $($yearFolders.Name -join ', ')

JSON Structure Changes:
- Added 'thumbnailPath' field with year-based paths (e.g., "1983/GameName_Publisher")
- Added 'pathWarning' field for entries with issues (will be removed in final version)

Next Steps:
1. Test the updated JSON in your Decentraland scene
2. Update your scene code to use 'thumbnailPath' instead of 'identifier' for thumbnail loading
3. Remove 'pathWarning' fields if everything works correctly
"@

$logContent | Out-File -FilePath $logFile -Encoding UTF8
Write-Host "`nLog saved to: $logFile" -ForegroundColor Cyan

# Exit with success code
exit 0