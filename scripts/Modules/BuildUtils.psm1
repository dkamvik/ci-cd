#Requires -Version 7.0
<#+
.SYNOPSIS
    Build and packaging utilities for build scripts.
.DESCRIPTION
    Provides functions for creating archives, managing deployment packages, and file operations used in build automation.
#>

# Import core utilities for logging, directory, and environment helpers
Import-Module (Join-Path $PSScriptRoot 'CoreUtils.psm1') -Force

Export-ModuleMember -Function @(
    'New-DeploymentArchive',
    'Add-VersionFile',
    'Remove-EnvironmentConfigs',
    'Copy-ApplicationFiles',
    'Get-ArchiveInfo',
    'Test-ArchiveIntegrity'
)

function New-DeploymentArchive {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath,
        [Parameter(Mandatory = $true)]
        [string]$AppName,
        [Parameter(Mandatory = $true)]
        [string]$Version,
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )
    try {
        Write-BuildInfo "Creating deployment archive..." -Emoji "📦" -Color Yellow
        Write-BuildInfo "Source: $SourcePath" -Color Blue
        Write-BuildInfo "Destination: $DestinationPath" -Color Blue
        if (-not (Test-Path $SourcePath)) { throw "Source path not found: $SourcePath" }
        $destinationDir = Split-Path $DestinationPath -Parent
        if ($destinationDir -and -not (Test-Path $destinationDir)) {
            New-DirectoryIfNotExists -Path $destinationDir -Force
        }
        if ($Force -and (Test-Path $DestinationPath)) {
            Remove-Item $DestinationPath -Force
            Write-BuildInfo "Removed existing archive: $DestinationPath" -Color Gray
        }
        $stopwatch = Start-BuildStopwatch
        $compressParams = @{ Path = "$SourcePath\*"; DestinationPath = $DestinationPath }
        if ($Force) { $compressParams.Force = $true }
        Compress-Archive @compressParams
        $timing = Stop-BuildStopwatch -Stopwatch $stopwatch -Operation "Archive creation"
        if (-not (Test-Path $DestinationPath)) { throw "Archive creation failed - file not found: $DestinationPath" }
        $archiveInfo = Get-Item $DestinationPath
        $archiveSizeMB = [math]::Round($archiveInfo.Length / 1MB, 2)
        Write-BuildSuccess "Archive created successfully"
        Write-BuildInfo "File: $($archiveInfo.Name)" -Color Blue
        Write-BuildInfo "Size: $archiveSizeMB MB" -Color Blue
        Write-BuildInfo "Time: $($timing.ElapsedSeconds) seconds" -Color Blue
        return @{ Path = $DestinationPath; SizeMB = $archiveSizeMB; CreationTime = $timing.ElapsedTimeSpan; Success = $true }
    } catch {
        Write-BuildError "Archive creation failed: $($_.Exception.Message)"
        return @{ Path = $DestinationPath; SizeMB = 0; CreationTime = [TimeSpan]::Zero; Success = $false; Error = $_.Exception.Message }
    }
}

function Add-VersionFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetPath,
        [Parameter(Mandatory = $true)]
        [string]$Version,
        [Parameter(Mandatory = $true)]
        [string]$AppType,
        [Parameter(Mandatory = $false)]
        [hashtable]$AdditionalInfo = @{}
    )
    try {
        Write-BuildInfo "Adding version file to $AppType application..." -Color Yellow
        if (-not (Test-Path $TargetPath)) { throw "$AppType application path not found: $TargetPath" }
        $versionFile = Join-Path $TargetPath "version.txt"
        $versionContent = @"`nVersion: $Version`nBuild Date: $(Get-BuildTimestamp)`nApplication: $AppType`nPowerShell Version: $($PSVersionTable.PSVersion)`nBuild Machine: $($env:COMPUTERNAME)`nBuild User: $($env:USERNAME)`n"@
        foreach ($key in $AdditionalInfo.Keys) {
            $versionContent += "`n$key`: $($AdditionalInfo[$key])"
        }
        Set-Content -Path $versionFile -Value $versionContent -Encoding UTF8
        Write-BuildSuccess "Version file added: $versionFile"
        return $true
    } catch {
        Write-BuildError "Failed to add version file to $AppType application: $($_.Exception.Message)"
        return $false
    }
}

function Remove-EnvironmentConfigs {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetPath,
        [Parameter(Mandatory = $false)]
        [string[]]$ConfigFiles = @(
            'web.config','app.config','appsettings.Development.json','appsettings.Local.json','appsettings.Staging.json','*.user','*.suo','bin\*.pdb')
    )
    try {
        Write-BuildInfo "Removing environment-specific configuration files..." -Color Yellow
        if (-not (Test-Path $TargetPath)) {
            Write-BuildWarning "Target path not found: $TargetPath"
            return $false
        }
        $removedCount = 0
        foreach ($pattern in $ConfigFiles) {
            $filesToRemove = Get-ChildItem -Path $TargetPath -Filter $pattern -Recurse -ErrorAction SilentlyContinue
            foreach ($file in $filesToRemove) {
                try {
                    Remove-Item $file.FullName -Force
                    Write-BuildInfo "Removed: $($file.Name)" -Color Green
                    $removedCount++
                } catch {
                    Write-BuildWarning "Could not remove $($file.FullName): $($_.Exception.Message)"
                }
            }
        }
        Write-BuildSuccess "Removed $removedCount environment-specific files"
        return $true
    } catch {
        Write-BuildError "Failed to remove environment configs: $($_.Exception.Message)"
        return $false
    }
}

