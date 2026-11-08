#Requires -Version 5.1
<#
.SYNOPSIS
    Génération de rapports HTML autonomes et exports CSV / JSON.

.DESCRIPTION
    Module de restitution de scripts-hub. Il produit des rapports HTML
    autonomes (sans dépendance externe), des exports CSV prêts pour Excel FR
    et des exports JSON structurés. Tous les fichiers sont écrits en UTF-8
    avec BOM.

.NOTES
    Author  : Scripts-Hub
    Version : 1.0.0
    Date    : 2026-11-08
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\Common\Common.psd1') -ErrorAction Stop

function ConvertTo-HubHtmlText {
    <#
    .SYNOPSIS
        Échappe une valeur pour une insertion sûre dans un document HTML.

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

function ConvertTo-HubDisplayValue {
    <#
    .SYNOPSIS
        Convertit une valeur quelconque en texte lisible par un humain.

    .PARAMETER Value
        Valeur à convertir.

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
        return '—'
    }

    if ($Value -is [bool]) {
        if ($Value) {
            return 'Oui'
        }
        return 'Non'
    }

    if ($Value -is [datetime]) {
        return $Value.ToString('yyyy-MM-dd HH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture)
    }

    if ($Value -is [System.Collections.IDictionary]) {
        $pairs = foreach ($key in $Value.Keys) {
            '{0}={1}' -f $key, $Value[$key]
        }
        return ($pairs -join '; ')
    }

    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        $elements = foreach ($element in $Value) {
            [string]$element
        }
        return ($elements -join ', ')
    }

    return [string]$Value
}

function Get-HubPropertyValue {
    <#
    .SYNOPSIS
        Lit une propriété ou une clé sur un objet quelconque.

    .PARAMETER Object
        Objet source.

    .PARAMETER Name
        Nom de la propriété ou de la clé.

    .OUTPUTS
        System.Object
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [AllowNull()]
        [object]$Object,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($null -eq $Object) {
        return $null
    }

    if ($Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($Name)) {
            return $Object[$Name]
        }
        return $null
    }

    $property = $Object.PSObject.Properties[$Name]
    if ($null -ne $property) {
        return $property.Value
    }

    return $null
}

function ConvertTo-HubHtmlTable {
    <#
    .SYNOPSIS
        Convertit un objet ou une collection en tableau HTML.

    .DESCRIPTION
        Une collection produit un tableau à une ligne par élément. Un objet
        unique produit un tableau clé / valeur. Les valeurs sont échappées.

    .PARAMETER Data
        Données à rendre.

    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [object]$Data
    )

    if ($null -eq $Data) {
        return '<p class="empty">Aucune donnée.</p>'
    }

    $items = @($Data)
    if ($items.Count -eq 0) {
        return '<p class="empty">Aucune donnée.</p>'
    }

    $isCollection = $Data -is [System.Collections.IEnumerable] -and -not ($Data -is [string])

    if (-not $isCollection) {
        $item = $items[0]
        $keys = @()
        if ($item -is [System.Collections.IDictionary]) {
            $keys = @($item.Keys)
        }
        else {
            $keys = @($item.PSObject.Properties | ForEach-Object { $_.Name })
        }

        $builder = New-Object System.Text.StringBuilder
        [void]$builder.AppendLine('<table class="kv"><tbody>')
        foreach ($key in $keys) {
            $value = ConvertTo-HubDisplayValue -Value (Get-HubPropertyValue -Object $item -Name $key)
            [void]$builder.AppendLine(('  <tr><th>{0}</th><td>{1}</td></tr>' -f (ConvertTo-HubHtmlText -Value $key), (ConvertTo-HubHtmlText -Value $value)))
        }
        [void]$builder.AppendLine('</tbody></table>')
        return $builder.ToString()
    }

    $propertyNames = New-Object System.Collections.Generic.List[string]
    foreach ($item in $items) {
        $names = @()
        if ($item -is [System.Collections.IDictionary]) {
            $names = @($item.Keys)
        }
        elseif (-not ($item -is [string]) -and -not ($item -is [ValueType])) {
            $names = @($item.PSObject.Properties | ForEach-Object { $_.Name })
        }

        foreach ($name in $names) {
            if (-not $propertyNames.Contains([string]$name)) {
                $propertyNames.Add([string]$name)
            }
        }
    }

    if ($propertyNames.Count -eq 0) {
        $propertyNames.Add('Valeur')
    }

    $builder = New-Object System.Text.StringBuilder
    [void]$builder.Append('<table class="grid"><thead><tr>')
    foreach ($name in $propertyNames) {
        [void]$builder.Append(('<th>{0}</th>' -f (ConvertTo-HubHtmlText -Value $name)))
    }
    [void]$builder.AppendLine('</tr></thead><tbody>')

    foreach ($item in $items) {
        [void]$builder.Append('  <tr>')
        foreach ($name in $propertyNames) {
            if ($name -eq 'Valeur' -and $propertyNames.Count -eq 1 -and -not ($item -is [System.Collections.IDictionary])) {
                $value = ConvertTo-HubDisplayValue -Value $item
            }
            else {
                $value = ConvertTo-HubDisplayValue -Value (Get-HubPropertyValue -Object $item -Name $name)
            }
            [void]$builder.Append(('<td>{0}</td>' -f (ConvertTo-HubHtmlText -Value $value)))
        }
        [void]$builder.AppendLine('</tr>')
    }

    [void]$builder.AppendLine('</tbody></table>')
    return $builder.ToString()
}

