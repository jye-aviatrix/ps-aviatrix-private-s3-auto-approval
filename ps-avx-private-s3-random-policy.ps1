# Get confirmation before continue, this would avoid this script gets scheduled accidently.

Write-Host ""
Write-Host "This script will *randomly* set Private S3 bucket access to either Allow/Deny/New"
Write-Host "This script is meant for pre-prod testing environment, to simulate potential of mixture of newly discovered buckets, and existing buckets with either Allow/Deny policy"
Write-Host ""
Write-Host "ONLY PROCEED IF YOU FULLY UNDERSTAND ABOVE"
Write-Host ""
$input = Read-Host "Enter 'agree' to continye or anything else to aboard"
if ($input -ne 'agree') {
    exit
}


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
    # if ($response.return -ne $true) {
    #     Write-Error "Failed to obtain list of S3 buckets from $NLB"
    #     Write-Error $response.reason
    #     exit
    # }
    # elseif ($response.results.bucket_list | Where-Object { $_.verdict -eq "New" }) {
    #     Write-Host "Found newly added S3 buckets for $NLB, working on allowing them"
    # }
    # else {
    #     Write-Host "No new S3 Buckets for $NLB found, nothing to do"
    #     Continue
    # }

    # Construct allow list
    $bucket_allow_list = @()
    foreach ($bucket in $response.results.bucket_list) {

        $t = Get-Random -Maximum 3
        if ($t -eq 0) {
            continue
        }
        if ($t -eq 1) {
            $bucket_allow_list += @{"bucket" = $bucket.bucket; "verdict" = "Allow" }
        }
        if ($t -eq 2) {
            $bucket_allow_list += @{"bucket" = $bucket.bucket; "verdict" = "Deny" }
        }

        # if ($bucket.verdict -eq "New") {
        #     $bucket_allow_list += @{"bucket" = $bucket.bucket; "verdict" = "Allow" }
        # } else {
        #     $bucket_allow_list += $bucket
        # }
             
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
        Write-Error "Failed to update allow S3 list on Private S3 NLB $NLB"
        Write-Error $response.reason
        exit
    }
    else {
        Write-Host "Successfully allowed S3 list Private S3 NLB $NLB"
        Write-Host $response.results
    }
}
