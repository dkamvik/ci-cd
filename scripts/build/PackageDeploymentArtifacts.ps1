#Requires -Version 7.0
<#
.SYNOPSIS
    Creates deployment packages for .NET applications.

.DESCRIPTION
    This script creates deployment packages by collecting build artifacts,
    adding version files, removing environment-specific configs, and creating
    a compressed archive ready for deployment.

.PARAMETER AppName
    The application name for packaging.

.PARAMETER WebName
    The web project name.

.PARAMETER ApiName
    The API project name.

.PARAMETER Version
    The version number to include in the package.

.PARAMETER DeployDir
    The deployment directory path.

.PARAMETER TempDir
    The temporary directory for packaging.

.PARAMETER WebOnly
    Whether to build web application only (skip API).

.EXAMPLE
    ./New-DeploymentPackage.ps1 -AppName "MyApp" -WebName "MyApp.Web" -ApiName "MyApp.API" -Version "24.01.15.1001" -DeployDir "deploy" -TempDir "deploy/_temp" -WebOnly:$false
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
    [string]$Version,
    
    [Parameter(Mandatory = $true)]
    [string]$DeployDir,
    
    [Parameter(Mandatory = $true)]
    [string]$TempDir,
    
    [Parameter(Mandatory = $false)]
    [switch]$WebOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-PackageInfo {
    param([string]$Message, [string]$Color = 'White')
    Write-Host "📦 $Message" -ForegroundColor $Color
}

function Initialize-PackageDirectories {
    param([string]$DeployPath, [string]$TempPath)
    
    try {
        Write-PackageInfo "Initializing package directories..." -Color Yellow
        
        # Create deploy directory
        if (-not (Test-Path $DeployPath)) {
            New-Item -ItemType Directory -Path $DeployPath -Force | Out-Null
            Write-PackageInfo "Created deploy directory: $DeployPath" -Color Green
        }
        
        # Clean and create temp directory
        if (Test-Path $TempPath) {
            Remove-Item -Path $TempPath -Recurse -Force
            Write-PackageInfo "Cleaned existing temp directory: $TempPath" -Color Blue
        }
        
        New-Item -ItemType Directory -Path $TempPath -Force | Out-Null
        Write-PackageInfo "Created temp directory: $TempPath" -Color Green
        
        return $true
    }
    catch {
        Write-PackageInfo "Failed to initialize directories: $($_.Exception.Message)" -Color Red
        return $false
    }
}

function Add-ApplicationToPackage {
    param(
        [string]$SourcePath,
        [string]$AppType,
        [string]$Version,
        [string]$TempPath
    )
    
    try {
        Write-PackageInfo "Processing $AppType application..." -Color Yellow
        
        # Validate source path
        if (-not (Test-Path $SourcePath)) {
            throw "$AppType application source not found: $SourcePath"
        }
        
        Write-PackageInfo "  Source: $SourcePath" -Color Blue
        
        # Add version file
        $versionFile = Join-Path $SourcePath "version.txt"
        $versionContent = @"
Version: $Version
Build Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')
Application: $AppType
"@
        Set-Content -Path $versionFile -Value $versionContent -Encoding UTF8
        Write-PackageInfo "  ✅ Added version file" -Color Green
        
        # Remove environment-specific configuration files
        $configFiles = @(
            'web.config',
            'app.config',
            'appsettings.Development.json',
            'appsettings.Local.json'
        )
        
        foreach ($configFile in $configFiles) {
            $configPath = Join-Path $SourcePath $configFile
            if (Test-Path $configPath) {
                Remove-Item $configPath -Force
                Write-PackageInfo "  ✅ Removed $configFile" -Color Green
            }
        }
        
        # Copy to temp directory
        $targetName = Split-Path $SourcePath -Leaf
        $targetPath = Join-Path $TempPath $targetName
        
        Copy-Item -Path $SourcePath -Destination $targetPath -Recurse -Force
        Write-PackageInfo "  ✅ Copied to package temp directory" -Color Green
        
        # Get application size
        $appSize = Get-DirectorySize -Path $targetPath
        Write-PackageInfo "  📊 Application size: $($appSize.SizeMB) MB ($($appSize.FileCount) files)" -Color Blue
        
        return $true
    }
    catch {
        Write-PackageInfo "  ❌ Failed to add $AppType application: $($_.Exception.Message)" -Color Red
        return $false
    }
}

function Get-DirectorySize {
    param([string]$Path)
    
    try {
        $files = Get-ChildItem -Path $Path -Recurse -File
        $totalSize = ($files | Measure-Object -Property Length -Sum).Sum
        
        return @{
            SizeBytes = $totalSize
            SizeMB = [math]::Round($totalSize / 1MB, 2)
            FileCount = $files.Count
        }
    }
    catch {
        return @{
            SizeBytes = 0
            SizeMB = 0
            FileCount = 0
        }
    }
}

