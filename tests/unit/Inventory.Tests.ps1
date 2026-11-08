#Requires -Version 5.1
<#
.SYNOPSIS
    Tests unitaires du module Inventory.
.NOTES
    Author  : Scripts-Hub
    Version : 1.0.0
    Date    : 2026-11-08
#>

BeforeAll {
    $script:repoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    Import-Module -Name (Join-Path -Path $script:repoRoot -ChildPath 'modules\Inventory\Inventory.psd1') -Force
}

Describe 'Inventory - Get-SystemInventory' {
    It 'retourne les informations système essentielles' {
        $inventory = Get-SystemInventory
        $inventory.ComputerName | Should -Not -BeNullOrEmpty
        $inventory.OperatingSystem | Should -Not -BeNullOrEmpty
        $inventory.TotalMemoryGB | Should -BeGreaterThan 0
        $inventory.PowerShellVersion | Should -Not -BeNullOrEmpty
    }

    It 'respecte le commutateur IncludeVolumes' {
        $withoutVolumes = Get-SystemInventory
        @($withoutVolumes.Volumes).Count | Should -Be 0

        $withVolumes = Get-SystemInventory -IncludeVolumes
        @($withVolumes.Volumes).Count | Should -BeGreaterThan 0
    }
}

Describe 'Inventory - Get-SystemVolume' {
    It 'retourne des volumes avec un taux d''occupation valide' {
        $volumes = @(Get-SystemVolume)
        $volumes.Count | Should -BeGreaterThan 0
        foreach ($volume in $volumes) {
            $volume.Drive | Should -Match '^[A-Z]:$'
            $volume.UsedPercent | Should -BeGreaterOrEqual 0
            $volume.UsedPercent | Should -BeLessOrEqual 100
            $volume.Health | Should -BeIn @('OK', 'Attention', 'Critique')
        }
    }
}

Describe 'Inventory - Get-ADInventory' {
    It 'échoue proprement si le module ActiveDirectory est absent' {
        if (Get-Command -Name 'Get-ADDomain' -ErrorAction SilentlyContinue) {
            Set-ItResult -Skipped -Because 'Le module ActiveDirectory est présent sur ce système.'
            return
        }

        { Get-ADInventory } | Should -Throw
    }
}
