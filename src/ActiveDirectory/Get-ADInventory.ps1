#Requires -Version 5.1
<#
.SYNOPSIS
    Collecte un inventaire Active Directory et génère les rapports associés.

.DESCRIPTION
    Interroge le domaine via le module ActiveDirectory (RSAT), journalise
    l'activité puis produit les livrables HTML, CSV et JSON.
    Le script échoue avec un message explicite si le module RSAT est absent ou
    si la connexion au domaine est refusée.

.PARAMETER Server
    Contrôleur de domaine cible. Par défaut, le DC du site courant.

.PARAMETER SearchBase
    Base de recherche LDAP. Par défaut, la racine du domaine.

.PARAMETER Credential
    Identité alternative pour la connexion au domaine.

.PARAMETER OutputDirectory
    Répertoire de sortie alternatif.

.PARAMETER Format
    Livrables à produire : Html, Csv, Json ou All (valeur par défaut).

.PARAMETER Environment
    Environnement de configuration : default, lab ou prod.

.PARAMETER PassThru
    Retourne l'objet d'inventaire au lieu de l'objet de synthèse.

.EXAMPLE
    PS> .\src\ActiveDirectory\Get-ADInventory.ps1 -Server dc01.contoso.com

.EXAMPLE
    PS> .\src\ActiveDirectory\Get-ADInventory.ps1 -SearchBase 'OU=Paris,DC=contoso,DC=com' -Credential (Get-Credential)

.NOTES
    Author  : Scripts-Hub
    Version : 1.0.0
    Date    : 2026-11-08
    Prérequis : module ActiveDirectory (RSAT) et accès réseau au contrôleur.
#>

