#Requires -Version 5.1
<#
.SYNOPSIS
    Audite l'environnement d'exécution du dépôt scripts-hub.

.DESCRIPTION
    Contrôle les versions PowerShell, l'architecture du processus, la
    disponibilité des assemblys .NET, l'installation de Git, l'état du dépôt
    et les modules de développement (Pester, PSScriptAnalyzer).
    Aucune modification n'est apportée au système.

.PARAMETER OutputFormat
    Format d'affichage : Text (défaut), Json ou Markdown.

.PARAMETER OutputPath
    Fichier de sortie pour les formats Json ou Markdown. Par défaut,
    reports\json\YYYY-MM-DD_Environment_Audit.json.

.PARAMETER PassThru
    Retourne l'objet d'audit.

.EXAMPLE
    PS> .\tools\maintenance\Test-Environment.ps1

.EXAMPLE
    PS> .\tools\maintenance\Test-Environment.ps1 -OutputFormat Json -PassThru

.NOTES
    Author  : Scripts-Hub
    Version : 1.0.0
    Date    : 2026-11-08
#>

[CmdletBinding()]
param(
    [ValidateSet('Text', 'Json', 'Markdown')]
    [string]$OutputFormat = 'Text',

    [string]$OutputPath,

    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$toolsDirectory = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$hubRoot = Split-Path -Path (Split-Path -Path $toolsDirectory -Parent) -Parent

Import-Module -Name (Join-Path -Path $hubRoot -ChildPath 'modules\Common\Common.psd1') -Force
Import-Module -Name (Join-Path -Path $hubRoot -ChildPath 'modules\Reporting\Reporting.psd1') -Force

$audit = [ordered]@{
    Timestamp             = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture)
    Repository            = $hubRoot
    PowerShellVersion     = $PSVersionTable.PSVersion.ToString()
    PSEdition             = $PSVersionTable.PSEdition
    Is64BitProcess        = [System.Environment]::Is64BitProcess
    OperatingSystem       = [System.Environment]::OSVersion.VersionString
    Culture               = (Get-Culture).Name
    ExecutionPolicy       = [string](Get-ExecutionPolicy)
    WindowsPowerShell51   = $null
    GitVersion            = $null
    IsGitRepository       = $false
    GitBranch             = $null
    GitRemote             = $null
    GitPendingChanges     = 0
    PesterVersion         = $null
    PSScriptAnalyzerVersion = $null
    Assemblies            = [ordered]@{}
}

$windowsPowerShell = Join-Path -Path $env:SystemRoot -ChildPath 'System32\WindowsPowerShell\v1.0\powershell.exe'
if (Test-Path -LiteralPath $windowsPowerShell -PathType Leaf) {
    $version = & $windowsPowerShell -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' 2>$null
    $audit.WindowsPowerShell51 = ([string]$version).Trim()
}

foreach ($assemblyName in @('System.Windows.Forms', 'System.Drawing', 'System.Web')) {
    try {
        Add-Type -AssemblyName $assemblyName -ErrorAction Stop
        $audit.Assemblies[$assemblyName] = 'Présent'
    }
    catch {
        $audit.Assemblies[$assemblyName] = 'Absent'
    }
}

$gitCommand = Get-Command -Name 'git' -ErrorAction SilentlyContinue
if ($null -ne $gitCommand) {
    $audit.GitVersion = ([string](& git --version 2>$null)).Trim()
    $isRepository = & git -C $hubRoot rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -eq 0 -and ([string]$isRepository).Trim() -eq 'true') {
        $audit.IsGitRepository = $true
        $audit.GitBranch = ([string](& git -C $hubRoot rev-parse --abbrev-ref HEAD 2>$null)).Trim()
        $audit.GitRemote = ([string](& git -C $hubRoot config --get remote.origin.url 2>$null)).Trim()
        $audit.GitPendingChanges = @(& git -C $hubRoot status --porcelain 2>$null).Count
    }
}

$pester = Get-Module -ListAvailable -Name 'Pester' | Sort-Object -Property Version -Descending | Select-Object -First 1
if ($null -ne $pester) {
    $audit.PesterVersion = $pester.Version.ToString()
}

$analyzer = Get-Module -ListAvailable -Name 'PSScriptAnalyzer' | Sort-Object -Property Version -Descending | Select-Object -First 1
if ($null -ne $analyzer) {
    $audit.PSScriptAnalyzerVersion = $analyzer.Version.ToString()
}

if ($OutputFormat -eq 'Text') {
    Write-Host ''
    Write-Host '=== Audit de l''environnement scripts-hub ===' -ForegroundColor Cyan
    foreach ($key in $audit.Keys) {
        if ($key -eq 'Assemblies') {
            foreach ($assemblyName in $audit.Assemblies.Keys) {
                Write-Host ('  {0,-26} : {1}' -f $assemblyName, $audit.Assemblies[$assemblyName])
            }
        }
        else {
            Write-Host ('  {0,-26} : {1}' -f $key, $audit[$key])
        }
    }
    Write-Host ''
}
elseif ($OutputFormat -eq 'Json') {
    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        $OutputPath = Get-HubReportPath -Name 'Environment_Audit' -Format 'json' -Root $hubRoot
    }
    Export-HubJson -InputObject ([pscustomobject]$audit) -Path $OutputPath | Out-Null
    Write-Host ('Audit JSON : {0}' -f $OutputPath)
}
else {
    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        $OutputPath = Join-Path -Path (Join-Path -Path $hubRoot -ChildPath 'docs\architecture') -ChildPath ('environment-audit-{0}.md' -f (Get-HubTimestamp -Format 'yyyy-MM-dd'))
    }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# Audit de l''environnement scripts-hub')
    $lines.Add('')
    $lines.Add(('Généré le {0}' -f $audit.Timestamp))
    $lines.Add('')
    $lines.Add('| Contrôle | Valeur |')
    $lines.Add('| --- | --- |')
    foreach ($key in $audit.Keys) {
        if ($key -eq 'Assemblies') {
            foreach ($assemblyName in $audit.Assemblies.Keys) {
                $lines.Add(('| {0} | {1} |' -f $assemblyName, $audit.Assemblies[$assemblyName]))
            }
        }
        else {
            $lines.Add(('| {0} | {1} |' -f $key, $audit[$key]))
        }
    }

    $parent = Split-Path -Path $OutputPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        New-HubDirectory -Path $parent -Confirm:$false | Out-Null
    }
    [System.IO.File]::WriteAllLines(
        [System.IO.Path]::GetFullPath($OutputPath),
        [string[]]$lines.ToArray(),
        (New-Object System.Text.UTF8Encoding($true))
    )
    Write-Host ('Audit Markdown : {0}' -f $OutputPath)
}

if ($PassThru) {
    [pscustomobject]$audit
}
