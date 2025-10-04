# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a data-only repository containing metadata for Commodore 64 software. The repository serves as a curated data source for the C64 Museum project.

## Structure

- `c64_software_cleaned.json` - The main data file containing an array of C64 software entries (12MB, 75,709 lines)
- `.git/` - Version control
- `.claude/` - Claude-specific directory (currently empty)

## Data Schema

Each entry in the JSON array contains:
- `identifier` - Unique ID for the software
- `title` - Software title
- `description` - Detailed description including gameplay, publisher, developer info (often sourced from MobyGames)
- `date` - Release date in ISO format
- `mediatype` - Type of media (typically "software")
- `tag` - Array of genre/category tags (e.g., "action", "racing", "adventure")
- `internetarchive` - Link to archive.org entry

Optional fields that may appear:
- `wikipedia` - Wikipedia article URL
- `manual` - Link to manual on archive.org
- `creator` - Developer/publisher name

## Common Tasks

### Viewing the data
```bash
# View first few entries
head -n 100 c64_software_cleaned.json

# Count total entries
jq 'length' c64_software_cleaned.json

# Search for specific titles
jq '.[] | select(.title | contains("SEARCH_TERM"))' c64_software_cleaned.json

# View unique tags
jq -r '.[].tag[]' c64_software_cleaned.json | sort | uniq
```

### Data Validation
```bash
# Validate JSON syntax
jq . c64_software_cleaned.json > /dev/null

# Check for duplicate identifiers
jq -r '.[].identifier' c64_software_cleaned.json | sort | uniq -d
```

## Important Notes

- This is a curated, cleaned dataset (indicated by "_cleaned" suffix)
- Data sources include MobyGames and Archive.org
- Recent commits show active deduplication efforts
- No build, test, or processing scripts are included - this is purely a data repository
- When modifying the JSON file, ensure proper formatting and validate the JSON structure