[CmdletBinding()]
param(
    [string]$Server,

    [string]$SearchBase,

    [System.Management.Automation.PSCredential]$Credential,

    [string]$OutputDirectory,

    [ValidateSet('Html', 'Csv', 'Json', 'All')]
    [string]$Format = 'All',

    [ValidateNotNullOrEmpty()]
    [string]$Environment = 'default',

    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$hubRoot = Split-Path -Path (Split-Path -Path $scriptDirectory -Parent) -Parent

Import-Module -Name (Join-Path -Path $hubRoot -ChildPath 'modules\Common\Common.psd1') -Force
Import-Module -Name (Join-Path -Path $hubRoot -ChildPath 'modules\Inventory\Inventory.psd1') -Force
Import-Module -Name (Join-Path -Path $hubRoot -ChildPath 'modules\Reporting\Reporting.psd1') -Force

$context = Get-HubRunContext -Name 'AD_Inventory' -Environment $Environment -Root $hubRoot
$startTime = Get-Date
$summary = $null

try {
    Write-HubLog -Message ('Début Get-ADInventory (exécution {0})' -f $context.RunId) -Path $context.LogPath
    if (-not [string]::IsNullOrWhiteSpace($Server)) {
        Write-HubLog -Message ('Contrôleur cible : {0}' -f $Server) -Path $context.LogPath
    }

    $inventoryParameters = @{}
    if (-not [string]::IsNullOrWhiteSpace($Server)) {
        $inventoryParameters['Server'] = $Server
    }
    if (-not [string]::IsNullOrWhiteSpace($SearchBase)) {
        $inventoryParameters['SearchBase'] = $SearchBase
    }
    if ($null -ne $Credential) {
        $inventoryParameters['Credential'] = $Credential
    }

    $inventory = Get-ADInventory @inventoryParameters
    Write-HubLog -Message ('Domaine {0} : {1} utilisateurs, {2} ordinateurs, {3} groupes' -f $inventory.Domain, $inventory.UsersTotal, $inventory.ComputersTotal, $inventory.GroupsTotal) -Path $context.LogPath

    $htmlPath = $null
    $csvPath = $null
    $jsonPath = $null

    $targetDirectory = $null
    if (-not [string]::IsNullOrWhiteSpace($OutputDirectory)) {
        $targetDirectory = New-HubDirectory -Path $OutputDirectory
    }

    if ($Format -eq 'Html' -or $Format -eq 'All') {
        if ($null -ne $targetDirectory) {
            $htmlPath = Join-Path -Path $targetDirectory -ChildPath (Split-Path -Path $context.HtmlPath -Leaf)
        }
        else {
            $htmlPath = $context.HtmlPath
        }

        $sections = [ordered]@{
            'Domaine' = $inventory
        }

        $usersDisabled = [int]$inventory.UsersTotal - [int]$inventory.UsersEnabled
        if ($usersDisabled -lt 0) {
            $usersDisabled = 0
        }

        $kpi = @(
            @{ Label = 'Domaine'; Value = $inventory.Domain; Tone = 'primary' }
            @{ Label = 'Utilisateurs'; Value = $inventory.UsersTotal }
            @{ Label = 'Utilisateurs actifs'; Value = $inventory.UsersEnabled; Tone = 'success' }
            @{ Label = 'Ordinateurs'; Value = $inventory.ComputersTotal }
            @{ Label = 'Groupes'; Value = $inventory.GroupsTotal }
            @{ Label = 'Unités d''organisation'; Value = $inventory.OrganizationalUnits }
        )

        $charts = @(
            @{
                Id     = 'chart-ad-objects'
                Title  = 'Objets Active Directory'
                Type   = 'bar'
                Label  = 'Objets'
                Labels = @('Utilisateurs', 'Ordinateurs', 'Groupes', 'OU')
                Values = @($inventory.UsersTotal, $inventory.ComputersTotal, $inventory.GroupsTotal, $inventory.OrganizationalUnits)
                Color  = 'primary'
            }
            @{
                Id     = 'chart-ad-users'
                Title  = 'Comptes utilisateurs'
                Type   = 'doughnut'
                Label  = 'Utilisateurs'
                Labels = @('Actifs', 'Désactivés')
                Values = @($inventory.UsersEnabled, $usersDisabled)
                Color  = 'success'
            }
        )

        $htmlPath = New-HubHtmlReport -Title 'Inventaire Active Directory' -Subtitle $inventory.Domain -Sections $sections -Path $htmlPath -Kpi $kpi -Charts $charts
        Write-HubLog -Message ('Rapport HTML : {0}' -f $htmlPath) -Path $context.LogPath
    }

    if ($Format -eq 'Csv' -or $Format -eq 'All') {
        if ($null -ne $targetDirectory) {
            $csvPath = Join-Path -Path $targetDirectory -ChildPath (Split-Path -Path $context.CsvPath -Leaf)
        }
        else {
            $csvPath = $context.CsvPath
        }

        $csvPath = Export-HubCsv -InputObject $inventory -Path $csvPath
        Write-HubLog -Message ('Export CSV : {0}' -f $csvPath) -Path $context.LogPath
    }

    if ($Format -eq 'Json' -or $Format -eq 'All') {
        if ($null -ne $targetDirectory) {
            $jsonPath = Join-Path -Path $targetDirectory -ChildPath (Split-Path -Path $context.JsonPath -Leaf)
        }
        else {
            $jsonPath = $context.JsonPath
        }

        $jsonPath = Export-HubJson -InputObject $inventory -Path $jsonPath
        Write-HubLog -Message ('Export JSON : {0}' -f $jsonPath) -Path $context.LogPath
    }

    $summary = [pscustomobject]@{
        Script       = 'Get-ADInventory'
        Domain       = $inventory.Domain
        DomainController = $inventory.DomainController
        CollectedAt  = $inventory.CollectedAt
        Duration     = ((Get-Date) - $startTime).TotalSeconds
        Html         = $htmlPath
        Csv          = $csvPath
        Json         = $jsonPath
        Log          = $context.LogPath
    }
}
catch {
    Write-HubLog -Level ERROR -Message ('Échec : {0}' -f $_.Exception.Message) -Path $context.LogPath
    throw
}
finally {
    $duration = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 2)
    Write-HubLog -Message ('Fin Get-ADInventory en {0} s' -f $duration) -Path $context.LogPath
}

if ($PassThru) {
    $inventory
}
else {
    $summary
}
