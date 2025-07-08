Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
param(
    [Parameter(Mandatory = $true)]
    [string]$Environment,
    
    [Parameter(Mandatory = $true)]
    [string]$PublishPath,
    
    [string]$ConfigPath = "environments"
)

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    
    $colorMap = @{
        "Red" = "Red"
        "Green" = "Green"
        "Yellow" = "Yellow"
        "Blue" = "Blue"
        "Magenta" = "Magenta"
        "Cyan" = "Cyan"
        "White" = "White"
    }
    
    Write-Host $Message -ForegroundColor $colorMap[$Color]
}

# Function to safely get JSON property
function Get-JsonProperty {
    param(
        [object]$JsonObject,
        [string]$PropertyName,
        [object]$DefaultValue = $null
    )
    
    if ($JsonObject.PSObject.Properties.Name -contains $PropertyName) {
        return $JsonObject.$PropertyName
    }
    return $DefaultValue
}

# Function to transform appsettings.json
function Transform-AppSettings {
    param(
        [string]$AppSettingsPath,
        [object]$EnvironmentConfig
    )
    
    if (-not (Test-Path $AppSettingsPath)) {
        Write-ColorOutput "⚠️  appsettings.json not found at: $AppSettingsPath" "Yellow"
        return
    }
    
    Write-ColorOutput "🔧 Transforming appsettings.json..." "Cyan"
    
    try {
        $appSettings = Get-Content $AppSettingsPath | ConvertFrom-Json
        
        # Transform connection strings
        $connectionStrings = Get-JsonProperty $EnvironmentConfig "connectionStrings"
        if ($connectionStrings) {
            Write-ColorOutput "  📝 Updating connection strings..." "Green"
            if (-not $appSettings.ConnectionStrings) {
                $appSettings | Add-Member -MemberType NoteProperty -Name "ConnectionStrings" -Value @{}
            }
            
            foreach ($connStr in $connectionStrings.PSObject.Properties) {
                $appSettings.ConnectionStrings | Add-Member -MemberType NoteProperty -Name $connStr.Name -Value $connStr.Value -Force
                Write-ColorOutput "    ✅ Updated: $($connStr.Name)" "Green"
            }
        }
        
        # Transform API endpoints
        $apiEndpoints = Get-JsonProperty $EnvironmentConfig "apiEndpoints"
        if ($apiEndpoints) {
            Write-ColorOutput "  🌐 Updating API endpoints..." "Green"
            if (-not $appSettings.ApiEndpoints) {
                $appSettings | Add-Member -MemberType NoteProperty -Name "ApiEndpoints" -Value @{}
            }
            
            foreach ($endpoint in $apiEndpoints.PSObject.Properties) {
                $appSettings.ApiEndpoints | Add-Member -MemberType NoteProperty -Name $endpoint.Name -Value $endpoint.Value -Force
                Write-ColorOutput "    ✅ Updated: $($endpoint.Name) -> $($endpoint.Value)" "Green"
            }
        }
        
        # Transform logging settings
        $logging = Get-JsonProperty $EnvironmentConfig "logging"
        if ($logging) {
            Write-ColorOutput "  📊 Updating logging configuration..." "Green"
            if (-not $appSettings.Logging) {
                $appSettings | Add-Member -MemberType NoteProperty -Name "Logging" -Value @{}
            }
            
            foreach ($logConfig in $logging.PSObject.Properties) {
                $appSettings.Logging | Add-Member -MemberType NoteProperty -Name $logConfig.Name -Value $logConfig.Value -Force
                Write-ColorOutput "    ✅ Updated logging: $($logConfig.Name)" "Green"
            }
        }
        
        # Transform custom application settings
        $appConfig = Get-JsonProperty $EnvironmentConfig "appSettings"
        if ($appConfig) {
            Write-ColorOutput "  ⚙️  Updating application settings..." "Green"
            foreach ($setting in $appConfig.PSObject.Properties) {
                $appSettings | Add-Member -MemberType NoteProperty -Name $setting.Name -Value $setting.Value -Force
                Write-ColorOutput "    ✅ Updated: $($setting.Name)" "Green"
            }
        }
        
        # Save the transformed file
        $appSettings | ConvertTo-Json -Depth 10 | Set-Content $AppSettingsPath -Encoding UTF8
        Write-ColorOutput "✅ appsettings.json transformed successfully!" "Green"
        
    } catch {
        Write-ColorOutput "❌ Error transforming appsettings.json: $($_.Exception.Message)" "Red"
        throw
    }
}

