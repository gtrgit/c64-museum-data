# FILENAME: compare_groupings.ps1
# Compare how folders and JSON entries will be grouped to ensure alignment

param(
    [string]$FolderPath = ".",
    [string]$JsonFile = "c64_software_cleaned.json",
    [int]$FolderWordCount = 4,
    [int]$JsonWordCount = 3
)

Write-Host "=== ALIGNMENT CHECK: Folders vs JSON Groupings ===" -ForegroundColor Cyan
Write-Host "Folder WordCount: $FolderWordCount" -ForegroundColor Yellow
Write-Host "JSON WordCount: $JsonWordCount" -ForegroundColor Yellow

# Function to extract base identifier
function Get-BaseGameIdentifier {
    param([string]$Name, [int]$WordCount)
    $words = $Name -split '_'
    if ($words.Count -ge $WordCount) {
        return ($words[0..($WordCount-1)] -join '_')
    } else {
        return $Name
    }
}

# Analyze folders
Write-Host "`n=== FOLDER ANALYSIS ===" -ForegroundColor Green
$folders = Get-ChildItem -Path $FolderPath -Directory
$folderGroups = @{}
foreach ($folder in $folders) {
    $baseId = Get-BaseGameIdentifier -Name $folder.Name -WordCount $FolderWordCount
    if (-not $folderGroups.ContainsKey($baseId)) {
        $folderGroups[$baseId] = @()
    }
    $folderGroups[$baseId] += $folder.Name
}

$folderDuplicates = $folderGroups.Keys | Where-Object { $folderGroups[$_].Count -gt 1 }
Write-Host "Total folders: $($folders.Count)"
Write-Host "Unique folder groups: $($folderGroups.Count)"
Write-Host "Groups with duplicates: $($folderDuplicates.Count)"
Write-Host "Folders to be deleted: $(($folderGroups.Values | ForEach-Object { $_.Count - 1 } | Measure-Object -Sum).Sum)"

# Analyze JSON if file exists
if (Test-Path $JsonFile) {
    Write-Host "`n=== JSON ANALYSIS ===" -ForegroundColor Green
    try {
        $jsonContent = Get-Content -Path $JsonFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $jsonGroups = @{}
        foreach ($entry in $jsonContent) {
            if ($entry.identifier) {
                $baseId = Get-BaseGameIdentifier -Name $entry.identifier -WordCount $JsonWordCount
                if (-not $jsonGroups.ContainsKey($baseId)) {
                    $jsonGroups[$baseId] = @()
                }
                $jsonGroups[$baseId] += $entry.identifier
            }
        }
        
        $jsonDuplicates = $jsonGroups.Keys | Where-Object { $jsonGroups[$_].Count -gt 1 }
        Write-Host "Total JSON entries: $($jsonContent.Count)"
        Write-Host "Unique JSON groups: $($jsonGroups.Count)"
        Write-Host "Groups with duplicates: $($jsonDuplicates.Count)"
        Write-Host "Entries to be deleted: $(($jsonGroups.Values | ForEach-Object { $_.Count - 1 } | Measure-Object -Sum).Sum)"
        
    } catch {
        Write-Host "Error reading JSON file: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "`nJSON file not found: $JsonFile" -ForegroundColor Yellow
}

# Show sample groupings for comparison
Write-Host "`n=== SAMPLE FOLDER GROUPINGS ===" -ForegroundColor Yellow
$folderDuplicates | Select-Object -First 5 | ForEach-Object {
    Write-Host "`nFolder Base: $_" -ForegroundColor Magenta
    $folderGroups[$_] | Sort-Object | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
}

if (Test-Path $JsonFile) {
    Write-Host "`n=== SAMPLE JSON GROUPINGS ===" -ForegroundColor Yellow
    $jsonDuplicates | Select-Object -First 5 | ForEach-Object {
        Write-Host "`nJSON Base: $_" -ForegroundColor Magenta
        $jsonGroups[$_] | Sort-Object | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
    }
}

# Check for potential misalignment
Write-Host "`n=== ALIGNMENT RECOMMENDATIONS ===" -ForegroundColor Cyan

$folderReduction = [math]::Round((($folders.Count - $folderGroups.Count) / $folders.Count) * 100, 1)
Write-Host "Folder reduction: $folderReduction%" -ForegroundColor Gray

if (Test-Path $JsonFile) {
    $jsonReduction = [math]::Round((($jsonContent.Count - $jsonGroups.Count) / $jsonContent.Count) * 100, 1)
    Write-Host "JSON reduction: $jsonReduction%" -ForegroundColor Gray
    
    if ([math]::Abs($folderReduction - $jsonReduction) -gt 10) {
        Write-Host "`nWARNING: Large difference in reduction percentages!" -ForegroundColor Red
        Write-Host "Consider adjusting WordCount values to better align the reductions." -ForegroundColor Yellow
    } else {
        Write-Host "`nGood: Reduction percentages are similar." -ForegroundColor Green
    }
}

Write-Host "`n=== NEXT STEPS ===" -ForegroundColor Cyan
Write-Host "1. Review the sample groupings above" -ForegroundColor Gray
Write-Host "2. If groupings look logical, proceed with current WordCount values" -ForegroundColor Gray
Write-Host "3. If misaligned, adjust WordCount values and re-test" -ForegroundColor Gray
Write-Host "4. Run folder cleanup first, then JSON cleanup" -ForegroundColor Gray