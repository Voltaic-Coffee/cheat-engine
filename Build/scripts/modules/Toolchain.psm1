#requires -Version 5.1
Set-StrictMode -Version Latest

function Resolve-ExistingPath {
    param(
        [string]$Candidate
    )

    if (-not $Candidate) {
        return $null
    }

    if (Test-Path -LiteralPath $Candidate) {
        return (Resolve-Path -LiteralPath $Candidate).Path
    }

    return $null
}

function Update-ToolchainSetting {
    param(
        [string]$ConfigPath,
        [string]$PropertyName,
        [string]$Value
    )

    if (-not $ConfigPath -or -not (Test-Path -LiteralPath $ConfigPath) -or -not $PropertyName -or -not $Value) {
        return
    }

    try {
        $config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
    }
    catch {
        Write-Verbose ('Failed to load config for updating {0}: {1}' -f $PropertyName, $_.Exception.Message)
        return
    }

    if (-not $config.Toolchain) {
        $config | Add-Member -MemberType NoteProperty -Name 'Toolchain' -Value (New-Object PSObject) -Force
    }

    $current = $config.Toolchain | Select-Object -ExpandProperty $PropertyName -ErrorAction SilentlyContinue
    if ($current -eq $Value) {
        return
    }

    $config.Toolchain | Add-Member -MemberType NoteProperty -Name $PropertyName -Value $Value -Force
    $config | ConvertTo-Json -Depth 64 | Set-Content -LiteralPath $ConfigPath -Encoding UTF8
}

function Find-LazBuildExecutable {
    $candidates = @()

    if ($env:LAZARUSDIR) {
        $candidates += (Join-Path -Path $env:LAZARUSDIR -ChildPath 'lazbuild.exe')
    }

    $defaultRoots = @('C:/lazarus')
    if ($env:SystemDrive) {
        $defaultRoots += (Join-Path -Path $env:SystemDrive -ChildPath 'lazarus')
    }

    foreach ($root in $defaultRoots) {
        if ($root) {
            $candidates += (Join-Path -Path $root -ChildPath 'lazbuild.exe')
        }
    }

    if ($env:ProgramFiles) {
        $candidates += (Join-Path -Path $env:ProgramFiles -ChildPath 'Lazarus/lazbuild.exe')
    }

    if (${env:ProgramFiles(x86)}) {
        $candidates += (Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath 'Lazarus/lazbuild.exe')
    }

    foreach ($candidate in ($candidates | Where-Object { $_ } | Select-Object -Unique)) {
        $resolved = Resolve-ExistingPath -Candidate $candidate
        if ($resolved) {
            return $resolved
        }
    }

    return $null
}

function Get-LazBuildPath {
    [CmdletBinding()]
    param(
        [string]$PreferredPath,
        [string]$ConfigPath
    )

    $resolved = Resolve-ExistingPath -Candidate $PreferredPath
    if ($resolved) {
        return $resolved
    }

    $command = Get-Command -Name lazbuild -ErrorAction SilentlyContinue
    if ($command) {
        if (-not [string]::IsNullOrWhiteSpace($ConfigPath) -and [string]::IsNullOrWhiteSpace($PreferredPath)) {
            Update-ToolchainSetting -ConfigPath $ConfigPath -PropertyName 'LazBuildPath' -Value $command.Path
        }
        return $command.Path
    }

    if ([string]::IsNullOrWhiteSpace($PreferredPath)) {
        $autoDetected = Find-LazBuildExecutable
        if ($autoDetected) {
            if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
                Update-ToolchainSetting -ConfigPath $ConfigPath -PropertyName 'LazBuildPath' -Value $autoDetected
            }
            return $autoDetected
        }
    }

    throw 'lazbuild.exe was not found. Please install Lazarus and ensure lazbuild is on PATH or specify the full path in the configuration file.'
}

function Get-MSBuildPath {
    [CmdletBinding()]
    param(
        [string]$PreferredPath,
        [string]$ConfigPath
    )

    $resolved = Resolve-ExistingPath -Candidate $PreferredPath
    if ($resolved) {
        return $resolved
    }

    $command = Get-Command -Name msbuild.exe -ErrorAction SilentlyContinue
    if ($command) {
        if (-not [string]::IsNullOrWhiteSpace($ConfigPath) -and [string]::IsNullOrWhiteSpace($PreferredPath)) {
            Update-ToolchainSetting -ConfigPath $ConfigPath -PropertyName 'MSBuildPath' -Value $command.Path
        }
        return $command.Path
    }

    $vswhere = $null
    if (${env:ProgramFiles(x86)}) {
        $vswhere = Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath 'Microsoft Visual Studio/Installer/vswhere.exe'
    }
    if ($vswhere -and (Test-Path -LiteralPath $vswhere)) {
        $path = & $vswhere -latest -requires Microsoft.Component.MSBuild -find 'MSBuild\\**\\Bin\\MSBuild.exe' | Select-Object -First 1
        if ($path) {
            $found = Resolve-ExistingPath -Candidate $path
            if ($found) {
                if (-not [string]::IsNullOrWhiteSpace($ConfigPath) -and [string]::IsNullOrWhiteSpace($PreferredPath)) {
                    Update-ToolchainSetting -ConfigPath $ConfigPath -PropertyName 'MSBuildPath' -Value $found
                }
                return $found
            }
        }
    }

    throw 'MSBuild.exe was not found. Install Visual Studio Build Tools or specify the msbuild path in the configuration file.'
}

