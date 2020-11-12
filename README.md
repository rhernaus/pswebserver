Based on mcr.microsoft.com/powershell:lts-ubuntu-18.04

Added code that runs a multithreaded webserver using powershell runspaces.
All environment variables will be passed to the runspaces so they can be used in your run.ps1 script

It will respond to request at /status with status code 200. This can be used for a kubernetes liveness probe.
All requests will be logged to the console.

You can add a file run.ps1 that will be called when there is an incoming request. Example is included:
```
Param(
    $httpRequest
)
$body = "Request method is $httpRequest.httpMethod"
@{
    StatusCode = 200
    ContentType = "text/plain"
    Body = $body
}
```

Environment variables:
- HTTP_PORT: Port that the webserver will listen on. Defaullt 8080.
- MAX_THREADS: The number of runspaces that will be started. Default 4.
