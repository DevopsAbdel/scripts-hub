#Requires -Version 5.1
<#
.SYNOPSIS
    Génère un rapport HTML autonome à partir d'objets PowerShell.

.DESCRIPTION
    Script générique de restitution : accepte une collection d'objets en entrée
    du pipeline, construit un rapport HTML professionnel et retourne le chemin
    du fichier produit. Les données ne sont jamais modifiées.

.PARAMETER InputObject
    Données à restituer. Accepte l'entrée du pipeline.

.PARAMETER Title
    Titre principal du rapport.

.PARAMETER Name
    Nom logique utilisé pour le fichier (convention YYYY-MM-DD_Nom.html).

.PARAMETER SectionTitle
    Titre de la section de données. Par défaut : Données.

.PARAMETER OutputPath
    Chemin complet du fichier HTML. Prioritaire sur OutputDirectory.

.PARAMETER OutputDirectory
    Répertoire de destination. Par défaut : reports\html.

.PARAMETER Kpi
    Cartes KPI optionnelles (Label, Value, Tone).

.PARAMETER Charts
    Graphiques optionnels (Id, Title, Type, Label, Labels, Values, Color).

.EXAMPLE
    PS> Get-Service | Select-Object -First 10 | .\src\Reporting\New-HTMLReport.ps1 -Title 'Services' -Name 'Services'

.EXAMPLE
    PS> .\src\Reporting\New-HTMLReport.ps1 -InputObject $data -Title 'Audit' -OutputPath .\reports\html\2026-11-08_Audit.html

.NOTES
    Author  : Scripts-Hub
    Version : 1.0.0
    Date    : 2026-11-08
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [AllowNull()]
    [object]$InputObject,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Title,

    [ValidateNotNullOrEmpty()]
    [string]$Name = 'Report',

    [ValidateNotNullOrEmpty()]
    [string]$SectionTitle = 'Données',

    [string]$OutputPath,

    [string]$OutputDirectory,

    [AllowNull()]
    [object[]]$Kpi,

    [AllowNull()]
    [object[]]$Charts
)

begin {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    $scriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
    $hubRoot = Split-Path -Path (Split-Path -Path $scriptDirectory -Parent) -Parent

    Import-Module -Name (Join-Path -Path $hubRoot -ChildPath 'modules\Common\Common.psd1') -Force
    Import-Module -Name (Join-Path -Path $hubRoot -ChildPath 'modules\Reporting\Reporting.psd1') -Force

    $items = New-Object System.Collections.Generic.List[object]
}

process {
    if ($null -eq $InputObject) {
        return
    }

    $isCollection = $InputObject -is [System.Collections.IEnumerable] -and
        -not ($InputObject -is [string]) -and
        -not ($InputObject -is [System.Collections.IDictionary])

    if ($isCollection) {
        foreach ($element in $InputObject) {
            if ($null -ne $element) {
                $items.Add($element)
            }
        }
    }
    else {
        $items.Add($InputObject)
    }
}

end {
    if ($items.Count -eq 0) {
        throw 'New-HTMLReport : aucune donnée à restituer.'
    }

    if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
        $targetPath = $OutputPath
    }
    elseif (-not [string]::IsNullOrWhiteSpace($OutputDirectory)) {
        $directory = New-HubDirectory -Path $OutputDirectory
        $targetPath = Join-Path -Path $directory -ChildPath ('{0}_{1}.html' -f (Get-HubTimestamp -Format 'yyyy-MM-dd'), $Name)
    }
    else {
        $targetPath = Get-HubReportPath -Name $Name -Format 'html' -Root $hubRoot
    }

    $reportPath = New-HubHtmlReport -Title $Title -Sections ([ordered]@{ $SectionTitle = $items.ToArray() }) -Path $targetPath -Kpi $Kpi -Charts $Charts
    Write-HubLog -Message ('Rapport HTML : {0}' -f $reportPath)

    $reportPath
}
