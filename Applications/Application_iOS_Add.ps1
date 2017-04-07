﻿
<#
 
.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
See LICENSE in the project root for license information.

#>

####################################################
 
function Get-AuthToken {

<#
.SYNOPSIS
This function is used to authenticate with the Graph API REST interface
.DESCRIPTION
The function authenticate with the Graph API Interface with the tenant name
.EXAMPLE
Get-AuthToken
Authenticates you with the Graph API interface
.NOTES
NAME: Get-AuthToken
.REFERENCE
Acknowledgement to Paolo Marques
https://blogs.technet.microsoft.com/paulomarques/2016/03/21/working-with-azure-active-directory-graph-api-from-powershell/

#>

[cmdletbinding()]

param
(
    [Parameter(Mandatory=$true)]
    $TenantName
)
 
$adal = "${env:ProgramFiles(x86)}\Microsoft SDKs\Azure\PowerShell\ServiceManagement\Azure\Services\Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
 
$adalforms = "${env:ProgramFiles(x86)}\Microsoft SDKs\Azure\PowerShell\ServiceManagement\Azure\Services\Microsoft.IdentityModel.Clients.ActiveDirectory.WindowsForms.dll"
 
    if((test-path "$adal") -eq $false){
 
    write-host
    write-host "Azure Powershell module not installed..." -f Red
    write-host "Please install Azure SDK for Powershell - https://azure.microsoft.com/en-us/downloads/" -f Yellow
    write-host "Script can't continue..." -f Red
    write-host
    exit
 
    }
 
[System.Reflection.Assembly]::LoadFrom($adal) | Out-Null
 
[System.Reflection.Assembly]::LoadFrom($adalforms) | Out-Null
 
$clientId = "1950a258-227b-4e31-a9cf-717495945fc2"
 
$redirectUri = "urn:ietf:wg:oauth:2.0:oob"
 
$resourceAppIdURI = "https://graph.microsoft.com"
 
$authority = "https://login.windows.net/$TenantName"
 
    try {

    $authContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $authority
 
    # https://msdn.microsoft.com/en-us/library/azure/microsoft.identitymodel.clients.activedirectory.promptbehavior.aspx
    # Change the prompt behaviour to force credentials each time: Auto, Always, Never, RefreshSession

    $authResult = $authContext.AcquireToken($resourceAppIdURI,$clientId,$redirectUri, "Always")

        # Building Rest Api header with authorization token
        $authHeader = @{
        'Content-Type'='application\json'
        'Authorization'=$authResult.CreateAuthorizationHeader()
        'ExpiresOn'=$authResult.ExpiresOn
        }

    return $authHeader

    }

    catch {

    write-host $_.Exception.Message -f Red
    write-host $_.Exception.ItemName -f Red
    write-host
    break

    }

}

####################################################

Function Get-itunesApplication(){

<#
.SYNOPSIS
This function is used to get an iOS application from the itunes store using the Apple REST API interface
.DESCRIPTION
The function connects to the Apple REST API Interface and returns applications from the itunes store
.EXAMPLE
Get-itunesApplication -SearchString "Microsoft Corporation"
Gets an iOS application from itunes store
.EXAMPLE
Get-itunesApplication -SearchString "Microsoft Corporation" -Limit 10
Gets an iOS application from itunes store with a limit of 10 results
.NOTES
NAME: Get-itunesApplication
https://affiliate.itunes.apple.com/resources/documentation/itunes-store-web-service-search-api/
#>

[cmdletbinding()]

param
(
    [Parameter(Mandatory=$true)]
    $SearchString,
    [int]$Limit
)

    try{

    Write-Verbose $SearchString

    # Testing if string contains a space and replacing it with a +
    $SearchString = $SearchString.replace(" ","+")

    Write-Verbose "SearchString variable converted if there is a space in the name $SearchString"

        if($Limit){

        $iTunesUrl = "https://itunes.apple.com/search?entity=software&term=$SearchString&attribute=softwareDeveloper&limit=$limit"

        }

        else {

        $iTunesUrl = "https://itunes.apple.com/search?entity=software&term=$SearchString&attribute=softwareDeveloper"

        }

    write-verbose $iTunesUrl
    $apps = Invoke-RestMethod -Uri $iTunesUrl -Method Get

    # Putting sleep in so that no more than 20 API calls to itunes REST API
    # https://affiliate.itunes.apple.com/resources/documentation/itunes-store-web-service-search-api/
    sleep 3

    return $apps

    }

    catch {

    write-host $_.Exception.Message -f Red
    write-host $_.Exception.ItemName -f Red
    write-verbose $_.Exception
    write-host
    break

    }

}
 
####################################################