function Copy-ApplicationFiles {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath,
        [Parameter(Mandatory = $true)]
        [string]$AppType,
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )
    try {
        Write-BuildInfo "Copying $AppType application files..." -Color Yellow
        Write-BuildInfo "From: $SourcePath" -Color Blue
        Write-BuildInfo "To: $DestinationPath" -Color Blue
        if (-not (Test-Path $SourcePath)) { throw "$AppType application source not found: $SourcePath" }
        $targetName = Split-Path $SourcePath -Leaf
        $fullDestinationPath = Join-Path $DestinationPath $targetName
        if ($Force -and (Test-Path $fullDestinationPath)) {
            Remove-DirectorySafely -Path $fullDestinationPath -Force
        }
        $stopwatch = Start-BuildStopwatch
        Copy-Item -Path $SourcePath -Destination $fullDestinationPath -Recurse -Force
        $timing = Stop-BuildStopwatch -Stopwatch $stopwatch -Operation "$AppType files copy"
        if (-not (Test-Path $fullDestinationPath)) { throw "Copy operation failed - destination not found: $fullDestinationPath" }
        $sizeInfo = Get-DirectorySize -Path $fullDestinationPath
        Write-BuildSuccess "$AppType application copied successfully"
        Write-BuildInfo "Files: $($sizeInfo.FileCount)" -Color Blue
        Write-BuildInfo "Size: $($sizeInfo.SizeMB) MB" -Color Blue
        Write-BuildInfo "Time: $($timing.ElapsedSeconds) seconds" -Color Blue
        return @{ Success = $true; DestinationPath = $fullDestinationPath; FileCount = $sizeInfo.FileCount; SizeMB = $sizeInfo.SizeMB; CopyTime = $timing.ElapsedTimeSpan }
    } catch {
        Write-BuildError "Failed to copy $AppType application: $($_.Exception.Message)"
        return @{ Success = $false; DestinationPath = $null; FileCount = 0; SizeMB = 0; CopyTime = [TimeSpan]::Zero; Error = $_.Exception.Message }
    }
}

function Get-ArchiveInfo {
    param([string]$ArchivePath)
    try {
        if (-not (Test-Path $ArchivePath)) { throw "Archive not found: $ArchivePath" }
        $archiveFile = Get-Item $ArchivePath
        $archiveContents = $null
        try {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $archive = [System.IO.Compression.ZipFile]::OpenRead($ArchivePath)
            $archiveContents = $archive.Entries
            $archive.Dispose()
        } catch {
            Write-BuildWarning "Could not read archive contents: $($_.Exception.Message)"
        }
        return @{ Path = $ArchivePath; Name = $archiveFile.Name; SizeBytes = $archiveFile.Length; SizeMB = [math]::Round($archiveFile.Length / 1MB, 2); CreationTime = $archiveFile.CreationTime; LastWriteTime = $archiveFile.LastWriteTime; EntryCount = if ($archiveContents) { $archiveContents.Count } else { 0 }; IsValid = $archiveContents -ne $null }
    } catch {
        Write-BuildError "Failed to get archive info: $($_.Exception.Message)"
        return @{ Path = $ArchivePath; Name = $null; SizeBytes = 0; SizeMB = 0; CreationTime = [DateTime]::MinValue; LastWriteTime = [DateTime]::MinValue; EntryCount = 0; IsValid = $false; Error = $_.Exception.Message }
    }
}

function Test-ArchiveIntegrity {
    param([string]$ArchivePath)
    try {
        Write-BuildInfo "Testing archive integrity..." -Color Yellow
        if (-not (Test-Path $ArchivePath)) {
            Write-BuildError "Archive not found: $ArchivePath"
            return $false
        }
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $archive = [System.IO.Compression.ZipFile]::OpenRead($ArchivePath)
        $entryCount = $archive.Entries.Count
        $validEntries = 0
        foreach ($entry in $archive.Entries) {
            try {
                $stream = $entry.Open()
                $stream.ReadByte() | Out-Null
                $stream.Close()
                $validEntries++
            } catch {
                Write-BuildWarning "Invalid entry found: $($entry.FullName)"
            }
        }
        $archive.Dispose()
        if ($validEntries -eq $entryCount) {
            Write-BuildSuccess "Archive integrity test passed ($entryCount entries)"
            return $true
        } else {
            Write-BuildError "Archive integrity test failed ($validEntries/$entryCount valid entries)"
            return $false
        }
    } catch {
        Write-BuildError "Archive integrity test failed: $($_.Exception.Message)"
        return $false
    }
}
