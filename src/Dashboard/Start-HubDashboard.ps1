#Requires -Version 5.1
<#
.SYNOPSIS
    Démarre le dashboard web local de scripts-hub.

.DESCRIPTION
    Lance un serveur HTTP limité à l'interface de bouclage (localhost) qui
    expose une console de pilotage : inventaire des rapports, exécution
    contrôlée des scripts par liste blanche, consultation des journaux et
    téléchargement des livrables. Aucune ressource Internet n'est utilisée.

    Le serveur s'arrête avec Ctrl+C ou via le bouton « Arrêter » de la page.

.PARAMETER Port
    Port d'écoute local. Valeur par défaut : 8080.

.PARAMETER NoBrowser
    N'ouvre pas automatiquement le navigateur par défaut.

.PARAMETER RunTimeoutSeconds
    Durée maximale d'une exécution de script avant arrêt forcé. Par défaut 300.

.EXAMPLE
    PS> .\src\Dashboard\Start-HubDashboard.ps1

.EXAMPLE
    PS> .\src\Dashboard\Start-HubDashboard.ps1 -Port 8090 -NoBrowser

.NOTES
    Author  : Scripts-Hub
    Version : 1.0.0
    Date    : 2026-11-08
#>

[CmdletBinding()]
param(
    [ValidateRange(1024, 65535)]
    [int]$Port = 8080,

    [switch]$NoBrowser,

    [ValidateRange(10, 3600)]
    [int]$RunTimeoutSeconds = 300
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$hubRoot = Split-Path -Path (Split-Path -Path $scriptDirectory -Parent) -Parent

Import-Module -Name (Join-Path -Path $hubRoot -ChildPath 'modules\Common\Common.psd1') -Force
Import-Module -Name (Join-Path -Path $hubRoot -ChildPath 'modules\Dashboard\Dashboard.psd1') -Force

$script:Encoding = New-Object System.Text.UTF8Encoding($false)
$script:CurrentRun = $null
$script:StopRequested = $false
$logPath = Join-Path -Path $hubRoot -ChildPath ('logs\{0}_Dashboard.log' -f (Get-HubTimestamp -Format 'yyyy-MM-dd'))

function Send-HubDashboardResponse {
    <#
    .SYNOPSIS
        Écrit une réponse HTTP complète et ferme le flux.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Net.HttpListenerContext]$Context,

        [int]$StatusCode = 200,

        [string]$ContentType = 'application/json; charset=utf-8',

        [AllowEmptyCollection()]
        [byte[]]$Body = @(),

        [string]$Disposition
    )

    $response = $Context.Response
    $response.StatusCode = $StatusCode
    $response.ContentType = $ContentType
    $response.AddHeader('Cache-Control', 'no-store, no-cache, must-revalidate')
    $response.AddHeader('X-Content-Type-Options', 'nosniff')
    $response.AddHeader('Referrer-Policy', 'no-referrer')

    if (-not [string]::IsNullOrWhiteSpace($Disposition)) {
        $response.AddHeader('Content-Disposition', $Disposition)
    }

    if ($null -eq $Body) {
        $Body = @()
    }

    $response.ContentLength64 = $Body.Length
    if ($Body.Length -gt 0) {
        $response.OutputStream.Write($Body, 0, $Body.Length)
    }
    $response.OutputStream.Flush()
    $response.Close()
}

function Send-HubDashboardJson {
    <#
    .SYNOPSIS
        Sérialise un objet et l'envoie en JSON UTF-8.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Net.HttpListenerContext]$Context,

        [int]$StatusCode = 200,

        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [object]$Payload
    )

    $json = ConvertTo-Json -InputObject $Payload -Depth 12 -Compress
    if ([string]::IsNullOrWhiteSpace($json)) {
        $json = 'null'
    }

    Send-HubDashboardResponse -Context $Context -StatusCode $StatusCode -ContentType 'application/json; charset=utf-8' -Body $script:Encoding.GetBytes($json)
}

function Read-HubDashboardBody {
    <#
    .SYNOPSIS
        Lit le corps d'une requête HTTP.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Net.HttpListenerContext]$Context
    )

    $reader = New-Object System.IO.StreamReader($Context.Request.InputStream, $Context.Request.ContentEncoding)
    try {
        return $reader.ReadToEnd()
    }
    finally {
        $reader.Dispose()
    }
}

