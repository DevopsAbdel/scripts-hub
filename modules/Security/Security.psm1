#Requires -Version 5.1
<#
.SYNOPSIS
    Audit de la posture de sécurité locale.

.DESCRIPTION
    Module de contrôle en lecture seule : administrateurs locaux, profils de
    pare-feu Windows et état de Microsoft Defender. Chaque collecte est
    indépendante afin qu'une source indisponible ne bloque pas les autres.

.NOTES
    Author  : Scripts-Hub
    Version : 1.0.0
    Date    : 2026-11-08
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\Utilities\Utilities.psd1') -ErrorAction Stop

function Get-LocalAdministratorAudit {
    <#
    .SYNOPSIS
        Liste les membres du groupe Administrateurs local.

    .DESCRIPTION
        Résout le groupe via son SID bien connu (S-1-5-32-544) afin de rester
        indépendant de la langue du système, puis retourne ses membres.

    .EXAMPLE
        PS> Get-LocalAdministratorAudit

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    if (-not (Test-HubCommand -Name 'Get-LocalGroupMember')) {
        throw 'Le module Microsoft.PowerShell.LocalAccounts est requis pour auditer les groupes locaux.'
    }

    $group = $null
    try {
        $group = Get-LocalGroup -SID 'S-1-5-32-544' -ErrorAction Stop
    }
    catch {
        $group = Get-LocalGroup -Name 'Administrators' -ErrorAction Stop
    }

    $members = @(Get-LocalGroupMember -Group $group -ErrorAction Stop)
    foreach ($member in $members) {
        [pscustomobject]@{
            Name            = $member.Name
            ObjectClass     = [string]$member.ObjectClass
            PrincipalSource = [string]$member.PrincipalSource
            SID             = [string]$member.SID.Value
        }
    }
}

function Get-FirewallProfileStatus {
    <#
    .SYNOPSIS
        Retourne l'état des profils de pare-feu Windows.

    .EXAMPLE
        PS> Get-FirewallProfileStatus

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    if (-not (Test-HubCommand -Name 'Get-NetFirewallProfile')) {
        throw 'Le module NetSecurity est requis pour contrôler le pare-feu Windows.'
    }

    $profiles = @(Get-NetFirewallProfile -ErrorAction Stop)
    foreach ($profile in $profiles) {
        [pscustomobject]@{
            Profile         = $profile.Name
            Enabled         = [bool]$profile.Enabled
            DefaultInbound  = [string]$profile.DefaultInboundAction
            DefaultOutbound = [string]$profile.DefaultOutboundAction
            LogAllowed      = [bool]$profile.LogAllowed
        }
    }
}

function Get-DefenderStatus {
    <#
    .SYNOPSIS
        Retourne l'état de Microsoft Defender.

    .DESCRIPTION
        Retourne $null et un avertissement si le module Defender n'est pas
        disponible sur le système.

    .EXAMPLE
        PS> Get-DefenderStatus

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    if (-not (Test-HubCommand -Name 'Get-MpComputerStatus')) {
        Write-Warning 'Microsoft Defender indisponible : module Defender absent.'
        return $null
    }

    $status = Get-MpComputerStatus -ErrorAction Stop

    [pscustomobject]@{
        AntivirusEnabled              = [bool]$status.AntivirusEnabled
        RealTimeProtectionEnabled     = [bool]$status.RealTimeProtectionEnabled
        AntivirusSignatureVersion     = [string]$status.AntivirusSignatureVersion
        AntivirusSignatureLastUpdated = $status.AntivirusSignatureLastUpdated
        FullScanEndTime               = $status.FullScanEndTime
        QuickScanEndTime              = $status.QuickScanEndTime
    }
}

function Get-SecurityPosture {
    <#
    .SYNOPSIS
        Agrège la posture de sécurité locale du poste.

    .DESCRIPTION
        Exécute les collectes administrateurs locaux, pare-feu et Defender.
        Les erreurs de collecte sont remontées dans la propriété Warnings sans
        interrompre le reste de l'audit.

    .EXAMPLE
        PS> Get-SecurityPosture | Format-List

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $warnings = New-Object System.Collections.Generic.List[string]
    $administrators = @()
    $firewall = @()
    $defender = $null

    try {
        $administrators = @(Get-LocalAdministratorAudit)
    }
    catch {
        $warnings.Add(('Administrateurs locaux : {0}' -f $_.Exception.Message))
    }

    try {
        $firewall = @(Get-FirewallProfileStatus)
    }
    catch {
        $warnings.Add(('Pare-feu : {0}' -f $_.Exception.Message))
    }

    try {
        $defender = Get-DefenderStatus
    }
    catch {
        $warnings.Add(('Defender : {0}' -f $_.Exception.Message))
    }

    [pscustomobject]@{
        ComputerName   = [System.Environment]::MachineName
        CollectedAt    = (Get-Date)
        Administrators = $administrators
        Firewall       = $firewall
        Defender       = $defender
        Warnings       = $warnings.ToArray()
    }
}

Export-ModuleMember -Function @(
    'Get-LocalAdministratorAudit'
    'Get-FirewallProfileStatus'
    'Get-DefenderStatus'
    'Get-SecurityPosture'
)
