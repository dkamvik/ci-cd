#Requires -Version 7.0
<#+
.SYNOPSIS
    Validation utilities for build and deployment scripts.
.DESCRIPTION
    Provides functions for validating inputs, files, versions, and prerequisites.
#>

# Import core utilities for logging, etc.
Import-Module (Join-Path $PSScriptRoot 'CoreUtils.psm1') -Force

Export-ModuleMember -Function @(
    'Test-VersionFormat',
    'Test-SolutionFile',
    'Test-BuildInputs',
    'Test-RequiredParameter',
    'Test-FileExists',
    'Test-MSBuildAvailable',
    'Test-NuGetAvailable',
    'Confirm-BuildPrerequisites'
)

function Test-VersionFormat {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version,
        [Parameter(Mandatory = $false)]
        [string]$Pattern = '^[0-9]+\.[0-9]+\.[0-9]+(\.[0-9]+)?$'
    )
    if ([string]::IsNullOrWhiteSpace($Version)) {
        Write-BuildError "Version string is null or empty"
        return $false
    }
    if ($Version -match $Pattern) {
        Write-BuildSuccess "Version format validated: $Version"
        return $true
    } else {
        Write-BuildError "Invalid version format: $Version. Expected pattern: $Pattern"
        return $false
    }
}

function Test-SolutionFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SolutionPath
    )
    try {
        $trimmedPath = $SolutionPath.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmedPath)) {
            Write-BuildError "Solution path is null or empty"
            return $false
        }
        if (-not (Test-Path $trimmedPath)) {
            Write-BuildError "Solution file not found: $trimmedPath"
            return $false
        }
        if (-not $trimmedPath.EndsWith('.sln', [System.StringComparison]::OrdinalIgnoreCase)) {
            Write-BuildWarning "File does not have .sln extension: $trimmedPath"
        }
        $content = Get-Content $trimmedPath -TotalCount 5 -ErrorAction Stop
        if ($content -and $content[0] -like "*Microsoft Visual Studio Solution File*") {
            Write-BuildSuccess "Solution file validated: $trimmedPath"
            return $true
        } else {
            Write-BuildError "File does not appear to be a valid Visual Studio solution: $trimmedPath"
            return $false
        }
    } catch {
        Write-BuildError "Failed to validate solution file '$SolutionPath': $($_.Exception.Message)"
        return $false
    }
}

function Test-BuildInputs {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Inputs,
        [Parameter(Mandatory = $true)]
        [string[]]$RequiredFields,
        [Parameter(Mandatory = $false)]
        [hashtable]$ValidationRules = @{}
    )
    $errors = @()
    Write-BuildInfo "Validating build inputs..." -Emoji "🔍"
    foreach ($field in $RequiredFields) {
        if (-not $Inputs.ContainsKey($field) -or [string]::IsNullOrWhiteSpace($Inputs[$field])) {
            $errors += "$field is required"
        }
    }
    foreach ($field in $ValidationRules.Keys) {
        if ($Inputs.ContainsKey($field) -and -not [string]::IsNullOrWhiteSpace($Inputs[$field])) {
            $rule = $ValidationRules[$field]
            $value = $Inputs[$field]
            switch ($rule.Type) {
                'File' {
                    if (-not (Test-Path $value)) {
                        $errors += "$field file not found: $value"
                    }
                }
                'Directory' {
                    if (-not (Test-Path $value -PathType Container)) {
                        $errors += "$field directory not found: $value"
                    }
                }
                'Version' {
                    if (-not (Test-VersionFormat -Version $value)) {
                        $errors += "$field has invalid version format: $value"
                    }
                }
                'Regex' {
                    if ($value -notmatch $rule.Pattern) {
                        $errors += "$field does not match required pattern: $value"
                    }
                }
            }
        }
    }
    if ($errors.Count -gt 0) {
        Write-BuildError "Input validation failed with $($errors.Count) error(s):"
        $errors | ForEach-Object { Write-BuildError "  - $_" }
        return $false
    } else {
        Write-BuildSuccess "All build inputs validated successfully"
        return $true
    }
}

function Test-RequiredParameter {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ParameterName,
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$ParameterValue,
        [Parameter(Mandatory = $false)]
        [string]$ValidationPattern
    )
    if ([string]::IsNullOrWhiteSpace($ParameterValue)) {
        Write-BuildError "Required parameter '$ParameterName' is null or empty"
        return $false
    }
    if ($ValidationPattern -and $ParameterValue -notmatch $ValidationPattern) {
        Write-BuildError "Parameter '$ParameterName' does not match required pattern: $ValidationPattern"
        return $false
    }
    Write-BuildSuccess "Parameter '$ParameterName' validated: $ParameterValue"
    return $true
}