function Get-HubDashboardArtifact {
    <#
    .SYNOPSIS
        Liste les livrables existants d'une exécution.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ReportName
    )

    $dateStamp = Get-HubTimestamp -Format 'yyyy-MM-dd'
    $items = New-Object System.Collections.Generic.List[object]

    foreach ($type in @('html', 'csv', 'json')) {
        $fileName = '{0}_{1}.{2}' -f $dateStamp, $ReportName, $type
        $fullPath = Join-Path -Path $hubRoot -ChildPath ('reports\{0}\{1}' -f $type, $fileName)
        if (Test-Path -LiteralPath $fullPath -PathType Leaf) {
            $items.Add([ordered]@{
                type     = $type
                fileName = $fileName
                url      = ('/reports/{0}/{1}' -f $type, [System.Uri]::EscapeDataString($fileName))
            })
        }
    }

    return @($items.ToArray())
}

function Get-HubDashboardRunStatus {
    <#
    .SYNOPSIS
        Calcule l'état de l'exécution courante et rafraîchit la sortie.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param()

    $run = $script:CurrentRun
    if ($null -eq $run) {
        return [ordered]@{ state = 'idle' }
    }

    $elapsed = [math]::Round(((Get-Date) - $run.StartedAt).TotalSeconds, 1)

    if ($run.State -eq 'running' -and $null -ne $run.Job) {
        $job = $run.Job
        $peek = @(Receive-Job -Job $job -Keep -ErrorAction SilentlyContinue)
        if ($peek.Count -gt 0) {
            $run.Output = (@($peek | ForEach-Object { [string]$_ }) -join "`r`n")
        }

        if ($job.State -in @('Completed', 'Failed', 'Stopped')) {
            $run.DurationSeconds = [math]::Round(((Get-Date) - $run.StartedAt).TotalSeconds, 1)
            if ($job.State -eq 'Completed') {
                $run.State = 'completed'
            }
            else {
                $run.State = 'failed'
                $run.Error = ('Le script s''est arrêté avec l''état {0}.' -f $job.State)
            }

            $run.Artifacts = @(Get-HubDashboardArtifact -ReportName $run.ReportName)
            Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
            $run.Job = $null

            $level = 'INFO'
            if ($run.State -eq 'failed') {
                $level = 'ERROR'
            }
            Write-HubLog -Message ('Exécution {0} {1} en {2} s' -f $run.ActionId, $run.State, $run.DurationSeconds) -Level $level -Path $logPath
        }
        elseif ($elapsed -gt $RunTimeoutSeconds) {
            Stop-Job -Job $job -ErrorAction SilentlyContinue
            Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
            $run.Job = $null
            $run.State = 'failed'
            $run.Error = ('Délai dépassé ({0} s) : exécution interrompue.' -f $RunTimeoutSeconds)
            $run.DurationSeconds = $elapsed
            Write-HubLog -Message $run.Error -Level ERROR -Path $logPath
        }
    }

    $currentElapsed = [math]::Round(((Get-Date) - $run.StartedAt).TotalSeconds, 1)

    return [ordered]@{
        state           = $run.State
        actionId        = $run.ActionId
        actionName      = $run.ActionName
        startedAt       = $run.StartedAt.ToString('o')
        elapsedSeconds  = $currentElapsed
        durationSeconds = $run.DurationSeconds
        output          = $run.Output
        error           = $run.Error
        artifacts       = @($run.Artifacts)
    }
}

$prefix = 'http://localhost:{0}/' -f $Port
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($prefix)

try {
    $listener.Start()
}
catch {
    throw ('Impossible de démarrer le dashboard sur {0}. Le port est peut-être déjà utilisé ; essayez -Port 8090. Détail : {1}' -f $prefix, $_.Exception.Message)
}

$startedAt = Get-Date
Write-HubLog -Message ('Dashboard démarré : {0}' -f $prefix) -Path $logPath
Write-Host ''
Write-Host ('scripts-hub dashboard : {0}' -f $prefix) -ForegroundColor Cyan
Write-Host 'Ctrl+C ou bouton « Arrêter » pour quitter.' -ForegroundColor DarkGray
Write-Host ''

