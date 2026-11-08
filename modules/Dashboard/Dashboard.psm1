#Requires -Version 5.1
<#
.SYNOPSIS
    Tableau de bord local et inventaire des livrables de scripts-hub.

.DESCRIPTION
    Module de support du dashboard web local. Il expose l'index des rapports
    générés, la liste blanche des scripts exécutables, l'index des journaux,
    la résolution sécurisée des fichiers servis et la construction de la page
    HTML autonome. Aucune connexion réseau sortante n'est effectuée.

.NOTES
    Author  : Scripts-Hub
    Version : 1.0.0
    Date    : 2026-11-08
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\Common\Common.psd1') -ErrorAction Stop

$script:DashboardVersion = '1.0.0'
$script:ReportTypes = @('html', 'csv', 'json')

function ConvertTo-HubDashboardText {
    <#
    .SYNOPSIS
        Échappe une valeur pour une insertion sûre dans le dashboard HTML.

    .PARAMETER Value
        Valeur à échapper.

    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return [string]::Empty
    }

    $text = [string]$Value
    $text = $text -replace '&', '&amp;'
    $text = $text -replace '<', '&lt;'
    $text = $text -replace '>', '&gt;'
    $text = $text -replace '"', '&quot;'
    return $text
}

function Get-HubDashboardAction {
    <#
    .SYNOPSIS
        Liste les scripts que le dashboard est autorisé à exécuter.

    .DESCRIPTION
        La liste blanche évite toute exécution arbitraire depuis l'interface.
        La disponibilité de chaque action est vérifiée sans échouer.

    .PARAMETER Root
        Racine du dépôt. Par défaut, la racine du module Common.

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string]$Root
    )

    if ([string]::IsNullOrWhiteSpace($Root)) {
        $Root = Get-HubRoot
    }

    $catalog = @(
        [pscustomobject]@{
            Id               = 'inventory'
            Name             = 'Inventaire système'
            Description      = 'Collecte matériel, système, disques et réseau, puis produit les rapports HTML, CSV et JSON.'
            Script           = 'src\Inventory\Get-SystemInventory.ps1'
            ReportName       = 'System_Inventory'
            Requirement      = $null
            EstimatedSeconds = 10
        }
        [pscustomobject]@{
            Id               = 'security'
            Name             = 'Posture de sécurité'
            Description      = 'Audite les administrateurs locaux, les profils pare-feu, Defender et les mises à jour.'
            Script           = 'src\Security\Get-SecurityPosture.ps1'
            ReportName       = 'Security_Posture'
            Requirement      = $null
            EstimatedSeconds      = 35
        }
        [pscustomobject]@{
            Id               = 'activedirectory'
            Name             = 'Inventaire Active Directory'
            Description      = 'Interroge le domaine : forêt, unités d''organisation, comptes et contrôleurs de domaine.'
            Script           = 'src\ActiveDirectory\Get-ADInventory.ps1'
            ReportName       = 'AD_Inventory'
            Requirement      = 'ActiveDirectory'
            EstimatedSeconds = 45
        }
    )

    foreach ($action in $catalog) {
        $scriptPath = Join-Path -Path $Root -ChildPath $action.Script
        $available = Test-Path -LiteralPath $scriptPath -PathType Leaf
        $reason = $null

        if (-not $available) {
            $reason = 'Script introuvable dans le dépôt.'
        }
        elseif (-not [string]::IsNullOrWhiteSpace($action.Requirement)) {
            $module = Get-Module -ListAvailable -Name $action.Requirement -ErrorAction SilentlyContinue |
                Select-Object -First 1
            if ($null -eq $module) {
                $available = $false
                $reason = ('Module {0} (RSAT) requis.' -f $action.Requirement)
            }
        }

        [pscustomobject]@{
            Id               = $action.Id
            Name             = $action.Name
            Description      = $action.Description
            Script           = $action.Script
            ReportName       = $action.ReportName
            Requirement      = $action.Requirement
            EstimatedSeconds = $action.EstimatedSeconds
            Available        = $available
            Reason           = $reason
        }
    }
}

