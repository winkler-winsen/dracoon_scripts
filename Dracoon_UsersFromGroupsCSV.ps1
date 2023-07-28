# Insert your FQDN here
$DracoonFQDN='FQDN'
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

# get nodes list 
# - depth_level=99
# - filter=type:eq:room:folder
#
# !!! maximum is 500. if more users, we have to use paging !!!
$SDSResponse = Invoke-WebRequest -UseBasicParsing -Uri "https://$DracoonFQDN/api/v4/groups?limit=200&offset=0&filter=&sort=name%3Aasc" `
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
$SDSGroups = $SDSResponse | ConvertFrom-Json
$SDSGroups = $SDSGroups.items

$SDSGroups | Select-Object -Property id,name,cntUsers |  Out-GridView -OutputMode Multiple -OutVariable selectedids

foreach ($group in $selectedids) {
    Write-Host "$($group.name) mit $($group.cntUsers) Benutzer ----------------------------------------------------------------------"
    Invoke-WebRequest -UseBasicParsing -Uri "https://$DracoonFQDN/api/v4/groups/$($group.id)/users?limit=200&offset=0&filter=" `
        -WebSession $session `
        -Headers @{
            "authority"="$DracoonFQDN"
            "method"="GET"
        } `
        -ContentType "application/json" -OutVariable result | Out-Null
    $result = [Text.Encoding]::UTF8.GetString( $result.RawContentStream.ToArray() )
    $result=$result | ConvertFrom-Json
    $result=$result.items
    $result | Select-Object -Property displayName,email | ft

    # export result to CSV
    $result | Export-Csv -Delimiter ';' -NoTypeInformation -Path "SDS_$($group.name)_$now.csv" -Encoding UTF8 -Verbose
}