function New-HubHtmlReport {
    <#
    .SYNOPSIS
        Crée un rapport HTML autonome et professionnel.

    .DESCRIPTION
        Assemble un document HTML5 autonome (CSS embarqué, aucune ressource
        externe) à partir de sections nommées. Chaque section est rendue sous
        forme de tableau clé / valeur ou de tableau de données.

    .PARAMETER Title
        Titre principal du rapport.

    .PARAMETER Sections
        Dictionnaire ordonné nom de section / données.

    .PARAMETER Path
        Chemin complet du fichier HTML à produire.

    .PARAMETER Subtitle
        Sous-titre optionnel.

    .PARAMETER Footer
        Texte de pied de page.

    .EXAMPLE
        PS> New-HubHtmlReport -Title 'Inventaire' -Path .\reports\html\2026-11-08_Inventory.html -Sections ([ordered]@{ 'Système' = $system })

    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Title,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.Collections.IDictionary]$Sections,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [string]$Subtitle,
        [string]$Footer = 'Rapport généré par scripts-hub'
    )

    $sectionsHtml = New-Object System.Text.StringBuilder
    foreach ($entry in $Sections.GetEnumerator()) {
        $content = ConvertTo-HubHtmlTable -Data $entry.Value
        [void]$sectionsHtml.AppendLine(('<section class="card"><h2>{0}</h2>{1}</section>' -f (ConvertTo-HubHtmlText -Value $entry.Key), $content))
    }

    $template = @'