function Get-HubDashboardReportIndex {
    <#
    .SYNOPSIS
        Indexe les rapports HTML, CSV et JSON générés.

    .PARAMETER Root
        Racine du dépôt. Par défaut, la racine du module Common.

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string]$Root
    )

    if ([string]::IsNullOrWhiteSpace($Root)) {
        $Root = Get-HubRoot
    }

    $index = New-Object System.Collections.Generic.List[object]

    foreach ($type in $script:ReportTypes) {
        $directory = Join-Path -Path (Join-Path -Path $Root -ChildPath 'reports') -ChildPath $type
        if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
            continue
        }

        $files = Get-ChildItem -LiteralPath $directory -File -Filter ('*.{0}' -f $type) -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
            $date = $null
            $reportName = $baseName

            if ($baseName -match '^(\d{4}-\d{2}-\d{2})_(.+)$') {
                $date = $Matches[1]
                $reportName = $Matches[2]
            }

            $index.Add([pscustomobject]@{
                Base     = $baseName
                Name     = ($reportName -replace '_', ' ')
                Type     = $type
                Date     = $date
                FileName = $file.Name
                Size     = $file.Length
                Modified = $file.LastWriteTime.ToString('o')
                Url      = ('/reports/{0}/{1}' -f $type, [System.Uri]::EscapeDataString($file.Name))
            })
        }
    }

    return @($index | Sort-Object -Property Modified -Descending)
}

function Get-HubDashboardLogIndex {
    <#
    .SYNOPSIS
        Indexe les journaux d'exécution les plus récents.

    .PARAMETER Root
        Racine du dépôt. Par défaut, la racine du module Common.

    .PARAMETER MaxItems
        Nombre maximal de journaux retournés. Par défaut 25.

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string]$Root,

        [ValidateRange(1, 500)]
        [int]$MaxItems = 25
    )

    if ([string]::IsNullOrWhiteSpace($Root)) {
        $Root = Get-HubRoot
    }

    $directory = Join-Path -Path $Root -ChildPath 'logs'
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
        return @()
    }

    $logs = Get-ChildItem -LiteralPath $directory -File -Filter '*.log' -ErrorAction SilentlyContinue |
        Sort-Object -Property LastWriteTime -Descending |
        Select-Object -First $MaxItems

    $result = foreach ($log in $logs) {
        [pscustomobject]@{
            Name     = $log.Name
            Size     = $log.Length
            Modified = $log.LastWriteTime.ToString('o')
            Url      = ('/api/log?name={0}' -f [System.Uri]::EscapeDataString($log.Name))
        }
    }

    return @($result)
}

