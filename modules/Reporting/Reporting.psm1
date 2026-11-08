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

    .PARAMETER TableId
        Identifiant HTML du tableau de données (tri et export CSV).

    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [object]$Data,

        [string]$TableId
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

    $tableAttributes = ''
    if (-not [string]::IsNullOrWhiteSpace($TableId)) {
        $safeTableId = $TableId -replace '[^\w\-]', '_'
        $tableAttributes = ' id="{0}"' -f $safeTableId
    }

    $builder = New-Object System.Text.StringBuilder
    [void]$builder.Append(('<table class="grid" data-sortable{0}><thead><tr>' -f $tableAttributes))
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

function Get-HubReportAsset {
    <#
    .SYNOPSIS
        Résout le chemin d'une ressource du framework de rapport.

    .PARAMETER RelativePath
        Chemin relatif à la racine du dépôt, par exemple assets\css\report.css.

    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RelativePath
    )

    $assetPath = Join-Path -Path (Get-HubRoot) -ChildPath $RelativePath
    if (-not (Test-Path -LiteralPath $assetPath -PathType Leaf)) {
        throw ('Ressource de rapport introuvable : {0}. Vérifiez le répertoire assets.' -f $assetPath)
    }

    return $assetPath
}

function ConvertTo-HubJsonLiteral {
    <#
    .SYNOPSIS
        Sérialise une valeur en JSON sûr pour une insertion dans un script HTML.

    .PARAMETER Value
        Valeur à sérialiser.

    .PARAMETER Depth
        Profondeur de sérialisation.

    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [object]$Value,

        [ValidateRange(1, 100)]
        [int]$Depth = 10
    )

    if ($null -eq $Value) {
        return 'null'
    }

    $json = ConvertTo-Json -InputObject $Value -Depth $Depth -Compress
    if ([string]::IsNullOrWhiteSpace($json)) {
        return 'null'
    }

    return ($json -replace '</', '<\/')
}

function New-HubKpiMarkup {
    <#
    .SYNOPSIS
        Construit le balisage des cartes KPI.

    .PARAMETER Kpi
        Collection d'objets comportant Label, Value et, optionnellement, Tone
        (primary, success, warning, danger).

    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [object[]]$Kpi
    )

    if ($null -eq $Kpi -or $Kpi.Count -eq 0) {
        return [string]::Empty
    }

    $builder = New-Object System.Text.StringBuilder
    foreach ($item in $Kpi) {
        if ($null -eq $item) {
            continue
        }

        $label = ConvertTo-HubHtmlText -Value (Get-HubPropertyValue -Object $item -Name 'Label')
        $value = ConvertTo-HubHtmlText -Value (Get-HubPropertyValue -Object $item -Name 'Value')
        $tone = ([string](Get-HubPropertyValue -Object $item -Name 'Tone')).ToLowerInvariant()

        $cardClass = 'kpi'
        $valueClass = 'kpi-value'
        switch ($tone) {
            'success' { $cardClass = 'kpi kpi-success'; $valueClass = 'kpi-value tone-success' }
            'warning' { $cardClass = 'kpi kpi-warning'; $valueClass = 'kpi-value tone-warning' }
            'danger' { $cardClass = 'kpi kpi-danger'; $valueClass = 'kpi-value tone-danger' }
            'primary' { $cardClass = 'kpi kpi-primary'; $valueClass = 'kpi-value tone-primary' }
        }

        [void]$builder.AppendLine(('<article class="{0}"><span class="kpi-label">{1}</span><span class="{2}">{3}</span></article>' -f $cardClass, $label, $valueClass, $value))
    }

    return $builder.ToString()
}

function New-HubChartMarkup {
    <#
    .SYNOPSIS
        Construit le balisage des cartes de graphiques.

    .PARAMETER Charts
        Collection de définitions comportant Id et Title.

    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [object[]]$Charts
    )

    if ($null -eq $Charts -or $Charts.Count -eq 0) {
        return [string]::Empty
    }

    $builder = New-Object System.Text.StringBuilder
    foreach ($chart in $Charts) {
        if ($null -eq $chart) {
            continue
        }

        $id = [string](Get-HubPropertyValue -Object $chart -Name 'Id')
        if ([string]::IsNullOrWhiteSpace($id)) {
            continue
        }

        $safeId = $id -replace '[^\w\-]', '_'
        $title = ConvertTo-HubHtmlText -Value (Get-HubPropertyValue -Object $chart -Name 'Title')

        [void]$builder.AppendLine('<section class="card chart-card">')
        [void]$builder.AppendLine(('  <div class="card-head"><h2>{0}</h2></div>' -f $title))
        [void]$builder.AppendLine(('  <div class="chart-wrap"><canvas id="{0}" role="img" aria-label="{1}"></canvas></div>' -f $safeId, $title))
        [void]$builder.AppendLine('</section>')
    }

    return $builder.ToString()
}