# Function to transform web.config
function Transform-WebConfig {
    param(
        [string]$WebConfigPath,
        [object]$EnvironmentConfig
    )
    
    if (-not (Test-Path $WebConfigPath)) {
        Write-ColorOutput "⚠️  web.config not found at: $WebConfigPath" "Yellow"
        return
    }
    
    Write-ColorOutput "🔧 Transforming web.config..." "Cyan"
    
    try {
        [xml]$webConfig = Get-Content $WebConfigPath
        
        # Transform connection strings
        $connectionStrings = Get-JsonProperty $EnvironmentConfig "connectionStrings"
        if ($connectionStrings) {
            Write-ColorOutput "  📝 Updating connection strings in web.config..." "Green"
            
            $connectionStringsNode = $webConfig.configuration.connectionStrings
            if (-not $connectionStringsNode) {
                $connectionStringsNode = $webConfig.CreateElement("connectionStrings")
                $webConfig.configuration.AppendChild($connectionStringsNode) | Out-Null
            }
            
            foreach ($connStr in $connectionStrings.PSObject.Properties) {
                $existingNode = $connectionStringsNode.SelectSingleNode("add[@name='$($connStr.Name)']")
                if ($existingNode) {
                    $existingNode.connectionString = $connStr.Value
                } else {
                    $newNode = $webConfig.CreateElement("add")
                    $newNode.SetAttribute("name", $connStr.Name)
                    $newNode.SetAttribute("connectionString", $connStr.Value)
                    $connectionStringsNode.AppendChild($newNode) | Out-Null
                }
                Write-ColorOutput "    ✅ Updated: $($connStr.Name)" "Green"
            }
        }
        
        # Transform app settings
        $appSettings = Get-JsonProperty $EnvironmentConfig "appSettings"
        if ($appSettings) {
            Write-ColorOutput "  ⚙️  Updating app settings in web.config..." "Green"
            
            $appSettingsNode = $webConfig.configuration.appSettings
            if (-not $appSettingsNode) {
                $appSettingsNode = $webConfig.CreateElement("appSettings")
                $webConfig.configuration.AppendChild($appSettingsNode) | Out-Null
            }
            
            foreach ($setting in $appSettings.PSObject.Properties) {
                $existingNode = $appSettingsNode.SelectSingleNode("add[@key='$($setting.Name)']")
                if ($existingNode) {
                    $existingNode.value = $setting.Value
                } else {
                    $newNode = $webConfig.CreateElement("add")
                    $newNode.SetAttribute("key", $setting.Name)
                    $newNode.SetAttribute("value", $setting.Value)
                    $appSettingsNode.AppendChild($newNode) | Out-Null
                }
                Write-ColorOutput "    ✅ Updated: $($setting.Name)" "Green"
            }
        }
        
        # Save the transformed file
        $webConfig.Save($WebConfigPath)
        Write-ColorOutput "✅ web.config transformed successfully!" "Green"
        
    } catch {
        Write-ColorOutput "❌ Error transforming web.config: $($_.Exception.Message)" "Red"
        throw
    }
}

