#Requires -Version 7.0
<#+
.SYNOPSIS
    Core utilities for build and deployment scripts.
.DESCRIPTION
    Provides logging, error handling, directory, environment, stopwatch, and GitHub Actions helpers.
#>

Export-ModuleMember -Function @(
    'Write-BuildInfo',
    'Write-BuildError',
    'Write-BuildSuccess',
    'Write-BuildWarning',
    'Write-BuildHeader',
    'Write-BuildSummary',
    'Set-GitHubOutput',
    'Test-DirectoryExists',
    'New-DirectoryIfNotExists',
    'Remove-DirectorySafely',
    'Get-DirectorySize',
    'Test-PowerShellVersion',
    'Get-BuildTimestamp',
    'Start-BuildStopwatch',
    'Stop-BuildStopwatch',
    'Initialize-BuildEnvironment'
)

function Write-BuildInfo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [Parameter(Mandatory = $false)]
        [string]$Emoji = "ℹ️",
        [Parameter(Mandatory = $false)]
        [string]$Color = 'Blue'
    )
    Write-Host "$Emoji $Message" -ForegroundColor $Color
}

function Write-BuildError {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

function Write-BuildSuccess {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-BuildWarning {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor Yellow
}

function Write-BuildHeader {
    param(
        [string]$Title,
        [string]$Emoji = "🏗️",
        [int]$Width = 60
    )
    Write-Host ""
    Write-Host "$Emoji $Title" -ForegroundColor Cyan
    Write-Host ("=" * $Width) -ForegroundColor Cyan
}

function Write-BuildSummary {
    param(
        [hashtable]$Summary,
        [string]$Title = "Build Summary",
        [int]$Width = 50
    )
    Write-Host ""
    Write-Host "📋 $Title" -ForegroundColor Cyan
    Write-Host ("-" * $Width) -ForegroundColor Cyan
    foreach ($key in $Summary.Keys) {
        Write-Host "  $key`: $($Summary[$key])" -ForegroundColor White
    }
    Write-Host ("-" * $Width) -ForegroundColor Cyan
}

function Set-GitHubOutput {
    param([string]$Name, [string]$Value)
    if ($env:GITHUB_OUTPUT) {
        Add-Content -Path $env:GITHUB_OUTPUT -Value "$Name=$Value"
        Write-BuildInfo "GitHub Output set: $Name = $Value" -Color Blue
    } else {
        Write-BuildInfo "GitHub Output not available (running locally)" -Color Yellow
        Write-BuildInfo "Would set: $Name = $Value" -Color Gray
    }
}

function Test-DirectoryExists {
    param([string]$Path)
    return Test-Path -Path $Path -PathType Container
}

function New-DirectoryIfNotExists {
    param([string]$Path, [switch]$Force)
    try {
        if (-not (Test-Path $Path)) {
            $params = @{ Path = $Path; ItemType = 'Directory' }
            if ($Force) { $params.Force = $true }
            New-Item @params | Out-Null
            Write-BuildSuccess "Created directory: $Path"
            return $true
        } else {
            Write-BuildInfo "Directory already exists: $Path" -Color Gray
            return $true
        }
    } catch {
        Write-BuildError "Failed to create directory '$Path': $($_.Exception.Message)"
        return $false
    }
}

function Remove-DirectorySafely {
    param([string]$Path, [switch]$Force, [switch]$Verbose)
    try {
        if (Test-Path $Path) {
            if ($Verbose) {
                Write-BuildInfo "Removing directory: $Path" -Color Yellow
                $items = Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
                if ($items) {
                    Write-BuildInfo "Items to be removed: $($items.Count)" -Color Gray
                }
            }
            $removeParams = @{ Path = $Path; Recurse = $true; ErrorAction = 'SilentlyContinue' }
            if ($Force) { $removeParams.Force = $true }
            Remove-Item @removeParams
            if (-not (Test-Path $Path)) {
                Write-BuildSuccess "Directory removed: $Path"
                return $true
            } else {
                Write-BuildWarning "Partial removal of directory: $Path"
                return $false
            }
        } else {
            if ($Verbose) {
                Write-BuildInfo "Directory not found (already clean): $Path" -Color Gray
            }
            return $true
        }
    } catch {
        Write-BuildError "Failed to remove directory '$Path': $($_.Exception.Message)"
        return $false
    }
}

function Get-DirectorySize {
    param([string]$Path)
    try {
        if (-not (Test-Path $Path)) {
            return @{ SizeBytes = 0; SizeMB = 0; FileCount = 0; DirectoryCount = 0 }
        }
        $files = Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue
        $directories = Get-ChildItem -Path $Path -Recurse -Directory -ErrorAction SilentlyContinue
        $totalSize = ($files | Measure-Object -Property Length -Sum).Sum
        return @{ SizeBytes = $totalSize; SizeMB = [math]::Round($totalSize / 1MB, 2); FileCount = $files.Count; DirectoryCount = $directories.Count }
    } catch {
        Write-BuildWarning "Could not calculate directory size for '$Path': $($_.Exception.Message)"
        return @{ SizeBytes = 0; SizeMB = 0; FileCount = 0; DirectoryCount = 0 }
    }
}

function Test-PowerShellVersion {
    param([version]$MinimumVersion = '7.0')
    $currentVersion = $PSVersionTable.PSVersion
    if ($currentVersion -ge $MinimumVersion) {
        Write-BuildSuccess "PowerShell version check passed: $currentVersion"
        return $true
    } else {
        Write-BuildError "PowerShell version $currentVersion is below minimum required version $MinimumVersion"
        return $false
    }
}

function Get-BuildTimestamp {
    param([string]$Format = 'yyyy-MM-dd HH:mm:ss UTC')
    return Get-Date -Format $Format
}

function Start-BuildStopwatch {
    return [System.Diagnostics.Stopwatch]::StartNew()
}

function Stop-BuildStopwatch {
    param([System.Diagnostics.Stopwatch]$Stopwatch, [string]$Operation = "Operation")
    $Stopwatch.Stop()
    $elapsed = $Stopwatch.Elapsed.TotalSeconds.ToString('F2')
    Write-BuildInfo "$Operation completed in $elapsed seconds" -Color Blue
    return @{ ElapsedSeconds = $elapsed; ElapsedTimeSpan = $Stopwatch.Elapsed }
}

function Initialize-BuildEnvironment {
    param([switch]$StrictMode, [string]$ErrorActionPreference = 'Stop')
    if ($StrictMode) {
        Set-StrictMode -Version Latest
        Write-BuildInfo "Strict mode enabled" -Color Blue
    }
    $global:ErrorActionPreference = $ErrorActionPreference
    Write-BuildInfo "Error action preference set to: $ErrorActionPreference" -Color Blue
    if (-not (Test-PowerShellVersion)) {
        throw "PowerShell version requirements not met"
    }
    Write-BuildSuccess "Build environment initialized"
}
