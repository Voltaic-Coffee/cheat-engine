# Build Configuration
# This file allows you to customize build paths and options
# Copy this to build-config.local.ps1 and modify as needed
# (build-config.local.ps1 is git-ignored)

# Lazarus Installation Path
# Default: C:\lazarus
$LazarusPath = "C:\lazarus"

# Visual Studio Version Preference
# Options: "latest", "2017", "2019", "2022"
# Default: "latest"
$VSVersion = "latest"

# Java JDK Path (for CEJVMTI)
# Set if JDK is in non-standard location
# Default: Uses JAVA_HOME environment variable
# $JavaHome = "C:\Program Files\Java\jdk-17"

# Build Output Verbosity
# Options: "quiet", "minimal", "normal", "detailed"
# Default: "minimal"
$BuildVerbosity = "minimal"

# Parallel Build
# Set to $true to enable parallel builds where possible
# Default: $true
$ParallelBuild = $true

# Clean Build by Default
# Set to $true to always clean before building
# Default: $false
$CleanByDefault = $false

# Skip Existing Builds
# Set to $true to only build projects that don't already exist
# Set to $false to always rebuild regardless of existing files
# Default: $true
$SkipExisting = $true

# Skip Optional Components
# Set to $true to skip building optional components
$SkipTCC = $false
$SkipLFS = $false
$SkipDBKKernel = $true  # Usually skip kernel driver

# Build Configurations
# For Visual Studio projects
$VSConfiguration = "Release"  # or "Debug"

# For Lazarus projects
$LazarusBuildMode = "Release"  # or "Debug"

# Architecture Targets
# Set to $false to skip building for specific architectures
$Build32bit = $true
$Build64bit = $true

# Additional MSBuild Arguments
# Add custom MSBuild arguments here
$AdditionalMSBuildArgs = @()

# Additional Lazbuild Arguments
# Add custom Lazbuild arguments here
$AdditionalLazbuildArgs = @()

# Dependency Paths
# Override default paths for third-party dependencies

# Windows SDK Debugging Tools
# $DbgHelpPath_x86 = "C:\Program Files (x86)\Windows Kits\10\Debuggers\x86"
# $DbgHelpPath_x64 = "C:\Program Files (x86)\Windows Kits\10\Debuggers\x64"

# SQLite
# $SQLitePath_x86 = "C:\path\to\sqlite\x86"
# $SQLitePath_x64 = "C:\path\to\sqlite\x64"

# Intel Processor Trace
# $LibIPTPath_x86 = "C:\path\to\libipt\x86"
# $LibIPTPath_x64 = "C:\path\to\libipt\x64"

# Build Notification
# Send notification when build completes (requires toast notifications)
$NotifyOnComplete = $false

# Log Build Output
# Save build output to log files
$LogBuilds = $true
$LogDirectory = "Build\logs"

# Git Integration
# Tag successful builds with version
$TagBuilds = $false

# Packaging
# Automatically create distribution package after successful build
$CreatePackage = $false
$PackageDirectory = "Build\packages"