Function Add-iOSApplication(){

<#
.SYNOPSIS
This function is used to add an iOS application using the Graph API REST interface
.DESCRIPTION
The function connects to the Graph API Interface and adds an iOS application from the itunes store
.EXAMPLE
Add-iOSApplication -AuthHeader $AuthHeader
Adds an iOS application into Intune from itunes store
.NOTES
NAME: Add-iOSApplication
#>

[cmdletbinding()]

param
(
    $itunesApp
)

$graphApiVersion = "Beta"
$Resource = "deviceAppManagement/mobileApps"

    try {

    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"

    $app = $itunesApp

    Write-Verbose $app

    Write-Host "Publishing $($app.trackName)" -f Yellow

    # Step 1 - Downloading the icon for the application
    $iconUrl = $app.artworkUrk60

        if ($iconUrl -eq $null){

        Write-Host "60x60 icon not found, using 100x100 icon"
        $iconUrl = $app.artworkUrl100

        }

        if ($iconUrl -eq $null){

        Write-Host "60x60 icon not found, using 512x512 icon"
        $iconUrl = $app.artworkUrl512

        }

    $iconResponse = Invoke-WebRequest $iconUrl
    $base64icon = [System.Convert]::ToBase64String($iconResponse.Content)
    $iconType = $iconResponse.Headers["Content-Type"]

        if(($app.minimumOsVersion.Split(".")).Count -gt 2){

        $Split = $app.minimumOsVersion.Split(".")

        $MOV = $Split[0] + "." + $Split[1]

        $osVersion = [Convert]::ToDouble($MOV)

        }

        else {

        $osVersion = [Convert]::ToDouble($app.minimumOsVersion)

        }

    # Setting support Operating System Devices
    if($app.supportedDevices -match "iPadMini"){ $iPad = $true } else { $iPad = $false }
    if($app.supportedDevices -match "iPhone6"){ $iPhone = $true } else { $iPhone = $false }

    # Step 2 - Create the Hashtable Object of the application

    $description = $app.description.Replace('“','"').Replace('”', '"')

    $graphApp = @{
        "@odata.type"="#microsoft.graph.iosStoreApp";
        displayName=$app.trackName;
        publisher=$app.artistName;
        description=$description;
        largeIcon= @{
            type=$iconType;
            value=$base64icon;
        };
        isFeatured=$false;
        appStoreUrl=$app.trackViewUrl;
        applicableDeviceType=@{
            iPad=$iPad;
            iPhoneAndIPod=$iPhone;
        };
        minimumSupportedOperatingSystem=@{
            v8_0=$osVersion -lt 9.0;
            v9_0=$osVersion -eq 9.0;
            v10_0=$osVersion -gt 9.0;
        };
    };

    $JSON = ConvertTo-Json $graphApp

    # Step 3 - Publish the application to Graph
    Write-Host "Creating application via Graph"
    $createResult = Invoke-RestMethod -Uri $uri -Method Post -ContentType "application/json" -Body (ConvertTo-Json $graphApp) -Headers $authToken
    Write-Host "Application created as $uri/$($createResult.id)"
    write-host

    }

    catch {

    $ex = $_.Exception
    $errorResponse = $ex.Response.GetResponseStream()
    $ex.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($errorResponse)
    $reader.BaseStream.Position = 0
    $reader.DiscardBufferedData()
    $responseBody = $reader.ReadToEnd();
    Write-Host "Response content:`n$responseBody" -f Red
    Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
    write-host
    break

    }

}

####################################################

#region Authentication

write-host

# Checking if authToken exists before running authentication
if($global:authToken){

    # Setting DateTime to Universal time to work in all timezones
    $DateTime = (Get-Date).ToUniversalTime()

    # If the authToken exists checking when it expires
    $TokenExpires = ($authToken.ExpiresOn.datetime - $DateTime).Minutes

        if($TokenExpires -le 0){

        write-host "Authentication Token expired" $TokenExpires "minutes ago" -ForegroundColor Yellow
        write-host

            # Defining Azure AD tenant name, this is the name of your Azure Active Directory (do not use the verified domain name)

            if($tenant -eq $null -or $tenant -eq ""){

            $tenant = Read-Host -Prompt "Please specify your tenant name"
            Write-Host

            }

        $global:authToken = Get-AuthToken -TenantName $tenant

        }
}

# Authentication doesn't exist, calling Get-AuthToken function

else {

    if($tenant -eq $null -or $tenant -eq ""){

    # Defining Azure AD tenant name, this is the name of your Azure Active Directory (do not use the verified domain name)

    $tenant = Read-Host -Prompt "Please specify your tenant name"

    }

# Getting the authorization token
$global:authToken = Get-AuthToken -TenantName $tenant

}

#endregion

####################################################

$itunesApps = Get-itunesApplication -SearchString "Microsoft Corporation" -Limit 50

#region Office Example
$Applications = 'Microsoft Outlook','Microsoft Excel','OneDrive','Outlook Groups','Microsoft Word','Microsoft Excel'
#endregion

# If application list is specified
if($Applications) {

    # Looping through applications list
    foreach($Application in $Applications){

    $itunesApp = $itunesApps.results | ? { ($_.trackName).contains("$Application") }

        # if single application count is greater than 1 loop through names
        if($itunesApp.count -gt 1){

        $itunesApp.count
        write-host "More than 1 application was found in the itunes store" -f Cyan

            foreach($iapp in $itunesApp){

            Add-iOSApplication -itunesApp $iApp

            }

        }

        # Single application found, adding application
        elseif($itunesApp){

        Add-iOSApplication -itunesApp $itunesApp

        }

        # if application isn't found in itunes returning doesn't exist
        else {

        write-host
        write-host "Application '$Application' doesn't exist" -f Red
        write-host

        }

    }

}

# No Applications have been specified
else {

    # if there are results returned from itunes query
    if($itunesApps.results){

    write-host
    write-host "Number of iOS applications to add:" $itunesApps.results.count -f Yellow
    Write-Host

        # Looping through applications returned from itunes
        foreach($itunesApp in $itunesApps.results){

        Add-iOSApplication -itunesApp $itunesApp

        }

    }

    # No applications returned from itunes
    else {

    write-host
    write-host "No applications found..." -f Red
    write-host

    }

}