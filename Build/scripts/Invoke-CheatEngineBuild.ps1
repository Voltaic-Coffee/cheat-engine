#requires -Version 5.1
<#
.SYNOPSIS
    Builds Cheat Engine projects using Lazarus and Visual Studio.

.DESCRIPTION
    This script orchestrates the build process for Cheat Engine, including Lazarus projects 
    and Visual Studio solutions. It supports parallel builds to maximize CPU utilization
    and minimize build times.

.PARAMETER Target
    Specifies which build targets to execute: All, Lazarus, or VisualStudio.
    Default: All

.PARAMETER ConfigPath
    Path to the build configuration JSON file.
    Default: Build/config/build-settings.json

.PARAMETER SkipFileLogging
    Disables file logging for this build session.

.PARAMETER VerboseLogging
    Enables verbose logging output for detailed diagnostics.

.PARAMETER LazarusProject
    Specifies which Lazarus projects to build. Options: All, CheatEngineUI, Speedhack, 
    LuaClient, VEHDebug.
    Default: All

.PARAMETER Solution
    Specifies which Visual Studio solutions to build. Options: All, DirectXMess, 
    DotNetCompiler, MonoDataCollector, DotNetDataCollector, DotNetInvasiveDataCollector,
    CEJVMTI, TCCLib.
    Default: All

.PARAMETER Rebuild
    Forces a full rebuild of all projects instead of incremental builds.

.PARAMETER MaxParallelJobs
    Maximum number of concurrent build jobs. Set to 0 for automatic CPU detection (default),
    1 to disable parallelization, or a specific number to limit concurrent builds.
    Default: 0 (auto-detect: CPU cores - 1)

.EXAMPLE
    Build\scripts\Invoke-CheatEngineBuild.ps1
    Builds all projects using parallel builds with auto-detected CPU count.

.EXAMPLE
    Build\scripts\Invoke-CheatEngineBuild.ps1 -Rebuild -MaxParallelJobs 4
    Performs a full rebuild with maximum 4 concurrent jobs.

.EXAMPLE
    Build\scripts\Invoke-CheatEngineBuild.ps1 -Target Lazarus -MaxParallelJobs 1
    Builds only Lazarus projects sequentially (parallelization disabled).

.EXAMPLE
    Build\scripts\Invoke-CheatEngineBuild.ps1 -Solution MonoDataCollector,DotNetDataCollector
    Builds only the specified Visual Studio solutions in parallel.

.NOTES
    For more information about parallel builds, see Build/docs/PARALLEL_BUILD.md
#>
[CmdletBinding()]
param(
    [ValidateSet('All','Lazarus','VisualStudio')]
    [string]$Target = 'All',
    [string]$ConfigPath,
    [switch]$SkipFileLogging,
    [switch]$VerboseLogging,

    # Optional fine-grained selection within Lazarus/VisualStudio targets.
    # Values are PascalCase identifiers derived from the Names in
    # Build/config/build-settings.json, but without spaces.
    [ValidateSet('All','CheatEngineUI','Speedhack','LuaClient','VEHDebug')]
    [string[]]$LazarusProject = 'All',

    [ValidateSet('All','DirectXMess','DotNetCompiler','MonoDataCollector','DotNetDataCollector','DotNetInvasiveDataCollector','CEJVMTI','TCCLib')]
    [string[]]$Solution = 'All',

    # When specified, force a rebuild instead of an incremental build
    [switch]$Rebuild,

    # Maximum number of parallel build jobs (0 = auto-detect based on CPU count)
    [int]$MaxParallelJobs = 0
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$buildRoot = Split-Path -Parent $scriptRoot
$repoRoot = Split-Path -Parent $buildRoot

$defaultConfigPath = Join-Path -Path (Join-Path -Path $buildRoot -ChildPath 'config') -ChildPath 'build-settings.json'
if (-not $ConfigPath) {
    $ConfigPath = $defaultConfigPath
} elseif (-not [System.IO.Path]::IsPathRooted($ConfigPath)) {
    $ConfigPath = Join-Path -Path $repoRoot -ChildPath $ConfigPath
}

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "Configuration file not found at $ConfigPath"
}

Import-Module (Join-Path -Path $scriptRoot -ChildPath 'modules/Logging.psm1') -Force
Import-Module (Join-Path -Path $scriptRoot -ChildPath 'modules/Toolchain.psm1') -Force
Import-Module (Join-Path -Path $scriptRoot -ChildPath 'modules/Builder.psm1') -Force

function Resolve-RepoPath {
    param([string]$RelativePath)

    if (-not $RelativePath) {
        return $null
    }

    if ([System.IO.Path]::IsPathRooted($RelativePath)) {
        return $RelativePath
    }

    return Join-Path -Path $repoRoot -ChildPath $RelativePath
}

