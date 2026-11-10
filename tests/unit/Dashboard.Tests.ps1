#Requires -Version 5.1
<#
.SYNOPSIS
    Tests unitaires du module Dashboard et de la page de pilotage.
.NOTES
    Author  : Scripts-Hub
    Version : 1.0.0
    Date    : 2026-11-08
#>

BeforeAll {
    $script:repoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    Import-Module -Name (Join-Path -Path $script:repoRoot -ChildPath 'modules\Dashboard\Dashboard.psd1') -Force

    $script:sandbox = Join-Path -Path $TestDrive -ChildPath 'hub'
    foreach ($relative in @('reports\html', 'reports\csv', 'reports\json', 'logs', 'src\Inventory', 'src\Security')) {
        New-Item -ItemType Directory -Path (Join-Path -Path $script:sandbox -ChildPath $relative) -Force | Out-Null
    }

    Set-Content -LiteralPath (Join-Path -Path $script:sandbox -ChildPath 'reports\html\2026-11-08_System_Inventory.html') -Value '<html></html>' -Encoding UTF8
    Set-Content -LiteralPath (Join-Path -Path $script:sandbox -ChildPath 'reports\csv\2026-11-08_System_Inventory.csv') -Value 'Nom;Valeur' -Encoding UTF8
    Set-Content -LiteralPath (Join-Path -Path $script:sandbox -ChildPath 'reports\json\2026-11-08_Security_Posture.json') -Value '[]' -Encoding UTF8
    Set-Content -LiteralPath (Join-Path -Path $script:sandbox -ChildPath 'reports\html\readme.txt') -Value 'hors index' -Encoding UTF8
    Set-Content -LiteralPath (Join-Path -Path $script:sandbox -ChildPath 'logs\2026-11-08_System_Inventory.log') -Value 'ligne 1' -Encoding UTF8
    Set-Content -LiteralPath (Join-Path -Path $script:sandbox -ChildPath 'src\Inventory\Get-SystemInventory.ps1') -Value '# test' -Encoding UTF8
    Set-Content -LiteralPath (Join-Path -Path $script:sandbox -ChildPath 'src\Security\Get-SecurityPosture.ps1') -Value '# test' -Encoding UTF8
}

Describe 'Dashboard - Get-HubDashboardReportIndex' {
    It 'indexe les trois formats avec leurs métadonnées' {
        $index = @(Get-HubDashboardReportIndex -Root $script:sandbox)

        $index.Count | Should -Be 3
        @($index | Where-Object { $_.Type -eq 'html' }).Count | Should -Be 1

        $html = $index | Where-Object { $_.Type -eq 'html' } | Select-Object -First 1
        $html.Base | Should -Be '2026-11-08_System_Inventory'
        $html.Name | Should -Be 'System Inventory'
        $html.Date | Should -Be '2026-11-08'
        $html.Url | Should -Be '/reports/html/2026-11-08_System_Inventory.html'
        $html.Size | Should -BeGreaterThan 0
    }

    It 'ignore les fichiers non pris en charge' {
        $index = @(Get-HubDashboardReportIndex -Root $script:sandbox)
        @($index | Where-Object { $_.FileName -eq 'readme.txt' }).Count | Should -Be 0
    }

    It 'retourne un tableau vide sans répertoire reports' {
        $empty = Join-Path -Path $TestDrive -ChildPath 'vide'
        New-Item -ItemType Directory -Path $empty -Force | Out-Null
        @(Get-HubDashboardReportIndex -Root $empty).Count | Should -Be 0
    }
}

Describe 'Dashboard - Resolve-HubDashboardReportPath' {
    It 'résout un rapport HTML valide' {
        $path = Resolve-HubDashboardReportPath -RelativePath 'html/2026-11-08_System_Inventory.html' -Root $script:sandbox
        $path | Should -Not -BeNullOrEmpty
        Test-Path -LiteralPath $path -PathType Leaf | Should -BeTrue
    }

    It 'refuse une tentative d''évasion de répertoire' {
        Resolve-HubDashboardReportPath -RelativePath 'html/../../README.md' -Root $script:sandbox | Should -BeNullOrEmpty
        Resolve-HubDashboardReportPath -RelativePath '..%2f..%2fREADME.md' -Root $script:sandbox | Should -BeNullOrEmpty
    }

    It 'refuse un type de rapport inconnu' {
        Resolve-HubDashboardReportPath -RelativePath 'exe/2026-11-08_System_Inventory.html' -Root $script:sandbox | Should -BeNullOrEmpty
    }

    It 'refuse un fichier absent' {
        Resolve-HubDashboardReportPath -RelativePath 'html/absent.html' -Root $script:sandbox | Should -BeNullOrEmpty
    }
}

