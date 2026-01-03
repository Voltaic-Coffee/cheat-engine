#requires -Version 5.1
Set-StrictMode -Version Latest

function Invoke-BuildCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Executable,
        [string[]]$Arguments = @(),
        [string]$WorkingDirectory,
        [switch]$IgnoreExitCode
    )

    if (-not (Test-Path -LiteralPath $Executable)) {
        throw ('Build executable was not found: {0}' -f $Executable)
    }

    # Build a safely-quoted argument string so values with spaces are handled correctly.
    $quotedArgs = @()
    foreach ($arg in ($Arguments | Where-Object { $_ -ne $null })) {
        $text = [string]$arg
        if ($text -eq '') {
            continue
        }

        if ($text -match '\s' -or $text -match '"') {
            $escaped = $text.Replace('"', '""')
            $quotedArgs += ('"{0}"' -f $escaped)
        }
        else {
            $quotedArgs += $text
        }
    }

    $displayArgs = $quotedArgs -join ' '
    Write-BuildLog -Message ('Executing: {0} {1}' -f $Executable, $displayArgs) -Level 'DEBUG'

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Executable
    $psi.Arguments = $quotedArgs -join ' '
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    if ($WorkingDirectory) {
        if (-not (Test-Path -LiteralPath $WorkingDirectory)) {
            throw ('Working directory not found: {0}' -f $WorkingDirectory)
        }
        $psi.WorkingDirectory = $WorkingDirectory
    }

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi

    [void]$process.Start()

    $stdOut = $process.StandardOutput.ReadToEnd()
    $stdErr = $process.StandardError.ReadToEnd()

    $process.WaitForExit()

    $exitCode = $process.ExitCode

    # Log command output when verbose logging is enabled
    if ($stdOut) {
        Write-BuildLog -Message "Command output (stdout):`n$stdOut" -Level 'DEBUG'
    }
    if ($stdErr) {
        Write-BuildLog -Message "Command output (stderr):`n$stdErr" -Level 'DEBUG'
    }

    if ($exitCode -ne 0 -and -not $IgnoreExitCode) {
        $combined = ($stdOut + [Environment]::NewLine + $stdErr).Trim()
        if (-not $combined) {
            $combined = ('Command failed with exit code {0}: {1}' -f $exitCode, $Executable)
        }
        $err = New-Object System.Exception($combined)
        throw $err
    }

    return [PSCustomObject]@{
        ExitCode = $exitCode
        StdOut   = $stdOut
        StdErr   = $stdErr
    }
}

function Get-ObjectValue {
    param($Source, [string]$PropertyName)

    if ($null -eq $Source) {
        return $null
    }

    if ($Source -is [hashtable]) {
        if ($Source.ContainsKey($PropertyName)) {
            return $Source[$PropertyName]
        }
        return $null
    }

    $prop = $Source.PSObject.Properties[$PropertyName]
    if ($prop) {
        return $prop.Value
    }

    return $null
}

function Has-ObjectProperty {
    param($Source, [string]$PropertyName)

    if ($null -eq $Source) {
        return $false
    }

    if ($Source -is [hashtable]) {
        return $Source.ContainsKey($PropertyName)
    }

    return $null -ne $Source.PSObject.Properties[$PropertyName]
}

function ConvertTo-Hashtable {
    param($Source)

    if ($null -eq $Source) {
        return @{}
    }

    if ($Source -is [hashtable]) {
        return $Source
    }

    $table = @{}
    foreach ($property in $Source.PSObject.Properties) {
        $table[$property.Name] = $property.Value
    }

    return $table
}

