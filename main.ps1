# Declare the function - this will be standard in all Tasks
Function New-ModulefromGitHub {
    <#
    .SYNOPSIS
    Takes a Github Raw url, downloads the Powershell Script and Executes as a Dynamic Module
 
    .DESCRIPTION
    Takes a Github Raw url, downloads the Powershell Script and Executes as a Dynamic Module
 
    Examples:
    New-ModulefromGitHub -ScriptUrl <Github Raw URL for the Powershell script> -Name "GibModule"
 
    .PARAMETER ScriptUrl
    GitHub Raw Url to Powershell script
 
    .PARAMETER Name
    A String to identify the Dynamic Module name
 
    .OUTPUTS
    Loads a Dynamic Module
 
    #>     
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [String]$ScriptUrl,
        [Parameter(Mandatory=$true,Position=1)]
        [String]$Name
    )
    if ($ScriptUrl) {
        try {
            $Response = Invoke-WebRequest -Uri $ScriptUrl -UseBasicParsing -ErrorAction SilentlyContinue
            $StatusCode = $Response.StatusCode
        }
        catch {
            $StatusCode = $_.Exception.Response.StatusCode
            Write-Warning "Cannot locate Script Url $ScriptUrl - Status:$StatusCode"
        }
        if ($StatusCode -eq 200) {
            try {
                New-Module -Name $Name -ScriptBlock ([ScriptBlock]::Create($Response.Content))
            }
            catch {
                Write-Error "ScriptUrl is not a valid Powershell Module ScriptBlock"
            }           
        }
    } else {
        Write-Warning "You must enter a Script URL"
    }
}
 
# Start your custom script here
 
# Git Raw URL of a scipt to load as a Module. (Note it must be a raw Url type)
$GitUrl = "https://raw.githubusercontent.com/ThePoshArchitect/PWSHHPEMorpheus/refs/heads/main/hpemorpheusfunctions.ps1"
 
# Hide Progress updates in Morpheus
$ProgressPreference="SilentlyContinue"
 
