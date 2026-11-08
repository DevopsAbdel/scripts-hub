#Requires -Version 5.1
<#
.SYNOPSIS
    Helpers transverses de disponibilité, formatage et nommage.

.DESCRIPTION
    Module utilitaire de scripts-hub. Il fournit des fonctions sans état,
    testables unitairement, utilisées par les autres modules et scripts.

.NOTES
    Author  : Scripts-Hub
    Version : 1.0.0
    Date    : 2026-11-08
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-HubCommand {
    <#
    .SYNOPSIS
        Vérifie la disponibilité d'une commande PowerShell.

    .PARAMETER Name
        Nom de la commande à tester.

    .EXAMPLE
        PS> Test-HubCommand -Name 'Get-ADDomain'
        False

    .OUTPUTS
        System.Boolean
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    return $null -ne (Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function Format-HubByteSize {
    <#
    .SYNOPSIS
        Convertit un nombre d'octets en taille lisible.

    .PARAMETER Bytes
        Taille en octets.

    .PARAMETER Precision
        Nombre de décimales. Par défaut 1.

    .EXAMPLE
        PS> Format-HubByteSize -Bytes 1610612736
        1.5 GB

    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateRange(0, [double]::MaxValue)]
        [double]$Bytes,

        [ValidateRange(0, 4)]
        [int]$Precision = 1
    )

    $units = @('B', 'KB', 'MB', 'GB', 'TB', 'PB')
    $value = $Bytes
    $index = 0

    while ($value -ge 1024 -and $index -lt ($units.Count - 1)) {
        $value = $value / 1024
        $index++
    }

    $numberFormat = 'F{0}' -f $Precision
    return [string]::Format(
        [System.Globalization.CultureInfo]::InvariantCulture,
        '{0:' + $numberFormat + '} {1}',
        $value,
        $units[$index]
    )
}

function ConvertTo-HubSafeName {
    <#
    .SYNOPSIS
        Normalise un libellé en nom de fichier sûr.

    .DESCRIPTION
        Remplace tout caractère non alphanumérique (hors point, tiret et
        underscore) par un underscore, puis supprime les underscores
        consécutifs.

    .PARAMETER Name
        Libellé source.

    .EXAMPLE
        PS> ConvertTo-HubSafeName -Name 'AD Inventory (prod)'
        AD_Inventory_prod

    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    process {
        $safe = $Name -replace '[^\w\-\.]', '_'
        $safe = $safe -replace '_+', '_'
        return $safe.Trim('_')
    }
}

function Test-HubApprovedVerb {
    <#
    .SYNOPSIS
        Vérifie qu'un verbe fait partie des verbes approuvés PowerShell.

    .PARAMETER Verb
        Verbe à contrôler, par exemple Get ou Invoke.

    .EXAMPLE
        PS> Test-HubApprovedVerb -Verb 'Get'
        True

    .OUTPUTS
        System.Boolean
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Verb
    )

    return $null -ne (Get-Verb -Verb $Verb -ErrorAction SilentlyContinue)
}

Export-ModuleMember -Function @(
    'Test-HubCommand'
    'Format-HubByteSize'
    'ConvertTo-HubSafeName'
    'Test-HubApprovedVerb'
)