function Get-VSInstallations {
    [CmdletBinding()]
    param()

    $results = @()

    if (-not ${env:ProgramFiles(x86)}) {
        return $results
    }

    $vswhere = Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath 'Microsoft Visual Studio/Installer/vswhere.exe'
    if (-not (Test-Path -LiteralPath $vswhere)) {
        return $results
    }

    Write-BuildLog -Message ('[Toolchain] Using vswhere at: {0}' -f $vswhere) -Level 'DEBUG'
    $raw = & $vswhere -all -requires Microsoft.Component.MSBuild -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -format json 2>$null
    if (-not $raw) {
        return $results
    }

    try {
        $data = $raw | ConvertFrom-Json
    }
    catch {
        Write-BuildLog -Message ('[Toolchain] Failed to parse vswhere output: {0}' -f $_.Exception.Message) -Level 'DEBUG'
        return $results
    }

    foreach ($item in @($data)) {
        $results += [PSCustomObject]@{
            InstallationPath = $item.installationPath
            DisplayName      = $item.displayName
            CatalogProductLineVersion = $item.catalog.productLineVersion
            CatalogProductDisplayVersion = $item.catalog.productDisplayVersion
        }
    }

    Write-BuildLog -Message ('[Toolchain] Discovered {0} Visual Studio installation(s) with MSBuild + VC tools.' -f @($results).Count) -Level 'DEBUG'
    return $results
}

function Get-LatestVisualStudioVersion {
    [CmdletBinding()]
    param(
        [Version]$MinimumVersion = [Version]'14.0.0.0'
    )

    # TODO: Re-enable Visual Studio detection when we need
    #       MSVC/Platform Toolset selection again.
    #
    # NOTE: This function is kept for future use but is
    #       currently unused by the build pipeline.

    $installations = Get-VSInstallations
    if (-not $installations -or @($installations).Count -eq 0) {
        Write-BuildLog -Message '[Toolchain] Get-LatestVisualStudioVersion: no suitable installations found.' -Level 'DEBUG'
        return $null
    }

    $candidates = @()
    foreach ($inst in $installations) {
        # Prefer a real semantic version, but fall back to major version mapping
        $vText = $null

        # VS 2017+ exposes catalog.productLineVersion (e.g. "17.11") – preferred.
        if ($inst.CatalogProductLineVersion) {
            $vText = $inst.CatalogProductLineVersion
        }
        elseif ($inst.DisplayName -match '\b(20\d{2})\b') {
            # Rough mapping based on marketing year used in DisplayName.
            # 2015 -> 14.x, 2017 -> 15.x, 2019 -> 16.x, 2022 -> 17.x
            switch ($Matches[1]) {
                '2015' { $vText = '14.0' }
                '2017' { $vText = '15.0' }
                '2019' { $vText = '16.0' }
                '2022' { $vText = '17.0' }
            }
        }

        if (-not $vText) { continue }
        try {
            $v = [Version]$vText
        }
        catch {
            continue
        }

        if ($v -ge $MinimumVersion) {
            $candidates += [PSCustomObject]@{
                Version          = $v
                VersionText      = $vText
                InstallationPath = $inst.InstallationPath
                DisplayName      = $inst.DisplayName
            }
        }
    }

    if (@($candidates).Count -eq 0) {
        Write-BuildLog -Message ('[Toolchain] Get-LatestVisualStudioVersion: no installations met minimum version {0}.' -f $MinimumVersion) -Level 'DEBUG'
        return $null
    }

    $selected = $candidates | Sort-Object -Property Version -Descending | Select-Object -First 1
    Write-BuildLog -Message ('[Toolchain] Selected Visual Studio: {0} (Version {1})' -f $selected.DisplayName, $selected.VersionText) -Level 'DEBUG'
    return $selected
}

