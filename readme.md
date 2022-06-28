# PowerShell script to Auto Approve Private S3 Buckets

Environment variables:

Linux:

```
$ export AVIATRIX_CONTROLLER_IP = "1.2.3.4"
$ export AVIATRIX_USERNAME = "admin"
$ export AVIATRIX_PASSWORD = "password"
```

The script does the following:

1. Login to Aviatrix Controller and obtain CID
2. Obtain Private S3 NLBs 
3. Obtain S3 Buckets and set policy to allow, if they are not allowed already.

REST API reference:
1. Login to https://support.aviatrix.com/
2. Download postman collection that's corresponding to your Aviatrix controller version https://support.aviatrix.com/apiDownloads
3. Login to Aviatrix Controller to obtain CID, click on </> and pick your favourit language
![](20220628122632.png)  
4. Obtain Private S3 NLBs
![](20220628122857.png)  
5. Obtain list of S3 buckets
![](20220628123016.png)  
6. Within the code, update bucket "verdict" to "Allow"
7. Update Private S3 bucket policy
![](20220628123221.png)  
