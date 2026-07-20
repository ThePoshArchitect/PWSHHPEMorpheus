<#
.SYNOPSIS
Helper functions for interacting with the HPE Morpheus API.

.DESCRIPTION
This script provides reusable PowerShell functions for common Morpheus
administration tasks (tenants, roles, groups, clouds, folders, networks,
datastores, and credentials).

Public release notes:
- No credentials are stored in this file, but runtime inputs can include
    sensitive values (for example access tokens and user passwords).
- Review and validate tenant-specific defaults before sharing publicly.
- Prefer secure certificate validation in production environments.

.NOTES
Author: Kevin Kerr
Last reviewed: 2026-07-16
#>

Set-StrictMode -Version Latest

# Logging function to log messages with a timestamp
Function My-Logger {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$message
    )
    $timeStamp = Get-Date -Format "MM-dd-yyyy_HH:mm:ss"
    "[$timestamp] $message"
}

# Connect to Morpheus
# Params:
# - token: API token for authentication
function Connect-Morpheus {
    [CmdletBinding()]
    param(
        $token
    )
    $headers = @{ }
    $headers.Add("accept", "application/json")
    $headers.Add("content-type", "application/json")
    $headers.Add("authorization", "Bearer $($token)")

    return $headers
}

# Get Tenants
# Params:
# - headers: Authentication headers
# - morpheushosturl: Morpheus host URL
function Get-MorpheusTenants {
    [CmdletBinding()]
    param(
        $headers,
        $morpheushosturl
    )

    $httenants = @{ }
    $url = $morpheushosturl + "api/accounts"
    $response = ((Invoke-WebRequest -Uri $url -Method get -Headers $headers -SkipCertificateCheck).Content | ConvertFrom-Json).accounts

    foreach ($tenant in $response) {
        $httenants[$tenant.name] = $tenant
    }

    return $httenants
}

# Get Clouds
# Params:
# - headers: Authentication headers
# - morpheushosturl: Morpheus host URL
function Get-MorpheusClouds {
    [CmdletBinding()]
    param(
        $headers,
        $morpheushosturl
    )

    $htzones = @{ }
    $url = $morpheushosturl + "api/zones"
    $response = ((Invoke-WebRequest -Uri $url -Method get -Headers $headers -SkipCertificateCheck).Content | ConvertFrom-Json).zones

    foreach ($zone in $response) {
        $htzones[$zone.name] = $zone
    }

    return $htzones
}

# Get Zones by ID
# Params:
# - headers: Authentication headers
# - morpheushosturl: Morpheus host URL
function Get-MorpheusZonesbyId {
    [CmdletBinding()]
    param(
        $headers,
        $morpheushosturl
    )
    $htzones = @{ }
    $url = $morpheushosturl + "api/zones"
    
    $response = ((Invoke-WebRequest -Uri $url -Method get -Headers $headers -SkipCertificateCheck).Content | ConvertFrom-Json -AsHashtable).zones

    foreach ($resource in $response) {
        $htzones[[string]$resource.id] = $resource
    }
    return $htzones
}

# Get Role details
# Params:
# - headers: Authentication headers
# - morpheushosturl: Morpheus host URL
function Get-MorpheusRoles {
    [CmdletBinding()]
    param(
        $headers,
        $morpheushosturl
    )

    $htroles = @{ }
    $url = $morpheushosturl + "api/roles"
    try {
        $response = ((Invoke-WebRequest -Uri $url -Method get -Headers $headers -SkipCertificateCheck).Content | ConvertFrom-Json).roles
        foreach ($role in $response) {
            $htroles[$role.name] = $role.id
        }
    }
    catch {
        write-output $error[0]
    }
    return $htroles
}

