# FILENAME: clean_json_duplicates.ps1
# Clean Duplicate Entries from C64 Software JSON
# Removes duplicates based on first N words of the identifier field

param(
    [string]$JsonFile = "c64_software_cleaned.json",
    [string]$OutputFile = "",  # If empty, will use input filename with "_deduplicated" suffix
    [int]$WordCount = 3,       # Number of words from identifier to use as base (3 for "msdos_Pac-Man_1983")
    [switch]$WhatIf = $true    # Set to $false to actually save the cleaned file
)

Write-Host "Starting JSON duplicate cleanup using first $WordCount words..." -ForegroundColor Green
Write-Host "Input file: $JsonFile" -ForegroundColor Yellow
Write-Host "WhatIf Mode: $WhatIf" -ForegroundColor Yellow

# Set output filename if not provided
if ([string]::IsNullOrEmpty($OutputFile)) {
    $fileInfo = Get-Item $JsonFile
    $OutputFile = Join-Path $fileInfo.DirectoryName "$($fileInfo.BaseName)_deduplicated$($fileInfo.Extension)"
}
Write-Host "Output file: $OutputFile" -ForegroundColor Yellow

# Check if input file exists
if (-not (Test-Path $JsonFile)) {
    Write-Host "Input file not found: $JsonFile" -ForegroundColor Red
    exit 1
}