function New-DeploymentArchive {
    param(
        [string]$SourcePath,
        [string]$DestinationPath,
        [string]$AppName,
        [string]$Version
    )
    
    try {
        Write-PackageInfo "Creating deployment archive..." -Color Yellow
        
        # Create archive
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        Compress-Archive -Path "$SourcePath\*" -DestinationPath $DestinationPath -Force
        $stopwatch.Stop()
        
        # Verify archive
        if (-not (Test-Path $DestinationPath)) {
            throw "Archive creation failed - file not found: $DestinationPath"
        }
        
        # Get archive info
        $archiveInfo = Get-Item $DestinationPath
        $archiveSizeMB = [math]::Round($archiveInfo.Length / 1MB, 2)
        
        Write-PackageInfo "✅ Archive created successfully" -Color Green
        Write-PackageInfo "  📁 File: $($archiveInfo.Name)" -Color Blue
        Write-PackageInfo "  📊 Size: $archiveSizeMB MB" -Color Blue
        Write-PackageInfo "  ⏱️  Time: $($stopwatch.Elapsed.TotalSeconds.ToString('F2')) seconds" -Color Blue
        
        return @{
            Path = $DestinationPath
            SizeMB = $archiveSizeMB
            CreationTime = $stopwatch.Elapsed
        }
    }
    catch {
        Write-PackageInfo "❌ Archive creation failed: $($_.Exception.Message)" -Color Red
        throw
    }
}

function Set-GitHubOutput {
    param([string]$Name, [string]$Value)
    
    if ($env:GITHUB_OUTPUT) {
        Add-Content -Path $env:GITHUB_OUTPUT -Value "$Name=$Value"
        Write-PackageInfo "GitHub Output set: $Name = $Value" -Color Blue
    }
    else {
        Write-PackageInfo "Would set GitHub Output: $Name = $Value" -Color Gray
    }
}

function Write-PackageSummary {
    param([hashtable]$Summary)
    
    Write-Host ""
    Write-Host "📋 Package Summary" -ForegroundColor Cyan
    Write-Host ("-" * 50) -ForegroundColor Cyan
    Write-Host "  Application: $($Summary.AppName)" -ForegroundColor White
    Write-Host "  Version: $($Summary.Version)" -ForegroundColor White
    Write-Host "  Package File: $($Summary.PackageFile)" -ForegroundColor White
    Write-Host "  Package Size: $($Summary.PackageSizeMB) MB" -ForegroundColor White
    Write-Host "  Build Mode: $($Summary.BuildMode)" -ForegroundColor White
    Write-Host "  Creation Time: $($Summary.CreationTime)" -ForegroundColor White
    Write-Host "  Applications Included:" -ForegroundColor White
    foreach ($app in $Summary.Applications) {
        Write-Host "    - $app" -ForegroundColor Green
    }
    Write-Host ("-" * 50) -ForegroundColor Cyan
}

try {
    Write-PackageInfo "Starting deployment package creation..." -Color Cyan
    Write-PackageInfo "Application: $AppName" -Color Blue
    Write-PackageInfo "Version: $Version" -Color Blue
    Write-PackageInfo "Mode: $(if ($WebOnly) { 'Web Only' } else { 'Full Stack' })" -Color Blue

    # Initialize paths
    $paths = @{
        DeployDir = $DeployDir
        TempDir = $TempDir
        ZipFile = Join-Path $DeployDir "$AppName.$Version.zip"
        WebSource = Join-Path $WebName "build\$AppName\_PublishedWebsites\$WebName"
        ApiSource = Join-Path $ApiName "build\$AppName\_PublishedWebsites\$ApiName"
    }

    # Initialize directories
    if (-not (Initialize-PackageDirectories -DeployPath $paths.DeployDir -TempPath $paths.TempDir)) {
        throw "Failed to initialize package directories"
    }

    # Track applications added
    $applicationsAdded = @()

    # Add web application
    if (Add-ApplicationToPackage -SourcePath $paths.WebSource -AppType "Web" -Version $Version -TempPath $paths.TempDir) {
        $applicationsAdded += "Web Application ($WebName)"
    }
    else {
        throw "Failed to add web application to package"
    }

    # Add API application (if not web-only)
    if (-not $WebOnly) {
        if (Add-ApplicationToPackage -SourcePath $paths.ApiSource -AppType "API" -Version $Version -TempPath $paths.TempDir) {
            $applicationsAdded += "API Application ($ApiName)"
        }
        else {
            throw "Failed to add API application to package"
        }
    }

    # Create deployment archive
    $archiveInfo = New-DeploymentArchive -SourcePath $paths.TempDir -DestinationPath $paths.ZipFile -AppName $AppName -Version $Version

    # Set GitHub Actions output
    Set-GitHubOutput -Name "package-path" -Value $paths.ZipFile

    # Create summary
    $summary = @{
        AppName = $AppName
        Version = $Version
        PackageFile = Split-Path $paths.ZipFile -Leaf
        PackageSizeMB = $archiveInfo.SizeMB
        BuildMode = if ($WebOnly) { "Web Only" } else { "Full Stack" }
        CreationTime = $archiveInfo.CreationTime.ToString('mm\:ss\.fff')
        Applications = $applicationsAdded
    }

    Write-PackageSummary -Summary $summary
    Write-PackageInfo "✅ Deployment package created successfully" -Color Green
    exit 0
}
catch {
    Write-PackageInfo "❌ Package creation failed: $($_.Exception.Message)" -Color Red

    # Cleanup on failure
    try {
        if (Test-Path $TempDir) {
            Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
            Write-PackageInfo "Cleaned up temporary files" -Color Blue
        }
    }
    catch {
        Write-PackageInfo "Warning: Could not clean up temporary files" -Color Yellow
    }

    exit 1
}