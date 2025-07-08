#Requires -Version 7.0
<#
.SYNOPSIS
    Writes build context information to the console.

.DESCRIPTION
    This script displays comprehensive build context information including
    repository details, build parameters, and execution context.

.PARAMETER Repository
    The GitHub repository name.

.PARAMETER Branch
    The branch being built.

.PARAMETER Actor
    The user who triggered the build.

.PARAMETER Event
    The GitHub event that triggered the build.

.PARAMETER AppName
    The application name.

.PARAMETER SolutionName
    The solution file name.

.PARAMETER WebName
    The web project name.

.PARAMETER ApiName
    The API project name.

.PARAMETER WebOnly
    Whether this is a web-only build.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Repository,
    
    [Parameter(Mandatory = $true)]
    [string]$Branch,
    
    [Parameter(Mandatory = $true)]
    [string]$Actor,
    
    [Parameter(Mandatory = $true)]
    [string]$Event,
    
    [Parameter(Mandatory = $true)]
    [string]$AppName,
    
    [Parameter(Mandatory = $true)]
    [string]$SolutionName,
    
    [Parameter(Mandatory = $true)]
    [string]$WebName,
    
    [Parameter(Mandatory = $false)]
    [string]$ApiName = '',
    
    [Parameter(Mandatory = $false)]
    [switch]$WebOnly
)

Set-StrictMode -Version Latest

function Write-ContextHeader {
    param([string]$Title)
    Write-Host ""
    Write-Host "🏗️  $Title" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Cyan
}

function Write-ContextItem {
    param([string]$Label, [string]$Value)
    Write-Host "  $Label`: $Value" -ForegroundColor White
}

try {
    Write-ContextHeader "Build Context"
    
    # Repository Information
    Write-ContextItem "Repository" $Repository
    Write-ContextItem "Branch" $Branch
    Write-ContextItem "Triggered by" $Actor
    Write-ContextItem "Event" $Event
    
    Write-Host ""
    Write-Host "📦 Build Configuration" -ForegroundColor Yellow
    Write-Host ("-" * 30) -ForegroundColor Yellow
    
    # Build Configuration
    Write-ContextItem "Application" $AppName
    Write-ContextItem "Solution" $SolutionName
    Write-ContextItem "Web Project" $WebName
    Write-ContextItem "API Project" $(if ($WebOnly) { "N/A (Web Only)" } else { $ApiName })
    Write-ContextItem "Build Mode" $(if ($WebOnly) { "Web Only" } else { "Full Stack" })
    
    # Environment Information
    Write-Host ""
    Write-Host "🔧 Environment Details" -ForegroundColor Magenta
    Write-Host ("-" * 30) -ForegroundColor Magenta
    Write-ContextItem "PowerShell Version" $PSVersionTable.PSVersion
    Write-ContextItem "OS" $PSVersionTable.OS
    Write-ContextItem "Platform" $PSVersionTable.Platform
    Write-ContextItem "Working Directory" $PWD
    Write-ContextItem "Timestamp" (Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC")
    
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host "✅ Build context information displayed" -ForegroundColor Green
}
catch {
    Write-Error "Failed to display build context: $($_.Exception.Message)"
    exit 1
}