# Load the Dynamic Module using the function created above. To prevent output being written into the
# script assign the command below into a variable eg $NoOutput = New-ModuleFromGitHub ...
try{
New-ModuleFromGitHub -ScriptUrl $GitUrl -Name "MorpheusFunctions"
$apitoken = '<%=morpheus.apiAccessToken%>'
$morpheushosturl = '<%=morpheus.applianceUrl%>'
$headers = connect-morpheus -token $apitoken
write-host "######### Morpheus Host URL###############"
write-host $hosturl
 
 
[string]$tenanttype = '<%=customOptions.tenantType%>'  # Default tenant type
[string]$tenantName = '<%=customOptions.tenantName%>'  # Name of the tenant to create or use
[string]$vCenter = ''  # Default vCenter server
[string]$Cluster = ''  # Cluster name in vCenter
[string]$vcuser = '<%=cypher.read("secret/vcenterserviceaccount")%>'  # vCenter username
[string]$vcpassword = '<%=cypher.read("secret/vcenterserviceaccountpassword")%>'  # vCenter password
[string]$TopLevelResPool = ''  # Top-level resource pool name
[string]$parentfoldername = ''  # Parent folder name in vCenter
[string]$datacenter = ''  # Datacenter name in vCenter
[int]$zonetypeid =   # Zone type ID for Morpheus
[int]$credentialid =   # Credential ID for Morpheus
[string]$location = ''  # Location for the cloud
[string]$adminuser = "admin" #Admin useraccount for tenant
[string]$adminpass = "demo1234!" #  Admin password for Admin User
[string]$useruser = "user" # Tenant user Name
[string]$userpass = "demo1234!" # Tenant User password
[string]$tenantUserRole = "CST_MultiTenant_Normal_User_Role_Base" # Tenant User Role
$tenantadminroleid = 151 # Tenant Admin Role ID
$tenantuserroleid = 288 # Tenant User Role ID

 
 
# Log the connection to vCenter
My-Logger "Connecting to vCenter"
$securePassword = ConvertTo-SecureString $vcpassword -AsPlainText -Force
 
$cred = New-Object System.Management.Automation.PSCredential ($vcuser, $securePassword)
#$vcsession = Connect-VIServer -Server $vCenter -Credential $cred -ErrorAction Stop
 
# Check for existing vCenter connections and disconnect them
$check = get-viserver -Server $vCenter -User $vcuser -Password $securePassword -ErrorAction SilentlyContinue
if ($check) {
    My-Logger "Disconnecting from existing vCenter connections"
    $disconnect = disconnect-viserver -Server $vCenter -Confirm:$false -ErrorAction SilentlyContinue
} else {
    My-Logger "No existing vCenter connections found"
}
My-Logger "Test vCenter is reachable"
# Check if the vCenter server is reachable
$ping = Test-Connection -ComputerName $vCenter -Count 1 -ErrorAction SilentlyContinue
if ($ping) {
    My-Logger "vCenter $vCenter is reachable"
} else {
    My-Logger "vCenter $vCenter is not reachable" 
    exit
}
 
# Log the received vCenter credentials
My-Logger "Received vcuser: $vcuser"
My-Logger "Received vcpassword: [REDACTED]"  # Avoid logging sensitive information
 
# Validate that vCenter credentials are provided
if (-not $vcuser -or -not $vcpassword) {
    My-Logger "vCenter credentials are not provided. Exiting." 
    exit
}
 
# Disconnect any existing vCenter sessions
try {
    My-Logger "Disconnecting any existing vCenter sessions"
    Disconnect-VIServer -Server $vCenter -Confirm:$false -ErrorAction SilentlyContinue
} catch {
    My-Logger "No existing vCenter sessions to disconnect."
}
 
# Connect to vCenter using the provided credentials
try {
    My-Logger "Connecting to vCenter with provided credentials"
    
    #$vcsession = Connect-VIServer -Server $vCenter -User $vcuser -Password $securePassword -ErrorAction Stop
    $vcsession = Connect-VIServer -Server $vCenter -Credential $cred -force -ErrorAction Stop
    if ($vcsession.IsConnected) {
        My-Logger "Successfully connected to vCenter $vCenter"
    } else {
        My-Logger "Failed to establish a valid connection to vCenter $vCenter"
        exit
    }
} catch {
    My-Logger "Error while connecting to vCenter: $($_.Exception.Message)"
    exit
}
 
# Log the connection to Morpheus
My-Logger "Connecting to Morpheus"
 
 
# Log the collection of Morpheus zones and clouds
My-Logger "Collecting Morpheus Zones/Clouds"
$zones = get-morpheuszones -headers $headers -morpheushosturl $morpheushosturl 
$zonesID = get-morpheuszonesbyId -headers $headers -morpheushosturl $morpheushosturl
$clustername = $zonesID["$($CloudID)"].config.cluster
 
# Log the collection of tenants
My-Logger "Collecting tenants"  
$HTAllTenants = get-morpheustenants -headers $headers -morpheushosturl $morpheushosturl
 
# Log the collection of roles
My-Logger "Collecting roles"
$HTRoles = get-morpheusroles -headers $headers -morpheushosturl $morpheushosturl
 
# Check if the tenant already exists
My-Logger "Checking whether tenant exists"          
$check = (get-morpheustenants -headers $headers -morpheushosturl $morpheushosturl)["$($tenantname)"]
 
# If the tenant exists, skip creation
if ($check.count -ne 0) {
    My-Logger "Tenant $tenantname already exists, skipping..." 
} else {
    # Log the creation of a new tenant
    My-Logger "Tenant does not exist, creating"
    My-Logger "Creating Tenant: $tenantname"
 
    # Create a subdomain by removing spaces and converting to lowercase
    $subdomain = $tenantname.replace(" ", "").tolower()
 
    # Create the tenant in Morpheus
    $newtenant = new-morpheustenant -headers $headers -morpheushosturl $morpheushosturl -tenantname $tenantname -tenantdescription $tenantname -enabled "true" -subdomain $subdomain -base_role_id $HTRoles["CST_Tenant_Role_Base"] -currency "GBP"
    [int64]$tenantid = $(($newtenant.Content | convertfrom-json).account.id) 
    My-Logger "Tenant ID: $tenantid"
    My-Logger "Tenant $tenantname created" 
    My-Logger "New tenant account object returned by Morpheus"
}
 
# Log the start of vCenter resource pool operations
My-Logger "Starting vCenter operations"
My-Logger "Collecting resource pools"
 
# Collect resource pools in the specified cluster
$vcrespools = Get-ResourcePool -location $cluster
$htrespools = @{ }
foreach ($vcrespool in $vcrespools) {
    $htrespools[$vcrespool.name] = $vcrespool
}
 
# Define the resource pool name
$respoollocation = get-cluster $cluster
$respoolname = "CMP-$($TenantName)-$($tenanttype)"
 
# Check if the resource pool already exists
$checkpool = $htrespools["$respoolname"]
My-Logger "Checking resource pool"
if ($checkpool.count -ne 0) {
    My-Logger "MSP resource pool $respoolname already exists"
    My-Logger "Using existing resource pool"
} else {
    My-Logger "Creating resource pool $respoolname"
    $parentResourcePool = Get-ResourcePool -Name $TopLevelResPool -Location $respoollocation
    My-Logger "Parent resource pool: $($parentResourcePool.name)"
 
    # Ensure $parentResourcePool contains a single valid object
    if ($parentResourcePool -is [array]) {
        if ($parentResourcePool.Count -eq 1) {
            $parentResourcePool = $parentResourcePool[0]  # Use the single object
        } else {
            My-Logger "Multiple parent resource pools found. Please refine your selection criteria."
            exit
        }
    } elseif (-not $parentResourcePool) {
        My-Logger "No parent resource pool found. Please check the TopLevelResPool and Cluster parameters."
        exit
    }
 
    # Proceed with creating the resource pool
    $newrespool = New-ResourcePool -Name "$($respoolname)" -Location $parentResourcePool
}
 
# Define the folder name
$foldername = $respoolname
 
# Log the creation of vSphere folders
My-Logger "Creating folder"  
$vcfolders = Get-folder -Location $parentfoldername
$htfolders = @{ }
foreach ($vcfolder in $vcfolders) {
    $htfolders[$vcfolder.name] = $vcfolder
}
 
# Check if the folder already exists
$checkfolder = $htfolders["$foldername"]
$parentFolder = Get-Folder -Name $parentfoldername -Type VM -Location $datacenter
if ($checkfolder.count -ne 0) {
    My-Logger "MSP Folder $foldername already exists" 
} else {
    My-Logger "Creating Folder $foldername"
    $newfolder = New-folder -Name "$($foldername)" -Location $parentFolder
}
 
# Define the cloud name
$cloudname = "$($location)-$($tenantname)-$($tenanttype)"
 
# Log the creation of the cloud
My-Logger "Creating Cloud $cloudname"
 
# Create the cloud in Morpheus
$createcloud = New-MorpheusVCenterCloud `
    -morpheushostUrl "$morpheushosturl" `
    -headers $headers `
    -cloudName $cloudname `
    -datacenter "$($datacenter)" `
    -resourcePool "$respoolname" `
    -applianceurl "" `
    -diskstoragetype "thin" `
    -cluster $Cluster `
    -groupid 286 `
    -tenantid $tenantid `
    -zonetypeid $zonetypeid `
    -location $location `
    -credentialid $credentialid `
    -apiurl "https://$($vcenter)/sdk"
 
# Wait for the cloud to be fully configured
start-sleep 10
 
# Log the cloud ID
My-Logger "Cloud ID: $($createcloud.zone.id)"  
 
# Log the start of network permissions setup
My-Logger "Setting permissions for $($createcloud.name)"
$cloudid = $createcloud.zone.id
My-Logger "Cloud ID: $cloudid"
 
# Collect and disable all networks in the new cloud
My-Logger "Get all networks in $($createcloud.name)"
$networks = get-morcloudnetworks -morpheushosturl $morpheushosturl -headers $headers -cloudid $cloudid
My-Logger "Disabling all networks in $($createcloud.name)"
$disablednetworks = @{ }
foreach ($network in $networks.networks) {
    [string]$netid = $network.id
    $disablednetworks[$netid] = disable-morcloudnetworks -morpheushosturl $morpheushosturl -headers $headers -networkid $netid
}
 
# Set permissions on networks based on the tenant name
My-Logger "Setting network permissions based on tenant name $tenantname"
$networks = get-morcloudtenantnetworks -morpheushosturl $morpheushosturl -headers $headers -tenantname $tenantname -cloudid $cloudid
if ($networks.networks.count -eq 0) {
    My-Logger "No networks found that match $($tenantname)"
} else {
    My-Logger "Found the following networks"
    My-Logger "Setting permissions for the found networks"
    $setperms = @{ }
    foreach ($id in $networks.networks.id) {
        $setperms[$id] = set-morcloudnetworkpermisions -morpheushosturl $morpheushosturl -networkid $id -cloudid $cloudid -headers $headers -tenantid $tenantid
    }
}
 
# Disable all datastores in the new cloud
My-Logger "Getting all datastores in Morpheus"
$disablednetworks = @{ }
$ds = get-morcloudDatastores -morpheushosturl $morpheushosturl -headers $headers -cloudid $cloudid
foreach ($x in $ds.datastores) {
    $disablednetworks[$x.id] = disable-morclouddatastores -morpheushosturl $morpheushosturl -headers $headers -datastoreid $x.id -cloudid $cloudid
}
 
# Set permissions on the correct datastore
My-Logger "Setting Morpheus datastore permissions"
$tdatas = get-morcloudtenantDatastores -morpheushosturl $morpheushosturl -headers $headers -cloudid $cloudid -tenantname $tenantname
if ($tdatas.datastores.count -eq 0) {
    My-Logger "No datastores found that contain tenant name $($tenantname)"
} else {
    $datastorepermissions = @{ }
    foreach ($id in $tdatas.datastores.id) {
        $datastorepermissions[$id] = set-morclouddatastorepermisions -datastoreid $id -morpheushosturl $morpheushosturl -cloudid $cloudid -headers $headers -tenantid $tenantid 
    }
}
 
# Disable all folders in the new cloud
My-Logger "Get vCenter Folders from Morpheus"
$disabledfolders = @{ }
$folders = get-morCloudFolders -morpheushosturl $morpheushosturl -headers $headers -cloudid $cloudid
My-Logger "Disabling all folders"
foreach ($folder in $folders.folders) {
    $disabledfolders[$folder.id] = disable-morCloudFolders -morpheushosturl $morpheushosturl -headers $headers -folderid $folder.id -cloudid $cloudid
}
 
# Extract Cloud Type to use in search for Folder
My-Logger "Getting target folder for cloud: $foldername"
$tenantfolder = get-morCloudTenantFolder -morpheushosturl $morpheushosturl -headers $headers -cloudid $cloudid -foldername $foldername
if ($tenantfolder.folders.count -eq 0) {
    My-Logger "No folders exist that match the name"
} else {
    My-Logger "Found the following folder $($tenantfolder.folders)"
    My-Logger "Set permissions on folder"
    $createdfolderid = $tenantfolder.folders.id
    My-Logger "Folder ID: $createdfolderid"
    My-Logger "Setting permissions on folder $($createdfolderid)"
    $folderpermissions = @{ }
    $folderpermissions[$createdfolderid] = set-morpheuscloudfolderpermissions -headers $headers -morpheushosturl $morpheushosturl -zoneid $cloudid -morpheusfolderid $createdfolderid -tenantname "$($tenantname)" -tenantid $tenantid
}
 
# Log the collection of tenants
My-Logger "Collecting tenants"  
$HTAllTenants = get-morpheustenants -headers $headers -morpheushosturl $morpheushosturl
 
# Create user accounts in the tenant
My-Logger "Creating users in tenant"


$newmspadmin = new-morpheususer -headers $headers -morpheushosturl $morpheushosturl -tenantid $HTAllTenants["$($tenantname)"].id -roleid $tenantadminroleid -firstname "MSP" -lastname "admin" -username $adminuser -password $adminpass -emailaddress "admin@demo.com"
$newmspuser = new-morpheususer -headers $headers -morpheushosturl $morpheushosturl -tenantid $HTAllTenants["$($tenantname)"].id -roleid $tenantuserroleid -firstname "MSP" -lastname "user" -username $useruser -password $userpass -emailaddress "user@demo.com"
 
# Remove existing cloud groups from the tenant
My-Logger "Removing existing cloud groups from tenant"
$existinggroups = get-morpheustenantgroups -headers $headers -morpheushosturl $morpheushosturl -tenantid $tenantid
foreach ($group in $existinggroups) {
    try {
        $rm = remove-morpheustenantgroup -headers $headers -morpheushosturl $morpheushosturl -tenantid $tenantid -groupid $group.id
        My-Logger "Removed existing groups"
    } catch {
        My-Logger "Failed to remove all existing groups"
    }
}
 
# Create a new group in the tenant
My-Logger "Creating group"
$groupname = "$($location)-MSP"
$mspgroup = new-morpheustenantgroup -headers $headers -morpheushosturl $morpheushosturl -tenantid $tenantid -groupname $groupname -groupcode $groupname -groupdescription $groupname -grouplocation $groupname.split(" ")[0]
$mspgroupid = ($mspgroup.content | convertfrom-json).group.id
 
# Add the cloud to the group
My-Logger "Adding cloud to group"
My-Logger "Cloud is MSP Cloud, adding to existing MSP Group"
$cloudid = $createcloud.zone.id
$groupzoneaddcloud = add-morpheustenantgroupzone -headers $headers -morpheushosturl $morpheushosturl -tenantid $tenantid -groupid $mspgroupid -zoneid $cloudid
 
# Set default permissions on groups
My-Logger "Collecting Tenant Roles"
$tenantRoles = get-tenantrole -headers $headers -morpheushosturl $morpheushosturl -tenantid $tenantid
My-Logger "Selecting CST_MultiTenant_Normal_User_Role_Base Role"
$role = $tenantRoles | Where-Object { $_.name -eq "$($tenantUserRole)" }
$roleid = $role.id
My-Logger "Setting Role Permissions, all Groups to Read"
$roleperms = update-rolepermissions -headers $headers -morpheushosturl $morpheushosturl -roleid $roleid
exit 0
}catch{
Write-Host "An error occurred: $($_.Exception.Message)"
exit 1
}