# Create Tenant
# Params:
# - headers: Authentication headers
# - morpheushosturl: Morpheus host URL
# - tenantname: Name of the tenant
# - tenantdescription: Description of the tenant
# - enabled: Boolean to enable or disable the tenant
# - subdomain: Subdomain for the tenant
# - base_role_id: Base role ID for the tenant
# - currency: Currency for the tenant
# - account_number: Account number for the tenant
# - account_name: Account name for the tenant
# - customer_number: Customer number for the tenant
function New-MorpheusTenant {
    [CmdletBinding()]
    param(
        $headers,
        $morpheushosturl,
        $tenantname,
        $tenantdescription,
        $enabled,
        $subdomain,
        $base_role_id,
        $currency,
        $account_number,
        $account_name,
        $customer_number
    )

    $body = @{
        account = @{
            role           = @{
                id = $base_role_id
            }
            name           = $tenantname
            description    = $tenantdescription
            enabled        = $enabled
            subdomain      = $subdomain
            currency       = $currency
            accountNumber  = $account_number
            accountName    = $account_name
            customerNumber = $customer_number
        }
    }

    $json = $body | ConvertTo-Json -Depth 5
    $url = $morpheushosturl + "api/accounts"
    try {
        $response = Invoke-WebRequest -Uri $url -Method post -Headers $headers -Body $json -SkipCertificateCheck
    }
    catch {
        throw "New-MorpheusTenant failed: $($_.Exception.Message)"
    }

    return $response
}

# Remove Tenant
# Params:
# - headers: Authentication headers
# - morpheushosturl: Morpheus host URL
# - tenantid: ID of the tenant to be removed
function Remove-MorpheusTenant {
    [CmdletBinding()]
    param(
        $headers,
        $morpheushosturl,
        $tenantid
    )
        $url = $morpheushosturl + "api/accounts/$($tenantid)?removeResources=false"
        $response = Invoke-WebRequest -Uri $url -Method DELETE -Headers $headers -SkipCertificateCheck

    return $response.Content | ConvertFrom-Json
}

# Get Resource Pools
# Params:
# - zoneid: ID of the zone
# - headers: Authentication headers
# - morpheushosturl: Morpheus host URL
function Get-MorpheusResourcePools {
    [CmdletBinding()]
    param(
        $zoneid,
        $headers,
        $morpheushosturl
    )
    $htrespools = @{ }
    $url = $morpheushosturl + "api/zones/$zoneid/resource-pools"
        $response = ((Invoke-WebRequest -Uri $url -Method get -Headers $headers -SkipCertificateCheck).Content | ConvertFrom-Json).resourcePools

    foreach ($resource in $response) {
        $htrespools[$resource.name] = $resource
    }
    return $htrespools
}

# Get Zones
# Params:
# - headers: Authentication headers
# - morpheushosturl: Morpheus host URL
function Get-MorpheusZones {
    [CmdletBinding()]
    param(
        $headers,
        $morpheushosturl
    )
    $htzones = @{ }
    $url = $morpheushosturl + "api/zones"
    
    $response = ((Invoke-WebRequest -Uri $url -Method get -Headers $headers -SkipCertificateCheck).Content | ConvertFrom-Json -AsHashtable).zones

    foreach ($resource in $response) {
        $htzones[$resource.name] = $resource
    }
    return $htzones
}

# Get Folders
# Params:
# - headers: Authentication headers
# - morpheushosturl: Morpheus host URL
# - zoneid: ID of the zone
function Get-MorpheusFolders {
    [CmdletBinding()]
    param(
        $headers,
        $morpheushosturl,
        $zoneid
    )
    $htfolders = @{ }
    $url = $morpheushosturl + "api/zones/$zoneid/folders"
    $response = ((Invoke-WebRequest -Uri $url -Method GET -Headers $headers -SkipCertificateCheck).Content | ConvertFrom-Json).folders
        foreach ($resource in $response) {
        $htfolders[$resource.name] = $resource
    }
    return $htfolders
}

# Refresh Cloud
# Params:
# - headers: Authentication headers
# - morpheushosturl: Morpheus host URL
# - zoneid: ID of the zone
# - mode: Mode for refreshing the cloud
function Refresh-MorpheusCloud {
    [CmdletBinding()]
    param(
        $headers,
        $morpheushosturl,
        $zoneid,
        $mode
    )

    $body = @{
        mode = $mode
    }

    $url = $morpheushosturl + "api/zones/$zoneid/refresh"
    $json = $body | ConvertTo-Json
    $response = Invoke-WebRequest -Uri $url -Method post -Headers $headers -Body $json -SkipCertificateCheck
}