function Resolve-HubDashboardReportPath {
    <#
    .SYNOPSIS
        Résout un chemin de rapport en empêchant toute évasion de répertoire.

    .PARAMETER RelativePath
        Chemin relatif au répertoire reports, par exemple html/rapport.html.

    .PARAMETER Root
        Racine du dépôt. Par défaut, la racine du module Common.

    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RelativePath,

        [string]$Root
    )

    if ([string]::IsNullOrWhiteSpace($Root)) {
        $Root = Get-HubRoot
    }

    $reportsRoot = [System.IO.Path]::GetFullPath((Join-Path -Path $Root -ChildPath 'reports')).TrimEnd('\')
    $normalized = $RelativePath -replace '\\', '/'
    $segments = @($normalized -split '/' | Where-Object { $_ -ne '' })

    if ($segments.Count -ne 2) {
        return $null
    }

    if ($script:ReportTypes -notcontains $segments[0].ToLowerInvariant()) {
        return $null
    }

    if ($segments[1] -notmatch '^[\w\.\-]+\.(html|csv|json)$') {
        return $null
    }

    $candidate = [System.IO.Path]::GetFullPath((Join-Path -Path $reportsRoot -ChildPath ($segments -join '\')))
    $prefix = $reportsRoot + '\'

    if (-not $candidate.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $null
    }

    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        return $null
    }

    return $candidate
}

function Get-HubDashboardLogContent {
    <#
    .SYNOPSIS
        Retourne les dernières lignes d'un journal d'exécution.

    .PARAMETER Name
        Nom du fichier journal, sans chemin.

    .PARAMETER Root
        Racine du dépôt. Par défaut, la racine du module Common.

    .PARAMETER Tail
        Nombre de lignes retournées. Par défaut 200.

    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [string]$Root,

        [ValidateRange(1, 5000)]
        [int]$Tail = 200
    )

    if ($Name -notmatch '^[\w\.\-]+\.log$') {
        throw 'Nom de journal invalide.'
    }

    if ([string]::IsNullOrWhiteSpace($Root)) {
        $Root = Get-HubRoot
    }

    $directory = [System.IO.Path]::GetFullPath((Join-Path -Path $Root -ChildPath 'logs')).TrimEnd('\')
    $candidate = [System.IO.Path]::GetFullPath((Join-Path -Path $directory -ChildPath $Name))

    if (-not $candidate.StartsWith(($directory + '\'), [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'Chemin de journal invalide.'
    }

    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        throw ('Journal introuvable : {0}' -f $Name)
    }

    $lines = Get-Content -LiteralPath $candidate -Tail $Tail -ErrorAction Stop
    return (@($lines) -join "`r`n")
}

function Get-HubDashboardState {
    <#
    .SYNOPSIS
        Construit l'état complet exposé par l'API du dashboard.

    .PARAMETER Root
        Racine du dépôt. Par défaut, la racine du module Common.

    .PARAMETER Port
        Port d'écoute du serveur local.

    .PARAMETER StartedAt
        Date de démarrage du serveur, utilisée pour calculer la disponibilité.

    .OUTPUTS
        System.Collections.Specialized.OrderedDictionary
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [string]$Root,

        [int]$Port = 8080,

        [datetime]$StartedAt = (Get-Date)
    )

    if ([string]::IsNullOrWhiteSpace($Root)) {
        $Root = Get-HubRoot
    }

    $uptime = [math]::Max(0, [math]::Round(((Get-Date) - $StartedAt).TotalSeconds, 0))
    $reports = @(Get-HubDashboardReportIndex -Root $Root)
    $actions = @(Get-HubDashboardAction -Root $Root)
    $logs = @(Get-HubDashboardLogIndex -Root $Root)

    return [ordered]@{
        GeneratedAt = (Get-Date).ToString('o')
        Environment = [ordered]@{
            Machine      = [System.Environment]::MachineName
            User         = [System.Environment]::UserName
            PowerShell   = $PSVersionTable.PSVersion.ToString()
            Edition      = $PSVersionTable.PSEdition
            Root         = $Root
            Port         = $Port
            StartedAt    = $StartedAt.ToString('o')
            UptimeSeconds = $uptime
            Version      = $script:DashboardVersion
        }
        Summary     = [ordered]@{
            Reports  = $reports.Count
            Html     = @($reports | Where-Object { $_.Type -eq 'html' }).Count
            Csv      = @($reports | Where-Object { $_.Type -eq 'csv' }).Count
            Json     = @($reports | Where-Object { $_.Type -eq 'json' }).Count
            Actions  = $actions.Count
            Runnable = @($actions | Where-Object { $_.Available }).Count
            Logs     = $logs.Count
        }
        Reports     = $reports
        Actions     = $actions
        Logs        = $logs
    }
}

function New-HubDashboardPage {
    <#
    .SYNOPSIS
        Assemble la page HTML autonome du dashboard.

    .DESCRIPTION
        Lit le template et concatène la feuille de style des rapports avec
        celle du dashboard, puis injecte le JavaScript. Aucune ressource
        distante n'est référencée.

    .PARAMETER Root
        Racine du dépôt. Par défaut, la racine du module Common.

    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [string]$Root
    )

    if ([string]::IsNullOrWhiteSpace($Root)) {
        $Root = Get-HubRoot
    }

    $assets = [ordered]@{
        Template   = 'assets\templates\dashboard.html'
        ReportCss  = 'assets\css\report.css'
        Dashboard  = 'assets\css\dashboard.css'
        Script     = 'assets\js\dashboard.js'
    }

    foreach ($entry in $assets.GetEnumerator()) {
        $path = Join-Path -Path $Root -ChildPath $entry.Value
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw ('Ressource du dashboard introuvable : {0}' -f $path)
        }
    }

    $template = [System.IO.File]::ReadAllText((Join-Path -Path $Root -ChildPath $assets.Template))
    $stylesheet = [System.IO.File]::ReadAllText((Join-Path -Path $Root -ChildPath $assets.ReportCss))
    $stylesheet += [System.Environment]::NewLine + [System.IO.File]::ReadAllText((Join-Path -Path $Root -ChildPath $assets.Dashboard))
    $dashboardScript = [System.IO.File]::ReadAllText((Join-Path -Path $Root -ChildPath $assets.Script))

    $generated = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture)

    $page = $template
    $page = $page.Replace('{{CSS}}', $stylesheet)
    $page = $page.Replace('{{JS}}', $dashboardScript)
    $page = $page.Replace('{{GENERATED_AT}}', (ConvertTo-HubDashboardText -Value $generated))
    $page = $page.Replace('{{VERSION}}', (ConvertTo-HubDashboardText -Value $script:DashboardVersion))
    $page = $page.Replace('{{MACHINE}}', (ConvertTo-HubDashboardText -Value ([System.Environment]::MachineName)))
    $page = $page.Replace('{{USER}}', (ConvertTo-HubDashboardText -Value ([System.Environment]::UserName)))
    return $page
}

Export-ModuleMember -Function @(
    'Get-HubDashboardAction'
    'Get-HubDashboardReportIndex'
    'Get-HubDashboardLogIndex'
    'Resolve-HubDashboardReportPath'
    'Get-HubDashboardLogContent'
    'Get-HubDashboardState'
    'New-HubDashboardPage'
)
