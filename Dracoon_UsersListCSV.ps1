# Insert your FQDN here
$DracoonFQDN='fqdn' # e.g. dracoon.domain.tld
$url = "https://$DracoonFQDN/api/v4/auth/login"

function Get-RandomString {
    param ([int]$length)

    return -join ((65..90) + (97..122) | Get-Random -Count $length | % {[char]$_})
}

# Use credentials to get bearer token
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$session.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/111.0.0.0 Safari/537.36'
$header = @{
    'accept'='application/json'; 
    'Content-Type'='application/json'
}
$creddi = Get-Credential
$body = @{
 'userName'="$($creddi.UserName)";
 'password'="$($creddi.GetNetworkCredential().Password)";
 'authType'='basic'
}
$LoginResponse = Invoke-WebRequest -Uri $url -WebSession $session -Body ($body|ConvertTo-Json) -Headers $header -Method 'POST'

# overwrite credentials
$creddi = New-Object System.Management.Automation.PSCredential ((Get-RandomString(32)), (ConvertTo-SecureString (Get-RandomString(32)) -AsPlainText -Force))
$body.userName=Get-RandomString(32)
$body.password=Get-RandomString(32)

# extract bearer Token
$token = ($LoginResponse.Content | ConvertFrom-Json).token

# get user list
# !!! maximum is 500. if more users, we have to use paging !!!
$SDSResponse = Invoke-WebRequest -UseBasicParsing -Uri "https://$DracoonFQDN/api/v4/users" `
-WebSession $session `
-Headers @{
    'accept'='application/json'; 
    'Content-Type'='application/json';
    'X-Sds-Auth-Token'=$token
} `
-ContentType 'application/json'

# encode to UTF8
$SDSResponse = 
  [Text.Encoding]::UTF8.GetString(
    $SDSResponse.RawContentStream.ToArray()
  )

$now=Get-Date -Format 'yyyymmdd_HHmmss'

# get all Dracoon users
$SDSUsers = $SDSResponse | ConvertFrom-Json
$SDSUsers = $SDSUsers.items

# split email user and domain
$SDSUsers | ForEach-Object { 
    $_ | Add-Member -MemberType NoteProperty -Name 'emailUser' -Value ($_.email.substring(0,($_.email.IndexOf('@'))))
    $_ | Add-Member -MemberType NoteProperty -Name 'emailDomain' -Value ($_.email.substring(($_.email.IndexOf('@')+1))).ToLower()
}

# export all users to CSV
$SDSUsers | Export-Csv -Encoding UTF8 -Delimiter ';' -NoTypeInformation -Path "Dracoon_$now.csv"

# ui output
$SDSUsers | Out-GridView -Title 'Dracoon user list' -Wait
