# --- FUNCTIONS ---

function Get-ToolsetID {
    param ([string]$Version)
    if ($Version -match "^14\.4") { return "v143 (VS 2022 - Latest)" }
    if ($Version -match "^14\.3") { return "v143 (VS 2022)" }
    if ($Version -match "^14\.2") { return "v142 (VS 2019)" }
    if ($Version -match "^14\.1") { return "v141 (VS 2017)" }
    if ($Version -match "^14\.0") { return "v140 (VS 2015)" }
    return "Unknown ($Version)"
}

function Get-WindowsSDKs {
    $regPath = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows Kits\Installed Roots"
    if (-not (Test-Path $regPath)) { $regPath = "HKLM:\SOFTWARE\Microsoft\Windows Kits\Installed Roots" }
    
    $sdks = @()
    
    # Check Windows 10/11
    $root10 = Get-ItemPropertyValue -Path $regPath -Name "KitsRoot10" -ErrorAction SilentlyContinue
    if ($root10 -and (Test-Path (Join-Path $root10 "Include"))) {
        $dirs = Get-ChildItem -Path (Join-Path $root10 "Include") -Directory
        foreach ($d in $dirs) {
            if ($d.Name -match "^10\.\d+\.\d+\.\d+$") { $sdks += $d.Name }
        }
    }
    
    # Check Windows 8.1
    $regKey = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
    # Check for Windows 8.1 Root (Legacy)
    if ($regKey.KitsRoot81 -and ($sdks -notcontains "8.1")) {
        $sdks += "8.1"
    }

    return $sdks
}

# --- MAIN EXECUTION ---

Clear-Host
Write-Host "=== Visual Studio Environment Report ===" -ForegroundColor Cyan
Write-Host ""

# 1. REPORT SDKS
Write-Host "Available Windows SDK Versions:" -ForegroundColor Yellow
$sdkList = Get-WindowsSDKs
if ($sdkList) {
    $sdkList | ForEach-Object { Write-Host "  [+] $_" -ForegroundColor Green }
} else {
    Write-Host "  [-] No SDKs found." -ForegroundColor Red
}
Write-Host ""

# 2. REPORT TOOLSETS
Write-Host "Available MSVC Platform Toolsets:" -ForegroundColor Yellow
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"

if (Test-Path $vswhere) {
    $instances = & $vswhere -all -format json | ConvertFrom-Json
    foreach ($inst in $instances) {
        $msvcPath = Join-Path $inst.installationPath "VC\Tools\MSVC"
        if (Test-Path $msvcPath) {
            Write-Host "  In $($inst.displayName):" -ForegroundColor White
            $tools = Get-ChildItem -Path $msvcPath -Directory
            foreach ($t in $tools) {
                $tid = Get-ToolsetID -Version $t.Name
                Write-Host "    [+] $tid" -NoNewline -ForegroundColor Green
                Write-Host " ($($t.Name))" -ForegroundColor DarkGray
            }
        }
    }
} else {
    Write-Error "vswhere.exe not found."
}

Write-Host "`nReport Complete."
