#Requires -Version 5.1
<#
.SYNOPSIS
    Initialise ou répare l'arborescence cible du dépôt scripts-hub.

.DESCRIPTION
    Vérifie la présence des répertoires de l'architecture cible et crée
    uniquement ceux qui manquent. Les répertoires vides reçoivent un fichier
    .gitkeep afin d'être conservés par Git. L'opération est idempotente et
    n'écrase jamais de donnée existante.

.PARAMETER Root
    Racine du dépôt. Par défaut, la racine déduite de l'emplacement du script.

.PARAMETER PassThru
    Retourne un objet de synthèse.

.EXAMPLE
    PS> .\tools\maintenance\Initialize-HubStructure.ps1

.EXAMPLE
    PS> .\tools\maintenance\Initialize-HubStructure.ps1 -WhatIf

.NOTES
    Author  : Scripts-Hub
    Version : 1.0.0
    Date    : 2026-11-08
#>

[CmdletBinding(SupportsShouldProcess = $true)]
[OutputType([pscustomobject])]
param(
    [string]$Root,

    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Root)) {
    $scriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
    $Root = Split-Path -Path (Split-Path -Path $scriptDirectory -Parent) -Parent
}

$Root = [System.IO.Path]::GetFullPath($Root)

$directories = @(
    'src\ActiveDirectory'
    'src\Azure'
    'src\Microsoft365'
    'src\HyperV'
    'src\VMware'
    'src\Network'
    'src\Security'
    'src\Inventory'
    'src\Reporting'
    'src\Dashboard'
    'modules\Common'
    'modules\Inventory'
    'modules\Reporting'
    'modules\Security'
    'modules\Dashboard'
    'modules\Utilities'
    'config\settings'
    'config\environments'
    'config\templates'
    'reports\html'
    'reports\csv'
    'reports\json'
    'reports\archive'
    'logs'
    'docs\architecture'
    'docs\procedures'
    'docs\standards'
    'docs\runbooks'
    'tests\unit'
    'tests\integration'
    'tests\data'
    'tools\build'
    'tools\deployment'
    'tools\maintenance'
    'tools\migration'
    'assets\css'
    'assets\js'
    'assets\icons'
    'assets\templates'
    'archive'
    '.github\workflows'
)

$created = New-Object System.Collections.Generic.List[string]
$kept = New-Object System.Collections.Generic.List[string]

foreach ($relative in $directories) {
    $fullPath = Join-Path -Path $Root -ChildPath $relative

    if (-not (Test-Path -LiteralPath $fullPath -PathType Container)) {
        if ($PSCmdlet.ShouldProcess($fullPath, 'Créer le répertoire')) {
            New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
            $created.Add($relative)
            Write-Host ('Créé      : {0}' -f $relative) -ForegroundColor Green
        }
        continue
    }

    $hasContent = @(Get-ChildItem -LiteralPath $fullPath -Force -ErrorAction Stop).Count -gt 0
    if (-not $hasContent) {
        $gitKeep = Join-Path -Path $fullPath -ChildPath '.gitkeep'
        if ($PSCmdlet.ShouldProcess($gitKeep, 'Créer le marqueur .gitkeep')) {
            New-Item -ItemType File -Path $gitKeep -Force | Out-Null
            $kept.Add($relative)
            Write-Host ('Marqueur  : {0}\.gitkeep' -f $relative) -ForegroundColor DarkGray
        }
    }
}

$summary = [pscustomobject]@{
    Root               = $Root
    DirectoriesChecked = $directories.Count
    Created            = $created.ToArray()
    Kept               = $kept.ToArray()
}

Write-Host ''
Write-Host ('Arborescence vérifiée : {0} répertoires / {1} créés / {2} marqueurs .gitkeep' -f $directories.Count, $created.Count, $kept.Count) -ForegroundColor Cyan

if ($PassThru) {
    $summary
}