function Test-FileExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [Parameter(Mandatory = $false)]
        [string]$Description = "File"
    )
    $trimmedPath = $FilePath.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmedPath)) {
        Write-BuildError "$Description path is null or empty"
        return $false
    }
    if (Test-Path $trimmedPath) {
        Write-BuildSuccess "$Description found: $trimmedPath"
        return $true
    } else {
        Write-BuildError "$Description not found: $trimmedPath"
        return $false
    }
}

function Test-MSBuildAvailable {
    try {
        $msbuildPaths = @(
            "${env:ProgramFiles}\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\Bin\MSBuild.exe",
            "${env:ProgramFiles}\Microsoft Visual Studio\2022\Professional\MSBuild\Current\Bin\MSBuild.exe",
            "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe",
            "${env:ProgramFiles}\Microsoft Visual Studio\2019\Enterprise\MSBuild\Current\Bin\MSBuild.exe",
            "${env:ProgramFiles}\Microsoft Visual Studio\2019\Professional\MSBuild\Current\Bin\MSBuild.exe",
            "${env:ProgramFiles}\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe",
            "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\Bin\MSBuild.exe",
            "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\Professional\MSBuild\Current\Bin\MSBuild.exe",
            "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe",
            "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Enterprise\MSBuild\Current\Bin\MSBuild.exe",
            "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Professional\MSBuild\Current\Bin\MSBuild.exe",
            "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe"
        )
        foreach ($path in $msbuildPaths) {
            if (Test-Path $path) {
                Write-BuildSuccess "MSBuild found: $path"
                return @{ Available = $true; Path = $path }
            }
        }
        $msbuildInPath = Get-Command "msbuild" -ErrorAction SilentlyContinue
        if ($msbuildInPath) {
            Write-BuildSuccess "MSBuild found in PATH: $($msbuildInPath.Source)"
            return @{ Available = $true; Path = $msbuildInPath.Source }
        }
        Write-BuildError "MSBuild not found in any common locations or PATH"
        return @{ Available = $false; Path = $null }
    } catch {
        Write-BuildError "Failed to check MSBuild availability: $($_.Exception.Message)"
        return @{ Available = $false; Path = $null }
    }
}

function Test-NuGetAvailable {
    try {
        $nugetCommand = Get-Command "nuget" -ErrorAction SilentlyContinue
        if ($nugetCommand) {
            $version = & nuget help | Select-Object -First 1
            Write-BuildSuccess "NuGet CLI found: $version"
            return @{ Available = $true; Path = $nugetCommand.Source; Version = $version }
        } else {
            Write-BuildError "NuGet CLI not found in PATH"
            return @{ Available = $false; Path = $null; Version = $null }
        }
    } catch {
        Write-BuildError "Failed to check NuGet availability: $($_.Exception.Message)"
        return @{ Available = $false; Path = $null; Version = $null }
    }
}

function Confirm-BuildPrerequisites {
    param(
        [Parameter(Mandatory = $false)]
        [switch]$RequireMSBuild,
        [Parameter(Mandatory = $false)]
        [switch]$RequireNuGet,
        [Parameter(Mandatory = $false)]
        [version]$MinimumPowerShellVersion = '7.0'
    )
    $prerequisites = @{ PowerShell = $true; MSBuild = $true; NuGet = $true }
    Write-BuildHeader "Build Prerequisites Check"
    if (-not (Test-PowerShellVersion -MinimumVersion $MinimumPowerShellVersion)) {
        $prerequisites.PowerShell = $false
    }
    if ($RequireMSBuild) {
        $msbuildCheck = Test-MSBuildAvailable
        if (-not $msbuildCheck.Available) { $prerequisites.MSBuild = $false }
    } else {
        Write-BuildInfo "MSBuild check skipped (not required)" -Color Gray
    }
    if ($RequireNuGet) {
        $nugetCheck = Test-NuGetAvailable
        if (-not $nugetCheck.Available) { $prerequisites.NuGet = $false }
    } else {
        Write-BuildInfo "NuGet check skipped (not required)" -Color Gray
    }
    $allPassed = $prerequisites.Values -notcontains $false
    if ($allPassed) {
        Write-BuildSuccess "All build prerequisites satisfied"
        return $true
    } else {
        Write-BuildError "Build prerequisites check failed"
        $prerequisites.GetEnumerator() | ForEach-Object {
            $status = if ($_.Value) { "✅" } else { "❌" }
            Write-Host "  $status $($_.Key)" -ForegroundColor White
        }
        return $false
    }
}
