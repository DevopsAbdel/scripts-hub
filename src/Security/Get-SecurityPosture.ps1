#Requires -Version 5.1
<#
.SYNOPSIS
    Audite la posture de sécurité locale et génère les rapports associés.

.DESCRIPTION
    Collecte les administrateurs locaux, l'état des profils de pare-feu et de
    Microsoft Defender, journalise l'activité puis produit les livrables HTML,
    CSV et JSON. Les sources indisponibles sont signalées sans interrompre
    l'audit.

.PARAMETER OutputDirectory
    Répertoire de sortie alternatif.

.PARAMETER Format
    Livrables à produire : Html, Csv, Json ou All (valeur par défaut).

.PARAMETER Environment
    Environnement de configuration : default, lab ou prod.

.PARAMETER PassThru
    Retourne l'objet de posture au lieu de l'objet de synthèse.

.EXAMPLE
    PS> .\src\Security\Get-SecurityPosture.ps1

.EXAMPLE
    PS> $posture = .\src\Security\Get-SecurityPosture.ps1 -PassThru
    PS> $posture.Firewall | Format-Table

.NOTES
    Author  : Scripts-Hub
    Version : 1.0.0
    Date    : 2026-11-08
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
Import-Module -Name (Join-Path -Path $hubRoot -ChildPath 'modules\Security\Security.psd1') -Force
Import-Module -Name (Join-Path -Path $hubRoot -ChildPath 'modules\Reporting\Reporting.psd1') -Force

$context = Get-HubRunContext -Name 'Security_Posture' -Environment $Environment -Root $hubRoot
$startTime = Get-Date
$summary = $null

try {
    Write-HubLog -Message ('Début Get-SecurityPosture (exécution {0})' -f $context.RunId) -Path $context.LogPath

    $posture = Get-SecurityPosture

    foreach ($warning in $posture.Warnings) {
        Write-HubLog -Level WARNING -Message $warning -Path $context.LogPath
    }

    Write-HubLog -Message ('Administrateurs locaux : {0} / profils pare-feu : {1}' -f $posture.Administrators.Count, $posture.Firewall.Count) -Path $context.LogPath

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
            'Synthèse' = [pscustomobject]@{
                ComputerName        = $posture.ComputerName
                CollectedAt         = $posture.CollectedAt
                LocalAdministrators = $posture.Administrators.Count
                FirewallProfiles    = $posture.Firewall.Count
                DefenderAvailable   = ($null -ne $posture.Defender)
                Warnings            = $posture.Warnings
            }
            'Administrateurs locaux' = @($posture.Administrators)
            'Pare-feu Windows'       = @($posture.Firewall)
            'Microsoft Defender'     = $posture.Defender
        }

        $firewallTotal = @($posture.Firewall).Count
        $firewallEnabled = @($posture.Firewall | Where-Object { $_.Enabled }).Count
        $firewallInactive = $firewallTotal - $firewallEnabled
        $firewallTone = 'success'
        if ($firewallEnabled -lt $firewallTotal) {
            $firewallTone = 'danger'
        }

        $defenderAvailable = $null -ne $posture.Defender
        $defenderTone = 'warning'
        $defenderLabel = 'Indisponible'
        if ($defenderAvailable) {
            if ($posture.Defender.RealTimeProtectionEnabled) {
                $defenderTone = 'success'
                $defenderLabel = 'Temps réel actif'
            }
            else {
                $defenderTone = 'danger'
                $defenderLabel = 'Temps réel inactif'
            }
        }

        $warningTone = 'success'
        if ($posture.Warnings.Count -gt 0) {
            $warningTone = 'warning'
        }

        $kpi = @(
            @{ Label = 'Machine'; Value = $posture.ComputerName; Tone = 'primary' }
            @{ Label = 'Administrateurs locaux'; Value = $posture.Administrators.Count }
            @{ Label = 'Pare-feu actifs'; Value = ('{0} / {1}' -f $firewallEnabled, $firewallTotal); Tone = $firewallTone }
            @{ Label = 'Profils pare-feu'; Value = $firewallTotal }
            @{ Label = 'Defender'; Value = $defenderLabel; Tone = $defenderTone }
            @{ Label = 'Avertissements'; Value = $posture.Warnings.Count; Tone = $warningTone }
        )

        $charts = @()

        if ($firewallTotal -gt 0) {
            $charts += @{
                Id     = 'chart-firewall'
                Title  = 'Profils pare-feu'
                Type   = 'doughnut'
                Label  = 'Profils'
                Labels = @('Actifs', 'Inactifs')
                Values = @($firewallEnabled, $firewallInactive)
                Color  = 'success'
            }
        }

        if ($defenderAvailable) {
            $charts += @{
                Id     = 'chart-defender'
                Title  = 'Protections Defender'
                Type   = 'bar'
                Label  = 'État (1 = actif)'
                Labels = @('Antivirus', 'Temps réel')
                Values = @([int][bool]$posture.Defender.AntivirusEnabled, [int][bool]$posture.Defender.RealTimeProtectionEnabled)
                Color  = 'success'
            }
        }

        if ($posture.Administrators.Count -gt 0) {
            $adminGroups = @($posture.Administrators | Group-Object -Property ObjectClass)
            $charts += @{
                Id     = 'chart-admins'
                Title  = 'Administrateurs locaux par type'
                Type   = 'bar'
                Label  = 'Comptes'
                Labels = @($adminGroups | ForEach-Object { $_.Name })
                Values = @($adminGroups | ForEach-Object { $_.Count })
                Color  = 'warning'
            }
        }

        $htmlPath = New-HubHtmlReport -Title 'Posture de sécurité locale' -Subtitle $posture.ComputerName -Sections $sections -Path $htmlPath -Kpi $kpi -Charts $charts
        Write-HubLog -Message ('Rapport HTML : {0}' -f $htmlPath) -Path $context.LogPath
    }

    if ($Format -eq 'Csv' -or $Format -eq 'All') {
        if ($null -ne $targetDirectory) {
            $csvPath = Join-Path -Path $targetDirectory -ChildPath (Split-Path -Path $context.CsvPath -Leaf)
        }
        else {
            $csvPath = $context.CsvPath
        }

        $csvPath = Export-HubCsv -InputObject @($posture.Administrators) -Path $csvPath
        Write-HubLog -Message ('Export CSV : {0}' -f $csvPath) -Path $context.LogPath
    }

    if ($Format -eq 'Json' -or $Format -eq 'All') {
        if ($null -ne $targetDirectory) {
            $jsonPath = Join-Path -Path $targetDirectory -ChildPath (Split-Path -Path $context.JsonPath -Leaf)
        }
        else {
            $jsonPath = $context.JsonPath
        }

        $jsonPath = Export-HubJson -InputObject $posture -Path $jsonPath
        Write-HubLog -Message ('Export JSON : {0}' -f $jsonPath) -Path $context.LogPath
    }

    $summary = [pscustomobject]@{
        Script      = 'Get-SecurityPosture'
        ComputerName = $posture.ComputerName
        CollectedAt = $posture.CollectedAt
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
    Write-HubLog -Message ('Fin Get-SecurityPosture en {0} s' -f $duration) -Path $context.LogPath
}

if ($PassThru) {
    $posture
}
else {
    $summary
}
