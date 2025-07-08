<#
.SYNOPSIS
    Cleans up temporary files and directories created during the build process.

.DESCRIPTION
    This PowerShell script safely removes temporary files and directories that may have been
    created during the build or packaging process. It includes comprehensive error handling
    to ensure the script runs successfully even if cleanup operations fail.

    The script performs the following operations:
    - Validates the existence of temporary directories
    - Removes temporary files and folders recursively
    - Provides informative output about cleanup operations
    - Handles errors gracefully without failing the overall process

.PARAMETER TempDirectory
    The path to the temporary directory to clean up. This parameter is mandatory.

.PARAMETER Force
    If specified, forces removal of read-only files and directories.

.PARAMETER Verbose
    If specified, provides detailed output about each cleanup operation.

.EXAMPLE
    .\CleanupTempFiles.ps1 -TempDirectory "C:\Temp\PackageTemp"
    
    Cleans up the specified temporary directory.

.EXAMPLE
    .\CleanupTempFiles.ps1 -TempDirectory "temp\build" -Force -Verbose
    
    Forcefully cleans up the temporary directory with verbose output.

.EXAMPLE
    .\CleanupTempFiles.ps1 -TempDirectory @("temp\build", "temp\package", "artifacts\temp")
    
    Cleans up multiple temporary directories.

.NOTES
    Author: Generated Script
    
    This script is designed to run even when previous steps have failed (equivalent to if: always()).
    It uses SilentlyContinue error action to prevent cleanup failures from stopping the process.
#>

param(
    [Parameter(Mandatory = $true)]
    [string[]]$TempDirectory,
    
    [Parameter(Mandatory = $false)]
    [switch]$Force,
    
    [Parameter(Mandatory = $false)]
    [switch]$Verbose
)

# Function to clean up a single directory
function Remove-TempDirectory {
    param(
        [string]$Path,
        [switch]$Force
    )
    try {
        if (-not (Test-Path $Path)) {
            Write-Host "[WARN] Directory not found: $Path" -ForegroundColor Yellow
            return
        }
        Remove-Item -Path $Path -Recurse -Force:$Force -ErrorAction Stop
        Write-Host "[SUCCESS] Removed: $Path" -ForegroundColor Green
    } catch {
        Write-Host "[ERROR] Failed to remove $Path: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Main cleanup logic
try {
    Write-Host "[INFO] Starting temporary file cleanup..." -ForegroundColor Cyan
    foreach ($dir in $TempDirectory) {
        Remove-TempDirectory -Path $dir -Force:$Force
    }
    Write-Host "[SUCCESS] Cleanup completed successfully." -ForegroundColor Green
    exit 0
}
    Write-Host "[ERROR] Cleanup failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
    Write-Host "Cleanup process completed with warnings" -ForegroundColor Yellow
}

