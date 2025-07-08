#Requires -Version 7.0
<#
.SYNOPSIS
    Restores NuGet packages for a .NET solution.

.DESCRIPTION
    This script restores NuGet packages for the specified solution file,
    with comprehensive error handling and logging.

.PARAMETER SolutionName
    The solution file name to restore packages for.

.EXAMPLE
    ./Restore-NuGetPackages.ps1 -SolutionName "MyApp.sln"
#>


[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SolutionName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-RestoreStatus {
    param([string]$Message, [string]$Color = 'White')
    Write-Host "📦 $Message" -ForegroundColor $Color
}

function Test-NuGetAvailable {
    try {
        $nugetVersion = & nuget help | Select-Object -First 1
        Write-RestoreStatus "NuGet CLI detected: $nugetVersion" -Color Green
        return $true
    }
    catch {
        Write-RestoreStatus "NuGet CLI not found" -Color Red
        return $false
    }
}

function Invoke-NuGetRestore {
    param([string]$SolutionPath)
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        Write-RestoreStatus "Starting NuGet package restore..." -Color Yellow
        Write-RestoreStatus "Solution: $SolutionPath" -Color Blue
        
        # Run nuget restore with verbose output
        $restoreArgs = @(
            'restore'
            $SolutionPath
            '-NonInteractive'
            '-Verbosity', 'normal'
        )
        
        Write-RestoreStatus "Command: nuget $($restoreArgs -join ' ')" -Color Gray
        
        $process = Start-Process -FilePath 'nuget' -ArgumentList $restoreArgs -NoNewWindow -Wait -PassThru
        
        if ($process.ExitCode -eq 0) {
            $stopwatch.Stop()
            Write-RestoreStatus "✅ NuGet package restore completed successfully" -Color Green
            Write-RestoreStatus "Restore time: $($stopwatch.Elapsed.TotalSeconds.ToString('F2')) seconds" -Color Blue
        }
        else {
            throw "NuGet restore failed with exit code: $($process.ExitCode)"
        }
    }
    catch {
        $stopwatch.Stop()
        Write-RestoreStatus "❌ NuGet restore failed after $($stopwatch.Elapsed.TotalSeconds.ToString('F2')) seconds" -Color Red
        throw "Package restoration failed: $($_.Exception.Message)"
    }
}

function Get-PackagesSummary {
    param([string]$SolutionPath)
    
    try {
        $solutionDir = Split-Path $SolutionPath -Parent
        $packagesConfig = Get-ChildItem -Path $solutionDir -Filter "packages.config" -Recurse
        $projectFiles = Get-ChildItem -Path $solutionDir -Filter "*.csproj" -Recurse
        
        Write-RestoreStatus "Package configuration files found: $($packagesConfig.Count)" -Color Blue
        Write-RestoreStatus "Project files found: $($projectFiles.Count)" -Color Blue
        
        # Check for packages folder
        $packagesFolder = Join-Path $solutionDir "packages"
        if (Test-Path $packagesFolder) {
            $packageCount = (Get-ChildItem -Path $packagesFolder -Directory | Measure-Object).Count
            Write-RestoreStatus "Packages installed: $packageCount" -Color Green
        }
        else {
            Write-RestoreStatus "Packages folder not found (may be using PackageReference)" -Color Yellow
        }
    }
    catch {
        Write-RestoreStatus "Could not generate packages summary: $($_.Exception.Message)" -Color Yellow
    }
}

try {
    Write-RestoreStatus "Initializing NuGet package restoration..." -Color Cyan

    # Validate solution file exists
    if (-not (Test-Path $SolutionName)) {
        throw "Solution file not found: $SolutionName"
    }

    # Check NuGet availability
    if (-not (Test-NuGetAvailable)) {
        throw "NuGet CLI is not available. Please ensure NuGet is installed and in PATH."
    }

    # Get packages summary before restore
    Write-RestoreStatus "Pre-restore analysis:" -Color Magenta
    Get-PackagesSummary -SolutionPath $SolutionName

    # Perform restore
    Invoke-NuGetRestore -SolutionPath $SolutionName

    # Get packages summary after restore
    Write-RestoreStatus "Post-restore analysis:" -Color Magenta
    Get-PackagesSummary -SolutionPath $SolutionName

    Write-RestoreStatus "Package restoration process completed successfully" -Color Green
    exit 0
}
catch {
    Write-RestoreStatus "❌ Package restoration failed: $($_.Exception.Message)" -Color Red

    # Additional troubleshooting information
    Write-RestoreStatus "Troubleshooting information:" -Color Yellow
    Write-RestoreStatus "  - Solution path: $SolutionName" -Color Gray
    Write-RestoreStatus "  - Current directory: $PWD" -Color Gray
    Write-RestoreStatus "  - PowerShell version: $($PSVersionTable.PSVersion)" -Color Gray

    exit 1
}