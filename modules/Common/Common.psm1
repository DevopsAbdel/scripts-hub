#Requires -Version 5.1
<#
.SYNOPSIS
    Fonctions transverses du hub : racine, journalisation, configuration et audit.

.DESCRIPTION
    Module de socle utilisé par tous les scripts et modules de scripts-hub.
    Il centralise la résolution de la racine du dépôt, l'horodatage, la
    journalisation, la résolution des chemins de rapports, le chargement de la
    configuration et l'audit de l'environnement d'exécution.

.NOTES
    Author  : Scripts-Hub
    Version : 1.0.0
    Date    : 2026-11-08
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:HubRoot = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath '..\..')).TrimEnd('\')

function Get-HubRoot {
    <#
    .SYNOPSIS
        Retourne le chemin absolu de la racine du dépôt scripts-hub.

    .DESCRIPTION
        La racine est déduite de l'emplacement du module (modules/Common) et
        mise en cache au chargement du module.

    .EXAMPLE
        PS> Get-HubRoot
        D:\00_Inbox\scripts-hub

    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    return $script:HubRoot
}

function Get-HubTimestamp {
    <#
    .SYNOPSIS
        Retourne l'horodatage courant au format demandé.

    .DESCRIPTION
        Utilise la culture invariante afin de produire des noms de fichiers
        stables quel que soit le profil régional de la machine.

    .PARAMETER Format
        Chaîne de format .NET. Valeur par défaut : yyyy-MM-dd_HHmmss.

    .EXAMPLE
        PS> Get-HubTimestamp -Format 'yyyy-MM-dd'
        2026-11-08

    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [ValidateNotNullOrEmpty()]
        [string]$Format = 'yyyy-MM-dd_HHmmss'
    )

    return (Get-Date).ToString($Format, [System.Globalization.CultureInfo]::InvariantCulture)
}

function New-HubDirectory {
    <#
    .SYNOPSIS
        Crée un répertoire de façon idempotente.

    .DESCRIPTION
        Vérifie l'existence du répertoire avant création. La fonction ne lève
        pas d'erreur si le répertoire existe déjà et retourne son chemin absolu.

    .PARAMETER Path
        Chemin du répertoire à créer.

    .EXAMPLE
        PS> New-HubDirectory -Path (Join-Path (Get-HubRoot) 'logs')

    .OUTPUTS
        System.String
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        if ($PSCmdlet.ShouldProcess($Path, 'Créer le répertoire')) {
            New-Item -ItemType Directory -Path $Path -Force | Out-Null
        }
    }

    return [System.IO.Path]::GetFullPath($Path)
}

function Write-HubLog {
    <#
    .SYNOPSIS
        Écrit un message journalisé sur la console et/ou dans un fichier.

    .DESCRIPTION
        Produit une ligne horodatée au format [date] [niveau] message.
        L'écriture fichier utilise UTF-8 ; le répertoire parent est créé
        automatiquement si nécessaire.

    .PARAMETER Message
        Message à journaliser. Accepte l'entrée du pipeline.

    .PARAMETER Level
        Niveau de gravité : DEBUG, INFO, WARNING ou ERROR.

    .PARAMETER Path
        Fichier de journal cible. Si omis, seule la console est utilisée.

    .PARAMETER NoConsole
        Supprime l'affichage console et conserve uniquement l'écriture fichier.

    .EXAMPLE
        PS> Write-HubLog -Message 'Démarrage' -Level INFO -Path .\logs\run.log

    .EXAMPLE
        PS> 'Ligne 1', 'Ligne 2' | Write-HubLog -Path .\logs\run.log

    .OUTPUTS
        None
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [AllowEmptyString()]
        [string]$Message,

        [ValidateSet('DEBUG', 'INFO', 'WARNING', 'ERROR')]
        [string]$Level = 'INFO',

        [string]$Path,

        [switch]$NoConsole
    )

    begin {
        $culture = [System.Globalization.CultureInfo]::InvariantCulture
    }

    process {
        $line = '[{0}] [{1}] {2}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss', $culture), $Level, $Message

        if (-not $NoConsole) {
            switch ($Level) {
                'ERROR' { Write-Host $line -ForegroundColor Red }
                'WARNING' { Write-Host $line -ForegroundColor Yellow }
                'DEBUG' { Write-Host $line -ForegroundColor DarkGray }
                default { Write-Host $line }
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($Path)) {
            $parent = Split-Path -Path $Path -Parent
            if (-not [string]::IsNullOrWhiteSpace($parent)) {
                New-HubDirectory -Path $parent -Confirm:$false | Out-Null
            }
            Add-Content -LiteralPath $Path -Value $line -Encoding UTF8
        }
    }
}

