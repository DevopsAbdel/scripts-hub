#Requires -Version 5.1
<#
.SYNOPSIS
    Normalise l'encodage des fichiers texte du dépôt.

.DESCRIPTION
    Réécrit les fichiers texte en UTF-8 avec BOM et fins de ligne CRLF,
    conformément au standard du projet. Les fichiers déjà conformes sont
    réécrits à l'identique ; l'opération est donc idempotente.
    Les répertoires .git, logs et reports\archive sont ignorés.

.PARAMETER Root
    Racine du dépôt. Par défaut, la racine déduite de l'emplacement du script.

.PARAMETER Extension
    Extensions de fichiers à traiter. Par défaut : .ps1, .psm1, .psd1, .md,
    .json, .yml, .yaml, .csv, .html, .css, .txt, .xml, .config.

.PARAMETER PassThru
    Retourne la liste des fichiers modifiés.

.EXAMPLE
    PS> .\tools\maintenance\Set-FileEncoding.ps1

.EXAMPLE
    PS> .\tools\maintenance\Set-FileEncoding.ps1 -WhatIf

.NOTES
    Author  : Scripts-Hub
    Version : 1.0.0
    Date    : 2026-11-08
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$Root,

    [string[]]$Extension = @('.ps1', '.psm1', '.psd1', '.md', '.json', '.yml', '.yaml', '.csv', '.html', '.css', '.js', '.txt', '.xml', '.config', '.code-workspace'),

    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Root)) {
    $scriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
    $hubRoot = Split-Path -Path (Split-Path -Path $scriptDirectory -Parent) -Parent
    $Root = $hubRoot
}

$Root = [System.IO.Path]::GetFullPath($Root)
$excludedDirectories = @('.git', 'logs', 'bin', 'obj')
$encoding = New-Object System.Text.UTF8Encoding($true)
$changedFiles = New-Object System.Collections.Generic.List[string]

$files = Get-ChildItem -LiteralPath $Root -Recurse -File -ErrorAction Stop | Where-Object {
    $relative = $_.FullName.Substring($Root.Length).TrimStart('\')
    $segments = $relative -split '\\'

    $excluded = $false
    foreach ($segment in $segments) {
        if ($excludedDirectories -contains $segment) {
            $excluded = $true
        }
    }

    if ($excluded) {
        return $false
    }

    if ($relative -like 'reports\archive\*') {
        return $false
    }

    if ($_.Name -in @('.editorconfig', '.gitignore', '.gitattributes', 'LICENSE')) {
        return $true
    }

    return $Extension -contains $_.Extension.ToLowerInvariant()
}

foreach ($file in $files) {
    $content = [System.IO.File]::ReadAllText($file.FullName)
    $normalized = $content -replace "`r`n", "`n"
    $normalized = $normalized -replace "`r", "`n"
    $normalized = $normalized -replace "`n", "`r`n"

    if ($normalized -ne $content) {
        if ($PSCmdlet.ShouldProcess($file.FullName, 'Normaliser en UTF-8 BOM / CRLF')) {
            [System.IO.File]::WriteAllText($file.FullName, $normalized, $encoding)
            $changedFiles.Add($file.FullName)
        }
    }
    elseif ($PSCmdlet.ShouldProcess($file.FullName, 'Vérifier l''encodage UTF-8 BOM')) {
        $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
        $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
        if (-not $hasBom) {
            [System.IO.File]::WriteAllText($file.FullName, $normalized, $encoding)
            $changedFiles.Add($file.FullName)
        }
    }
}

Write-Host ('Fichiers traités : {0} / normalisés : {1}' -f $files.Count, $changedFiles.Count)

if ($PassThru) {
    $changedFiles
}