function Invoke-LazarusProjectBuild {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ProjectPath,
        [Parameter(Mandatory)][string]$LazBuildPath,
        [string]$DisplayName = $ProjectPath,
        [object[]]$Targets,
        [string[]]$AdditionalArguments = @(),
        [switch]$Rebuild
    )

    $resolvedProject = (Resolve-Path -LiteralPath $ProjectPath -ErrorAction Stop).ProviderPath
    $workingDirectory = Split-Path -Parent $resolvedProject
    $targetList = $Targets

    $targetListCount = if ($targetList) { @($targetList).Count } else { 0 }
    if ($targetListCount -eq 0) {
        $targetList = @(@{})
    }

    foreach ($target in $targetList) {
        # lazbuild expects: lazbuild [options] filename
        # Global options should precede the project file and we always
        # build recursively without writing into the project file.
        $args = @()

        # Global lazbuild options
        $args += '--recursive'
        $args += '--no-write-project'

        # Force a full rebuild of all units if requested
        if ($Rebuild) {
            $args += '--build-all'
        }

        # Target-specific options
        if (Has-ObjectProperty $target 'BuildMode') { $args += ('--build-mode="{0}"' -f (Get-ObjectValue $target 'BuildMode')) }
        if (Has-ObjectProperty $target 'Cpu') { $args += ('--cpu="{0}"' -f (Get-ObjectValue $target 'Cpu')) }
        if (Has-ObjectProperty $target 'Os') { $args += ('--os="{0}"' -f (Get-ObjectValue $target 'Os')) }
        if (Has-ObjectProperty $target 'WidgetSet') { $args += ('--ws="{0}"' -f (Get-ObjectValue $target 'WidgetSet')) }
        if (Has-ObjectProperty $target 'AdditionalArgs') { $args += (Get-ObjectValue $target 'AdditionalArgs') }
        if ($AdditionalArguments) { $args += $AdditionalArguments }

        # Project file goes last to respect "lazbuild [options] filename"
        $args += ('"{0}"' -f $resolvedProject)

        $targetName = Get-ObjectValue $target 'Name'
        $targetLabel = if ($targetName) { $targetName } else { 'default' }
        Write-BuildLog -Message ('[Lazarus] {0} -> {1}' -f $DisplayName, $targetLabel) -Level 'INFO'

        Invoke-BuildCommand -Executable $LazBuildPath -Arguments $args -WorkingDirectory $workingDirectory | Out-Null
    }

    Write-BuildLog -Message ('[Lazarus] {0} completed.' -f $DisplayName) -Level 'SUCCESS'
}