function Get-HubReportPath {
    <#
    .SYNOPSIS
        Construit le chemin horodaté d'un rapport.

    .DESCRIPTION
        Applique la convention YYYY-MM-DD_Type_Rapport.ext sous reports\<format>,
        crée le répertoire cible et retourne le chemin absolu.

    .PARAMETER Name
        Nom logique du rapport, par exemple AD_Inventory.

    .PARAMETER Format
        Extension cible : html, csv ou json.

    .PARAMETER DateStamp
        Date au format yyyy-MM-dd. Par défaut, date du jour.

    .PARAMETER Root
        Racine du dépôt. Par défaut, la racine du module.

    .EXAMPLE
        PS> Get-HubReportPath -Name 'AD_Inventory' -Format 'html'
        D:\00_Inbox\scripts-hub\reports\html\2026-11-08_AD_Inventory.html

    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [ValidateSet('html', 'csv', 'json')]
        [string]$Format = 'html',

        [ValidateNotNullOrEmpty()]
        [string]$DateStamp = (Get-HubTimestamp -Format 'yyyy-MM-dd'),

        [string]$Root
    )

    if ([string]::IsNullOrWhiteSpace($Root)) {
        $Root = $script:HubRoot
    }

    $safeName = $Name -replace '[^\w\-\.]', '_'
    $directory = Join-Path -Path (Join-Path -Path $Root -ChildPath 'reports') -ChildPath $Format
    New-HubDirectory -Path $directory -Confirm:$false | Out-Null

    $fileName = '{0}_{1}.{2}' -f $DateStamp, $safeName, $Format
    return [System.IO.Path]::GetFullPath((Join-Path -Path $directory -ChildPath $fileName))
}

function Join-HubSettingsData {
    <#
    .SYNOPSIS
        Fusionne récursivement deux dictionnaires de configuration.

    .DESCRIPTION
        Fonction interne au module. Les clés du dictionnaire de surcharge
        écrasent celles du dictionnaire de base ; les tables imbriquées sont
        fusionnées clé par clé.

    .PARAMETER Base
        Dictionnaire de base.

    .PARAMETER Override
        Dictionnaire de surcharge.

    .OUTPUTS
        System.Collections.Hashtable
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Base,

        [Parameter(Mandatory = $true)]
        [hashtable]$Override
    )

    $result = @{}
    foreach ($key in $Base.Keys) {
        $result[$key] = $Base[$key]
    }

    foreach ($key in $Override.Keys) {
        $value = $Override[$key]
        if ($value -is [hashtable] -and $result.ContainsKey($key) -and $result[$key] -is [hashtable]) {
            $result[$key] = Join-HubSettingsData -Base $result[$key] -Override $value
        }
        else {
            $result[$key] = $value
        }
    }

    return $result
}

function Get-HubConfig {
    <#
    .SYNOPSIS
        Charge la configuration du hub pour un environnement donné.

    .DESCRIPTION
        Lit config/settings/default.psd1 puis, si un environnement est précisé,
        fusionne config/environments/<environnement>.psd1 par-dessus.
        Les fichiers absents du répertoire environments provoquent une erreur
        explicite.

    .PARAMETER Environment
        Nom de l'environnement : default, lab, prod, etc.

    .PARAMETER Root
        Racine du dépôt. Par défaut, la racine du module.

    .EXAMPLE
        PS> Get-HubConfig -Environment 'lab'

    .OUTPUTS
        System.Collections.Hashtable
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [ValidateNotNullOrEmpty()]
        [string]$Environment = 'default',

        [string]$Root
    )

    if ([string]::IsNullOrWhiteSpace($Root)) {
        $Root = $script:HubRoot
    }

    $config = @{}
    $settingsDirectory = Join-Path -Path (Join-Path -Path $Root -ChildPath 'config') -ChildPath 'settings'
    $defaultPath = Join-Path -Path $settingsDirectory -ChildPath 'default.psd1'

    if (Test-Path -LiteralPath $defaultPath -PathType Leaf) {
        $defaultData = Import-PowerShellDataFile -LiteralPath $defaultPath
        $config = Join-HubSettingsData -Base $config -Override $defaultData
    }

    if ($Environment -ne 'default') {
        $environmentsDirectory = Join-Path -Path (Join-Path -Path $Root -ChildPath 'config') -ChildPath 'environments'
        $environmentPath = Join-Path -Path $environmentsDirectory -ChildPath ('{0}.psd1' -f $Environment)

        if (-not (Test-Path -LiteralPath $environmentPath -PathType Leaf)) {
            throw ('Environnement introuvable : {0} ({1})' -f $Environment, $environmentPath)
        }

        $environmentData = Import-PowerShellDataFile -LiteralPath $environmentPath
        $config = Join-HubSettingsData -Base $config -Override $environmentData
    }

    return $config
}

