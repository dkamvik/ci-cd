#Requires -Version 7.0
<#
.SYNOPSIS
    Validates build inputs for the .NET build workflow.

.DESCRIPTION
    This script validates all required inputs for the .NET build process,
    ensuring that all necessary parameters are provided and the solution file exists.

.PARAMETER AppName
    The application name for packaging.

.PARAMETER WebName
    The web project name.

.PARAMETER ApiName
    The API project name (optional for web-only builds).

.PARAMETER SolutionName
    The solution file name.

.PARAMETER WebOnly
    Whether to build web application only (skip API).

.EXAMPLE
    ./Validate-BuildInputs.ps1 -AppName "MyApp" -WebName "MyApp.Web" -ApiName "MyApp.API" -SolutionName "MyApp.sln" -WebOnly:$false
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$AppName,
    
    [Parameter(Mandatory = $true)]
    [string]$WebName,
    
    [Parameter(Mandatory = $false)]
    [string]$ApiName = '',
    
    [Parameter(Mandatory = $true)]
    [string]$SolutionName,
    
    [Parameter(Mandatory = $false)]
    [switch]$WebOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-ValidationError {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

function Write-ValidationSuccess {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-ValidationInfo {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor Blue
}

try {
    Write-Host "🔍 Validating build inputs..." -ForegroundColor Yellow
    
    # Trim all input values
    $inputs = @{
        AppName      = $AppName.Trim()
        WebName      = $WebName.Trim()
        ApiName      = $ApiName.Trim()
        SolutionName = $SolutionName.Trim()
        WebOnly      = $WebOnly.IsPresent
    }
    
    # Validate required fields
    $errors = @()
    
    if ([string]::IsNullOrWhiteSpace($inputs.AppName)) {
        $errors += "app_name is required"
    }
    
    if ([string]::IsNullOrWhiteSpace($inputs.WebName)) {
        $errors += "web_name is required"
    }
    
    if ([string]::IsNullOrWhiteSpace($inputs.SolutionName)) {
        $errors += "solution_name is required"
    }
    
    if (-not $inputs.WebOnly -and [string]::IsNullOrWhiteSpace($inputs.ApiName)) {
        $errors += "api_name is required when web_only is false"
    }
    
    # Report validation errors
    if ($errors.Count -gt 0) {
        Write-ValidationError "Input validation failed:"
        $errors | ForEach-Object { Write-ValidationError "  - $_" }
        throw "Input validation failed with $($errors.Count) error(s)"
    }
    
    # Validate solution file exists
    if (-not (Test-Path $inputs.SolutionName)) {
        Write-ValidationError "Solution file not found: $($inputs.SolutionName)"
        throw "Solution file validation failed"
    }
    
    # Success messages
    Write-ValidationSuccess "All required inputs validated successfully"
    Write-ValidationSuccess "Solution file found: $($inputs.SolutionName)"
    
    # Log validation summary
    Write-ValidationInfo "Validation Summary:"
    Write-ValidationInfo "  Application: $($inputs.AppName)"
    Write-ValidationInfo "  Web Project: $($inputs.WebName)"
    Write-ValidationInfo "  API Project: $(if ($inputs.WebOnly) { 'N/A (Web Only)' } else { $inputs.ApiName })"
    Write-ValidationInfo "  Solution: $($inputs.SolutionName)"
    Write-ValidationInfo "  Mode: $(if ($inputs.WebOnly) { 'Web Only' } else { 'Full Stack' })"
    
    Write-Host "✅ Validation completed successfully" -ForegroundColor Green
}
catch {
    Write-ValidationError "Validation failed: $($_.Exception.Message)"
    exit 1
}