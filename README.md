# HPE Morpheus PowerShell Functions

This repository contains reusable PowerShell functions for common HPE Morpheus API operations:

- Authentication and headers
- Tenant lifecycle and role operations
- Group and zone assignment
- Cloud creation and update
- Folder, network, and datastore permissions
- Credential queries

## File

- hpemorpheusfunctions.ps1

## Requirements

- PowerShell 7+
- Network access to your Morpheus appliance
- A Morpheus API token with sufficient permissions

## Quick Start

1. Import or dot-source the functions file.
2. Create headers with your API token.
3. Call the required function.

Example:

```powershell
. .\hpemorpheusfunctions.ps1

$headers = Connect-Morpheus -token $env:MORPHEUS_TOKEN
$tenants = Get-MorpheusTenants -headers $headers -morpheushosturl "https://morpheus.example.local/"
$tenants.Keys
```

## Examples

### 1. Connect And List Tenants

```powershell
. .\hpemorpheusfunctions.ps1

$morpheusHost = "https://morpheus.example.local/"
$token = $env:MORPHEUS_TOKEN
$headers = Connect-Morpheus -token $token

$tenants = Get-MorpheusTenants -headers $headers -morpheushosturl $morpheusHost
$tenants.Keys
```

### 2. Create A Tenant

```powershell
$newTenantResponse = New-MorpheusTenant `
	-headers $headers `
	-morpheushosturl $morpheusHost `
	-tenantname "contoso" `
	-tenantdescription "Contoso tenant" `
	-enabled $true `
	-subdomain "contoso" `
	-base_role_id 2 `
	-currency "USD" `
	-account_number "1001" `
	-account_name "Contoso" `
	-customer_number "CUST-1001"

$newTenantResponse.StatusCode
```

### 3. Create A Tenant User

```powershell
$userResponse = New-MorpheusUser `
	-headers $headers `
	-morpheushosturl $morpheusHost `
	-tenantid 10 `
	-roleid 2 `
	-firstname "Jane" `
	-lastname "Doe" `
	-username "jane.doe" `
	-password "ReplaceWithSecurePassword" `
	-emailaddress "jane.doe@example.com"

$userResponse.StatusCode
```

### 4. Create A Group And Assign A Zone

```powershell
$groupResponse = New-MorpheusTenantGroup `
	-headers $headers `
	-morpheushosturl $morpheusHost `
	-tenantid 10 `
	-groupname "contoso-prod" `
	-groupdescription "Production group" `
	-groupcode "CTO-PROD" `
	-grouplocation "London"

$groupId = ($groupResponse.Content | ConvertFrom-Json).group.id

Add-MorpheusTenantGroupZone `
	-headers $headers `
	-morpheushosturl $morpheusHost `
	-tenantid 10 `
	-groupid $groupId `
	-zoneid 3
```

### 5. Create A vCenter Cloud

```powershell
$cloudResponse = New-MorpheusVCenterCloud `
	-morpheushostUrl $morpheusHost `
	-headers $headers `
	-cloudName "contoso-vc01" `
	-vCenterHost "vcsa01.example.local" `
	-datacenter "DC1" `
	-resourcePool "Resources" `
	-applianceurl "https://morpheus-appliance.example.local" `
	-diskstoragetype "thin" `
	-cluster "Cluster01" `
	-accountid 10 `
	-groupid 20 `
	-zoneTypeid 6 `
	-credentialid 15 `
	-location "London" `
	-tenantid 10 `
	-apiurl "https://vcsa01.example.local" `
	-tenanttype "MSP"

$cloudResponse
```

### 6. Set Resource Pool Permissions For A Tenant

```powershell
Set-MorpheusCloudResPoolPermissions `
	-headers $headers `
	-morpheushosturl $morpheusHost `
	-tenantid 10 `
	-zoneid 3 `
	-morpheusrespoolid 200 `
	-tenantname "contoso"
```