<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{{TITLE}}</title>
<style>
  :root { color-scheme: light; }
  * { box-sizing: border-box; }
  body {
    margin: 0; padding: 0 24px 48px;
    font-family: "Segoe UI", "Helvetica Neue", Arial, sans-serif;
    font-size: 14px; line-height: 1.5;
    color: #1f2937; background: #f4f6f9;
  }
  header { padding: 32px 0 16px; border-bottom: 3px solid #2563eb; margin-bottom: 24px; }
  h1 { margin: 0 0 4px; font-size: 26px; color: #0f172a; }
  .subtitle { margin: 0; color: #4b5563; font-size: 15px; }
  .meta { margin-top: 12px; color: #6b7280; font-size: 12px; }
  .meta span { margin-right: 16px; }
  .card {
    background: #ffffff; border: 1px solid #e5e7eb; border-radius: 8px;
    padding: 16px 20px; margin-bottom: 20px;
    box-shadow: 0 1px 2px rgba(15, 23, 42, 0.06);
  }
  h2 { margin: 0 0 12px; font-size: 16px; color: #1d4ed8; text-transform: uppercase; letter-spacing: .04em; }
  table { width: 100%; border-collapse: collapse; }
  th, td { text-align: left; padding: 6px 10px; border-bottom: 1px solid #eef2f7; vertical-align: top; }
  thead th { background: #f8fafc; color: #334155; font-weight: 600; white-space: nowrap; border-bottom: 2px solid #e2e8f0; }
  tbody tr:nth-child(even) { background: #fbfcfe; }
  table.kv th { width: 30%; color: #475569; font-weight: 600; }
  td { word-break: break-word; }
  .empty { color: #6b7280; font-style: italic; margin: 0; }
  footer { margin-top: 8px; color: #6b7280; font-size: 12px; }
  @media print {
    body { background: #ffffff; padding: 0; }
    .card { break-inside: avoid; box-shadow: none; }
  }
</style>
</head>
<body>
<header>
  <h1>{{TITLE}}</h1>
  <p class="subtitle">{{SUBTITLE}}</p>
  <div class="meta"><span>Généré le {{GENERATED}}</span><span>Machine : {{HOST}}</span><span>Opérateur : {{USER}}</span></div>
</header>
<main>
{{SECTIONS}}
</main>
<footer>{{FOOTER}}</footer>
</body>
</html>
'@

    $generated = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture)
    $document = $template.Replace('{{TITLE}}', (ConvertTo-HubHtmlText -Value $Title))
    $document = $document.Replace('{{SUBTITLE}}', (ConvertTo-HubHtmlText -Value $Subtitle))
    $document = $document.Replace('{{GENERATED}}', $generated)
    $document = $document.Replace('{{HOST}}', (ConvertTo-HubHtmlText -Value ([System.Environment]::MachineName)))
    $document = $document.Replace('{{USER}}', (ConvertTo-HubHtmlText -Value ([System.Environment]::UserName)))
    $document = $document.Replace('{{SECTIONS}}', $sectionsHtml.ToString())
    $document = $document.Replace('{{FOOTER}}', (ConvertTo-HubHtmlText -Value $Footer))

    $parent = Split-Path -Path $Path -Parent
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        New-HubDirectory -Path $parent -Confirm:$false | Out-Null
    }

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    [System.IO.File]::WriteAllText($fullPath, $document, (New-Object System.Text.UTF8Encoding($true)))
    return $fullPath
}

function Export-HubCsv {
    <#
    .SYNOPSIS
        Exporte des objets vers un fichier CSV UTF-8 avec BOM.

    .DESCRIPTION
        Utilise le séparateur ';' par défaut pour une ouverture directe dans
        un tableur configuré en français.

    .PARAMETER InputObject
        Objets à exporter. Accepte l'entrée du pipeline.

    .PARAMETER Path
        Chemin complet du fichier CSV.

    .PARAMETER Delimiter
        Séparateur de colonnes. Par défaut ';'.

    .EXAMPLE
        PS> $items | Export-HubCsv -Path .\reports\csv\2026-11-08_Inventory.csv

    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [AllowNull()]
        [object]$InputObject,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [char]$Delimiter = ';'
    )

    begin {
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
            Write-Warning 'Export-HubCsv : aucune donnée à exporter.'
            return $null
        }

        $parent = Split-Path -Path $Path -Parent
        if (-not [string]::IsNullOrWhiteSpace($parent)) {
            New-HubDirectory -Path $parent -Confirm:$false | Out-Null
        }

        $lines = @($items.ToArray() | ConvertTo-Csv -NoTypeInformation -Delimiter $Delimiter)
        $fullPath = [System.IO.Path]::GetFullPath($Path)
        [System.IO.File]::WriteAllLines($fullPath, [string[]]$lines, (New-Object System.Text.UTF8Encoding($true)))
        return $fullPath
    }
}

function Export-HubJson {
    <#
    .SYNOPSIS
        Exporte des objets vers un fichier JSON UTF-8 avec BOM.

    .PARAMETER InputObject
        Objets à exporter. Accepte l'entrée du pipeline.

    .PARAMETER Path
        Chemin complet du fichier JSON.

    .PARAMETER Depth
        Profondeur de sérialisation. Par défaut 8.

    .EXAMPLE
        PS> $items | Export-HubJson -Path .\reports\json\2026-11-08_Inventory.json

    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [AllowNull()]
        [object]$InputObject,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [ValidateRange(1, 100)]
        [int]$Depth = 8
    )

    begin {
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
            Write-Warning 'Export-HubJson : aucune donnée à exporter.'
            return $null
        }

        $parent = Split-Path -Path $Path -Parent
        if (-not [string]::IsNullOrWhiteSpace($parent)) {
            New-HubDirectory -Path $parent -Confirm:$false | Out-Null
        }

        $json = ConvertTo-Json -InputObject @($items.ToArray()) -Depth $Depth
        $fullPath = [System.IO.Path]::GetFullPath($Path)
        [System.IO.File]::WriteAllText($fullPath, $json, (New-Object System.Text.UTF8Encoding($true)))
        return $fullPath
    }
}

function Export-HubReport {
    <#
    .SYNOPSIS
        Produit un ou plusieurs rapports horodatés (HTML, CSV, JSON).

    .DESCRIPTION
        Orchestre la génération des livrables à partir d'une collection
        d'objets. Les chemins respectent la convention
        YYYY-MM-DD_Type_Rapport.ext.

    .PARAMETER InputObject
        Données du rapport. Accepte l'entrée du pipeline.

    .PARAMETER Name
        Nom logique du rapport, par exemple System_Inventory.

    .PARAMETER Format
        Formats à produire : Html, Csv, Json ou All.

    .PARAMETER Title
        Titre du rapport HTML. Par défaut, le nom logique.

    .PARAMETER Root
        Racine du dépôt. Par défaut, la racine détectée par le module Common.

    .PARAMETER DateStamp
        Date au format yyyy-MM-dd utilisée dans les noms de fichiers.

    .EXAMPLE
        PS> $data | Export-HubReport -Name 'System_Inventory' -Format All

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [AllowNull()]
        [object]$InputObject,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [ValidateSet('Html', 'Csv', 'Json', 'All')]
        [string]$Format = 'All',

        [string]$Title,

        [string]$Root,

        [string]$DateStamp = (Get-HubTimestamp -Format 'yyyy-MM-dd')
    )

    begin {
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
            Write-Warning 'Export-HubReport : aucune donnée à exporter.'
            return $null
        }

        if ([string]::IsNullOrWhiteSpace($Title)) {
            $Title = $Name
        }

        $data = $items.ToArray()
        $paths = [ordered]@{
            Name  = $Name
            Html  = $null
            Csv   = $null
            Json  = $null
        }

        if ($Format -eq 'Html' -or $Format -eq 'All') {
            $htmlPath = Get-HubReportPath -Name $Name -Format 'html' -DateStamp $DateStamp -Root $Root
            $paths.Html = New-HubHtmlReport -Title $Title -Sections ([ordered]@{ 'Données' = $data }) -Path $htmlPath
        }

        if ($Format -eq 'Csv' -or $Format -eq 'All') {
            $csvPath = Get-HubReportPath -Name $Name -Format 'csv' -DateStamp $DateStamp -Root $Root
            $paths.Csv = Export-HubCsv -InputObject $data -Path $csvPath
        }

        if ($Format -eq 'Json' -or $Format -eq 'All') {
            $jsonPath = Get-HubReportPath -Name $Name -Format 'json' -DateStamp $DateStamp -Root $Root
            $paths.Json = Export-HubJson -InputObject $data -Path $jsonPath
        }

        return [pscustomobject]$paths
    }
}

Export-ModuleMember -Function @(
    'New-HubHtmlReport'
    'Export-HubCsv'
    'Export-HubJson'
    'Export-HubReport'
)