function Invoke-LazarusProjectsInParallel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$Projects,
        [Parameter(Mandatory)][string]$LazBuildPath,
        [switch]$Rebuild,
        [int]$MaxParallelJobs = 0
    )

    if ($Projects.Count -eq 0) {
        return
    }

    # Build array of tasks to execute in parallel
    $tasks = @()
    
    foreach ($project in $Projects) {
        $projectPath = $project.ProjectPath
        $displayName = $project.DisplayName
        $targets = $project.Targets
        $additionalArgs = $project.AdditionalArguments
        
        # Serialize targets to XML for safe transmission
        $targetsXml = [System.Management.Automation.PSSerializer]::Serialize($targets)
        $addArgsXml = [System.Management.Automation.PSSerializer]::Serialize($additionalArgs)
        
        # Create scriptblock for this project
        $taskScript = [scriptblock]::Create(@"
param(`$ProjPath, `$LazPath, `$DispName, `$TargetsXml, `$AddArgsXml, `$DoRebuild, `$ScriptRoot)

try {
    # Import required modules in the job context
    Import-Module (Join-Path -Path `$ScriptRoot -ChildPath 'Logging.psm1') -Force
    Import-Module (Join-Path -Path `$ScriptRoot -ChildPath 'Builder.psm1') -Force

    # Deserialize targets
    `$Targs = [System.Management.Automation.PSSerializer]::Deserialize(`$TargetsXml)
    `$AddArgs = [System.Management.Automation.PSSerializer]::Deserialize(`$AddArgsXml)

    Invoke-LazarusProjectBuild -ProjectPath `$ProjPath -LazBuildPath `$LazPath ``
        -DisplayName `$DispName -Targets `$Targs -AdditionalArguments `$AddArgs -Rebuild:`$DoRebuild
}
catch {
    `$errorMessage = `$_.Exception.Message
    Write-Error "Build failed for `${DispName}: `$errorMessage"
    throw
}
"@)
        
        $tasks += @{
            Script = $taskScript
            Description = "Lazarus: $displayName"
            Arguments = @($projectPath, $LazBuildPath, $displayName, $targetsXml, $addArgsXml, $Rebuild.IsPresent, $PSScriptRoot)
        }
    }

    Write-BuildLog -Message "Building $($tasks.Count) Lazarus projects in parallel..." -Level 'INFO'
    
    # Import ParallelBuilder module and execute
    $scriptRoot = $PSScriptRoot
    Import-Module (Join-Path -Path $scriptRoot -ChildPath 'ParallelBuilder.psm1') -Force
    
    Invoke-BuildTasksInParallel -Tasks $tasks -MaxParallelJobs $MaxParallelJobs
}

function Invoke-MSBuildSolution {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SolutionPath,
        [Parameter(Mandatory)][string]$MSBuildPath,
        [string]$DisplayName = $SolutionPath,
        [object[]]$Configurations,
        [string[]]$Targets = @('Build'),
        [hashtable]$GlobalProperties,
        [string[]]$AdditionalArguments = @(),
        [switch]$EnableAutoRetargetSolution,
        [switch]$Rebuild
    )

    $resolvedSolution = (Resolve-Path -LiteralPath $SolutionPath -ErrorAction Stop).ProviderPath
    $workingDirectory = Split-Path -Parent $resolvedSolution

    $configCount = if ($Configurations) { @($Configurations).Count } else { 0 }
    if ($configCount -eq 0) {
        $Configurations = @(@{ Configuration = 'Release'; Platform = 'x64' })
    }

    foreach ($configuration in $Configurations) {
        $configName = Get-ObjectValue $configuration 'Configuration'
        $platform = Get-ObjectValue $configuration 'Platform'
        if (-not $configName -or -not $platform) {
            throw "Configuration entries must define both 'Configuration' and 'Platform'."
        }

            $targetList = if (Has-ObjectProperty $configuration 'Targets') { Get-ObjectValue $configuration 'Targets' } else { $Targets }
        $targetCount = if ($targetList) { @($targetList).Count } else { 0 }

        # Respect -Rebuild even when explicit Targets are provided
        if ($Rebuild) {
                $targetList = @('Rebuild')
                $targetCount = 1
        }
        elseif ($targetCount -eq 0) {
                $targetList = @('Build')
                $targetCount = 1
        }

        foreach ($target in $targetList) {
            $args = @()
            $args += ('-t:{0}' -f $target)
            $args += ('-p:Configuration={0}' -f $configName)
            $args += ('-p:Platform={0}' -f $platform)

            if ($GlobalProperties) {
                foreach ($key in $GlobalProperties.Keys) {
                    $args += ('-p:{0}={1}' -f $key, $GlobalProperties[$key])
                }
            }

            if (Has-ObjectProperty $configuration 'Properties') {
                $properties = ConvertTo-Hashtable (Get-ObjectValue $configuration 'Properties')
                foreach ($key in $properties.Keys) {
                    $args += ('-p:{0}={1}' -f $key, $properties[$key])
                }
            }

            if (Has-ObjectProperty $configuration 'AdditionalArgs') {
                $args += (Get-ObjectValue $configuration 'AdditionalArgs')
            }

            if ($AdditionalArguments) {
                $args += $AdditionalArguments
            }

            $args += $resolvedSolution

            $label = '{0} ({1}|{2})' -f $DisplayName, $configName, $platform
            if ($target -ne 'Build') {
                $label = '{0} -> {1}' -f $label, $target
            }

            Write-BuildLog -Message ('[MSBuild] {0}' -f $label) -Level 'INFO'

            $retargetAttempted = $false

            while ($true) {
                try {
                    $result = Invoke-BuildCommand -Executable $MSBuildPath -Arguments $args -WorkingDirectory $workingDirectory
                    # If MSBuild exited successfully, just continue.
                    if ($result.ExitCode -eq 0) {
                        break
                    }

                    # Non-zero exit here only happens when IgnoreExitCode is used; treat generically.
                    throw ('MSBuild failed with exit code {0}.' -f $result.ExitCode)
                }
                catch {
                    $message = $_.Exception.Message

                    # Preserve the original MSBuild error output (if present) for easier diagnosis.
                    if ($message) {
                        Write-BuildLog -Message ('[MSBuild] Original error output: {0}' -f $message) -Level 'DEBUG'
                    }

                    $isSdkError = $false
                    if ($message -match 'MSB8036' -or $message -match 'The Windows SDK version 10\.0\.17763\.0 was not found') {
                        $isSdkError = $true
                    }

                    if (-not $isSdkError) {
                        throw
                    }

                    if (-not $EnableAutoRetargetSolution) {
                        Write-BuildLog -Message '[MSBuild] Detected Windows SDK 10.0.17763.0 missing (MSB8036).' -Level 'ERROR'
                        Write-BuildLog -Message '[MSBuild] Install a compatible Windows 10/11 SDK or enable automatic version selection (EnableAutoRetargetSolution=true) in Build/config/build-settings.json to let the build use a newer installed SDK if available.' -Level 'ERROR'
                        throw
                    }

                    if ($retargetAttempted) {
                        Write-BuildLog -Message '[MSBuild] MSB8036 persists even after attempting automatic SDK/version selection. Please verify that a suitable Windows SDK is installed or update the project settings manually.' -Level 'ERROR'
                        throw
                    }

                    $retargetAttempted = $true

                    Write-BuildLog -Message ('[MSBuild] Detected MSB8036 for {0}; attempting to retry with an auto-detected Windows SDK/toolset.' -f $resolvedSolution) -Level 'WARN'

                    # Append SDK/toolset/VS hint properties if not already present, using discovery helpers.
                    if (-not ($args -match 'WindowsTargetPlatformVersion=')) {
                        $sdkVersion = $null
                        try {
                            $sdkVersion = Get-LatestWindowsSdkVersion
                        }
                        catch {
                            $sdkVersion = $null
                        }

                        if ($sdkVersion) {
                            $args += ('-p:WindowsTargetPlatformVersion={0}' -f $sdkVersion)
                        }
                        else {
                            Write-BuildLog -Message '[MSBuild] No suitable Windows SDK version could be discovered; continuing without overriding WindowsTargetPlatformVersion.' -Level 'WARN'
                        }
                    }

                    # TODO: If we ever need to auto-select an MSVC
                    #       PlatformToolset or VisualStudioVersion
                    #       again, reintroduce logic here to call
                    #       Get-DefaultPlatformToolset / Get-LatestVisualStudioVersion.

                    Write-BuildLog -Message '[MSBuild] Added discovered properties for WindowsTargetPlatformVersion where available. Retrying MSBuild once.' -Level 'INFO'
                }
            }
        }
    }

    Write-BuildLog -Message ('[MSBuild] {0} completed.' -f $DisplayName) -Level 'SUCCESS'
}

function Invoke-MSBuildSolutionsInParallel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$Solutions,
        [Parameter(Mandatory)][string]$MSBuildPath,
        [switch]$EnableAutoRetargetSolution,
        [switch]$Rebuild,
        [int]$MaxParallelJobs = 0
    )

    if ($Solutions.Count -eq 0) {
        return
    }

    # Build array of tasks to execute in parallel
    $tasks = @()
    
    foreach ($solution in $Solutions) {
        $solutionPath = $solution.SolutionPath
        $displayName = $solution.DisplayName
        $configurations = $solution.Configurations
        $targets = $solution.Targets
        $globalProps = $solution.GlobalProperties
        $additionalArgs = $solution.AdditionalArguments
        
        # Serialize complex objects to XML for safe transmission
        $configsXml = [System.Management.Automation.PSSerializer]::Serialize($configurations)
        $targetsXml = [System.Management.Automation.PSSerializer]::Serialize($targets)
        $globalPropsXml = [System.Management.Automation.PSSerializer]::Serialize($globalProps)
        $addArgsXml = [System.Management.Automation.PSSerializer]::Serialize($additionalArgs)
        
        # Create scriptblock for this solution
        $taskScript = [scriptblock]::Create(@"
param(`$SolPath, `$MSBPath, `$DispName, `$ConfigsXml, `$TargsXml, `$GPropsXml, `$AddArgsXml, `$AutoRetarget, `$DoRebuild, `$ScriptRoot)

# Import required modules in the job context
Import-Module (Join-Path -Path `$ScriptRoot -ChildPath 'Logging.psm1') -Force
Import-Module (Join-Path -Path `$ScriptRoot -ChildPath 'Toolchain.psm1') -Force
Import-Module (Join-Path -Path `$ScriptRoot -ChildPath 'Builder.psm1') -Force

# Deserialize objects
`$Configs = [System.Management.Automation.PSSerializer]::Deserialize(`$ConfigsXml)
`$Targs = [System.Management.Automation.PSSerializer]::Deserialize(`$TargsXml)
`$GProps = [System.Management.Automation.PSSerializer]::Deserialize(`$GPropsXml)
`$AddArgs = [System.Management.Automation.PSSerializer]::Deserialize(`$AddArgsXml)