# Set Folder Permissions
# Params:
# - headers: Authentication headers
# - morpheushosturl: Morpheus host URL
# - tenantid: ID of the tenant
# - zoneid: ID of the zone
# - morpheusfolderid: ID of the Morpheus folder
# - tenantname: Name of the tenant
function Set-MorpheusCloudFolderPermissions {
    [CmdletBinding()]
    param(
        $headers,
        $morpheushosturl,
        $tenantid,
        $zoneid,
        $morpheusfolderid,
        $tenantname
    )

    $tenants = @()

    $ob = New-Object PSObject
    $ob | Add-Member -MemberType NoteProperty id -Value $tenantid
    $ob | Add-Member -MemberType NoteProperty name -Value $tenantname
    $ob | Add-Member -MemberType NoteProperty defaultStore -Value "false"
    $ob | Add-Member -MemberType NoteProperty defaultTarget -Value "false"
    $tenants += $ob

    
    $body = @{
        folder = @{
            defaultfolder       = "true"
            defaultimage        = "false"
            visibility          = "private"
            resourcePermissions = @{
                all      = "true"
                allplans = "true"
            }
            active              = "true"
            tenantPermissions   = @{
                accounts = @($tenantid)
            }
            tenants             = $tenants
        }
    }

    My-Logger "Updating folder permissions for tenant '$tenantname' (ID: $tenantid)"
    $json = $body | ConvertTo-Json -Depth 5
    $url = $morpheushosturl + "api/zones/$zoneid/folders/$morpheusfolderid"
    My-Logger "Request URL: $url"
    $response = Invoke-WebRequest -Uri $url -Method PUT -Headers $headers -Body $json -SkipCertificateCheck
    $return = ($response.Content | ConvertFrom-Json).folder

    return $return
}

# Create New User
# Params:
# - headers: Authentication headers
# - morpheushosturl: Morpheus host URL
# - tenantid: ID of the tenant
# - roleid: Role ID for the user
# - firstname: First name of the user
# - lastname: Last name of the user
# - username: Username for the user
# - password: Password for the user
# - emailaddress: Email address of the user
function New-MorpheusUser {
    [CmdletBinding()]
    param(
        $headers,
        $morpheushosturl,
        $tenantid,
        $roleid,
        $firstname,
        $lastname,
        $username,
        $password,
        $emailaddress
    )

    $roles = @()
    $ob = New-Object PSObject
    $ob | Add-Member -MemberType NoteProperty id -Value "$($roleid)"
    $roles += $ob

    $url = $morpheushosturl + "api/users?accountId=$($tenantid)"
    $body = @{
        user = @{
            receiveNotifications = "true"
            firstname            = "$firstname"
            lastname             = "$lastname"
            username             = "$username"
            email                = "$emailaddress"
            password             = $password
            roles                = $roles
        }
    }

    $json = $body | ConvertTo-Json -Depth 5
    $response = Invoke-WebRequest -Uri $url -Method POST -Headers $headers -Body $json -SkipCertificateCheck
    $return = $response

    return $return
}

