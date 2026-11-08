#Requires -Version 5.1
<#
.SYNOPSIS
    Test d'intégration du script Get-SystemInventory.
.DESCRIPTION
    Exécute le script de bout en bout et vérifie la création des livrables.
.NOTES
    Author  : Scripts-Hub
    Version : 1.0.0
    Date    : 2026-11-08
#>

BeforeAll {
    $script:repoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:scriptPath = Join-Path -Path $script:repoRoot -ChildPath 'src\Inventory\Get-SystemInventory.ps1'
}

Describe 'Get-SystemInventory.ps1 - intégration' {
    It 'génère les rapports HTML, CSV et JSON' {
        $outputDirectory = Join-Path -Path $TestDrive -ChildPath 'reports'
        $result = & $script:scriptPath -OutputDirectory $outputDirectory -Format All

        $result.Html | Should -Not -BeNullOrEmpty
        Test-Path -LiteralPath $result.Html -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $result.Csv -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $result.Json -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $result.Log -PathType Leaf | Should -BeTrue
    }

    It 'retourne l''inventaire avec -PassThru' {
        $outputDirectory = Join-Path -Path $TestDrive -ChildPath 'reports-pass'
        $inventory = & $script:scriptPath -OutputDirectory $outputDirectory -Format Html -PassThru

        $inventory.ComputerName | Should -Not -BeNullOrEmpty
        $inventory.OperatingSystem | Should -Not -BeNullOrEmpty
    }
}
