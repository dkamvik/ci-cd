#Requires -Version 7.0
<#
.SYNOPSIS
    Validates build inputs for the .NET build workflow.

.DESCRIPTION
    This script validates all required inputs for the .NET build process,
    ensuring that all necessary parameters are provided and the solution file exists.

.PARAMETER SolutionName
    The solution file name.


.EXAMPLE
    ./Validate-BuildInputs.ps1 -AppName "MyApp" -WebName "MyApp.Web" -ApiName "MyApp.API" -SolutionName "MyApp.sln" -WebOnly:$false
#>

[CmdletBinding()]
param(     
    [Parameter(Mandatory = $true)]
    [string]$SolutionName
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

try {
    Write-Host "🔍 Validating solution file..." -ForegroundColor Yellow
    
    # Trim all input values
    $inputs = @{
        SolutionName = $SolutionName.Trim()
    }    
 
    # Validate solution file exists
    if (-not (Test-Path $inputs.SolutionName)) {
        Write-ValidationError "Solution file not found: $($inputs.SolutionName)"
        throw "Solution file validation failed"
    }    
 
    Write-ValidationSuccess "Solution file found: $($inputs.SolutionName)"
    
    Write-Host "✅ Validation completed successfully" -ForegroundColor Green
}
catch {
    Write-ValidationError "Validation failed: $($_.Exception.Message)"
    exit 1
}