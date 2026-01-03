#requires -Version 5.1
Set-StrictMode -Version Latest

function Get-SolutionConfigurationMatrix {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SolutionPath
    )

    $resolvedPath = Resolve-Path -LiteralPath $SolutionPath -ErrorAction Stop
    $sectionStartPattern = '^\s*GlobalSection\(SolutionConfigurationPlatforms\)\s*=\s*preSolution\s*$'
    $sectionEndPattern = '^\s*EndGlobalSection'
    $entries = [ordered]@{}
    $inSection = $false

    foreach ($line in Get-Content -LiteralPath $resolvedPath) {
        if (-not $inSection) {
            if ($line -match $sectionStartPattern) {
                $inSection = $true
            }
            continue
        }

        if ($line -match $sectionEndPattern) {
            break
        }

        $trimmed = $line.Trim()
        if (-not $trimmed) {
            continue
        }

        $parts = $trimmed -split '=', 2
        if ($parts.Count -lt 1) {
            continue
        }

        $left = $parts[0].Trim()
        if (-not $left) {
            continue
        }

        $pair = $left -split '\|', 2
        if ($pair.Count -ne 2) {
            continue
        }

        $configuration = $pair[0].Trim()
        $platform = $pair[1].Trim()
        if (-not $configuration -or -not $platform) {
            continue
        }

        $target = ('{0}|{1}' -f $configuration, $platform)
        if (-not $entries.Contains($target)) {
            $entries[$target] = [pscustomobject]@{
                Target = $target
                Configuration = $configuration
                Platform = $platform
            }
        }
    }

    if (-not $inSection) {
        throw "SolutionConfigurationPlatforms section not found in $resolvedPath"
    }

    return @($entries.Values)
}

function Update-BuildSettingsSolutionConfigurations {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$BuildSettingsPath,
        [string]$RepoRoot
    )

    $resolvedSettings = Resolve-Path -LiteralPath $BuildSettingsPath -ErrorAction Stop

    if ($RepoRoot) {
        $resolvedRoot = Resolve-Path -LiteralPath $RepoRoot -ErrorAction Stop
    }
    else {
        $configDir = Split-Path -Parent $resolvedSettings
        $buildDir = Split-Path -Parent $configDir
        $resolvedRoot = Split-Path -Parent $buildDir
    }

    $configObject = Get-Content -LiteralPath $resolvedSettings -Raw | ConvertFrom-Json
    if (-not $configObject.Solutions) {
        Write-Verbose 'No solutions defined in build settings.'
        return
    }

    $changes = $false
    foreach ($solution in @($configObject.Solutions)) {
        $solutionPath = $solution.SolutionPath
        if (-not $solutionPath) {
            continue
        }

        if ([System.IO.Path]::IsPathRooted($solutionPath)) {
            $resolvedSolutionPath = $solutionPath
        }
        else {
            $resolvedSolutionPath = Join-Path -Path $resolvedRoot -ChildPath $solutionPath
        }

        if (-not (Test-Path -LiteralPath $resolvedSolutionPath)) {
            Write-Warning ("Solution file not found: {0}" -f $resolvedSolutionPath)
            continue
        }

        try {
            $entries = Get-SolutionConfigurationMatrix -SolutionPath $resolvedSolutionPath
        }
        catch {
            Write-Warning ("Failed to read configurations from {0}: {1}" -f $resolvedSolutionPath, $_.Exception.Message)
            continue
        }

        if (-not $entries -or $entries.Count -eq 0) {
            Write-Verbose ("No configuration entries detected for {0}" -f $solution.Name)
            continue
        }

        $solution.Configurations = @()
        foreach ($entry in $entries) {
            $solution.Configurations += [pscustomobject]@{
                Target = $entry.Target
                Configuration = $entry.Configuration
                Platform = $entry.Platform
            }
        }

        $changes = $true
        Write-Verbose ("Updated configurations for {0}" -f $solution.Name)
    }

    if (-not $changes) {
        Write-Verbose 'No updates were applied to build settings.'
        return
    }

    $json = $configObject | ConvertTo-Json -Depth 10
    Set-Content -LiteralPath $resolvedSettings -Value $json -Encoding UTF8
}

Export-ModuleMember -Function Get-SolutionConfigurationMatrix, Update-BuildSettingsSolutionConfigurations
