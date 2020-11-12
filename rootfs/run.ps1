Param(
    $httpRequest
)
$body = "Request method is $httpRequest.httpMethod"
@{
    StatusCode = 200
    ContentType = "text/plain"
    Body = $body
}