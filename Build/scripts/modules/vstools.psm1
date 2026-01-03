#requires -Version 5.1
Set-StrictMode -Version Latest

function Get-VisualStudioEnvironment {
    <#
    .SYNOPSIS
    Detects all Visual Studio environment information in a single scan.

    .DESCRIPTION
    Queries vswhere once, scans registry for SDKs once, and inspects MSVC toolsets
    to return comprehensive environment information needed for building.

    .OUTPUTS
    PSCustomObject with VS path, version, toolset, MSVC version, SDKs, and MSBuild path.
    Returns $null if Visual Studio is not found.
    #>
    [CmdletBinding()]
    param()

    # Find vswhere.exe
    $vswhere = $null
    if (${env:ProgramFiles(x86)}) {
        $vswhere = Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath 'Microsoft Visual Studio/Installer/vswhere.exe'
    }

    if (-not $vswhere -or -not (Test-Path -LiteralPath $vswhere)) {
        Write-BuildLog -Message '[Toolchain] vswhere.exe not found' -Level 'ERROR'
        return $null
    }

    # Single vswhere call to get latest VS installation with build tools
    try {
        $raw = & $vswhere -latest `
                         -requires Microsoft.Component.MSBuild `
                         -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
                         -format json 2>$null

        if (-not $raw) {
            Write-BuildLog -Message '[Toolchain] No Visual Studio installation found with required components' -Level 'ERROR'
            return $null
        }

        $vsInfo = ($raw | ConvertFrom-Json)
    }
    catch {
        Write-BuildLog -Message "[Toolchain] Failed to query vswhere: $_" -Level 'ERROR'
        return $null
    }

    # Extract VS information
    $vsPath = $vsInfo.installationPath
    $vsDisplayName = $vsInfo.displayName

    # Determine VS version (prefer catalog.productLineVersion)
    $vsVersion = $vsInfo.catalog.productLineVersion
    if (-not $vsVersion -and $vsDisplayName -match '\b(20\d{2})\b') {
        # Fallback: map year to version
        $vsVersion = switch ($Matches[1]) {
            '2015' { '14.0' }
            '2017' { '15.0' }
            '2019' { '16.0' }
            '2022' { '17.0' }
            default { '17.0' }
        }
    }

    Write-BuildLog -Message "[Toolchain] Found: $vsDisplayName (Version $vsVersion)" -Level 'INFO'

    # Detect MSVC toolset version and platform toolset
    $vcToolsRoot = Join-Path -Path $vsPath -ChildPath 'VC/Tools/MSVC'
    $msvcVersion = $null
    $platformToolset = $null

    if (Test-Path -LiteralPath $vcToolsRoot) {
        # Get newest MSVC version directory (e.g., 14.39.33519)
        $msvcDirs = Get-ChildItem -LiteralPath $vcToolsRoot -Directory -ErrorAction SilentlyContinue |
                    Sort-Object -Property Name -Descending

        if ($msvcDirs) {
            $msvcVersion = $msvcDirs[0].Name

            # Map MSVC version to platform toolset
            # 14.4x → v143 (VS 2022 Latest), 14.3x → v143 (VS 2022)
            # 14.2x → v142 (VS 2019), 14.1x → v141 (VS 2017), 14.0x → v140 (VS 2015)
            $platformToolset = switch -Regex ($msvcVersion) {
                '^14.5'  { 'v145' }
                '^14\.4' { 'v143' }
                '^14\.3' { 'v143' }
                '^14\.2' { 'v142' }
                '^14\.1' { 'v141' }
                '^14\.0' { 'v140' }
                default { 'v145' }  # Default to latest
            }

            Write-BuildLog -Message "[Toolchain] MSVC $msvcVersion → Platform Toolset $platformToolset" -Level 'DEBUG'
        }
    }

    # Fallback: infer toolset from VS version if MSVC detection failed
    if (-not $platformToolset) {
        $platformToolset = if ($vsVersion -match '^17.5') { 'v145' }
                          elseif ($vsVersion -match '^17') { 'v143' }
                          elseif ($vsVersion -match '^16') { 'v142' }
                          elseif ($vsVersion -match '^15') { 'v141' }
                          else { 'v140' }
        Write-BuildLog -Message "[Toolchain] Using VS version fallback: $platformToolset" -Level 'DEBUG'
    }

    # Detect Windows SDKs from registry
    $sdks = @()
    $regPath = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows Kits\Installed Roots'
    if (-not (Test-Path $regPath)) {
        $regPath = 'HKLM:\SOFTWARE\Microsoft\Windows Kits\Installed Roots'
    }

    if (Test-Path $regPath) {
        # Windows 10/11 SDKs
        try {
            $root10 = Get-ItemPropertyValue -Path $regPath -Name 'KitsRoot10' -ErrorAction SilentlyContinue
            if ($root10) {
                $includeDir = Join-Path -Path $root10 -ChildPath 'Include'
                if (Test-Path -LiteralPath $includeDir) {
                    Get-ChildItem -LiteralPath $includeDir -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                        if ($_.Name -match '^10\.\d+\.\d+\.\d+$') {
                            $sdks += $_.Name
                        }
                    }
                }
            }
        }
        catch {
            Write-BuildLog -Message "[Toolchain] Failed to query Windows 10 SDK: $_" -Level 'DEBUG'
        }

        # Windows 8.1 SDK
        try {
            $root81 = Get-ItemPropertyValue -Path $regPath -Name 'KitsRoot81' -ErrorAction SilentlyContinue
            if ($root81 -and ($sdks -notcontains '8.1')) {
                $sdks += '8.1'
            }
        }
        catch {
            Write-BuildLog -Message "[Toolchain] Failed to query Windows 8.1 SDK: $_" -Level 'DEBUG'
        }
    }

    # Fallback: environment variable
    if ($env:WindowsSDKVersion) {
        $envSdk = $env:WindowsSDKVersion.TrimEnd('\')
        if ($envSdk -and ($sdks -notcontains $envSdk)) {
            $sdks += $envSdk
        }
    }

    # Sort SDKs and pick latest
    $sortedSdks = $sdks | Where-Object { $_ } |
                         Sort-Object -Descending -Property { [Version]($_ -replace '^8\.1$', '8.1.0.0') }

    $latestSdk = $sortedSdks | Select-Object -First 1

    if ($latestSdk) {
        Write-BuildLog -Message "[Toolchain] Windows SDKs: $($sortedSdks -join ', ') (using $latestSdk)" -Level 'DEBUG'
    }
    else {
        Write-BuildLog -Message '[Toolchain] WARNING: No Windows SDK detected' -Level 'WARN'
    }

    # Find MSBuild.exe
    $msBuildPath = $null
    $msBuildCandidates = @(
        (Join-Path -Path $vsPath -ChildPath 'MSBuild\Current\Bin\MSBuild.exe'),
        (Join-Path -Path $vsPath -ChildPath 'MSBuild\Current\Bin\amd64\MSBuild.exe')
    )

    # Detect .NET SDKs
    $dotNetSdks = @()
    if (Get-Command 'dotnet' -ErrorAction SilentlyContinue) {
        try {
            # Capture output like "8.0.100 [C:\Program Files\dotnet\sdk]"
            $dotNetSdks = dotnet --list-sdks 2>$null
            
            if ($dotNetSdks) {
                Write-BuildLog -Message "[Toolchain] Found .NET SDKs: $($dotNetSdks.Count) installed" -Level 'DEBUG'
            }
        }
        catch {
            Write-BuildLog -Message "[Toolchain] Failed to query .NET SDKs: $_" -Level 'DEBUG'
        }
    }

    foreach ($candidate in $msBuildCandidates) {
        if (Test-Path -LiteralPath $candidate) {
            $msBuildPath = $candidate
            Write-BuildLog -Message "[Toolchain] MSBuild: $msBuildPath" -Level 'DEBUG'
            break
        }
    }

    # Return comprehensive environment object
    return [PSCustomObject]@{
        VSInstallPath     = $vsPath
        VSVersion         = $vsVersion
        VSDisplayName     = $vsDisplayName
        PlatformToolset   = $platformToolset
        MSVCVersion       = $msvcVersion
        WindowsSDKs       = $sortedSdks
        LatestSDK         = $latestSdk
        MSBuildPath       = $msBuildPath
        DotNetSDKs        = $dotNetSdks
    }
}

Export-ModuleMember -Function Get-VisualStudioEnvironment