function Should-Build {
    param([string]$Component)

    if ($Target -eq 'All') { return $true }
    return $Target -eq $Component
}

function Should-BuildNamedItem {
    param(
        [string[]]$Selection,
        [string]$ItemName
    )

    if (-not $Selection -or $Selection -contains 'All') {
        return $true
    }

    # Normalize names by removing spaces and converting to lowercase for comparison
    $normalizedItemName = $ItemName -replace '\s+', '' -replace '[^\w]', ''
    foreach ($selectedItem in $Selection) {
        $normalizedSelection = $selectedItem -replace '\s+', '' -replace '[^\w]', ''
        if ($normalizedItemName -eq $normalizedSelection) {
            return $true
        }
    }

    return $false
}

function Convert-ConfigObjectToHashtable {
    param($Object)

    if (-not $Object) {
        return $null
    }

    if ($Object -is [hashtable]) {
        return $Object
    }

    $table = @{}
    foreach ($prop in $Object.PSObject.Properties) {
        $table[$prop.Name] = $prop.Value
    }

    return $table
}

function Get-ConfigPropertyValue {
    param($Object, [string]$PropertyName)

    if ($null -eq $Object) {
        return $null
    }

    if ($Object -is [hashtable]) {
        if ($Object.ContainsKey($PropertyName)) {
            return $Object[$PropertyName]
        }
        return $null
    }

    $prop = $Object.PSObject.Properties[$PropertyName]
    if ($prop) {
        return $prop.Value
    }

    return $null
}

function Get-VSConfigurationTargetId {
    param($Configuration)

    if (-not $Configuration) {
        return $null
    }

    $targetId = Get-ConfigPropertyValue $Configuration 'Target'
    if ($targetId) {
        return $targetId
    }

    $cfgName = Get-ConfigPropertyValue $Configuration 'Configuration'
    $platform = Get-ConfigPropertyValue $Configuration 'Platform'

    if ($cfgName -and $platform) {
        return ('{0}|{1}' -f $cfgName, $platform)
    }

    return $null
}

function Invoke-LazarusBuilds {
    param(
        $Projects,
        [string]$LazBuildPath,
        [string[]]$SelectedProjects,
        [switch]$Rebuild,
        [int]$MaxParallelJobs = 0
    )

    if (-not $Projects) {
        Write-BuildLog -Message 'No Lazarus projects defined in configuration.' -Level 'WARN'
        return
    }

    # Collect projects to build
    $projectsToBuild = @()

    foreach ($project in @($Projects)) {
        $projectData = Convert-ConfigObjectToHashtable $project
        $projectName = Get-ConfigPropertyValue $projectData 'Name'
        $isEnabled = Get-ConfigPropertyValue $projectData 'Enabled'

        if ($isEnabled -eq $false) {
            Write-BuildLog -Message ("[Lazarus] Skipping disabled project {0}" -f $projectName) -Level 'DEBUG'
            continue
        }

        if (-not (Should-BuildNamedItem -Selection $SelectedProjects -ItemName $projectName)) {
            Write-BuildLog -Message ("[Lazarus] Skipping non-selected project {0}" -f $projectName) -Level 'DEBUG'
            continue
        }

        $projectPathValue = Get-ConfigPropertyValue $projectData 'ProjectPath'
        $projectPath = Resolve-RepoPath $projectPathValue
        if (-not (Test-Path -LiteralPath $projectPath)) {
            throw ("Lazarus project not found: {0}" -f $projectPath)
        }

        $targetsConfig = Get-ConfigPropertyValue $projectData 'Targets'
        $targets = if ($targetsConfig) { @($targetsConfig) } else { @() }
        $defaultTargetsConfig = Get-ConfigPropertyValue $projectData 'DefaultTargets'
        $defaultNames = if ($defaultTargetsConfig) { @($defaultTargetsConfig) } else { @() }

        $defaultNamesCount = @($defaultNames).Count
        $targetsCount = @($targets).Count

        if ($defaultNamesCount -gt 0 -and $targetsCount -gt 0) {
            $filteredTargets = @()
            foreach ($target in $targets) {
                $targetName = Get-ConfigPropertyValue $target 'Name'
                if (-not $targetName -or $defaultNames -contains $targetName) {
                    $filteredTargets += $target
                }
            }

            if (@($filteredTargets).Count -gt 0) {
                $targets = $filteredTargets
            }
            else {
                Write-BuildLog -Message ('[Lazarus] No targets matched DefaultTargets for {0}. Using all targets.' -f $projectName) -Level 'WARN'
            }
        }

        $additionalArgsConfig = Get-ConfigPropertyValue $projectData 'AdditionalArguments'
        $additional = if ($additionalArgsConfig) { @($additionalArgsConfig) } else { @() }

        $projectsToBuild += [PSCustomObject]@{
            ProjectPath = $projectPath
            DisplayName = $projectName
            Targets = $targets
            AdditionalArguments = $additional
        }
    }

    if ($projectsToBuild.Count -eq 0) {
        Write-BuildLog -Message 'No Lazarus projects selected for build.' -Level 'INFO'
        return
    }

    # Build Lazarus projects sequentially to avoid file locking issues
    # with shared Lazarus packages (like lazutils, lcl, etc.)
    Write-BuildLog -Message "Building $($projectsToBuild.Count) Lazarus projects sequentially..." -Level 'INFO'
    foreach ($proj in $projectsToBuild) {
        Invoke-LazarusProjectBuild -ProjectPath $proj.ProjectPath -LazBuildPath $LazBuildPath -DisplayName $proj.DisplayName -Targets $proj.Targets -AdditionalArguments $proj.AdditionalArguments -Rebuild:$Rebuild
    }
}

