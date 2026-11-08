#Requires -Version 5.1
<#
.SYNOPSIS
    Collecte d'inventaire système et Active Directory.

.DESCRIPTION
    Module d'inventaire de scripts-hub. Les fonctions système reposent sur CIM
    et sont disponibles sur tout poste Windows. Les fonctions Active Directory
    nécessitent le module RSAT et échouent avec un message explicite en son
    absence.

.NOTES
    Author  : Scripts-Hub
    Version : 1.0.0
    Date    : 2026-11-08
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\Common\Common.psd1') -ErrorAction Stop
Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\Utilities\Utilities.psd1') -ErrorAction Stop

function Get-SystemVolume {
    <#
    .SYNOPSIS
        Retourne les volumes locaux fixes avec leur occupation.

    .DESCRIPTION
        Interroge Win32_LogicalDisk pour les volumes de type 3 (disque fixe)
        et calcule la taille, l'espace libre et le taux d'occupation.

    .EXAMPLE
        PS> Get-SystemVolume

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $volumes = Get-CimInstance -ClassName 'Win32_LogicalDisk' -Filter 'DriveType = 3' -ErrorAction Stop

    foreach ($volume in $volumes) {
        $sizeBytes = [double]$volume.Size
        $freeBytes = [double]$volume.FreeSpace
        $usedPercent = 0
        if ($sizeBytes -gt 0) {
            $usedPercent = [math]::Round((($sizeBytes - $freeBytes) / $sizeBytes) * 100, 1)
        }

        $health = 'OK'
        if ($usedPercent -ge 90) {
            $health = 'Critique'
        }
        elseif ($usedPercent -ge 75) {
            $health = 'Attention'
        }

        [pscustomobject]@{
            Drive       = $volume.DeviceID
            Label       = $volume.VolumeName
            FileSystem  = $volume.FileSystem
            SizeGB      = [math]::Round($sizeBytes / 1GB, 1)
            FreeGB      = [math]::Round($freeBytes / 1GB, 1)
            UsedPercent = $usedPercent
            Health      = $health
        }
    }
}

function Get-SystemInventory {
    <#
    .SYNOPSIS
        Collecte l'inventaire matériel et logiciel du poste local.

    .DESCRIPTION
        Rassemble les informations système (OS, matériel, mémoire, domaine),
        les volumes fixes et la version PowerShell. La fonction est en lecture
        seule et ne nécessite aucun privilège particulier.

    .PARAMETER IncludeVolumes
        Ajoute le détail des volumes dans la propriété Volumes.

    .EXAMPLE
        PS> Get-SystemInventory | Format-List

    .EXAMPLE
        PS> Get-SystemInventory -IncludeVolumes | ConvertTo-Json -Depth 4

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [switch]$IncludeVolumes
    )

    $operatingSystem = Get-CimInstance -ClassName 'Win32_OperatingSystem' -ErrorAction Stop
    $computerSystem = Get-CimInstance -ClassName 'Win32_ComputerSystem' -ErrorAction Stop
    $processor = Get-CimInstance -ClassName 'Win32_Processor' -ErrorAction Stop | Select-Object -First 1
    $bios = Get-CimInstance -ClassName 'Win32_BIOS' -ErrorAction Stop

    $totalMemory = [double]$computerSystem.TotalPhysicalMemory
    $freeMemory = [double]$operatingSystem.FreePhysicalMemory * 1KB
    $uptime = (Get-Date) - $operatingSystem.LastBootUpTime

    $inventory = [pscustomobject]@{
        ComputerName     = $computerSystem.Name
        Domain           = $computerSystem.Domain
        Manufacturer     = $computerSystem.Manufacturer
        Model            = $computerSystem.Model
        SerialNumber     = $bios.SerialNumber
        OperatingSystem  = $operatingSystem.Caption
        OSVersion        = $operatingSystem.Version
        BuildNumber      = $operatingSystem.BuildNumber
        Architecture     = $operatingSystem.OSArchitecture
        LastBootTime     = $operatingSystem.LastBootUpTime
        UptimeDays       = [math]::Round($uptime.TotalDays, 1)
        Processor        = $processor.Name
        Cores            = $processor.NumberOfCores
        LogicalProcessors = $processor.NumberOfLogicalProcessors
        TotalMemoryGB    = [math]::Round($totalMemory / 1GB, 1)
        FreeMemoryGB     = [math]::Round($freeMemory / 1GB, 1)
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        PSEdition        = $PSVersionTable.PSEdition
        CollectedAt      = (Get-Date)
        Volumes          = @()
    }

    if ($IncludeVolumes) {
        $inventory.Volumes = @(Get-SystemVolume)
    }

    return $inventory
}

function Get-ADInventory {
    <#
    .SYNOPSIS
        Collecte un inventaire de synthèse Active Directory.

    .DESCRIPTION
        Compte les utilisateurs, ordinateurs, groupes et unités
        d'organisation du domaine. Nécessite le module ActiveDirectory (RSAT)
        et un contexte d'authentification autorisé.

    .PARAMETER Server
        Contrôleur de domaine cible. Par défaut, le DC du site courant.

    .PARAMETER SearchBase
        Base de recherche LDAP. Par défaut, la racine du domaine.

    .PARAMETER Credential
        Identité alternative pour la connexion au domaine.

    .EXAMPLE
        PS> Get-ADInventory -Server dc01.contoso.com

    .EXAMPLE
        PS> Get-ADInventory -SearchBase 'OU=Paris,DC=contoso,DC=com' -Credential (Get-Credential)

    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string]$Server,
        [string]$SearchBase,
        [System.Management.Automation.PSCredential]$Credential
    )

    if (-not (Test-HubCommand -Name 'Get-ADDomain')) {
        throw 'Le module ActiveDirectory (RSAT) est requis. Installez RSAT-AD-PowerShell puis réessayez.'
    }

    $domainParameters = @{}
    if (-not [string]::IsNullOrWhiteSpace($Server)) {
        $domainParameters['Server'] = $Server
    }
    if ($null -ne $Credential) {
        $domainParameters['Credential'] = $Credential
    }

    $domain = Get-ADDomain @domainParameters

    $queryParameters = @{ Filter = '*' }
    if (-not [string]::IsNullOrWhiteSpace($Server)) {
        $queryParameters['Server'] = $Server
    }
    if (-not [string]::IsNullOrWhiteSpace($SearchBase)) {
        $queryParameters['SearchBase'] = $SearchBase
    }
    if ($null -ne $Credential) {
        $queryParameters['Credential'] = $Credential
    }

    $users = @(Get-ADUser @queryParameters)
    $computers = @(Get-ADComputer @queryParameters)
    $groups = @(Get-ADGroup @queryParameters)
    $organizationalUnits = @(Get-ADOrganizationalUnit @queryParameters)

    [pscustomobject]@{
        Domain                = $domain.DNSRoot
        NetBIOSName           = $domain.NetBIOSName
        DomainController      = $domain.PDCEmulator
        Forest                = $domain.Forest
        DistinguishedName     = $domain.DistinguishedName
        UsersTotal            = $users.Count
        UsersEnabled          = @($users | Where-Object { $_.Enabled }).Count
        ComputersTotal        = $computers.Count
        GroupsTotal           = $groups.Count
        OrganizationalUnits   = $organizationalUnits.Count
        CollectedAt           = (Get-Date)
    }
}

Export-ModuleMember -Function @(
    'Get-SystemVolume'
    'Get-SystemInventory'
    'Get-ADInventory'
)
