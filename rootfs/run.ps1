Param(
    $httpRequest
)
$body = "Request method is $($httpRequest.httpMethod | Out-String)"
@{
    StatusCode = 200
    ContentType = "text/plain"
    Body = $body
}