# Set Resource Pool Permissions
# Params:
# - headers: Authentication headers
# - morpheushosturl: Morpheus host URL
# - tenantid: ID of the tenant
# - zoneid: ID of the zone
# - morpheusrespoolid: ID of the Morpheus resource pool
# - tenantname: Name of the tenant
function Set-MorpheusCloudResPoolPermissions {
    [CmdletBinding()]
    param(
        $headers,
        $morpheushosturl,
        $tenantid,
        $zoneid,
        $morpheusrespoolid,
        $tenantname
    )

    $tenants = @()

    $ob = New-Object PSObject
    $ob | Add-Member -MemberType NoteProperty id -Value "1"
    $ob | Add-Member -MemberType NoteProperty name -Value "MSP_Master"
    $ob | Add-Member -MemberType NoteProperty defaultStore -Value "false"
    $ob | Add-Member -MemberType NoteProperty defaultTarget -Value "false"
    $tenants += $ob

    $ob = New-Object PSObject
    $ob | Add-Member -MemberType NoteProperty id -Value $tenantid
    $ob | Add-Member -MemberType NoteProperty name -Value $tenantname
    $ob | Add-Member -MemberType NoteProperty defaultStore -Value "false"
    $ob | Add-Member -MemberType NoteProperty defaultTarget -Value "false"
    $tenants += $ob

    $body = @{
        resourcePool = @{
            visibility          = "private"
            defaultPool         = "false"
            resourcePermissions = @{
                all      = "true"
                allplans = "true"
            }
            active              = "true"
            tenantPermissions   = @{
                accounts = @($tenantid)
            }
            tenants             = $tenants
        }
    }

    $json = $body | ConvertTo-Json -Depth 5
    $url = $morpheushosturl + "api/zones/$zoneid/resource-pools/$morpheusrespoolid"
    $response = Invoke-WebRequest -Uri $url -Method PUT -Headers $headers -Body $json -SkipCertificateCheck
    $return = ($response.Content | ConvertFrom-Json).resourcePool

    return $return
}

# Get Tenant Role
# Params:
# - headers: Authentication headers
# - morpheushosturl: Morpheus host URL
# - tenantid: ID of the tenant
function get-tenantrole {
    [CmdletBinding()]
    param(
        $headers,
        $morpheushosturl,
        $tenantid
    )
    $url = $morpheushosturl + "api/users/available-roles?accountId=$($tenantid)"
    $response = Invoke-WebRequest -Uri $url -Method GET -Headers $headers -SkipCertificateCheck
    $return = ($response.Content | ConvertFrom-Json -AsHashtable).roles
    return $return
}

# Update Tenant Role
# Params:
# - headers: Authentication headers
# - morpheushosturl: Morpheus host URL
# - groupid: ID of the group
# - roleid: Role ID to be updated
function update-tenantrole {
    [CmdletBinding()]
    param(
        $headers,
        $morpheushosturl,
        [int]$groupid,
        $roleid
    )

    $url = $morpheushosturl + "api/roles/$roleid/update-group"
    $Body = @{
        group = @{
            id   = $groupid
            role = "read"
        }
    } | ConvertTo-Json -Depth 2
    $response = Invoke-WebRequest -Uri $url -Method PUT -Headers $headers -ContentType 'application/json' -Body $Body -SkipCertificateCheck
    return $response
}

# Update Role Permissions
# Params:
# - headers: Authentication headers
# - morpheushosturl: Morpheus host URL
# - roleid: Role ID to be updated
function update-rolepermissions {
    [CmdletBinding()]
    param(
        $headers,
        $morpheushosturl,
        $roleid
    )

    $url = $morpheushosturl + "api/roles/$roleid/update-permission"

    # Define the hash table
    $permission = @{
        permissionCode = "ComputeSite"
        access         = "read"
    }

    # Convert the hash table to JSON format (if needed)
    $jsonPermission = $permission | ConvertTo-Json

    $response = Invoke-WebRequest -Uri $url -Method PUT -Headers $headers -ContentType 'application/json' -Body  $jsonPermission -SkipCertificateCheck
    return $response
}

# Get Tenant Groups
# Params:
# - headers: Authentication headers
# - morpheushosturl: Morpheus host URL
# - tenantid: ID of the tenant
function Get-MorpheusTenantGroups {
    [CmdletBinding()]
    param(
        $headers,
        $morpheushosturl,
        $tenantid
    )

    $url = $morpheushosturl + "api/accounts/$tenantid/groups"
    $response = Invoke-WebRequest -Uri $url -Method GET -Headers $headers -SkipCertificateCheck
    $return = ($response.Content | ConvertFrom-Json -AsHashtable).groups
    return $return
}

# Remove Tenant Group
# Params:
# - headers: Authentication headers
# - morpheushosturl: Morpheus host URL
# - tenantid: ID of the tenant
# - groupid: ID of the group to be removed
function Remove-MorpheusTenantGroup {
    [CmdletBinding()]
    param(
        $headers,
        $morpheushosturl,
        $tenantid,
        $groupid
    )

    $url = $morpheushosturl + "api/accounts/$tenantid/groups/$groupid"
    $response = Invoke-WebRequest -Uri $url -Method DELETE -Headers $headers -SkipCertificateCheck
    return $response
}

