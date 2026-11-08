#Requires -Version 5.1
<#
.SYNOPSIS
    Vérifie la conformité, la qualité statique et les tests du dépôt.

.DESCRIPTION
    Exécute les contrôles suivants :
      1. présence du BOM UTF-8 sur les fichiers texte ;
      2. présence de l'en-tête d'aide obligatoire sur les .ps1 et .psm1 ;
      3. analyse statique PSScriptAnalyzer (si le module est installé) ;
      4. tests Pester (si Pester 5+ est installé).
    Retourne un code de sortie non nul en cas d'échec.

.PARAMETER SkipTests
    Ignore l'exécution des tests Pester.

.PARAMETER SkipAnalyzer
    Ignore l'analyse statique PSScriptAnalyzer.

.EXAMPLE
    PS> .\tools\build\Build.ps1

.EXAMPLE
    PS> .\tools\build\Build.ps1 -SkipTests

.NOTES
    Author  : Scripts-Hub
    Version : 1.0.0
    Date    : 2026-11-08
#>

[CmdletBinding()]
param(
    [switch]$SkipTests,
    [switch]$SkipAnalyzer
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$buildDirectory = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$hubRoot = Split-Path -Path (Split-Path -Path $buildDirectory -Parent) -Parent

Import-Module -Name (Join-Path -Path $hubRoot -ChildPath 'modules\Common\Common.psd1') -Force

$failures = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]
$startTime = Get-Date

function Test-FileConformance {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root
    )

    $results = New-Object System.Collections.Generic.List[object]
    $files = Get-ChildItem -LiteralPath $Root -Recurse -File -ErrorAction Stop | Where-Object {
        $_.FullName -notlike '*\.git\*' -and
        $_.Extension -in @('.ps1', '.psm1', '.psd1', '.md', '.json', '.yml', '.yaml', '.ps1xml', '.editorconfig')
    }

    foreach ($file in $files) {
        $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
        $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
        $results.Add([pscustomobject]@{
            Path   = $file.FullName
            HasBom = $hasBom
            Type   = $file.Extension
        })
    }

    return $results
}

Write-Host ''
Write-Host '=== [1/5] Conformité encodage UTF-8 BOM ===' -ForegroundColor Cyan
$conformance = Test-FileConformance -Root $hubRoot
foreach ($item in $conformance) {
    if (-not $item.HasBom) {
        $failures.Add(('BOM manquant : {0}' -f $item.Path))
    }
}
Write-Host ('Fichiers contrôlés : {0} / BOM manquants : {1}' -f $conformance.Count, $failures.Count)

Write-Host ''
Write-Host '=== [2/5] En-têtes d''aide obligatoires ===' -ForegroundColor Cyan
$scriptsToCheck = Get-ChildItem -LiteralPath $hubRoot -Recurse -File -Include '*.ps1', '*.psm1' -ErrorAction Stop | Where-Object {
    $_.FullName -notlike '*\.git\*'
}
$headerFailures = 0
foreach ($script in $scriptsToCheck) {
    $content = [System.IO.File]::ReadAllText($script.FullName)
    $hasSynopsis = $content -match '\.SYNOPSIS'
    $hasAuthor = $content -match '\.AUTHOR' -or $content -match '(?im)^\s*Author\s*:'
    if (-not $hasSynopsis -or -not $hasAuthor) {
        $failures.Add(('En-tête incomplet : {0}' -f $script.FullName))
        $headerFailures++
    }
}
Write-Host ('Fichiers contrôlés : {0} / en-têtes incomplets : {1}' -f $scriptsToCheck.Count, $headerFailures)

