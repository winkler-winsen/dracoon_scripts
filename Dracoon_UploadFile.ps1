#
# Upload a file to Dracoon Upload-Link
#
# Version: 
#   1.0
# Date:
#   20.07.2023
#

#region initialize 
# Place file to upload here
$file='C:\Windows\WinSxS\amd64_microsoft-windows-dxp-deviceexperience_31bf3856ad364e35_10.0.19041.746_none_251e769058968366\pictures.ico'
# Dacroon Upload URL https://FQDN/public/upload-shares/32RANDOMCHARS
$DracoonUploadURL='https://FQDN/public/upload-shares/H3BYUJnU3hmpDUI7QacY7L8ve6pcXZHt'
#endregion


# Cut FQDN
$DracoonUploadURL -match '([^:]*:\/\/)?(?<FQDN>[^\/]+\.[^\/]+)' | Out-Null
$DracoonFQDN = $Matches.FQDN

# Cut Code
$DracoonUploadURL -match '(?<Id>\w+$)' | Out-Null
$DracoonUploadId = $Matches.Id

$filecontent = Get-Content -Path $file -Raw -Encoding Byte

$response=$null
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$session.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36"

# upload prepare - get uploadID and prepare upload - send name and size
try {
    Invoke-WebRequest -UseBasicParsing -Uri "https://$DracoonFQDN/api/v4/public/shares/uploads/$DracoonUploadId" `
    -Method "POST" `
    -WebSession $session `
    -ContentType "application/json" `
    -Body "{`"name`":`"$(Split-Path $file -Leaf)`",`"size`":$((Get-Item $file).length),`"directS3Upload`":false,`"timestampCreation`":null,`"timestampModification`":null}" -OutVariable response | Out-Null
}
catch 
{
    Write-Host "error in upload prepare"
    break
}

if ($response.StatusCode -ne 201) {
    Write-Host "error in upload prepare"
    break
} 
$uploadId=($response.Content | ConvertFrom-Json).uploadId

# send file content
try {
    Invoke-WebRequest -UseBasicParsing -Uri "https://$DracoonFQDN/api/v4/public/shares/uploads/$DracoonUploadId/$uploadId" `
    -Method "POST" `
    -WebSession $session `
    -ContentType "application/octet-stream" `
    -Body ($filecontent) -OutVariable response | Out-Null
}
catch 
{
    Write-Host "error sending file"
    break
}
if ($response.StatusCode -ne 201) {
    Write-Host "error sending file"
    break
} 

# put
try {
    Invoke-WebRequest -UseBasicParsing -Uri "https://$DracoonFQDN/api/v4/public/shares/uploads/$DracoonUploadId/$uploadId" `
    -Method "PUT" `
    -WebSession $session -OutVariable response | Out-Null
}
catch 
{
    Write-Host "error in put"
    break
}
if ($response.StatusCode -ne 201) {
    Write-Host "error in put"
    break
} 
Write-Host "Upload complete."