# Create New Tenant Group
# Params:
# - headers: Authentication headers
# - morpheushosturl: Morpheus host URL
# - tenantid: ID of the tenant
# - groupname: Name of the group
# - groupdescription: Description of the group
# - groupcode: Code for the group
# - grouplocation: Location of the group
function New-MorpheusTenantGroup {
    [CmdletBinding()]
    param(
        $headers,
        $morpheushosturl,
        $tenantid,
        $groupname,
        $groupdescription,
        $groupcode,
        $grouplocation
    )

    $body = @{
        group = @{
            name        = $groupname
            description = $groupdescription
            code        = $groupcode
            location    = $grouplocation
            visibility  = "private"
            active      = "true"
        }
    }

    $json = $body | ConvertTo-Json -Depth 5
    $url = $morpheushosturl + "api/accounts/$tenantid/groups"
    $response = Invoke-WebRequest -Uri $url -Method POST -Headers $headers -Body $json -SkipCertificateCheck
    return $response
}

# Add Tenant Group Zone
# Params:
# - headers: Authentication headers
# - morpheushosturl: Morpheus host URL
# - tenantid: ID of the tenant
# - groupid: ID of the group
# - zoneid: ID of the zone
function Add-MorpheusTenantGroupZone {
    [CmdletBinding()]
    param(
        $headers,
        $morpheushosturl,
        $tenantid,
        $groupid,
        $zoneid
    )

    $zones = @()
    $ob = New-Object PSObject
    $ob | Add-Member -MemberType NoteProperty -Name "id" -Value $zoneid
    $zones += $ob

    $body = @{
        group = @{
            zones = $zones
        }
    }

    $json = $body | ConvertTo-Json -Depth 5
    $url = $morpheushosturl + "api/accounts/$tenantid/groups/$groupid/update-zones"
    $response = Invoke-WebRequest -Uri $url -Method PUT -Headers $headers -Body $json -SkipCertificateCheck
    return $response
}

# Create Cloud Function
# Params:
# - morpheushostUrl: Morpheus API URL
# - headers: Authentication headers
# - cloudName: Desired name for the vCenter Cloud in Morpheus
# - vCenterHost: vCenter Hostname or IP Address
# - datacenter: vCenter Datacenter Name
# - resourcePool: vCenter Resource Pool Name
# - applianceurl: Appliance URL
# - diskstoragetype: Disk storage type
# - cluster: Cluster name
# - accountid: Account ID
# - groupid: Group ID
# - zoneTypeid: Zone Type ID
# - credentialid: Credential ID
# - location: Location
# - tenantid: Tenant ID
# - apiurl: API URL
# - tenanttype: Tenant type
function New-MorpheusVCenterCloud {
    [CmdletBinding()]
    param(
        [string]$morpheushostUrl, # Morpheus API URL
        $headers, # Morpheus API Key
        [string]$cloudName, # Desired name for the vCenter Cloud in Morpheus
        [string]$vCenterHost, # vCenter Hostname or IP Address
        [string]$datacenter, # vCenter Datacenter Name
        [string]$resourcePool, # vCenter Resource Pool Name
        [string]$applianceurl,
        [string]$diskstoragetype,
        [string]$cluster,
        [int64]$accountid,
        [int64]$groupid,
        [int64]$zoneTypeid,
        [int64]$credentialid,
        [string]$location,
        [int64]$tenantid,
        [string]$apiurl,
        [string]$tenanttype
    )

    if ($tenanttype -eq "MSP") {
        $inventory = "on"
    }
    else {
        $inventory = "off"
    }
    # Morpheus API Base URL
    $baseUri = "$($morpheushostUrl)api"

    # Construct the body for the POST request to create a vCenter cloud
    $body = @{
        zone = @{
            name                       = $cloudName
            code                       = "$($cloudName.ToLower())"  # Unique code for the cloud
            description                = "vCenter Cloud for $cloudName"
            visibility                 = "private"
            enabled                    = $true
            type                       = "vmwarevsphere"  # vCenter Type in Morpheus
            config                     = @{
                apiUrl               = $apiurl
                datacenter           = $datacenter
                resourcePool         = $resourcePool
                validateCertificates = $false  # Set to true if using trusted certs
                applianceurl         = $applianceurl
                diskstoragetype      = $diskstoragetype
                cluster              = $cluster
                enableVnc            = "on"
                securityServer       = "off"
                hideHostSelection    = "on"
            }
            timezone                   = "Europe/London"
            regionCode                 = "c6cef5644dbbe8a9917584149664bc898b75cdceaef16372007dd5e4"
            consoleKeymap              = "uk"
            inventoryLevel             = $inventory
            groupid                    = $groupid
            importExisting             = "off"
            enableStorageTypeSelection = "off"
            enableDiskTypeSelection    = "off"
            enableNetworkTypeSelection = "off"
            credential                 = @{
                id   = $credentialid
                type = "username and password"
            }
            location                   = $location
            accountId                  = $tenantid  # Adjust as per your tenant structure, 1 is usually the default tenant ID
            zoneType                   = @{
                id = $zonetypeid
            }
        }
    }

    #write-output $body
    # Convert body to JSON
    $jsonBody = $body | ConvertTo-Json -Depth 9

    #write-output $jsonBody

    # Make API request to create the vCenter cloud
    try {
        $response = Invoke-RestMethod -Uri "$baseUri/zones" -Method Post -Headers $headers -Body $jsonBody -SkipCertificateCheck
        if ($response) {
            My-Logger "vCenter Cloud '$cloudName' created successfully." 
        }
    }
    catch {
        My-Logger "Failed to create vCenter Cloud: $_"
        throw
    }
    return $response
}