function Invoke-VSBuilds {
    param(
        $Solutions,
        [string]$MSBuildPath,
        [switch]$EnableAutoRetargetSolution,
        [string[]]$SelectedSolutions,
        [switch]$Rebuild,
        [int]$MaxParallelJobs = 0
    )

    if (-not $Solutions) {
        Write-BuildLog -Message 'No Visual Studio solutions defined in configuration.' -Level 'WARN'
        return
    }

    # Collect solutions to build
    $solutionsToBuild = @()

    foreach ($solution in @($Solutions)) {
        $solutionData = Convert-ConfigObjectToHashtable $solution
        $solutionName = Get-ConfigPropertyValue $solutionData 'Name'
        $isEnabled = Get-ConfigPropertyValue $solutionData 'Enabled'

        if ($isEnabled -eq $false) {
            Write-BuildLog -Message ("[MSBuild] Skipping disabled solution {0}" -f $solutionName) -Level 'DEBUG'
            continue
        }

        if (-not (Should-BuildNamedItem -Selection $SelectedSolutions -ItemName $solutionName)) {
            Write-BuildLog -Message ("[MSBuild] Skipping non-selected solution {0}" -f $solutionName) -Level 'DEBUG'
            continue
        }

        $solutionPathValue = Get-ConfigPropertyValue $solutionData 'SolutionPath'
        $solutionPath = Resolve-RepoPath $solutionPathValue
        if (-not (Test-Path -LiteralPath $solutionPath)) {
            throw ("Solution not found: {0}" -f $solutionPath)
        }

        $configurationsConfig = Get-ConfigPropertyValue $solutionData 'Configurations'
        $configurations = if ($configurationsConfig) { @($configurationsConfig) } else { @() }
        $defaultTargetsConfig = Get-ConfigPropertyValue $solutionData 'DefaultTargets'
        $defaultTargets = if ($defaultTargetsConfig) { @($defaultTargetsConfig) } else { @() }

        $defaultTargetsCount = @($defaultTargets).Count
        $configurationsCount = @($configurations).Count

        if ($defaultTargetsCount -gt 0 -and $configurationsCount -gt 0) {
            $filteredConfigurations = @()
            foreach ($configuration in $configurations) {
                $targetId = Get-VSConfigurationTargetId $configuration
                if (-not $targetId -or $defaultTargets -contains $targetId) {
                    $filteredConfigurations += $configuration
                }
            }

            if (@($filteredConfigurations).Count -gt 0) {
                $configurations = $filteredConfigurations
            }
            else {
                Write-BuildLog -Message ('[MSBuild] No configurations matched DefaultTargets for {0}. Using all configurations.' -f $solutionName) -Level 'WARN'
            }
        }

        $targetsConfig = Get-ConfigPropertyValue $solutionData 'Targets'
        if ($targetsConfig) {
            $targets = @($targetsConfig)
        }
        else {
            if ($Rebuild) {
                $targets = @('Rebuild')
            }
            else {
                $targets = @('Build')
            }
        }
        $additionalArgsConfig = Get-ConfigPropertyValue $solutionData 'AdditionalArguments'
        $additional = if ($additionalArgsConfig) { @($additionalArgsConfig) } else { @() }
        $globalPropsConfig = Get-ConfigPropertyValue $solutionData 'GlobalProperties'
        $globalProps = if ($globalPropsConfig) { (Convert-ConfigObjectToHashtable $globalPropsConfig) } else { $null }

        $solutionsToBuild += [PSCustomObject]@{
            SolutionPath = $solutionPath
            DisplayName = $solutionName
            Configurations = $configurations
            Targets = $targets
            GlobalProperties = $globalProps
            AdditionalArguments = $additional
        }
    }

    if ($solutionsToBuild.Count -eq 0) {
        Write-BuildLog -Message 'No Visual Studio solutions selected for build.' -Level 'INFO'
        return
    }

    # Use parallel build for multiple solutions
    if ($solutionsToBuild.Count -gt 1) {
        Invoke-MSBuildSolutionsInParallel -Solutions $solutionsToBuild -MSBuildPath $MSBuildPath -EnableAutoRetargetSolution:$EnableAutoRetargetSolution -Rebuild:$Rebuild -MaxParallelJobs $MaxParallelJobs
    }
    else {
        # Single solution - build directly
        $sol = $solutionsToBuild[0]
        Invoke-MSBuildSolution -SolutionPath $sol.SolutionPath -MSBuildPath $MSBuildPath -DisplayName $sol.DisplayName -Configurations $sol.Configurations -Targets $sol.Targets -GlobalProperties $sol.GlobalProperties -AdditionalArguments $sol.AdditionalArguments -EnableAutoRetargetSolution:$EnableAutoRetargetSolution -Rebuild:$Rebuild
    }
}

