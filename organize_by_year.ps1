# FILENAME: organize_by_year.ps1
# Reorganize game folders by year using JSON date information
# Creates year-based folders and moves game folders accordingly

param(
    [string]$JsonFile = "c64_software_cleaned.json",
    [string]$ThumbnailsPath = ".",
    [switch]$WhatIf = $true    # Set to $false to actually move folders
)

Write-Host "=== ORGANIZE THUMBNAILS BY YEAR ===" -ForegroundColor Cyan
Write-Host "JSON File: $JsonFile" -ForegroundColor Yellow
Write-Host "Thumbnails Path: $ThumbnailsPath" -ForegroundColor Yellow
Write-Host "WhatIf Mode: $WhatIf" -ForegroundColor Yellow

# Check if JSON file exists
if (-not (Test-Path $JsonFile)) {
    Write-Host "JSON file not found: $JsonFile" -ForegroundColor Red
    exit 1
}

# Read JSON data
try {
    Write-Host "`nReading JSON data..." -ForegroundColor Cyan
    $jsonContent = Get-Content -Path $JsonFile -Raw -Encoding UTF8
    $gameEntries = $jsonContent | ConvertFrom-Json
    Write-Host "Found $($gameEntries.Count) JSON entries" -ForegroundColor Green
} catch {
    Write-Host "Error reading JSON: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Get all current folders
$allFolders = Get-ChildItem -Path $ThumbnailsPath -Directory
Write-Host "Found $($allFolders.Count) thumbnail folders" -ForegroundColor Green

# Function to extract year from date string
function Get-YearFromDate {
    param([string]$DateString)
    
    if ([string]::IsNullOrEmpty($DateString)) {
        return "Unknown"
    }
    
    # Try to parse different date formats
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

# Create mapping of identifier to year
Write-Host "`nAnalyzing years from JSON data..." -ForegroundColor Cyan
$identifierToYear = @{}
$yearStats = @{}

foreach ($entry in $gameEntries) {
    if ($entry.identifier) {
        $year = Get-YearFromDate -DateString $entry.date
        $identifierToYear[$entry.identifier] = $year
        
        if (-not $yearStats.ContainsKey($year)) {
            $yearStats[$year] = 0
        }
        $yearStats[$year]++
    }
}

# Show year distribution
Write-Host "`n=== YEAR DISTRIBUTION ===" -ForegroundColor Yellow
$yearStats.Keys | Sort-Object | ForEach-Object {
    Write-Host "  $($_): $($yearStats[$_]) games" -ForegroundColor Gray
}

# Find folders that match JSON identifiers
Write-Host "`nMatching folders to JSON entries..." -ForegroundColor Cyan
$folderMappings = @()
$unmatchedFolders = @()

foreach ($folder in $allFolders) {
    if ($identifierToYear.ContainsKey($folder.Name)) {
        $year = $identifierToYear[$folder.Name]
        $folderMappings += [PSCustomObject]@{
            FolderName = $folder.Name
            FolderPath = $folder.FullName
            Year = $year
            Matched = $true
        }
    } else {
        # Try to extract year from folder name as fallback
        $folderYear = "Unknown"
        if ($folder.Name -match '(\d{4})') {
            $folderYear = $matches[1]
        }
        
        $unmatchedFolders += [PSCustomObject]@{
            FolderName = $folder.Name
            FolderPath = $folder.FullName
            Year = $folderYear
            Matched = $false
        }
    }
}

Write-Host "Matched folders: $($folderMappings.Count)" -ForegroundColor Green
Write-Host "Unmatched folders: $($unmatchedFolders.Count)" -ForegroundColor Yellow

# Show sample mappings
Write-Host "`n=== SAMPLE FOLDER MAPPINGS ===" -ForegroundColor Yellow
$folderMappings | Group-Object Year | Sort-Object Name | ForEach-Object {
    Write-Host "`nYear $($_.Name): $($_.Count) folders" -ForegroundColor Magenta
    $_.Group | Select-Object -First 3 | ForEach-Object {
        Write-Host "  - $($_.FolderName)" -ForegroundColor Gray
    }
    if ($_.Count -gt 3) {
        Write-Host "  ... and $($_.Count - 3) more" -ForegroundColor Gray
    }
}

# Ask for confirmation if not in WhatIf mode
if (-not $WhatIf) {
    Write-Host "`nWARNING: This will create year folders and move existing folders!" -ForegroundColor Red
    Write-Host "Make sure you have a backup before proceeding!" -ForegroundColor Red
    $confirmation = Read-Host "Type 'MOVE' to confirm you want to proceed"
    if ($confirmation -ne 'MOVE') {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        exit
    }
}

# Create year folders and move games
$moveLog = @()
$createdYears = @()

Write-Host "`n=== CREATING YEAR FOLDERS AND MOVING GAMES ===" -ForegroundColor Cyan

# Get unique years that need folders
$yearsToCreate = ($folderMappings | Group-Object Year).Name | Where-Object { $_ -ne "Unknown" }

foreach ($year in $yearsToCreate) {
    $yearFolder = Join-Path $ThumbnailsPath $year
    
    if (-not (Test-Path $yearFolder)) {
        if (-not $WhatIf) {
            try {
                New-Item -Path $yearFolder -ItemType Directory -Force | Out-Null
                Write-Host "Created folder: $year" -ForegroundColor Green
                $createdYears += $year
            } catch {
                Write-Host "Failed to create folder $year : $($_.Exception.Message)" -ForegroundColor Red
                continue
            }
        } else {
            Write-Host "Would create folder: $year" -ForegroundColor Yellow
            $createdYears += $year
        }
    } else {
        Write-Host "Folder already exists: $year" -ForegroundColor Gray
    }
}

# Move matched folders
$movedCount = 0
$errorCount = 0

foreach ($mapping in $folderMappings) {
    if ($mapping.Year -eq "Unknown") {
        Write-Host "Skipping unknown year: $($mapping.FolderName)" -ForegroundColor Yellow
        continue
    }
    
    $sourcePath = $mapping.FolderPath
    $yearFolder = Join-Path $ThumbnailsPath $mapping.Year
    $destinationPath = Join-Path $yearFolder $mapping.FolderName
    
    if (-not $WhatIf) {
        try {
            Move-Item -Path $sourcePath -Destination $destinationPath -Force
            Write-Host "Moved $($mapping.FolderName) to $($mapping.Year)/" -ForegroundColor Green
            $movedCount++
        } catch {
            Write-Host "Failed to move $($mapping.FolderName): $($_.Exception.Message)" -ForegroundColor Red
            $errorCount++
        }
    } else {
        Write-Host "Would move: $($mapping.FolderName) to $($mapping.Year)/" -ForegroundColor Gray
        $movedCount++
    }
    
    $moveLog += [PSCustomObject]@{
        Action = if ($WhatIf) { "WOULD MOVE" } else { "MOVE" }
        FolderName = $mapping.FolderName
        FromPath = $sourcePath
        ToPath = $destinationPath
        Year = $mapping.Year
        Status = if ($WhatIf) { "Dry Run" } else { "Success" }
    }
}

# Handle unmatched folders
if ($unmatchedFolders.Count -gt 0) {
    Write-Host "`n=== UNMATCHED FOLDERS ===" -ForegroundColor Yellow
    Write-Host "These folders don't match JSON identifiers:" -ForegroundColor Yellow
    
    # Try to group by extracted year
    $unmatchedByYear = $unmatchedFolders | Group-Object Year
    
    foreach ($yearGroup in $unmatchedByYear) {
        Write-Host "`nYear $($yearGroup.Name): $($yearGroup.Count) folders" -ForegroundColor Magenta
        $yearGroup.Group | ForEach-Object {
            Write-Host "  - $($_.FolderName)" -ForegroundColor Gray
        }
    }
    
    Write-Host "`nRecommendation: Review these manually or update JSON data" -ForegroundColor Cyan
}

# Summary
Write-Host "`n=== SUMMARY ===" -ForegroundColor Green
Write-Host "Year folders $(if($WhatIf){'to create'}else{'created'}): $($createdYears.Count)" -ForegroundColor Cyan
Write-Host "Folders $(if($WhatIf){'to move'}else{'moved'}): $movedCount" -ForegroundColor Cyan
Write-Host "Errors: $errorCount" -ForegroundColor Red
Write-Host "Unmatched folders: $($unmatchedFolders.Count)" -ForegroundColor Yellow

if ($WhatIf) {
    Write-Host "`nThis was a DRY RUN - no folders were moved." -ForegroundColor Yellow
    Write-Host "To execute the reorganization, run:" -ForegroundColor Yellow
    Write-Host ".\organize_by_year.ps1 -WhatIf:`$false" -ForegroundColor White
} else {
    Write-Host "`nFolder reorganization completed!" -ForegroundColor Green
    Write-Host "Next step: Update JSON to include year-based paths" -ForegroundColor Cyan
}

# Create log file
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$logFile = "year_organization_$timestamp.log"
$csvFile = "folder_moves_$timestamp.csv"

$logContent = @"
Year-Based Folder Organization Log
Generated: $(Get-Date)
WhatIf Mode: $WhatIf

JSON File: $JsonFile
Thumbnails Path: $ThumbnailsPath

Total JSON entries: $($gameEntries.Count)
Total folders found: $($allFolders.Count)
Matched folders: $($folderMappings.Count)
Unmatched folders: $($unmatchedFolders.Count)

Year folders $(if($WhatIf){'to create'}else{'created'}): $($createdYears.Count)
Folders $(if($WhatIf){'to move'}else{'moved'}): $movedCount
Errors: $errorCount

Created Years: $($createdYears -join ', ')
"@

$logContent | Out-File -FilePath $logFile -Encoding UTF8
$moveLog | Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8

Write-Host "`nLogs saved:" -ForegroundColor Cyan
Write-Host "  Text log: $logFile" -ForegroundColor Gray
Write-Host "  CSV log: $csvFile" -ForegroundColor Gray