try {
    # Read and parse JSON
    Write-Host "Reading JSON file..." -ForegroundColor Cyan
    $jsonContent = Get-Content -Path $JsonFile -Raw -Encoding UTF8
    $gameEntries = $jsonContent | ConvertFrom-Json
    
    if (-not $gameEntries -or $gameEntries.Count -eq 0) {
        Write-Host "No entries found in JSON file or invalid format" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Found $($gameEntries.Count) total entries" -ForegroundColor Cyan
    
} catch {
    Write-Host "Error reading JSON file: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Function to extract base game identifier from first N words
function Get-BaseGameIdentifier {
    param(
        [string]$Identifier,
        [int]$WordCount
    )
    
    # Split by underscore and take first N words
    $words = $Identifier -split '_'
    
    if ($words.Count -ge $WordCount) {
        # Join first N words back together
        $baseId = ($words[0..($WordCount-1)] -join '_')
    } else {
        # If identifier has fewer words than WordCount, use all of them
        $baseId = $Identifier
    }
    
    return $baseId
}

# Group entries by base identifier
$groupedEntries = @{}
$debugInfo = @()

foreach ($entry in $gameEntries) {
    if (-not $entry.identifier) {
        Write-Host "Warning: Entry without identifier found, skipping" -ForegroundColor Yellow
        continue
    }
    
    $baseId = Get-BaseGameIdentifier -Identifier $entry.identifier -WordCount $WordCount
    
    if (-not $groupedEntries.ContainsKey($baseId)) {
        $groupedEntries[$baseId] = @()
    }
    $groupedEntries[$baseId] += $entry
    
    # Store debug info
    $debugInfo += [PSCustomObject]@{
        Identifier = $entry.identifier
        BaseIdentifier = $baseId
        Title = $entry.title
        WordCount = ($entry.identifier -split '_').Count
    }
}

Write-Host "Grouped into $($groupedEntries.Count) unique game identifiers" -ForegroundColor Cyan

# Show some examples of grouping for verification
Write-Host "`n=== GROUPING EXAMPLES (First 10) ===" -ForegroundColor Yellow
$exampleCount = 0
foreach ($baseId in ($groupedEntries.Keys | Sort-Object)[0..9]) {
    if ($groupedEntries[$baseId].Count -gt 1) {
        Write-Host "`nBase ID: $baseId" -ForegroundColor Magenta
        foreach ($entry in ($groupedEntries[$baseId] | Sort-Object identifier)) {
            $entryTitle = if ($entry.title) { $entry.title } else { "No Title" }
            Write-Host "  - $($entry.identifier) [$entryTitle]" -ForegroundColor Gray
        }
        $exampleCount++
        if ($exampleCount -ge 5) { break }  # Show max 5 examples
    }
}

# Ask for confirmation if not in WhatIf mode
if (-not $WhatIf) {
    Write-Host "`nWARNING: This will overwrite the output file!" -ForegroundColor Red
    $confirmation = Read-Host "Type 'SAVE' to confirm you want to proceed"
    if ($confirmation -ne 'SAVE') {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        exit
    }
}

# Process each group and build deduplicated list
$deduplicatedEntries = @()
$totalRemoved = 0
$duplicateGroups = 0
$removalLog = @()

foreach ($baseId in $groupedEntries.Keys) {
    $entries = $groupedEntries[$baseId]
    
    if ($entries.Count -gt 1) {
        $duplicateGroups++
        
        # Sort alphabetically by identifier and keep the first one
        $sortedEntries = $entries | Sort-Object identifier
        $keepEntry = $sortedEntries[0]
        $removeEntries = $sortedEntries[1..($sortedEntries.Count - 1)]
        
        Write-Host "`nBase ID: $baseId" -ForegroundColor Yellow
        $keepTitle = if ($keepEntry.title) { $keepEntry.title } else { "No Title" }
        Write-Host "  KEEPING: $($keepEntry.identifier) [$keepTitle]" -ForegroundColor Green
        
        # Add the kept entry to output
        $deduplicatedEntries += $keepEntry
        
        foreach ($removeEntry in $removeEntries) {
            $removeTitle = if ($removeEntry.title) { $removeEntry.title } else { "No Title" }
            Write-Host "  REMOVE:  $($removeEntry.identifier) [$removeTitle]" -ForegroundColor Red
            $totalRemoved++
            
            $removalLog += [PSCustomObject]@{
                BaseIdentifier = $baseId
                Action = if ($WhatIf) { "WOULD REMOVE" } else { "REMOVE" }
                Identifier = $removeEntry.identifier
                Title = $removeTitle
                KeptIdentifier = $keepEntry.identifier
                KeptTitle = $keepTitle
            }
        }
    } else {
        # Single entry, keep it
        $deduplicatedEntries += $entries[0]
    }
}

Write-Host "`n=== SUMMARY ===" -ForegroundColor Green
Write-Host "Total entries found: $($gameEntries.Count)" -ForegroundColor Cyan
Write-Host "Unique game identifiers (first $WordCount words): $($groupedEntries.Count)" -ForegroundColor Cyan  
Write-Host "Games with duplicates: $duplicateGroups" -ForegroundColor Yellow
Write-Host "Entries $(if($WhatIf){'to remove'}else{'removed'}): $totalRemoved" -ForegroundColor Red
Write-Host "Final entry count: $($deduplicatedEntries.Count)" -ForegroundColor Green

# Statistics about word count distribution
$wordCountStats = $debugInfo | Group-Object WordCount | Sort-Object Name
Write-Host "`n=== IDENTIFIER WORD COUNT DISTRIBUTION ===" -ForegroundColor Cyan
foreach ($stat in $wordCountStats) {
    Write-Host "Identifiers with $($stat.Name) words: $($stat.Count)" -ForegroundColor Gray
}

if (-not $WhatIf) {
    try {
        # Save the deduplicated JSON
        Write-Host "`nSaving cleaned JSON..." -ForegroundColor Cyan
        $deduplicatedJson = $deduplicatedEntries | ConvertTo-Json -Depth 100 -Compress:$false
        $deduplicatedJson | Out-File -FilePath $OutputFile -Encoding UTF8
        Write-Host "Cleaned JSON saved to: $OutputFile" -ForegroundColor Green
    } catch {
        Write-Host "Error saving file: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# Create detailed log files
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$logFile = "json_cleanup_$timestamp.log"
$csvFile = "json_removal_log_$timestamp.csv"

# Text log
$logContent = @"
JSON Duplicate Cleanup Log
Generated: $(Get-Date)
WhatIf Mode: $WhatIf
Word Count for Base ID: $WordCount

Input File: $JsonFile
Output File: $OutputFile

Total entries found: $($gameEntries.Count)
Unique game identifiers: $($groupedEntries.Count)
Games with duplicates: $duplicateGroups
Entries $(if($WhatIf){'to remove'}else{'removed'}): $totalRemoved
Final entry count: $($deduplicatedEntries.Count)

Word Count Distribution:
$($wordCountStats | ForEach-Object { "  $($_.Name) words: $($_.Count) identifiers" } | Out-String)

Settings Used:
  Base Identifier: First $WordCount words separated by '_'
  Sorting: Alphabetical by identifier (A-Z)
  Keep: First entry in sorted order per base identifier
  Remove: All subsequent entries with same base identifier
"@

$logContent | Out-File -FilePath $logFile -Encoding UTF8

# CSV log for detailed analysis
if ($removalLog.Count -gt 0) {
    $removalLog | Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8
    Write-Host "CSV removal log: $csvFile" -ForegroundColor Gray
}

if ($WhatIf) {
    Write-Host "`nThis was a DRY RUN - no files were actually modified." -ForegroundColor Yellow
    Write-Host "To actually clean the JSON, run:" -ForegroundColor Yellow
    Write-Host ".\clean_json_duplicates.ps1 -JsonFile '$JsonFile' -WordCount $WordCount -WhatIf:`$false" -ForegroundColor White
} else {
    Write-Host "`nJSON cleanup completed!" -ForegroundColor Green
}

Write-Host "`nLog saved to: $logFile" -ForegroundColor Cyan

# Show identifiers that might need manual review (very few words)
$shortIdentifiers = $debugInfo | Where-Object { $_.WordCount -lt $WordCount }
if ($shortIdentifiers.Count -gt 0) {
    Write-Host "`n=== IDENTIFIERS WITH FEWER THAN $WordCount WORDS (Manual Review Suggested) ===" -ForegroundColor Yellow
    $shortIdentifiers | ForEach-Object { 
        $wordText = if ($_.WordCount -eq 1) { "word" } else { "words" }
        Write-Host "  $($_.Identifier) ($($_.WordCount) $wordText)" -ForegroundColor Gray 
    }
}