# Update vCenter Cloud
# Params:
# - id: ID of the vCenter Cloud
# - morpheushostUrl: Morpheus API URL
# - headers: Authentication headers
# - cloudName: Desired name for the vCenter Cloud in Morpheus
# - accountid: Account ID
# - groupid: Group ID
# - zoneTypeid: Zone Type ID
# - credentialid: Credential ID
# - apiurl: API URL
# - inventorylevel: Inventory level (on or off)
function Update-MorpheusVCenterCloud {
    [CmdletBinding()]
    param(
        $id,
        [string]$morpheushostUrl, # Morpheus API URL
        $headers, # Morpheus API Key
        [string]$cloudName, # Desired name for the vCenter Cloud in Morpheus
        [int64]$accountid,
        [int64]$groupid,
        [int64]$zoneTypeid,
        [int64]$credentialid,
        [string]$apiurl,
        [string]$inventorylevel # on or off
    )

    # Morpheus API Base URL
    $baseUri = "$morpheushostUrl/api"

    # Construct the body for the POST request to create a vCenter cloud
    $body = @{
        zone = @{
            name           = $cloudName
            type           = "vmwarevsphere"  # vCenter Type in Morpheus
            inventoryLevel = $inventorylevel
            groupid        = $groupid
            credential     = @{
                id   = $credentialid
                type = "username and password"
            }
        }
    }

    # Convert body to JSON
    $jsonBody = $body | ConvertTo-Json -Depth 9

    # Make API request to create the vCenter cloud
    try {
        $response = Invoke-RestMethod -Uri "$baseUri/zones/$id" -Method Put -Headers $headers -Body $jsonBody -SkipCertificateCheck
        if ($response) {
            My-Logger "vCenter Cloud '$cloudName' updated successfully." 
        }
    }
    catch {
        Write-Error "Failed to update vCenter Cloud: $_"
    }
    return $response
}

# Get Cloud Networks
# Params:
# - morpheushosturl: Morpheus host URL
# - headers: Authentication headers
# - cloudid: ID of the cloud
function get-morcloudnetworks {
    [CmdletBinding()]
    param(
        $morpheushosturl,
        $headers,
        $cloudid
    )

    $url = $morpheushosturl + "api/networks?max=500&zoneId=$cloudid"
    $response = Invoke-WebRequest -Uri $url -Method GET -Headers $headers -SkipCertificateCheck
    return $response.content | convertfrom-json
}

