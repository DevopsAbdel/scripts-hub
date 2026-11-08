#Requires -Version 5.1
<#
.SYNOPSIS
    Installe les modules de développement requis par le dépôt.

.DESCRIPTION
    Installe ou met à jour Pester (5+) et PSScriptAnalyzer depuis la galerie
    PowerShell. Vérifie au préalable la disponibilité de PowerShellGet et de
    la source PSGallery. Par défaut, l'installation est limitée à
    l'utilisateur courant.

.PARAMETER Scope
    Portée d'installation : CurrentUser (défaut) ou AllUsers (administrateur).

.PARAMETER Force
    Réinstalle les modules même s'ils sont déjà présents et à jour.

.EXAMPLE
    PS> .\tools\deployment\Install-HubModules.ps1

.EXAMPLE
    PS> .\tools\deployment\Install-HubModules.ps1 -Scope AllUsers -Force

.NOTES
    Author  : Scripts-Hub
    Version : 1.0.0
    Date    : 2026-11-08
    Modifie le système : installation de modules dans la portée choisie.
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [ValidateSet('CurrentUser', 'AllUsers')]
    [string]$Scope = 'CurrentUser',

    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$requiredModules = @(
    @{ Name = 'Pester'; MinimumVersion = '5.7.0' }
    @{ Name = 'PSScriptAnalyzer'; MinimumVersion = '1.21.0' }
)

if (-not (Get-Command -Name 'Install-Module' -ErrorAction SilentlyContinue)) {
    throw 'PowerShellGet est requis pour installer les modules.'
}

try {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
}
catch {
    Write-Verbose 'TLS 1.2 déjà configuré ou non applicable.'
}

$repository = Get-PSRepository -Name 'PSGallery' -ErrorAction SilentlyContinue
if ($null -eq $repository) {
    throw 'La source PSGallery est introuvable. Enregistrez-la avec Register-PSRepository -Default.'
}

foreach ($module in $requiredModules) {
    $installed = Get-Module -ListAvailable -Name $module.Name | Sort-Object -Property Version -Descending | Select-Object -First 1
    $isUpToDate = $null -ne $installed -and $installed.Version -ge [version]$module.MinimumVersion

    if ($isUpToDate -and -not $Force) {
        Write-Host ('{0} {1} déjà installé.' -f $module.Name, $installed.Version) -ForegroundColor Green
        continue
    }

    if ($PSCmdlet.ShouldProcess(('{0} >= {1}' -f $module.Name, $module.MinimumVersion), 'Installer le module')) {
        Write-Host ('Installation de {0} (>= {1})...' -f $module.Name, $module.MinimumVersion)
        Install-Module -Name $module.Name -MinimumVersion $module.MinimumVersion -Scope $Scope -Repository 'PSGallery' -Force -AllowClobber -ErrorAction Stop
        $newVersion = (Get-Module -ListAvailable -Name $module.Name | Sort-Object -Property Version -Descending | Select-Object -First 1).Version
        Write-Host ('{0} {1} installé.' -f $module.Name, $newVersion) -ForegroundColor Green
    }
}

Write-Host ''
Write-Host 'Modules de développement prêts.' -ForegroundColor Green
