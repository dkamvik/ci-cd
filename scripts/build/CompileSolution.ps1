<#
.SYNOPSIS
    Builds a .NET solution using MSBuild with customizable configuration and version settings.

.DESCRIPTION
    This PowerShell script builds a .NET solution file using MSBuild with comprehensive error handling,
    version management, and output organization. 

.PARAMETER SolutionName
    The path to the .NET solution file (.sln) to build. This parameter is mandatory.

.PARAMETER Configuration
    The build configuration to use (e.g., Debug, Release). Default is "Release".

.PARAMETER AppName
    The application name used for the output directory structure. This parameter is mandatory.

.PARAMETER Version
    The version number to apply to all version-related MSBuild properties
    (Version, AssemblyVersion, FileVersion, InformationalVersion). Default is "1.0.0".

.EXAMPLE
     .\BuildSolution.ps1 -SolutionName "MyApp.sln" -AppName "MyApp" -Configuration "Debug" -Version "2.1.0"
    
     Builds the solution using Debug configuration with version 2.1.0.
#>


[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SolutionName,  
    [Parameter(Mandatory = $true)]
    [string]$AppName,
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [Parameter(Mandatory = $false)]
    [string]$BuildConfiguration = "Release"
)


Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "Building solution..." -ForegroundColor Yellow

try {
    # Validate that solution file exists
    if (-not (Test-Path $SolutionName)) {
        throw "Solution file '$SolutionName' not found"
    }

    # Create build directory if it doesn't exist
    $outputPath = "build\$AppName"
    if (-not (Test-Path $outputPath)) {
        Write-Host "Creating output directory: $outputPath" -ForegroundColor Cyan
        New-Item -Path $outputPath -ItemType Directory -Force | Out-Null
    }

    # Build MSBuild arguments array
    $buildArgs = @(
        $SolutionName
        "/p:Configuration=$BuildConfiguration"
        "/p:OutputPath=$outputPath"
        "/p:Version=$Version"
        "/p:AssemblyVersion=$Version"
        "/p:FileVersion=$Version"
        "/p:InformationalVersion=$Version"
        "/m"
        "/nologo"
        "/verbosity:minimal"
    )

    $msbuild = $env:MSBuildPath
    if (-not $msbuild) { $msbuild = "msbuild" }
    Write-Host "  Command: $msbuild $($buildArgs -join ' ')" -ForegroundColor Cyan

    & $msbuild @buildArgs

    if ($LASTEXITCODE -ne 0) {
        throw "MSBuild failed with exit code $LASTEXITCODE"
    }

    Write-Host "Solution built successfully" -ForegroundColor Green

    # Display build output information
    Write-Host "Build Details:" -ForegroundColor Cyan
    Write-Host "  Solution: $SolutionName" -ForegroundColor White
    Write-Host "  Configuration: $BuildConfiguration" -ForegroundColor White
    Write-Host "  Output Path: $outputPath" -ForegroundColor White
    Write-Host "  Version: $Version" -ForegroundColor White

    # Optional: List built files
    if (Test-Path $outputPath) {
        Write-Host "`nBuild artifacts:" -ForegroundColor Cyan
        Get-ChildItem -Path $outputPath -Recurse -File | ForEach-Object {
            Write-Host "  $($_.FullName)" -ForegroundColor Gray
        }
    }
    exit 0
}
catch {
    Write-Error "Build failed: $($_.Exception.Message)"
    exit 1
}