#Requires -Version 5.1
<#
.SYNOPSIS
    Collecte l'inventaire du poste local et génère les rapports associés.

.DESCRIPTION
    Exécute Get-SystemInventory, journalise l'activité puis produit un rapport
    HTML, un export CSV des volumes et un export JSON complet.
    Le script est en lecture seule et idempotent : une ré-exécution écrase les
    livrables du jour sans dupliquer de données.

.PARAMETER OutputDirectory
    Répertoire de sortie alternatif. Par défaut, reports\html, reports\csv et
    reports\json du dépôt.

.PARAMETER Format
    Livrables à produire : Html, Csv, Json ou All (valeur par défaut).

.PARAMETER Environment
    Environnement de configuration : default, lab ou prod.

.PARAMETER PassThru
    Retourne l'objet d'inventaire au lieu de l'objet de synthèse.

.EXAMPLE
    PS> .\src\Inventory\Get-SystemInventory.ps1

.EXAMPLE
    PS> .\src\Inventory\Get-SystemInventory.ps1 -Format Html -PassThru | ConvertTo-Json -Depth 4

.NOTES
    Author  : Scripts-Hub
    Version : 1.0.0
    Date    : 2026-11-08
    Le CSV contient les volumes fixes enrichis du nom de machine ; le JSON
    contient l'objet d'inventaire complet, volumes inclus.
#>

[CmdletBinding()]
param(
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

$context = Get-HubRunContext -Name 'System_Inventory' -Environment $Environment -Root $hubRoot
$startTime = Get-Date
$summary = $null

try {
    Write-HubLog -Message ('Début Get-SystemInventory (exécution {0})' -f $context.RunId) -Path $context.LogPath
    Write-HubLog -Message ('PowerShell {0} / {1}' -f $PSVersionTable.PSVersion, $PSVersionTable.PSEdition) -Path $context.LogPath
    Write-HubLog -Message ('Machine {0} / opérateur {1}' -f [System.Environment]::MachineName, [System.Environment]::UserName) -Path $context.LogPath

    $inventory = Get-SystemInventory -IncludeVolumes
    Write-HubLog -Message ('Inventaire collecté : {0} | {1} | {2} GB' -f $inventory.ComputerName, $inventory.OperatingSystem, $inventory.TotalMemoryGB) -Path $context.LogPath

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
            'Système' = [pscustomobject]@{
                ComputerName      = $inventory.ComputerName
                Domain            = $inventory.Domain
                Manufacturer      = $inventory.Manufacturer
                Model             = $inventory.Model
                SerialNumber      = $inventory.SerialNumber
                OperatingSystem   = $inventory.OperatingSystem
                OSVersion         = $inventory.OSVersion
                BuildNumber       = $inventory.BuildNumber
                Architecture      = $inventory.Architecture
                LastBootTime      = $inventory.LastBootTime
                UptimeDays        = $inventory.UptimeDays
                Processor         = $inventory.Processor
                Cores             = $inventory.Cores
                LogicalProcessors = $inventory.LogicalProcessors
                TotalMemoryGB     = $inventory.TotalMemoryGB
                FreeMemoryGB      = $inventory.FreeMemoryGB
                PowerShellVersion = $inventory.PowerShellVersion
            }
            'Volumes fixes' = @($inventory.Volumes)
        }

        $memoryUsedGB = [math]::Round([double]$inventory.TotalMemoryGB - [double]$inventory.FreeMemoryGB, 1)
        if ($memoryUsedGB -lt 0) {
            $memoryUsedGB = 0
        }

        $freeMemoryTone = 'success'
        if ([double]$inventory.TotalMemoryGB -gt 0) {
            $freeMemoryPercent = ([double]$inventory.FreeMemoryGB / [double]$inventory.TotalMemoryGB) * 100
            if ($freeMemoryPercent -lt 10) {
                $freeMemoryTone = 'danger'
            }
            elseif ($freeMemoryPercent -lt 25) {
                $freeMemoryTone = 'warning'
            }
        }

        $criticalVolumes = @($inventory.Volumes | Where-Object { $_.Health -eq 'Critique' }).Count
        $volumeTone = 'success'
        if ($criticalVolumes -gt 0) {
            $volumeTone = 'danger'
        }

        $kpi = @(
            @{ Label = 'Machine'; Value = $inventory.ComputerName; Tone = 'primary' }
            @{ Label = 'Système'; Value = $inventory.OperatingSystem }
            @{ Label = 'Mémoire totale'; Value = ('{0} Go' -f $inventory.TotalMemoryGB) }
            @{ Label = 'Mémoire libre'; Value = ('{0} Go' -f $inventory.FreeMemoryGB); Tone = $freeMemoryTone }
            @{ Label = 'Uptime'; Value = ('{0} j' -f $inventory.UptimeDays) }
            @{ Label = 'Volumes critiques'; Value = $criticalVolumes; Tone = $volumeTone }
        )

        $charts = @(
            @{
                Id     = 'chart-volumes'
                Title  = 'Occupation des volumes (%)'
                Type   = 'bar'
                Label  = 'Occupation (%)'
                Labels = @($inventory.Volumes | ForEach-Object { $_.Drive })
                Values = @($inventory.Volumes | ForEach-Object { $_.UsedPercent })
                Color  = 'primary'
            }
            @{
                Id     = 'chart-memory'
                Title  = 'Mémoire (Go)'
                Type   = 'doughnut'
                Label  = 'Mémoire'
                Labels = @('Utilisée', 'Libre')
                Values = @($memoryUsedGB, $inventory.FreeMemoryGB)
                Color  = 'primary'
            }
        )

        $htmlPath = New-HubHtmlReport -Title 'Inventaire système' -Subtitle $inventory.ComputerName -Sections $sections -Path $htmlPath -Kpi $kpi -Charts $charts
        Write-HubLog -Message ('Rapport HTML : {0}' -f $htmlPath) -Path $context.LogPath
    }

    if ($Format -eq 'Csv' -or $Format -eq 'All') {
        if ($null -ne $targetDirectory) {
            $csvPath = Join-Path -Path $targetDirectory -ChildPath (Split-Path -Path $context.CsvPath -Leaf)
        }
        else {
            $csvPath = $context.CsvPath
        }

        $volumes = @($inventory.Volumes)
        if ($volumes.Count -eq 0) {
            $csvPath = Export-HubCsv -InputObject ([pscustomobject]@{
                ComputerName = $inventory.ComputerName
                OperatingSystem = $inventory.OperatingSystem
                TotalMemoryGB = $inventory.TotalMemoryGB
                FreeMemoryGB = $inventory.FreeMemoryGB
                CollectedAt = $inventory.CollectedAt
            }) -Path $csvPath
        }
        else {
            $csvPath = Export-HubCsv -InputObject $volumes -Path $csvPath
        }
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
        Script      = 'Get-SystemInventory'
        ComputerName = $inventory.ComputerName
        CollectedAt = $inventory.CollectedAt
        Duration    = ((Get-Date) - $startTime).TotalSeconds
        Html        = $htmlPath
        Csv         = $csvPath
        Json        = $jsonPath
        Log         = $context.LogPath
    }
}
catch {
    Write-HubLog -Level ERROR -Message ('Échec : {0}' -f $_.Exception.Message) -Path $context.LogPath
    throw
}
finally {
    $duration = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 2)
    Write-HubLog -Message ('Fin Get-SystemInventory en {0} s' -f $duration) -Path $context.LogPath
}

if ($PassThru) {
    $inventory
}
else {
    $summary
}
