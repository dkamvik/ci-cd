
#Requires -Version 7.0
<#
.SYNOPSIS
    Applies a specified version to all AssemblyInfo.cs files in the project.

.DESCRIPTION
    Updates all AssemblyInfo.cs files in the current directory and subdirectories
    with the specified version number. Replaces both AssemblyVersion and AssemblyFileVersion attributes.

.PARAMETER Version
    The version string to apply to all AssemblyInfo.cs files. Format: "x.y.z.w" (e.g., "1.2.3.4")

.PARAMETER Verbose
    If specified, provides detailed output about each file being processed.

.EXAMPLE
    .\apply-version.ps1 -Version "1.2.3.4"
    Applies version 1.2.3.4 to all AssemblyInfo.cs files in the current directory and subdirectories.

.EXAMPLE
    .\apply-version.ps1 -Version "1.2.3.4" -Verbose
    Applies version with detailed output about each file processed.
#>


[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [Parameter(Mandatory = $false)]
    [switch]$Verbose
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"


# Import required modules and initialize environment
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$utilsPath = Join-Path (Split-Path $scriptPath -Parent) "utils"
Import-Module (Join-Path $utilsPath "Build-Common.psm1") -Force
Import-Module (Join-Path $utilsPath "Build-Validation.psm1") -Force
Initialize-BuildEnvironment -StrictMode


function Update-AssemblyInfoFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [Parameter(Mandatory = $true)]
        [string]$NewVersion,
        [Parameter(Mandatory = $false)]
        [switch]$VerboseOutput
    )
    try {
        if ($VerboseOutput) {
            Write-BuildInfo "Processing: $FilePath" -Color Gray
        }
        $content = Get-Content $FilePath
        $modified = $false
        # Update AssemblyVersion
        $newContent = $content -replace 'AssemblyVersion\(".*?"\)', "AssemblyVersion(`"$NewVersion`")"
        if ($newContent -ne $content) {
            $content = $newContent
            $modified = $true
            if ($VerboseOutput) {
                Write-BuildInfo "Updated AssemblyVersion to: $NewVersion" -Color Gray
            }
        }
        # Update AssemblyFileVersion
        $newContent = $content -replace 'AssemblyFileVersion\(".*?"\)', "AssemblyFileVersion(`"$NewVersion`")"
        if ($newContent -ne $content) {
            $content = $newContent
            $modified = $true
            if ($VerboseOutput) {
                Write-BuildInfo "Updated AssemblyFileVersion to: $NewVersion" -Color Gray
            }
        }
        if ($modified) {
            $content | Set-Content $FilePath
            Write-BuildSuccess "Updated: $FilePath"
            return $true
        } else {
            if ($VerboseOutput) {
                Write-BuildInfo "No version attributes found in: $FilePath" -Color Gray
            }
            return $false
        }
    }
    catch {
        Write-BuildWarning "Failed to update $FilePath`: $($_.Exception.Message)"
        return $false
    }
}


try {
    Write-BuildHeader "Assembly Version Application"

    # Validate version format
    if (-not (Test-VersionFormat -Version $Version)) {
        throw "Invalid version format: $Version. Expected format: x.y.z.w (e.g., 1.2.3.4)"
    }

    Write-BuildInfo "Version to apply: $Version" -Color Cyan

    # Resolve base directory
    $searchPath = Get-Location
    if ($Verbose) {
        Write-BuildInfo "Base directory: $searchPath" -Color Gray
    }

    # Find all AssemblyInfo.cs files
    Write-BuildInfo "Searching for AssemblyInfo.cs files..." -Color Yellow
    $files = Get-ChildItem -Path $searchPath -Recurse -Filter "AssemblyInfo.cs" -ErrorAction SilentlyContinue

    if (-not $files -or $files.Count -eq 0) {
        Write-BuildWarning "No AssemblyInfo.cs files found in $searchPath"
        Write-BuildInfo "Assembly version update completed (no files to update)." -Color Yellow
        exit 0
    }

    Write-BuildSuccess "Found $($files.Count) AssemblyInfo.cs file(s)"

    # Process each file
    $updatedCount = 0
    $processedCount = 0

    foreach ($file in $files) {
        $processedCount++
        if ($Verbose) {
            Write-BuildInfo "Processing file $processedCount of $($files.Count): $($file.Name)" -Color Gray
        }

        $wasUpdated = Update-AssemblyInfoFile -FilePath $file.FullName -NewVersion $Version -VerboseOutput:$Verbose
        if ($wasUpdated) {
            $updatedCount++
        }
    }

    # Create summary
    $summary = @{
        "Version Applied" = $Version
        "Files Found" = $files.Count
        "Files Processed" = $processedCount
        "Files Updated" = $updatedCount
    }

    Write-BuildSummary -Summary $summary -Title "Assembly Version Update Summary"

    # List all processed files if verbose
    if ($Verbose) {
        Write-BuildInfo "Processed Files:" -Color Cyan
        foreach ($file in $files) {
            Write-BuildInfo "  - $($file.FullName)" -Color Gray
        }
    }

    Write-BuildSuccess "Assembly version update completed successfully"
    exit 0
}
catch {
    Write-BuildError "Failed to update assembly versions: $($_.Exception.Message)"
    exit 1
}