try {
    $config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
    $loggingSection = $config.Logging
    $logDir = if ($loggingSection.Directory) { Resolve-RepoPath $loggingSection.Directory } else { Join-Path -Path $buildRoot -ChildPath 'logs' }

    $logSettingsPath = Join-Path -Path (Join-Path -Path $buildRoot -ChildPath 'config') -ChildPath 'log-settings.json'

    $disableFileLog = $SkipFileLogging
    if ($loggingSection.EnableFileLogging -eq $false) {
        $disableFileLog = $true
    }

    Start-BuildLog -LogDirectory $logDir -DisableFileLogging:$disableFileLog -LogSettingsPath $logSettingsPath -EnableVerbose:$VerboseLogging
    Write-BuildSection -Title 'Cheat Engine Build'
    Write-BuildLog -Message ('Target selection: {0}' -f $Target) -Level 'INFO'
    if ($VerboseLogging) {
        Write-BuildLog -Message 'Verbose logging enabled for this session.' -Level 'DEBUG'
    }

    # Determine max parallel jobs from config or parameter
    $maxJobs = $MaxParallelJobs
    if ($maxJobs -eq 0 -and $config.PSObject.Properties['Build'] -and $config.Build.PSObject.Properties['MaxParallelJobs']) {
        $maxJobs = $config.Build.MaxParallelJobs
    }

    if ($maxJobs -gt 0) {
        Write-BuildLog -Message "Parallel build enabled: maximum $maxJobs concurrent jobs" -Level 'INFO'
    }
    else {
        Write-BuildLog -Message 'Parallel build enabled: auto-detecting job count based on CPU cores' -Level 'INFO'
    }

    $lazBuildPath = $null
    $msBuildPath = $null
    $enableAutoRetarget = $false
    if ($config.Toolchain -and $config.Toolchain.EnableAutoRetargetSolution -eq $true) {
        $enableAutoRetarget = $true
    }

    # Determine if user specified a specific subset of projects/solutions
    $specificLazarusSelected = $LazarusProject -and ($LazarusProject -notcontains 'All')
    $specificSolutionSelected = $Solution -and ($Solution -notcontains 'All')

    # Skip Visual Studio if a specific Lazarus project was selected
    $shouldBuildLazarus = Should-Build 'Lazarus'
    $shouldBuildVisualStudio = (Should-Build 'VisualStudio') -and (-not $specificLazarusSelected)

    # Skip Lazarus if a specific Visual Studio solution was selected
    if ($specificSolutionSelected) {
        $shouldBuildLazarus = $false
        $shouldBuildVisualStudio = $true
    }

    if ($shouldBuildLazarus) {
        $lazBuildPath = Get-LazBuildPath -PreferredPath $config.Toolchain.LazBuildPath -ConfigPath $ConfigPath
        Assert-ToolAvailability -ToolPath $lazBuildPath -ToolName 'lazbuild'
        Invoke-LazarusBuilds -Projects $config.LazarusProjects -LazBuildPath $lazBuildPath -SelectedProjects $LazarusProject -Rebuild:$Rebuild -MaxParallelJobs $maxJobs
    }

    if ($shouldBuildVisualStudio) {
        $msBuildPath = Get-MSBuildPath -PreferredPath $config.Toolchain.MSBuildPath -ConfigPath $ConfigPath
        Assert-ToolAvailability -ToolPath $msBuildPath -ToolName 'MSBuild'

        Invoke-VSBuilds -Solutions $config.Solutions -MSBuildPath $msBuildPath -EnableAutoRetargetSolution:$enableAutoRetarget -SelectedSolutions $Solution -Rebuild:$Rebuild -MaxParallelJobs $maxJobs
    }

    Write-BuildLog -Message 'Cheat Engine build pipeline completed successfully.' -Level 'SUCCESS'
}
catch {
    Write-BuildLog -Message ("Build failed: {0}" -f $_.Exception.Message) -Level 'ERROR'
    throw
}
finally {
    Stop-BuildLog
}
