#Requires -Version 5.1
<#
.SYNOPSIS
    Tests unitaires du module Common.
.NOTES
    Author  : Scripts-Hub
    Version : 1.0.0
    Date    : 2026-11-08
#>

BeforeAll {
    $script:repoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    Import-Module -Name (Join-Path -Path $script:repoRoot -ChildPath 'modules\Common\Common.psd1') -Force
}

Describe 'Common - Get-HubRoot' {
    It 'retourne un répertoire existant' {
        $root = Get-HubRoot
        $root | Should -Not -BeNullOrEmpty
        Test-Path -LiteralPath $root -PathType Container | Should -BeTrue
    }
}

Describe 'Common - Get-HubTimestamp' {
    It 'respecte le format demandé' {
        Get-HubTimestamp -Format 'yyyy-MM-dd' | Should -Match '^\d{4}-\d{2}-\d{2}$'
    }

    It 'utilise le format par défaut yyyy-MM-dd_HHmmss' {
        Get-HubTimestamp | Should -Match '^\d{4}-\d{2}-\d{2}_\d{6}$'
    }
}

Describe 'Common - New-HubDirectory' {
    It 'crée un répertoire absent' {
        $target = Join-Path -Path $TestDrive -ChildPath 'nouveau\dossier'
        New-HubDirectory -Path $target | Out-Null
        Test-Path -LiteralPath $target -PathType Container | Should -BeTrue
    }

    It 'est idempotent sur un répertoire existant' {
        $target = Join-Path -Path $TestDrive -ChildPath 'existant'
        New-HubDirectory -Path $target | Out-Null
        { New-HubDirectory -Path $target } | Should -Not -Throw
    }
}

Describe 'Common - Get-HubReportPath' {
    It 'applique la convention YYYY-MM-DD_Type_Rapport.ext' {
        $path = Get-HubReportPath -Name 'AD_Inventory' -Format 'html' -DateStamp '2026-11-08' -Root $script:repoRoot
        Split-Path -Path $path -Leaf | Should -Be '2026-11-08_AD_Inventory.html'
        Split-Path -Path $path -Parent | Should -BeLike '*reports\html'
    }
}

Describe 'Common - Get-HubConfig' {
    It 'charge la configuration par défaut' {
        $config = Get-HubConfig
        $config.ContainsKey('Organization') | Should -BeTrue
    }

    It 'échoue sur un environnement inconnu' {
        { Get-HubConfig -Environment 'inexistant' } | Should -Throw
    }
}

Describe 'Common - Test-HubEnvironment' {
    It 'retourne les informations essentielles' {
        $result = Test-HubEnvironment
        $result.PowerShellVersion | Should -Not -BeNullOrEmpty
        $result.Assemblies.Keys | Should -Contain 'System.Drawing'
    }
}