# Disable Cloud Networks
# Params:
# - morpheushosturl: Morpheus host URL
# - headers: Authentication headers
# - networkid: ID of the network to be disabled
function disable-morcloudnetworks {
    [CmdletBinding()]
    param(
        $morpheushosturl,
        $headers,
        [string]$networkid
    )

    $body = @{
        network = @{
            visibility = "private"
            active     = $false
            tenants    = @{
                id = 1
            }
        }
    }

    $jsonbody = $body | convertto-json -Depth 9

    $url = $morpheushosturl + "api/networks/$networkid"
    $response = Invoke-WebRequest -Uri $url -Method PUT -Headers $headers -ContentType 'application/json' -Body $jsonbody -SkipCertificateCheck
    return $response
}

# Get Cloud Datastores
# Params:
# - morpheushosturl: Morpheus host URL
# - headers: Authentication headers
# - cloudid: ID of the cloud
function get-morcloudDatastores {
    [CmdletBinding()]
    param(
        $morpheushosturl,
        $headers,
        $cloudid
    )
    $url = $morpheushosturl + "api/zones/$cloudid/data-stores?max=500"
    $response = Invoke-WebRequest -Uri $url -Method GET -Headers $headers -SkipCertificateCheck
    return $response.content | convertfrom-json
}

# Disable Cloud Datastores
# Params:
# - morpheushosturl: Morpheus host URL
# - headers: Authentication headers
# - datastoreid: ID of the datastore to be disabled
# - cloudid: ID of the cloud
function disable-morclouddatastores {
    [CmdletBinding()]
    param(
        $morpheushosturl,
        $headers,
        [string]$datastoreid,
        $cloudid
    )
    $url = $morpheushosturl + "api/zones/$cloudid/data-stores/$datastoreid"
    $response = Invoke-WebRequest -Uri $url -Method PUT -Headers $headers -ContentType 'application/json' -Body '{"datastore":{"visibility":"private","resourcePermissions":{"all":true,"allPlans":true},"tenantPermissions":[{"accounts":[1]}],"active":false}}' -SkipCertificateCheck
    return $response
}

# Get Cloud Folders
# Params:
# - morpheushosturl: Morpheus host URL
# - headers: Authentication headers
# - cloudid: ID of the cloud
function get-morCloudFolders {
    [CmdletBinding()]
    param(
        $morpheushosturl,
        $headers,
        $cloudid
    )
    $url = $morpheushosturl + "api/zones/$cloudid/folders?max=500"
    $response = Invoke-WebRequest -Uri $url -Method GET -Headers $headers -SkipCertificateCheck
    return $response.content | convertfrom-json
}

# Get Cloud Tenant Folders
# Params:
# - morpheushosturl: Morpheus host URL
# - headers: Authentication headers
# - cloudid: ID of the cloud
# - foldername: Name of the folder
function get-morCloudTenantFolder{
    [CmdletBinding()]
    param(
        $morpheushosturl,
        $headers,
        $cloudid,
        $foldername
    )
    $url = $morpheushosturl + "api/zones/$cloudid/folders?max=1&name=$($foldername)"
    $response = Invoke-WebRequest -Uri $url -Method GET -Headers $headers -SkipCertificateCheck
    return $response.content | convertfrom-json
}

# Disable Cloud Folders
# Params:
# - morpheushosturl: Morpheus host URL
# - headers: Authentication headers
# - folderid: ID of the folder to be disabled
# - cloudid: ID of the cloud
function disable-morCloudFolders {
    [CmdletBinding()]
    param(
        $morpheushosturl,
        $headers,
        [string]$folderid,
        $cloudid
    )
    $url = $morpheushosturl + "api/zones/$cloudid/folders/$folderid"
    $response = Invoke-WebRequest -Uri $url -Method PUT -Headers $headers -ContentType 'application/json' -Body '{"folder":{"defaultFolder":false,"defaultImage":false,"visibility":"private","resourcePermissions":{"all":true,"allPlans":true},"active":false,"tenantPermissions":[{"accounts":[1]}]}}' -SkipCertificateCheck
    return $response
}

