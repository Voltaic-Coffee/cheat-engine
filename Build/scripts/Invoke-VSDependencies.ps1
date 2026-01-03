#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$ConfigPath,
    [switch]$SkipFileLogging,
    [switch]$VerboseLogging
)

Set-StrictMode -Version Latest
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$mainScript = Join-Path -Path $scriptRoot -ChildPath 'Invoke-CheatEngineBuild.ps1'

$arguments = @('-Target','VisualStudio')
if ($ConfigPath) { $arguments += @('-ConfigPath', $ConfigPath) }
if ($SkipFileLogging) { $arguments += '-SkipFileLogging' }
if ($VerboseLogging) { $arguments += '-VerboseLogging' }

& $mainScript @arguments