Describe 'Dashboard - Get-HubDashboardLogIndex et Get-HubDashboardLogContent' {
    It 'indexe les journaux et expose une URL de lecture' {
        $logs = @(Get-HubDashboardLogIndex -Root $script:sandbox)
        $logs.Count | Should -Be 1
        $logs[0].Name | Should -Be '2026-11-08_System_Inventory.log'
        $logs[0].Url | Should -Match '^/api/log\?name='
    }

    It 'lit le contenu d''un journal' {
        Get-HubDashboardLogContent -Name '2026-11-08_System_Inventory.log' -Root $script:sandbox | Should -Be 'ligne 1'
    }

    It 'refuse un nom de journal hors du répertoire logs' {
        { Get-HubDashboardLogContent -Name '..\secret.log' -Root $script:sandbox } | Should -Throw
        { Get-HubDashboardLogContent -Name 'absent.log' -Root $script:sandbox } | Should -Throw
    }
}

Describe 'Dashboard - Get-HubDashboardAction' {
    It 'retourne la liste blanche des scripts' {
        $actions = @(Get-HubDashboardAction -Root $script:sandbox)
        $actions.Count | Should -Be 3
        @($actions | ForEach-Object { $_.Id }) | Should -Contain 'inventory'
        @($actions | ForEach-Object { $_.Id }) | Should -Contain 'security'
        @($actions | ForEach-Object { $_.Id }) | Should -Contain 'activedirectory'
    }

    It 'détecte les scripts présents et absents' {
        $actions = @(Get-HubDashboardAction -Root $script:sandbox)
        ($actions | Where-Object { $_.Id -eq 'inventory' }).Available | Should -BeTrue
        ($actions | Where-Object { $_.Id -eq 'security' }).Available | Should -BeTrue
        ($actions | Where-Object { $_.Id -eq 'activedirectory' }).Available | Should -BeFalse
        ($actions | Where-Object { $_.Id -eq 'activedirectory' }).Reason | Should -Not -BeNullOrEmpty
    }
}

Describe 'Dashboard - Get-HubDashboardState' {
    It 'agrège l''environnement, les rapports et les actions' {
        $started = (Get-Date).AddSeconds(-15)
        $state = Get-HubDashboardState -Root $script:sandbox -Port 8090 -StartedAt $started

        $state.Environment.Port | Should -Be 8090
        $state.Environment.Root | Should -Be $script:sandbox
        $state.Summary.Reports | Should -Be 3
        $state.Summary.Html | Should -Be 1
        $state.Summary.Csv | Should -Be 1
        $state.Summary.Json | Should -Be 1
        $state.Summary.Actions | Should -Be 3
        $state.Summary.Runnable | Should -Be 2
        $state.Summary.Logs | Should -Be 1
        $state.Environment.UptimeSeconds | Should -BeGreaterOrEqual 15
    }
}

Describe 'Dashboard - New-HubDashboardPage' {
    It 'produit une page autonome avec les points d''ancrage attendus' {
        $page = New-HubDashboardPage -Root $script:repoRoot

        $page | Should -Match '<!DOCTYPE html>'
        $page | Should -Match 'id="hub-kpis"'
        $page | Should -Match 'id="hub-actions"'
        $page | Should -Match 'id="hub-search"'
        $page | Should -Match 'id="hub-reports-table"'
        $page | Should -Match 'id="hub-run-panel"'
        $page | Should -Match 'id="hub-log-viewer"'
        $page | Should -Match '--hub-bg:\s*#0D1117'
        $page | Should -Match '--hub-primary:\s*#58A6FF'
        $page | Should -Not -Match '\{\{[A-Z_]+\}\}'
    }

    It 'ne référence aucune ressource distante' {
        $page = New-HubDashboardPage -Root $script:repoRoot
        $page | Should -Not -Match 'src="https?://'
        $page | Should -Not -Match 'href="https?://'
        $page | Should -Not -Match 'fetch\(''https?://'
    }

    It 'échoue clairement si une ressource manque' {
        $empty = Join-Path -Path $TestDrive -ChildPath 'assets-vides'
        New-Item -ItemType Directory -Path $empty -Force | Out-Null
        { New-HubDashboardPage -Root $empty } | Should -Throw '*introuvable*'
    }
}

Describe 'Dashboard - Démarrage du serveur' {
    It 'parse le script sans erreur' {
        $scriptPath = Join-Path -Path $script:repoRoot -ChildPath 'src\Dashboard\Start-HubDashboard.ps1'
        $tokens = $null
        $errors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$errors)
        @($errors).Count | Should -Be 0
    }
}
