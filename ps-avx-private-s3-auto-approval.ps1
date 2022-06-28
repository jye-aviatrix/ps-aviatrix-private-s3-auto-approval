# Login to Aviatrix Controller
$multipartContent = [System.Net.Http.MultipartFormDataContent]::new()
$stringHeader = [System.Net.Http.Headers.ContentDispositionHeaderValue]::new("form-data")
$stringHeader.Name = "action"
$stringContent = [System.Net.Http.StringContent]::new("login")
$stringContent.Headers.ContentDisposition = $stringHeader
$multipartContent.Add($stringContent)

$stringHeader = [System.Net.Http.Headers.ContentDispositionHeaderValue]::new("form-data")
$stringHeader.Name = "username"
$stringContent = [System.Net.Http.StringContent]::new($env:AVIATRIX_USERNAME)
$stringContent.Headers.ContentDisposition = $stringHeader
$multipartContent.Add($stringContent)

$stringHeader = [System.Net.Http.Headers.ContentDispositionHeaderValue]::new("form-data")
$stringHeader.Name = "password"
$stringContent = [System.Net.Http.StringContent]::new($env:AVIATRIX_PASSWORD)
$stringContent.Headers.ContentDisposition = $stringHeader
$multipartContent.Add($stringContent)

$body = $multipartContent

$response = Invoke-RestMethod "https://${env:AVIATRIX_CONTROLLER_IP}/v1/api" -Method 'POST' -Headers $headers -Body $body -SkipCertificateCheck
# $response | ConvertTo-Json

if ($response.return -ne $true) {
    Write-Error "Failed to login to Aviatrix Controller"
    Write-Error $response.reason
    exit
}
else {
    Write-Host "Successfully login to Aviatrix Controller"
    $CID = $response.CID
}

# Get S3 Private NLBs
$response = Invoke-RestMethod "https://${env:AVIATRIX_CONTROLLER_IP}/v1/api?action=get_private_s3_nlbs&CID=$CID" -Method 'GET' -Headers $headers -SkipCertificateCheck
# $response | ConvertTo-Json
if ($response.return -ne $true) {
    Write-Error "Failed to obtain list of Private S3 NLBs"
    Write-Error $response.reason
    exit
}
else {
    Write-Host "Successfully obtained Private S3 NLBs"
    $NLBs = $response.results
}

# Get S3 Buckets
foreach ($NLB in $NLBs) {
    $response = Invoke-RestMethod "https://${env:AVIATRIX_CONTROLLER_IP}/v1/api?action=get_private_s3_buckets&CID=$CID&nlb_name=$NLB" -Method 'GET' -Headers $headers -SkipCertificateCheck
    # $response | ConvertTo-Json

    # Check to see if there are S3 Buckets still not allowed for NLB, if all S3 Buckets already allowed, skip to next NLB
    if ($response.results.bucket_list | Where-Object { $_.verdict -ne "Allow" }) {
        Write-Host "Found S3 buckets for $NLB not allowed, working on allowing them"
    }
    else {
        Write-Host "All S3 Buckets for $NLB already allowed, nothing to do"
        Continue
    }

    # Construct allow list
    $bucket_allow_list = @()
    foreach ($bucket in $response.results.bucket_list) {
        $bucket_allow_list += @{"bucket" = $bucket.bucket; "verdict" = "Allow" }     
    }
    $bucket_allow_list_json = $bucket_allow_list | ConvertTo-Json

    # Update S3 Bucket List to allow
    $multipartContent = [System.Net.Http.MultipartFormDataContent]::new()
    $stringHeader = [System.Net.Http.Headers.ContentDispositionHeaderValue]::new("form-data")
    $stringHeader.Name = "action"
    $stringContent = [System.Net.Http.StringContent]::new("update_private_s3_buckets")
    $stringContent.Headers.ContentDisposition = $stringHeader
    $multipartContent.Add($stringContent)

    $stringHeader = [System.Net.Http.Headers.ContentDispositionHeaderValue]::new("form-data")
    $stringHeader.Name = "CID"
    $stringContent = [System.Net.Http.StringContent]::new($CID)
    $stringContent.Headers.ContentDisposition = $stringHeader
    $multipartContent.Add($stringContent)

    $stringHeader = [System.Net.Http.Headers.ContentDispositionHeaderValue]::new("form-data")
    $stringHeader.Name = "nlb_name"
    $stringContent = [System.Net.Http.StringContent]::new($NLB)
    $stringContent.Headers.ContentDisposition = $stringHeader
    $multipartContent.Add($stringContent)

    $stringHeader = [System.Net.Http.Headers.ContentDispositionHeaderValue]::new("form-data")
    $stringHeader.Name = "s3_bucket_urls"
    $stringContent = [System.Net.Http.StringContent]::new($bucket_allow_list_json)
    $stringContent.Headers.ContentDisposition = $stringHeader
    $multipartContent.Add($stringContent)

    $body = $multipartContent

    $response = Invoke-RestMethod "https://${env:AVIATRIX_CONTROLLER_IP}/v1/api" -Method 'POST' -Headers $headers -Body $body -SkipCertificateCheck
    # $response | ConvertTo-Json
    if ($response.return -ne $true) {
        Write-Error "Failed to allow S3 list on Private S3 NLB $NLB"
        Write-Error $response.reason
        exit
    }
    else {
        Write-Host "Successfully allowed S3 list Private S3 NLB $NLB"
        Write-Host $response.results
    }
}
