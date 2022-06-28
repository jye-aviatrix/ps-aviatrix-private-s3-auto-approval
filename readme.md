# PowerShell script to Auto Approve Private S3 Buckets

Environment variables:

Linux:
$ export AVIATRIX_CONTROLLER_IP = "1.2.3.4"
$ export AVIATRIX_USERNAME = "admin"
$ export AVIATRIX_PASSWORD = "password"

The script does the following:

1. Login to Aviatrix Controller and obtain CID
2. Obtain Private S3 NLBs 
3. Obtain S3 Buckets and set policy to allow, if they are not allowed already.
