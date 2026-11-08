#Requires -Version 5.1
<#
.SYNOPSIS
    Purge les rapports dont la date de modification dépasse la rétention.

.DESCRIPTION
    Supprime les fichiers de reports\html, reports\csv et reports\json plus
    anciens que le nombre de jours demandé. Le répertoire reports\archive
    n'est jamais touché. Utilise SupportsShouldProcess : -WhatIf permet de
    simuler la suppression.

.PARAMETER Days
    Durée de rétention en jours. Par défaut 90.

.PARAMETER Category
    Catégorie à purger : html, csv, json ou all (défaut).

.PARAMETER Root
    Racine du dépôt. Par défaut, la racine déduite de l'emplacement du script.

.EXAMPLE
    PS> .\tools\maintenance\Clear-OldReports.ps1 -Days 30 -WhatIf

.EXAMPLE
    PS> .\tools\maintenance\Clear-OldReports.ps1 -Days 90 -Category html

.NOTES
    Author  : Scripts-Hub
    Version : 1.0.0
    Date    : 2026-11-08
    Opération destructive : validation explicite recommandée.
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [ValidateRange(1, 3650)]
    [int]$Days = 90,

    [ValidateSet('html', 'csv', 'json', 'all')]
    [string]$Category = 'all',

    [string]$Root
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Root)) {
    $scriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
    $Root = Split-Path -Path (Split-Path -Path $scriptDirectory -Parent) -Parent
}

$reportsRoot = Join-Path -Path $Root -ChildPath 'reports'
if (-not (Test-Path -LiteralPath $reportsRoot -PathType Container)) {
    Write-Warning ('Répertoire absent : {0}' -f $reportsRoot)
    return
}

$cutoff = (Get-Date).AddDays(-$Days)
$categories = @('html', 'csv', 'json')
if ($Category -ne 'all') {
    $categories = @($Category)
}

$deleted = 0
$freedBytes = 0

foreach ($item in $categories) {
    $directory = Join-Path -Path $reportsRoot -ChildPath $item
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
        continue
    }

    $files = Get-ChildItem -LiteralPath $directory -File -Recurse -ErrorAction Stop | Where-Object {
        $_.LastWriteTime -lt $cutoff
    }

    foreach ($file in $files) {
        if ($PSCmdlet.ShouldProcess($file.FullName, ('Supprimer (antérieur au {0:yyyy-MM-dd})' -f $cutoff))) {
            $size = $file.Length
            Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
            $deleted++
            $freedBytes += $size
        }
    }
}

Write-Host ('Rapports supprimés : {0} / espace libéré : {1:N2} MB' -f $deleted, ($freedBytes / 1MB))
