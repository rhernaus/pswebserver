# Variables
$httpPort = ($env:HTTP_PORT ?? '8080')
$maxThreads = ($env:MAX_THREADS ?? 4 )

# Server
$Server = [Hashtable]::Synchronized(@{})
$Server.Listener = New-Object System.Net.HttpListener
$Server.Listener.Prefixes.Add("http://+:$httpPort/")
$Server.Listener.Start()

# Runspaces
$SessionState = [Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
ForEach ($Var in (Get-ChildItem -Path 'Env:')) {
    $Variable = New-object System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList "$($Var.Key)","$($Var.Value)",$Null
    $SessionState.EnvironmentVariables.Add($Variable)
}
$Pool = [RunspaceFactory]::CreateRunspacePool(1, $MaxThreads, $SessionState, $Host)
$Pool.ApartmentState  = 'STA'
$Pool.CleanupInterval = 2 * [timespan]::TicksPerMinute
$Pool.Open()

$Jobs = New-Object Collections.Generic.List[PSCustomObject]

# RequestProcessing
$requestCallback = {
    param($ThreadID,$Server)

    $Context = $Server.Listener.GetContext()
    $Request = $Context.Request
    $Response = $Context.Response

    # Handle /status request for livenessprobe
    $Params = ($Request.RawUrl).Split("/")
    If ($Params[1] -Eq 'status') {
        $ScriptOutput = @{
            StatusCode  = 200
            ContentType = 'text/plain'
            Body        = "$($Request.RawUrl)"
        }
    } Else {
        $ScriptOutput = ./run.ps1 -httpRequest $Request
        # Expected output
        # @{
        #   StatusCode  =
        #   ContentType =
        #   Body        =
        # }
    }

    $Response.Headers.Add("Content-Type",($ScriptOutput.ContentType ?? 'text/plain'))
    $Response.StatusCode = ($ScriptOutput.StatusCode ?? 500)
    $Buffer = [Text.Encoding]::UTF8.GetBytes($ScriptOutput.Body)
    $Response.ContentLength64 = $Buffer.Length
    $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
    $Response.Close()

    # Return data to console
    New-Object -TypeName PSObject -Property @{
        ThreadID      = $ThreadID
        StatusCode    = $ScriptOutput.StatusCode
        ConsoleOutput = $ScriptOutput.Body
    }
}

# Build initial ThreadQueue
For ($i = 0 ; $i -lt $MaxThreads ; $i++) {
    $Pipeline = [PowerShell]::Create()
    $Pipeline.RunspacePool = $Pool
    [void]$Pipeline.AddScript($RequestCallback)

    $Params =   @{
        ThreadID           = $i
        Server             = $Server
    }

    [void]$Pipeline.AddParameters($Params)

    $Jobs.Add((New-Object PSObject -Property @{
        Pipeline = $Pipeline
        Job      = $Pipeline.BeginInvoke()
    }))
}

Write-Output "Starting Listener Threads: $($Jobs.Count)"

While ($Jobs.Count -gt 0) {
    $AwaitingRequest = $true
    while ($AwaitingRequest) {
        ForEach ($Job in $Jobs) {
            if ($Job.Job.IsCompleted) {
                $AwaitingRequest = $False
                $JobIndex = $Jobs.IndexOf($Job)
                Break
            }
        }
    }

    $Results = $Jobs.Item($JobIndex).Pipeline.EndInvoke($Jobs.Item($JobIndex).Job)

    $Results | ForEach-Object {
        Write-Output "[$(Get-Date -Format "dd-MM-yyyy HH:mm:ss")] Thread:$($_.ThreadId) Status:$($_.StatusCode) Output:$($_.ConsoleOutput)"
    }

    $Jobs.Item($JobIndex).Pipeline.Dispose()
    $Jobs.RemoveAt($JobIndex)

    $Pipeline = [PowerShell]::Create()
    $Pipeline.RunspacePool = $Pool
    [void]$Pipeline.AddScript($RequestCallback)

    $Params =   @{
        ThreadID           = $JobIndex
        Server             = $Server
    }

    [void]$Pipeline.AddParameters($Params)

    $Jobs.Insert($JobIndex, (New-Object PSObject -Property @{
        Pipeline = $Pipeline
        Job      = $Pipeline.BeginInvoke()
    }))
}