# Main execution
try {
    Write-ColorOutput "🚀 Starting configuration transformation..." "Magenta"
    Write-ColorOutput "  Environment: $Environment" "Cyan"
    Write-ColorOutput "  Publish Path: $PublishPath" "Cyan"
    Write-ColorOutput "  Config Path: $ConfigPath" "Cyan"
    
    # Validate inputs
    if (-not (Test-Path $PublishPath)) {
        throw "Publish path does not exist: $PublishPath"
    }
    
    # Load environment configuration
    $envConfigPath = Join-Path $ConfigPath "$Environment/webapp.json"
    
    if (-not (Test-Path $envConfigPath)) {
        Write-ColorOutput "⚠️  Environment configuration not found: $envConfigPath" "Yellow"
        Write-ColorOutput "📝 Available environments:" "Yellow"
        $availableEnvs = Get-ChildItem $ConfigPath -Directory | Select-Object -ExpandProperty Name
        foreach ($env in $availableEnvs) {
            Write-ColorOutput "  - $env" "Yellow"
        }
        throw "Environment configuration not found"
    }
    
    Write-ColorOutput "📋 Loading environment configuration..." "Cyan"
    $environmentConfig = Get-Content $envConfigPath | ConvertFrom-Json
    
    # Find configuration files to transform
    $appsettingsPath = Join-Path $PublishPath "appsettings.json"
    $webConfigPath = Join-Path $PublishPath "web.config"
    
    # Transform appsettings.json
    if (Test-Path $appsettingsPath) {
        Transform-AppSettings -AppSettingsPath $appsettingsPath -EnvironmentConfig $environmentConfig
    }
    
    # Transform web.config
    if (Test-Path $webConfigPath) {
        Transform-WebConfig -WebConfigPath $webConfigPath -EnvironmentConfig $environmentConfig
    }
    
    # Create environment-specific appsettings file
    $envAppsettingsPath = Join-Path $PublishPath "appsettings.$Environment.json"
    if (Test-Path $appsettingsPath) {
        Write-ColorOutput "📄 Creating environment-specific appsettings..." "Cyan"
        $envSpecificSettings = @{
            "Environment" = $Environment
            "Timestamp" = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            "BuildNumber" = $env:GITHUB_RUN_NUMBER
            "CommitHash" = $env:GITHUB_SHA
        }
        
        $envSpecificSettings | ConvertTo-Json -Depth 10 | Set-Content $envAppsettingsPath -Encoding UTF8
        Write-ColorOutput "✅ Created: appsettings.$Environment.json" "Green"
    }
    
    # Copy environment-specific files if they exist
    $envFilesPath = Join-Path $ConfigPath "$Environment"
    $envFiles = @("robots.txt", "favicon.ico", "*.css", "*.js")
    
    foreach ($pattern in $envFiles) {
        $files = Get-ChildItem -Path $envFilesPath -Filter $pattern -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            $destPath = Join-Path $PublishPath $file.Name
            Copy-Item $file.FullName $destPath -Force
            Write-ColorOutput "📁 Copied environment file: $($file.Name)" "Green"
        }
    }
    
    # Validate transformed configuration
    Write-ColorOutput "🔍 Validating transformed configuration..." "Cyan"
    
    if (Test-Path $appsettingsPath) {
        try {
            $validatedSettings = Get-Content $appsettingsPath | ConvertFrom-Json
            Write-ColorOutput "✅ appsettings.json is valid JSON" "Green"
            
            # Check for required settings
            $requiredSettings = @("ConnectionStrings", "Logging")
            foreach ($setting in $requiredSettings) {
                if ($validatedSettings.PSObject.Properties.Name -contains $setting) {
                    Write-ColorOutput "✅ Required setting found: $setting" "Green"
                } else {
                    Write-ColorOutput "⚠️  Required setting missing: $setting" "Yellow"
                }
            }
        } catch {
            Write-ColorOutput "❌ Invalid JSON in appsettings.json: $($_.Exception.Message)" "Red"
            throw
        }
    }
    
    if (Test-Path $webConfigPath) {
        try {
            [xml]$validatedConfig = Get-Content $webConfigPath
            Write-ColorOutput "✅ web.config is valid XML" "Green"
        } catch {
            Write-ColorOutput "❌ Invalid XML in web.config: $($_.Exception.Message)" "Red"
            throw
        }
    }
    
    # Generate transformation report
    $reportPath = Join-Path $PublishPath "transformation-report.json"
    $report = @{
        "environment" = $Environment
        "timestamp" = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        "configPath" = $envConfigPath
        "publishPath" = $PublishPath
        "transformedFiles" = @()
        "buildInfo" = @{
            "runNumber" = $env:GITHUB_RUN_NUMBER
            "commitHash" = $env:GITHUB_SHA
            "branch" = $env:GITHUB_REF_NAME
            "actor" = $env:GITHUB_ACTOR
        }
    }
    
    if (Test-Path $appsettingsPath) {
        $report.transformedFiles += @{
            "file" = "appsettings.json"
            "path" = $appsettingsPath
            "size" = (Get-Item $appsettingsPath).Length
        }
    }
    
    if (Test-Path $webConfigPath) {
        $report.transformedFiles += @{
            "file" = "web.config"
            "path" = $webConfigPath
            "size" = (Get-Item $webConfigPath).Length
        }
    }
    
    $report | ConvertTo-Json -Depth 10 | Set-Content $reportPath -Encoding UTF8
    Write-ColorOutput "📊 Generated transformation report: transformation-report.json" "Green"
    
    Write-ColorOutput "🎉 Configuration transformation completed successfully!" "Green"
    Write-ColorOutput "📋 Summary:" "Cyan"
    Write-ColorOutput "  Environment: $Environment" "White"
    Write-ColorOutput "  Files transformed: $($report.transformedFiles.Count)" "White"
    Write-ColorOutput "  Publish path: $PublishPath" "White"
    
} catch {
    Write-ColorOutput "❌ Configuration transformation failed: $($_.Exception.Message)" "Red"
    Write-ColorOutput "📋 Stack trace:" "Red"
    Write-ColorOutput $_.Exception.StackTrace "Red"
    exit 1
}