if (-not $NoBrowser) {
    try {
        Start-Process -FilePath $prefix | Out-Null
    }
    catch {
        Write-Host ('Ouverture automatique impossible : {0}' -f $_.Exception.Message) -ForegroundColor Yellow
    }
}

try {
    while (-not $script:StopRequested) {
        $contextAsync = $listener.GetContextAsync()
        while (-not $contextAsync.AsyncWaitHandle.WaitOne(250)) {
            if ($script:StopRequested) {
                break
            }
        }

        if ($script:StopRequested) {
            break
        }

        if (-not $contextAsync.IsCompleted) {
            continue
        }

        $context = $null
        try {
            $context = $contextAsync.GetAwaiter().GetResult()
        }
        catch {
            continue
        }

        $responded = $false
        try {
            $request = $context.Request
            $method = $request.HttpMethod
            $absolutePath = '/'
            if ($null -ne $request.Url) {
                $absolutePath = $request.Url.AbsolutePath
            }

            $path = [System.Uri]::UnescapeDataString($absolutePath)
            if ($path.Length -gt 1) {
                $path = $path.TrimEnd('/')
            }

            if ($method -eq 'GET' -and ($path -eq '/' -or $path -eq '/index.html')) {
                $page = New-HubDashboardPage -Root $hubRoot
                Send-HubDashboardResponse -Context $context -StatusCode 200 -ContentType 'text/html; charset=utf-8' -Body $script:Encoding.GetBytes($page)
                $responded = $true
            }
            elseif ($method -eq 'GET' -and $path -eq '/favicon.ico') {
                Send-HubDashboardResponse -Context $context -StatusCode 204 -ContentType 'image/x-icon'
                $responded = $true
            }
            elseif ($method -eq 'GET' -and $path -eq '/api/state') {
                $payload = Get-HubDashboardState -Root $hubRoot -Port $Port -StartedAt $startedAt
                Send-HubDashboardJson -Context $context -StatusCode 200 -Payload $payload
                $responded = $true
            }
            elseif ($method -eq 'GET' -and $path -eq '/api/run/status') {
                Send-HubDashboardJson -Context $context -StatusCode 200 -Payload (Get-HubDashboardRunStatus)
                $responded = $true
            }
            elseif ($method -eq 'GET' -and $path -eq '/api/log') {
                $name = $request.QueryString['name']
                if ([string]::IsNullOrWhiteSpace($name)) {
                    Send-HubDashboardJson -Context $context -StatusCode 400 -Payload ([ordered]@{ error = 'Paramètre name manquant.' })
                }
                else {
                    try {
                        $content = Get-HubDashboardLogContent -Name $name -Root $hubRoot
                        Send-HubDashboardJson -Context $context -StatusCode 200 -Payload ([ordered]@{ name = $name; content = $content })
                    }
                    catch {
                        Send-HubDashboardJson -Context $context -StatusCode 404 -Payload ([ordered]@{ error = $_.Exception.Message })
                    }
                }
                $responded = $true
            }
            elseif ($method -eq 'POST' -and $path -eq '/api/run') {
                $bodyText = Read-HubDashboardBody -Context $context
                $payload = $null
                try {
                    $payload = $bodyText | ConvertFrom-Json
                }
                catch {
                    Send-HubDashboardJson -Context $context -StatusCode 400 -Payload ([ordered]@{ error = 'Corps JSON invalide.' })
                    $responded = $true
                    continue
                }

                if ($null -eq $payload -or -not ($payload.PSObject.Properties.Name -contains 'id')) {
                    Send-HubDashboardJson -Context $context -StatusCode 400 -Payload ([ordered]@{ error = 'Identifiant d''action manquant.' })
                    $responded = $true
                    continue
                }

                if ($null -ne $script:CurrentRun -and $script:CurrentRun.State -eq 'running') {
                    Send-HubDashboardJson -Context $context -StatusCode 409 -Payload ([ordered]@{ error = 'Une exécution est déjà en cours.' })
                    $responded = $true
                    continue
                }

                $actionId = [string]$payload.id
                $action = Get-HubDashboardAction -Root $hubRoot | Where-Object { $_.Id -eq $actionId } | Select-Object -First 1

                if ($null -eq $action) {
                    Send-HubDashboardJson -Context $context -StatusCode 404 -Payload ([ordered]@{ error = 'Action inconnue.' })
                    $responded = $true
                    continue
                }

                if (-not $action.Available) {
                    Send-HubDashboardJson -Context $context -StatusCode 409 -Payload ([ordered]@{ error = $action.Reason })
                    $responded = $true
                    continue
                }

                $scriptPath = Join-Path -Path $hubRoot -ChildPath $action.Script
                $job = Start-Job -Name ('hub-' + $action.Id) -ScriptBlock {
                    param($Path)
                    $ErrorActionPreference = 'Continue'
                    & $Path *>&1 | ForEach-Object { $_.ToString() }
                } -ArgumentList $scriptPath

                $script:CurrentRun = [pscustomobject]@{
                    State           = 'running'
                    ActionId        = $action.Id
                    ActionName      = $action.Name
                    ReportName      = $action.ReportName
                    StartedAt       = Get-Date
                    Job             = $job
                    Output          = 'Exécution démarrée…'
                    Error           = $null
                    Artifacts       = @()
                    DurationSeconds = 0
                }

                Write-HubLog -Message ('Exécution {0} démarrée' -f $action.Id) -Path $logPath
                Send-HubDashboardJson -Context $context -StatusCode 202 -Payload ([ordered]@{ ok = $true; actionId = $action.Id })
                $responded = $true
            }
            elseif ($method -eq 'POST' -and $path -eq '/api/shutdown') {
                Send-HubDashboardJson -Context $context -StatusCode 200 -Payload ([ordered]@{ ok = $true; message = 'Arrêt du serveur.' })
                $responded = $true
                $script:StopRequested = $true
            }
            elseif ($method -eq 'GET' -and $path -match '^/reports/(.+)$') {
                $relativePath = $Matches[1]
                $filePath = Resolve-HubDashboardReportPath -RelativePath $relativePath -Root $hubRoot

                if ($null -eq $filePath) {
                    Send-HubDashboardJson -Context $context -StatusCode 404 -Payload ([ordered]@{ error = 'Rapport introuvable.' })
                }
                else {
                    $extension = [System.IO.Path]::GetExtension($filePath).ToLowerInvariant()
                    $contentType = 'application/octet-stream'
                    $disposition = $null

                    switch ($extension) {
                        '.html' { $contentType = 'text/html; charset=utf-8' }
                        '.csv' {
                            $contentType = 'text/csv; charset=utf-8'
                            $disposition = ('attachment; filename="{0}"' -f [System.IO.Path]::GetFileName($filePath))
                        }
                        '.json' {
                            $contentType = 'application/json; charset=utf-8'
                            $disposition = ('attachment; filename="{0}"' -f [System.IO.Path]::GetFileName($filePath))
                        }
                    }

                    $bytes = [System.IO.File]::ReadAllBytes($filePath)
                    Send-HubDashboardResponse -Context $context -StatusCode 200 -ContentType $contentType -Body $bytes -Disposition $disposition
                }
                $responded = $true
            }
            else {
                Send-HubDashboardJson -Context $context -StatusCode 404 -Payload ([ordered]@{ error = 'Ressource inconnue.' })
                $responded = $true
            }
        }
        catch {
            if (-not $responded) {
                try {
                    Send-HubDashboardJson -Context $context -StatusCode 500 -Payload ([ordered]@{ error = $_.Exception.Message })
                }
                catch {
                    Write-HubLog -Message ('Réponse d''erreur impossible : {0}' -f $_.Exception.Message) -Level ERROR -Path $logPath
                }
            }
            Write-HubLog -Message ('Erreur de requête : {0}' -f $_.Exception.Message) -Level ERROR -Path $logPath
        }
        finally {
            try {
                $context.Response.Close()
            }
            catch {
                Write-Verbose 'Réponse déjà fermée.'
            }
        }
    }
}
finally {
    if ($null -ne $script:CurrentRun -and $null -ne $script:CurrentRun.Job) {
        Stop-Job -Job $script:CurrentRun.Job -ErrorAction SilentlyContinue
        Remove-Job -Job $script:CurrentRun.Job -Force -ErrorAction SilentlyContinue
    }

    $listener.Stop()
    $listener.Close()
    Write-HubLog -Message 'Dashboard arrêté.' -Path $logPath
    Write-Host ''
    Write-Host 'Dashboard arrêté.' -ForegroundColor DarkGray
}