Invoke-MSBuildSolution -SolutionPath `$SolPath -MSBuildPath `$MSBPath ``
    -DisplayName `$DispName -Configurations `$Configs -Targets `$Targs ``
    -GlobalProperties `$GProps -AdditionalArguments `$AddArgs ``
    -EnableAutoRetargetSolution:`$AutoRetarget -Rebuild:`$DoRebuild
"@)
        
        $tasks += @{
            Script = $taskScript
            Description = "MSBuild: $displayName"
            Arguments = @($solutionPath, $MSBuildPath, $displayName, $configsXml, $targetsXml, $globalPropsXml, $addArgsXml, $EnableAutoRetargetSolution.IsPresent, $Rebuild.IsPresent, $PSScriptRoot)
        }
    }

    Write-BuildLog -Message "Building $($tasks.Count) Visual Studio solutions in parallel..." -Level 'INFO'
    
    # Import ParallelBuilder module and execute
    $scriptRoot = $PSScriptRoot
    Import-Module (Join-Path -Path $scriptRoot -ChildPath 'ParallelBuilder.psm1') -Force
    
    Invoke-BuildTasksInParallel -Tasks $tasks -MaxParallelJobs $MaxParallelJobs
}

Export-ModuleMember -Function Invoke-BuildCommand, Invoke-LazarusProjectBuild, Invoke-MSBuildSolution, Invoke-LazarusProjectsInParallel, Invoke-MSBuildSolutionsInParallel
