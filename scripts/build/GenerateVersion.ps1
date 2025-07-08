#Requires -Version 7.0
<#
.SYNOPSIS
    Generates semantic version numbers for builds.

.DESCRIPTION
    This script generates semantic version numbers based on the current date
    and build run number, following the pattern: YY.MM.DD.BBBB

.PARAMETER RunNumber
    The GitHub Actions run number.

.PARAMETER CustomVersionScheme
    Optional custom version scheme. Default is 'DateBased'.

.EXAMPLE
    ./Generate-BuildVersion.ps1 -RunNumber 123
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [int]$RunNumber,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('DateBased', 'Sequential')]
    [string]$CustomVersionScheme = 'DateBased'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-VersionInfo {
    param([string]$Message, [string]$Color = 'White')
    Write-Host "🔢 $Message" -ForegroundColor $Color
}

function New-SemanticVersion {
    param(
        [int]$RunNumber,
        [string]$VersionScheme
    )
    
    $buildDate = Get-Date
    
    switch ($VersionScheme) {
        'DateBased' {
            $version = @{
                Major = $buildDate.ToString("yy")
                Minor = $buildDate.ToString("MM")
                Patch = $buildDate.ToString("dd")
                Build = "{0:D4}" -f ($RunNumber + 1000)
            }
        }
        'Sequential' {
            # Alternative scheme: Major.Minor based on year, Build number incremental
            $version = @{
                Major = $buildDate.ToString("yyyy")
                Minor = $buildDate.ToString("MM")
                Patch = "0"
                Build = $RunNumber.ToString()
            }
        }
        default {
            throw "Unknown version scheme: $VersionScheme"
        }
    }
    
    return $version
}

function Set-GitHubOutput {
    param([string]$Name, [string]$Value)
    
    if ($env:GITHUB_OUTPUT) {
        Add-Content -Path $env:GITHUB_OUTPUT -Value "$Name=$Value"
        Write-VersionInfo "GitHub Output set: $Name = $Value" -Color Blue
    }
    else {
        Write-VersionInfo "GitHub Output not available (running locally)" -Color Yellow
        Write-VersionInfo "Would set: $Name = $Value" -Color Gray
    }
}

function Test-VersionFormat {
    param([string]$Version)
    
    $versionRegex = '^(\d+)\.(\d+)\.(\d+)\.(\d+)$'
    if ($Version -match $versionRegex) {
        Write-VersionInfo "Version format validated: $Version" -Color Green
        return $true
    }
    else {
        Write-VersionInfo "Invalid version format: $Version" -Color Red
        return $false
    }
}

function Write-VersionSummary {
    param([hashtable]$Version, [string]$SemanticVersion, [string]$ReleaseTag)
    
    Write-Host ""
    Write-Host "📋 Version Generation Summary" -ForegroundColor Cyan
    Write-Host ("-" * 40) -ForegroundColor Cyan
    Write-Host "  Major (Year): $($Version.Major)" -ForegroundColor White
    Write-Host "  Minor (Month): $($Version.Minor)" -ForegroundColor White
    Write-Host "  Patch (Day): $($Version.Patch)" -ForegroundColor White
    Write-Host "  Build (Run): $($Version.Build)" -ForegroundColor White
    Write-Host ""
    Write-Host "  Semantic Version: $SemanticVersion" -ForegroundColor Green
    Write-Host "  Release Tag: $ReleaseTag" -ForegroundColor Green
    Write-Host "  Generation Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')" -ForegroundColor Blue
    Write-Host "  Version Scheme: $CustomVersionScheme" -ForegroundColor Blue
    Write-Host ("-" * 40) -ForegroundColor Cyan
}

try {
    Write-VersionInfo "Starting version generation..." -Color Yellow
    Write-VersionInfo "Run Number: $RunNumber" -Color Blue
    Write-VersionInfo "Version Scheme: $CustomVersionScheme" -Color Blue

    # Generate version components
    $version = New-SemanticVersion -RunNumber $RunNumber -VersionScheme $CustomVersionScheme

    # Create semantic version string
    $semanticVersion = "$($version.Major).$($version.Minor).$($version.Patch).$($version.Build)"
    $releaseTag = "v$semanticVersion"

    # Validate version format
    if (-not (Test-VersionFormat -Version $semanticVersion)) {
        throw "Generated version does not match expected format: $semanticVersion"
    }

    # Set GitHub Actions outputs
    Set-GitHubOutput -Name "version" -Value $semanticVersion
    Set-GitHubOutput -Name "release-tag" -Value $releaseTag

    # Display summary
    Write-VersionSummary -Version $version -SemanticVersion $semanticVersion -ReleaseTag $releaseTag

    Write-VersionInfo "✅ Version generation completed successfully" -Color Green

    # Additional metadata for debugging
    Write-VersionInfo "Build metadata:" -Color Magenta
    Write-VersionInfo "  UTC Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Color Gray
    Write-VersionInfo "  Time Zone: $((Get-TimeZone).DisplayName)" -Color Gray
    Write-VersionInfo "  PowerShell Version: $($PSVersionTable.PSVersion)" -Color Gray
    exit 0
}
catch {
    Write-VersionInfo "❌ Version generation failed: $($_.Exception.Message)" -Color Red

    # Debug information
    Write-VersionInfo "Debug information:" -Color Yellow
    Write-VersionInfo "  Run Number: $RunNumber" -Color Gray
    Write-VersionInfo "  Version Scheme: $CustomVersionScheme" -Color Gray
    Write-VersionInfo "  Current Date: $(Get-Date)" -Color Gray
    Write-VersionInfo "  Environment: $($env:GITHUB_ACTIONS -eq 'true' ? 'GitHub Actions' : 'Local')" -Color Gray

    exit 1
}