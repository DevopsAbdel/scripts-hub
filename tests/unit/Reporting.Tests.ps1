#Requires -Version 5.1
<#
.SYNOPSIS
    Tests unitaires des modules Utilities et Reporting.
.NOTES
    Author  : Scripts-Hub
    Version : 1.0.0
    Date    : 2026-11-08
#>

BeforeAll {
    $script:repoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    Import-Module -Name (Join-Path -Path $script:repoRoot -ChildPath 'modules\Utilities\Utilities.psd1') -Force
    Import-Module -Name (Join-Path -Path $script:repoRoot -ChildPath 'modules\Reporting\Reporting.psd1') -Force
}

Describe 'Utilities - Format-HubByteSize' {
    It 'convertit les kilo-octets' {
        Format-HubByteSize -Bytes 1024 | Should -Be '1.0 KB'
    }

    It 'convertit les méga-octets' {
        Format-HubByteSize -Bytes 1048576 | Should -Be '1.0 MB'
    }

    It 'gère zéro octet' {
        Format-HubByteSize -Bytes 0 | Should -Be '0.0 B'
    }
}

Describe 'Utilities - ConvertTo-HubSafeName' {
    It 'remplace les caractères interdits' {
        ConvertTo-HubSafeName -Name 'AD Inventory (prod)' | Should -Be 'AD_Inventory_prod'
    }

    It 'conserve tirets et underscores' {
        ConvertTo-HubSafeName -Name 'M365-Licenses_2026' | Should -Be 'M365-Licenses_2026'
    }
}

Describe 'Utilities - Test-HubCommand et Test-HubApprovedVerb' {
    It 'détecte une commande existante' {
        Test-HubCommand -Name 'Get-Command' | Should -BeTrue
    }

    It 'détecte une commande inexistante' {
        Test-HubCommand -Name 'Get-CommandeInexistante' | Should -BeFalse
    }

    It 'reconnaît un verbe approuvé' {
        Test-HubApprovedVerb -Verb 'Get' | Should -BeTrue
    }

    It 'rejette un verbe non approuvé' {
        Test-HubApprovedVerb -Verb 'Faire' | Should -BeFalse
    }
}

Describe 'Reporting - New-HubHtmlReport' {
    It 'produit un fichier HTML autonome en UTF-8 BOM' {
        $path = Join-Path -Path $TestDrive -ChildPath 'rapport.html'
        New-HubHtmlReport -Title 'Titre de test' -Sections ([ordered]@{ 'Données' = @([pscustomobject]@{ Nom = 'A'; Valeur = 1 }) }) -Path $path | Out-Null

        Test-Path -LiteralPath $path -PathType Leaf | Should -BeTrue

        $bytes = [System.IO.File]::ReadAllBytes($path)
        $bytes[0] | Should -Be 0xEF
        $bytes[1] | Should -Be 0xBB
        $bytes[2] | Should -Be 0xBF

        $content = [System.IO.File]::ReadAllText($path)
        $content | Should -Match '<!DOCTYPE html>'
        $content | Should -Match 'Titre de test'
    }

    It 'échappe le contenu HTML' {
        $path = Join-Path -Path $TestDrive -ChildPath 'echappe.html'
        New-HubHtmlReport -Title '<script>alert(1)</script>' -Sections ([ordered]@{ 'Données' = @([pscustomobject]@{ Nom = '<b>X</b>' }) }) -Path $path | Out-Null

        $content = [System.IO.File]::ReadAllText($path)
        $content | Should -Not -Match '<script>alert\(1\)</script>'
        $content | Should -Match '&lt;script&gt;'
    }
}

Describe 'Reporting - Export-HubCsv' {
    It 'écrit un CSV UTF-8 BOM avec séparateur point-virgule' {
        $path = Join-Path -Path $TestDrive -ChildPath 'export.csv'
        @(
            [pscustomobject]@{ Nom = 'Alpha'; Valeur = 1 }
            [pscustomobject]@{ Nom = 'Beta'; Valeur = 2 }
        ) | Export-HubCsv -Path $path | Out-Null

        $bytes = [System.IO.File]::ReadAllBytes($path)
        $bytes[0] | Should -Be 0xEF

        $content = [System.IO.File]::ReadAllText($path)
        $content | Should -Match 'Nom.+Valeur'
        $content | Should -Match 'Alpha.+1'
    }
}

Describe 'Reporting - Export-HubJson' {
    It 'produit un JSON valide' {
        $path = Join-Path -Path $TestDrive -ChildPath 'export.json'
        @([pscustomobject]@{ Nom = 'Alpha'; Valeur = 1 }) | Export-HubJson -Path $path | Out-Null

        $content = [System.IO.File]::ReadAllText($path)
        $data = $content | ConvertFrom-Json
        @($data).Count | Should -Be 1
        @($data)[0].Nom | Should -Be 'Alpha'
    }
}