function Get-InstalledWindowsSdkVersions {
    [CmdletBinding()]
    param()

    $versions = @()

    # Prefer environment variable if defined (common with newer SDKs)
    if ($env:WindowsSDKVersion) {
        $sdk = $env:WindowsSDKVersion.TrimEnd('\\')
        if ($sdk) {
            Write-BuildLog -Message ('[Toolchain] WindowsSDKVersion from environment: {0}' -f $sdk) -Level 'DEBUG'
            $versions += $sdk
        }
    }

    $possibleRoots = @()
    if ($env:ProgramFiles) {
        $possibleRoots += Join-Path -Path $env:ProgramFiles -ChildPath 'Windows Kits/10/Include'
    }
    if (${env:ProgramFiles(x86)}) {
        $possibleRoots += Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath 'Windows Kits/10/Include'
    }

    foreach ($root in ($possibleRoots | Where-Object { $_ } | Select-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $root)) {
            continue
        }

        Write-BuildLog -Message ('[Toolchain] Scanning Windows SDK include root: {0}' -f $root) -Level 'DEBUG'

        Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.Name -match '^(10\.0\.\d+\.\d+)$') {
                $versions += $_.Name
            }
        }
    }

    $unique = $versions | Where-Object { $_ } | Select-Object -Unique
    Write-BuildLog -Message ('[Toolchain] Detected Windows SDK versions: {0}' -f ($unique -join ', ')) -Level 'DEBUG'
    return $unique
}

function Get-LatestWindowsSdkVersion {
    [CmdletBinding()]
    param(
        [Version]$MinimumVersion = [Version]'10.0.0.0'
    )

    $versions = Get-InstalledWindowsSdkVersions
    if (-not $versions -or @($versions).Count -eq 0) {
        Write-BuildLog -Message '[Toolchain] Get-LatestWindowsSdkVersion: no SDK versions found.' -Level 'DEBUG'
        return $null
    }

    $candidates = @()
    foreach ($vText in $versions) {
        try {
            $v = [Version]$vText
        }
        catch {
            continue
        }

        if ($v -ge $MinimumVersion) {
            $candidates += [PSCustomObject]@{ Version = $v; VersionText = $vText }
        }
    }

    if (@($candidates).Count -eq 0) {
        Write-BuildLog -Message ('[Toolchain] Get-LatestWindowsSdkVersion: no SDK met minimum version {0}.' -f $MinimumVersion) -Level 'DEBUG'
        return $null
    }

    $selected = $candidates | Sort-Object -Property Version -Descending | Select-Object -First 1
    Write-BuildLog -Message ('[Toolchain] Selected Windows SDK version: {0}' -f $selected.VersionText) -Level 'DEBUG'
    return $selected.VersionText
}

function Get-DefaultPlatformToolset {
    [CmdletBinding()]
    param()

    # TODO: Re-enable default PlatformToolset inference when
    #       MSVC/Visual Studio detection is required again.
    #
    # NOTE: This function is kept for future use but is
    #       currently unused by the build pipeline.

    # If MSVC toolset is available under an installed VS instance, infer from directory names.
    $install = Get-LatestVisualStudioVersion -MinimumVersion ([Version]'14.0.0.0')
    if (-not $install -or -not $install.InstallationPath) {
        return $null
    }

    $vcToolsRoot = Join-Path -Path $install.InstallationPath -ChildPath 'VC/Tools/MSVC'
    if (-not (Test-Path -LiteralPath $vcToolsRoot)) {
        return $null
    }

    $toolVersions = Get-ChildItem -LiteralPath $vcToolsRoot -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
    if (-not $toolVersions -or @($toolVersions).Count -eq 0) {
        return $null
    }

    # Pick the newest MSVC tools folder and map to a reasonable PlatformToolset name.
    $selected = $toolVersions | Sort-Object -Descending | Select-Object -First 1

    # Approximate mapping based on VS major version inferred from latest installation.
    $vsVersion = $install.Version
    if ($vsVersion -and $vsVersion.Major -ge 17) { return 'v143' }
    if ($vsVersion -and $vsVersion.Major -eq 16) { return 'v142' }
    if ($vsVersion -and $vsVersion.Major -eq 15) { return 'v141' }

    # As a last resort, assume a modern toolset when MSVC is present at all.
    if ($vsVersion -and $vsVersion.Major -ge 14) {
        return 'v141'
    }

    return $null
}

function Assert-ToolAvailability {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ToolPath,
        [Parameter(Mandatory)][string]$ToolName
    )

    if (-not (Test-Path -LiteralPath $ToolPath)) {
        throw ('{0} was not found at {1}' -f $ToolName, $ToolPath)
    }
}

Export-ModuleMember -Function Get-LazBuildPath, Get-MSBuildPath, Assert-ToolAvailability, Get-LatestWindowsSdkVersion, Get-LatestVisualStudioVersion, Get-DefaultPlatformToolset