Write-Host ''
Write-Host '=== [3/5] Analyse statique PSScriptAnalyzer ===' -ForegroundColor Cyan
if ($SkipAnalyzer) {
    Write-Host 'Analyse ignorée (-SkipAnalyzer).' -ForegroundColor Yellow
}
else {
    $analyzer = Get-Module -ListAvailable -Name 'PSScriptAnalyzer' | Sort-Object -Property Version -Descending | Select-Object -First 1
    if ($null -eq $analyzer) {
        $warnings.Add('PSScriptAnalyzer absent : analyse statique ignorée. Exécutez tools\deployment\Install-HubModules.ps1.')
        Write-Host 'PSScriptAnalyzer absent : analyse ignorée.' -ForegroundColor Yellow
    }
    else {
        Import-Module -Name 'PSScriptAnalyzer' -MinimumVersion $analyzer.Version -ErrorAction Stop
        $settingsPath = Join-Path -Path (Join-Path -Path $hubRoot -ChildPath 'config\settings') -ChildPath 'PSScriptAnalyzerSettings.psd1'
        $targets = @(
            (Join-Path -Path $hubRoot -ChildPath 'src'),
            (Join-Path -Path $hubRoot -ChildPath 'modules'),
            (Join-Path -Path $hubRoot -ChildPath 'tools')
        )

        $analysisResults = foreach ($target in $targets) {
            if (Test-Path -LiteralPath $target -PathType Container) {
                Invoke-ScriptAnalyzer -Path $target -Recurse -Settings $settingsPath -ErrorAction Stop
            }
        }

        $analysisResults = @($analysisResults)
        foreach ($result in $analysisResults) {
            $message = ('{0} [{1}] {2}:{3} - {4}' -f $result.Severity, $result.RuleName, $result.ScriptPath, $result.Line, $result.Message)
            if ($result.Severity -eq 'Error') {
                $failures.Add($message)
            }
            else {
                $warnings.Add($message)
            }
        }

        Write-Host ('Constats : {0}' -f $analysisResults.Count)
    }
}

Write-Host ''
Write-Host '=== [4/5] Tests Pester ===' -ForegroundColor Cyan
if ($SkipTests) {
    Write-Host 'Tests ignorés (-SkipTests).' -ForegroundColor Yellow
}
else {
    $pester = Get-Module -ListAvailable -Name 'Pester' | Sort-Object -Property Version -Descending | Select-Object -First 1
    if ($null -eq $pester) {
        $warnings.Add('Pester absent : tests ignorés. Exécutez tools\deployment\Install-HubModules.ps1.')
        Write-Host 'Pester absent : tests ignorés.' -ForegroundColor Yellow
    }
    elseif ($pester.Version.Major -lt 5) {
        $warnings.Add(('Pester {0} détecté : Pester 5+ requis, tests ignorés.' -f $pester.Version))
        Write-Host ('Pester {0} détecté : Pester 5+ requis, tests ignorés.' -f $pester.Version) -ForegroundColor Yellow
    }
    else {
        Import-Module -Name 'Pester' -MinimumVersion $pester.Version -ErrorAction Stop
        $testResult = Invoke-Pester -Path (Join-Path -Path $hubRoot -ChildPath 'tests') -Output Normal -PassThru
        if ($testResult.FailedCount -gt 0) {
            $failures.Add(('Tests Pester en échec : {0}' -f $testResult.FailedCount))
        }
        Write-Host ('Tests : {0} réussis / {1} échoués' -f $testResult.PassedCount, $testResult.FailedCount)
    }
}

Write-Host ''
Write-Host '=== [5/5] Framework de rapport et dashboard (assets) ===' -ForegroundColor Cyan
$requiredAssets = @(
    'assets\css\report.css'
    'assets\css\dashboard.css'
    'assets\js\report.js'
    'assets\js\dashboard.js'
    'assets\js\chart.umd.min.js'
    'assets\templates\report.html'
    'assets\templates\dashboard.html'
)
$missingAssets = 0
foreach ($asset in $requiredAssets) {
    $assetPath = Join-Path -Path $hubRoot -ChildPath $asset
    if (-not (Test-Path -LiteralPath $assetPath -PathType Leaf)) {
        $failures.Add(('Ressource de rapport manquante : {0}' -f $assetPath))
        $missingAssets++
    }
}
Write-Host ('Ressources contrôlées : {0} / manquantes : {1}' -f $requiredAssets.Count, $missingAssets)

$duration = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 2)

Write-Host ''
Write-Host '=== Synthèse ===' -ForegroundColor Cyan
Write-Host ('Durée totale : {0} s' -f $duration)
Write-Host ('Échecs : {0} / Avertissements : {1}' -f $failures.Count, $warnings.Count)

if ($warnings.Count -gt 0) {
    Write-Host ''
    Write-Host 'Avertissements :' -ForegroundColor Yellow
    foreach ($warning in $warnings) {
        Write-Host ('  - {0}' -f $warning) -ForegroundColor Yellow
    }
}

if ($failures.Count -gt 0) {
    Write-Host ''
    Write-Host 'Échecs :' -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host ('  - {0}' -f $failure) -ForegroundColor Red
    }
    Write-Host ''
    exit 1
}

Write-Host ''
Write-Host 'Build réussi.' -ForegroundColor Green
exit 0