function Get-HubRunContext {
    <#
    .SYNOPSIS
        Prépare le contexte d'exécution d'un script du hub.

    .DESCRIPTION
        Calcule un identifiant d'exécution, prépare le chemin du journal et les
        chemins de rapports HTML, CSV et JSON, puis crée les répertoires requis.

    .PARAMETER Name
        Nom logique de l'exécution, par exemple Get-SystemInventory.

    .PARAMETER Environment
        Environnement de configuration associé.

    .PARAMETER Root
        Racine du dépôt. Par défaut, la racine du module.

    .EXAMPLE
        PS> $context = Get-HubRunContext -Name 'Get-SystemInventory'
        PS> Write-HubLog -Message 'Démarrage' -Path $context.LogPath

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [ValidateNotNullOrEmpty()]
        [string]$Environment = 'default',

        [string]$Root
    )

    if ([string]::IsNullOrWhiteSpace($Root)) {
        $Root = $script:HubRoot
    }

    $dateStamp = Get-HubTimestamp -Format 'yyyy-MM-dd'
    $logDirectory = Join-Path -Path $Root -ChildPath 'logs'
    New-HubDirectory -Path $logDirectory -Confirm:$false | Out-Null

    $safeName = $Name -replace '[^\w\-\.]', '_'
    $logPath = Join-Path -Path $logDirectory -ChildPath ('{0}_{1}.log' -f $dateStamp, $safeName)

    return [pscustomobject]@{
        Name        = $Name
        RunId       = Get-HubTimestamp -Format 'yyyyMMdd_HHmmss'
        StartedAt   = Get-Date
        Environment = $Environment
        Root        = $Root
        LogPath     = $logPath
        HtmlPath    = Get-HubReportPath -Name $safeName -Format 'html' -DateStamp $dateStamp -Root $Root
        CsvPath     = Get-HubReportPath -Name $safeName -Format 'csv' -DateStamp $dateStamp -Root $Root
        JsonPath    = Get-HubReportPath -Name $safeName -Format 'json' -DateStamp $dateStamp -Root $Root
    }
}

function Test-HubEnvironment {
    <#
    .SYNOPSIS
        Audite l'environnement d'exécution PowerShell, .NET et Git.

    .DESCRIPTION
        Vérifie la version et l'architecture PowerShell, la disponibilité des
        assemblys .NET utilisés par les rapports, et l'état du dépôt Git.
        Ne modifie aucun état.

    .PARAMETER Root
        Racine du dépôt à auditer. Par défaut, la racine du module.

    .EXAMPLE
        PS> Test-HubEnvironment | Format-List

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string]$Root
    )

    if ([string]::IsNullOrWhiteSpace($Root)) {
        $Root = $script:HubRoot
    }

    $result = [ordered]@{
        Timestamp         = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture)
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        PSEdition         = $PSVersionTable.PSEdition
        Is64BitProcess    = [System.Environment]::Is64BitProcess
        OperatingSystem   = [System.Environment]::OSVersion.VersionString
        Root              = $Root
        GitVersion        = $null
        IsGitRepository   = $false
        GitBranch         = $null
        GitRemote         = $null
        Assemblies        = [ordered]@{}
    }

    foreach ($assemblyName in @('System.Windows.Forms', 'System.Drawing', 'System.Web')) {
        try {
            Add-Type -AssemblyName $assemblyName -ErrorAction Stop
            $result.Assemblies[$assemblyName] = 'Présent'
        }
        catch {
            $result.Assemblies[$assemblyName] = 'Absent'
        }
    }

    $gitCommand = Get-Command -Name 'git' -ErrorAction SilentlyContinue
    if ($null -ne $gitCommand) {
        $gitVersion = & git --version 2>$null
        if ($LASTEXITCODE -eq 0 -and $gitVersion) {
            $result.GitVersion = [string]$gitVersion
        }

        $isRepository = & git -C $Root rev-parse --is-inside-work-tree 2>$null
        if ($LASTEXITCODE -eq 0 -and ([string]$isRepository).Trim() -eq 'true') {
            $result.IsGitRepository = $true
            $result.GitBranch = ([string](& git -C $Root rev-parse --abbrev-ref HEAD 2>$null)).Trim()
            $result.GitRemote = ([string](& git -C $Root config --get remote.origin.url 2>$null)).Trim()
        }
    }

    return [pscustomobject]$result
}

Export-ModuleMember -Function @(
    'Get-HubRoot'
    'Get-HubTimestamp'
    'New-HubDirectory'
    'Write-HubLog'
    'Get-HubReportPath'
    'Get-HubConfig'
    'Get-HubRunContext'
    'Test-HubEnvironment'
)
