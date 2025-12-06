#requires -Version 5.1
Set-StrictMode -Version Latest

function Get-LazarusBuildModes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ProjectPath
    )

    $resolvedProject = Resolve-Path -LiteralPath $ProjectPath -ErrorAction Stop
    [xml]$projectXml = Get-Content -LiteralPath $resolvedProject -Raw

    $buildModesNode = $projectXml.CONFIG.ProjectOptions.BuildModes
    if (-not $buildModesNode) {
        throw "BuildModes section not found in $resolvedProject"
    }

    $result = @()
    foreach ($child in $buildModesNode.ChildNodes) {
        if ($child.NodeType -ne [System.Xml.XmlNodeType]::Element) {
            continue
        }

        $nameAttr = $child.Attributes['Name']
        if (-not $nameAttr -or -not $nameAttr.Value) {
            continue
        }

        $isDefault = $false
        $defaultAttr = $child.Attributes['Default']
        if ($defaultAttr -and $defaultAttr.Value -eq 'True') {
            $isDefault = $true
        }

        $result += [pscustomobject]@{
            Name = $nameAttr.Value
            IsDefault = $isDefault
        }
    }

    return $result
}

function Update-BuildSettingsLazarusProjects {
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
    if (-not $configObject.LazarusProjects) {
        Write-Verbose 'No Lazarus projects defined in build settings.'
        return
    }

    $changes = $false
    foreach ($project in @($configObject.LazarusProjects)) {
        $projectPath = $project.ProjectPath
        if (-not $projectPath) {
            continue
        }

        if ([System.IO.Path]::IsPathRooted($projectPath)) {
            $resolvedProjectPath = $projectPath
        }
        else {
            $resolvedProjectPath = Join-Path -Path $resolvedRoot -ChildPath $projectPath
        }

        if (-not (Test-Path -LiteralPath $resolvedProjectPath)) {
            Write-Warning ("Lazarus project file not found: {0}" -f $resolvedProjectPath)
            continue
        }

        try {
            $modes = Get-LazarusBuildModes -ProjectPath $resolvedProjectPath
        }
        catch {
            Write-Warning ("Failed to read build modes from {0}: {1}" -f $resolvedProjectPath, $_.Exception.Message)
            continue
        }

        if (-not $modes -or $modes.Count -eq 0) {
            Write-Verbose ("No build modes detected for {0}" -f $project.Name)
            continue
        }

        $project.Targets = @()
        foreach ($mode in $modes) {
            $project.Targets += [pscustomobject]@{
                Name = $mode.Name
                BuildMode = $mode.Name
            }
        }

        $defaultModes = @($modes | Where-Object { $_.IsDefault })
        if ($defaultModes.Count -gt 0) {
            $project.DefaultTargets = @($defaultModes | ForEach-Object { $_.Name })
        }
        elseif (-not $project.DefaultTargets -or $project.DefaultTargets.Count -eq 0) {
            $project.DefaultTargets = @($modes[0].Name)
        }

        $changes = $true
        Write-Verbose ("Updated build modes for {0}" -f $project.Name)
    }

    if (-not $changes) {
        Write-Verbose 'No updates were applied to Lazarus project targets.'
        return
    }

    $json = $configObject | ConvertTo-Json -Depth 10
    Set-Content -LiteralPath $resolvedSettings -Value $json -Encoding UTF8
}

Export-ModuleMember -Function Get-LazarusBuildModes, Update-BuildSettingsLazarusProjects