# Get Cloud Tenant Networks
# Params:
# - morpheushosturl: Morpheus host URL
# - headers: Authentication headers
# - tenantname: Name of the tenant
# - cloudid: ID of the cloud
function get-morcloudTenantnetworks {
    [CmdletBinding()]
    param(
        $morpheushosturl,
        $headers,
        $tenantname,
        $cloudid
    )
    $url = $morpheushosturl + "api/networks?phrase=$tenantname&zoneId=$cloudid"
    $response = Invoke-WebRequest -Uri $url -Method GET -Headers $headers -SkipCertificateCheck
    return $response.content | convertfrom-json
}

# Set Cloud Network Permissions
# Params:
# - networkid: ID of the network
# - morpheushosturl: Morpheus host URL
# - cloudid: ID of the cloud
# - headers: Authentication headers
# - tenantid: ID of the tenant
function set-morcloudnetworkpermisions {
    [CmdletBinding()]
    param(
        $networkid,
        $morpheushosturl,
        $cloudid,
        $headers,
        $tenantid
    )

    $url = $morpheushosturl + "api/zones/$cloudid/networks/$networkid"
    $response = Invoke-WebRequest -Uri $url -Method PUT -Headers $headers -ContentType 'application/json' -Body "{'network':{'visibility':'private','tenants':[{'id':$($tenantid)}],'active':true}}" -SkipCertificateCheck
    return $response
}

# Get Cloud Tenant Datastores
# Params:
# - morpheushosturl: Morpheus host URL
# - headers: Authentication headers
# - tenantname: Name of the tenant
# - cloudid: ID of the cloud
function get-morcloudtenantdatastores {
    [CmdletBinding()]
    param(
        $morpheushosturl,
        $headers,
        $tenantname,
        $cloudid
    )
    $url = $morpheushosturl + "api/zones/$cloudid/data-stores?phrase=$tenantname"
    $response = Invoke-WebRequest -Uri $url -Method GET -Headers $headers -SkipCertificateCheck
    return $response.content | convertfrom-json
}

# Set Cloud Datastore Permissions
# Params:
# - datastoreid: ID of the datastore
# - morpheushosturl: Morpheus host URL
# - cloudid: ID of the cloud
# - headers: Authentication headers
# - tenantid: ID of the tenant
function set-morclouddatastorepermisions {
    [CmdletBinding()]
    param(
        $datastoreid,
        $morpheushosturl,
        $cloudid,
        $headers,
        $tenantid
    )

    $ids = @($tenantid)
    $tenantArray = $ids | ForEach-Object { "{`"id`":$_}" }
    $json = "{`"datastore`":{`"visibility`":`"private`",`"tenants`":[ $($tenantArray -join ',') ],`"active`":false}}"

    $url = $morpheushosturl + "api/zones/$cloudid/data-stores/$datastoreid"
    $response = Invoke-WebRequest -Uri $url -Method Put -Headers $headers -ContentType 'application/json' -Body $json -SkipCertificateCheck
    return ($response.content | convertfrom-json).datastore
}

# Get Credential
# Params:
# - morpheushosturl: Morpheus host URL
# - headers: Authentication headers
# - id: ID of the credential
function get-morcredential {
    [CmdletBinding()]
    param(
        $morpheushosturl,
        $headers,
        $id
    )

    $url = $morpheushosturl + "api/credentials/$id"
    $response = Invoke-WebRequest -Uri $url -Method GET -Headers $headers -SkipCertificateCheck
    return $response.content | convertfrom-json
}

# Get Credentials
# Params:
# - morpheushosturl: Morpheus host URL
# - headers: Authentication headers
function get-morcredentials {
    [CmdletBinding()]
    param(
        $morpheushosturl,
        $headers
    )

    $url = $morpheushosturl + "api/credentials/"
    $response = Invoke-WebRequest -Uri $url -Method GET -Headers $headers -SkipCertificateCheck
    return $response.content | convertfrom-json
}