function New-HubHtmlReport {
    <#
    .SYNOPSIS
        Crée un rapport HTML autonome et professionnel.

    .DESCRIPTION
        Assemble un document HTML5 autonome (CSS, JavaScript et Chart.js
        embarqués, aucune ressource externe) à partir de sections nommées.
        Le rendu applique le framework de présentation unifié : dark mode,
        cartes KPI, recherche instantanée, tri des colonnes, export CSV/JSON
        et impression PDF.

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

    .PARAMETER Kpi
        Collection de cartes KPI : Label, Value et Tone optionnel.

    .PARAMETER Charts
        Collection de graphiques : Id, Title, Type (bar, line, doughnut, pie),
        Label, Labels, Values et Color optionnel.

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
        [string]$Footer = 'Rapport généré par scripts-hub',

        [AllowNull()]
        [object[]]$Kpi,

        [AllowNull()]
        [object[]]$Charts
    )

    $sectionsHtml = New-Object System.Text.StringBuilder
    $dataPayload = [ordered]@{}
    $sectionIndex = 0

    foreach ($entry in $Sections.GetEnumerator()) {
        $sectionIndex++
        $sectionName = [string]$entry.Key
        $tableId = 'hub-table-{0}' -f $sectionIndex
        $content = ConvertTo-HubHtmlTable -Data $entry.Value -TableId $tableId
        $actions = ''

        if ($content -match 'data-sortable') {
            $safeSection = $sectionName -replace '[^\w\-]', '_'
            $actions = ('<button type="button" class="btn btn-ghost export-csv" data-table="{0}" data-section="{1}">Exporter CSV</button>' -f $tableId, $safeSection)
        }

        [void]$sectionsHtml.AppendLine(('<section class="card"><div class="card-head"><h2>{0}</h2>{1}</div><div class="table-wrap">{2}</div></section>' -f (ConvertTo-HubHtmlText -Value $sectionName), $actions, $content))
        $dataPayload[$sectionName] = $entry.Value
    }

    $chartDefinitions = New-Object System.Collections.Generic.List[object]
    foreach ($chart in @($Charts)) {
        if ($null -eq $chart) {
            continue
        }

        $chartId = [string](Get-HubPropertyValue -Object $chart -Name 'Id')
        if ([string]::IsNullOrWhiteSpace($chartId)) {
            continue
        }

        $chartType = [string](Get-HubPropertyValue -Object $chart -Name 'Type')
        if ([string]::IsNullOrWhiteSpace($chartType)) {
            $chartType = 'bar'
        }

        $chartColor = [string](Get-HubPropertyValue -Object $chart -Name 'Color')
        if ([string]::IsNullOrWhiteSpace($chartColor)) {
            $chartColor = 'primary'
        }

        $chartDefinitions.Add([ordered]@{
            id     = ($chartId -replace '[^\w\-]', '_')
            type   = $chartType
            label  = [string](Get-HubPropertyValue -Object $chart -Name 'Label')
            labels = @(Get-HubPropertyValue -Object $chart -Name 'Labels')
            values = @(Get-HubPropertyValue -Object $chart -Name 'Values')
            color  = $chartColor
        })
    }

    $template = [System.IO.File]::ReadAllText((Get-HubReportAsset -RelativePath 'assets\templates\report.html'))
    $stylesheet = [System.IO.File]::ReadAllText((Get-HubReportAsset -RelativePath 'assets\css\report.css'))
    $reportScript = [System.IO.File]::ReadAllText((Get-HubReportAsset -RelativePath 'assets\js\report.js'))
    $chartScript = [System.IO.File]::ReadAllText((Get-HubReportAsset -RelativePath 'assets\js\chart.umd.min.js'))

    $reportName = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    if ([string]::IsNullOrWhiteSpace($reportName)) {
        $reportName = 'report'
    }

    $generated = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture)
    $meta = ('<span>Généré le <strong>{0}</strong></span><span>Machine : <strong>{1}</strong></span><span>Opérateur : <strong>{2}</strong></span>' -f $generated, (ConvertTo-HubHtmlText -Value ([System.Environment]::MachineName)), (ConvertTo-HubHtmlText -Value ([System.Environment]::UserName)))

    $document = $template
    $document = $document.Replace('{{TITLE}}', (ConvertTo-HubHtmlText -Value $Title))
    $document = $document.Replace('{{SUBTITLE}}', (ConvertTo-HubHtmlText -Value $Subtitle))
    $document = $document.Replace('{{META}}', $meta)
    $document = $document.Replace('{{REPORT_NAME}}', (ConvertTo-HubHtmlText -Value $reportName))
    $document = $document.Replace('{{KPI}}', (New-HubKpiMarkup -Kpi $Kpi))
    $document = $document.Replace('{{CHARTS}}', (New-HubChartMarkup -Charts $Charts))
    $document = $document.Replace('{{SECTIONS}}', $sectionsHtml.ToString())
    $document = $document.Replace('{{FOOTER}}', (ConvertTo-HubHtmlText -Value $Footer))
    $document = $document.Replace('{{CSS}}', $stylesheet)
    $document = $document.Replace('{{CHARTJS}}', $chartScript)
    $document = $document.Replace('{{REPORT_JS}}', $reportScript)
    $document = $document.Replace('{{DATA_JSON}}', (ConvertTo-HubJsonLiteral -Value $dataPayload -Depth 10))
    $document = $document.Replace('{{CHARTS_JSON}}', (ConvertTo-HubJsonLiteral -Value @($chartDefinitions.ToArray()) -Depth 6))

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

    .PARAMETER Kpi
        Cartes KPI transmises au rapport HTML.

    .PARAMETER Charts
        Graphiques transmis au rapport HTML.

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

        [string]$DateStamp = (Get-HubTimestamp -Format 'yyyy-MM-dd'),

        [AllowNull()]
        [object[]]$Kpi,

        [AllowNull()]
        [object[]]$Charts
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
            $paths.Html = New-HubHtmlReport -Title $Title -Sections ([ordered]@{ 'Données' = $data }) -Path $htmlPath -Kpi $Kpi -Charts $Charts
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
