

function 480Banner()
{
    $banner=@'

    .----.   @   @
   / .-"-.`.  \v/
   | | '\ \ \_/ )
 ,-\ `-.' /.'  /
'---`----'----'
    WELCOME TO SEC 480 UTILS
                    > Nydia
'@
    Write-Host -ForegroundColor DarkGreen $banner
}


# Connects to serverr and validates connection
function 480connect([string] $server)
{
    # Check if already connected
    $connection = $global:DefaultVIServer

    if ($connection -and $connection.Name -eq $server) {
        Write-Host "Already connected to $server" -ForegroundColor Green
    }
    else {
        # Keep prompting until connection succeeds
        do {
            try {
                Write-Host -ForegroundColor Magenta "Connecting, please provide credentials"
                
                # Force error to trigger catch if connection fails
                $connection = Connect-VIServer -Server $server -ErrorAction Stop

                Write-Host "Connection to $server succeeded." -ForegroundColor Green
                break
            }
            catch {
                Write-Host "Connection failed: $($_.Exception.Message)" -ForegroundColor DarkRed
                $server = Read-Host "Enter a valid server name"
            }
        } while ($true)
    }
}

 

# Reads JSON config file and returns object

function 480config([string] $config_path)
{
    Write-Host "Reading $config_path"
# set config to null before starting
    $conf = $null
  # test the path
    if (Test-Path $config_path)
    {
        $conf = (Get-Content -Raw -Path $config_path | ConvertFrom-Json)
        # alert if worked
        Write-Host "Using config $config_path" -ForegroundColor Green
    }
    else {
        Write-Host "No Config Path found" -ForegroundColor DarkCyan
    }
    # end with config
    return $conf
}


# Allows user to select a VM from a folder

function select-vm([string] $folder)
{
    $selected_vm = $null

    try {
        # retrieve all VMs in folder
        $vms = Get-VM -Location $folder

        # display numbered list
        $index = 1
        foreach ($vm in $vms) {
            Write-Host "[$index] $($vm.Name)"
            $index++
        }

        $max_index = $index - 1

        # prompt until valid selection
        do {
            $pick_index = Read-Host "Select an index between 1 and $max_index"
        } while (($pick_index -lt 1) -or ($pick_index -gt $max_index))

        $selected_vm = $vms[$pick_index - 1]
        Write-Host "Using $($selected_vm.Name)" -ForegroundColor Green

        return $selected_vm
    }
    catch {
        Write-Host "Not a valid folder: $folder" -ForegroundColor DarkRed
    }
}

# cloner
# main cloning set up

function cloner([string] $config_path)
{

    Write-Host "Config Path: $config_path"

    
    # error handling 
    # config file load protection
    
    try {
        if (-not (Test-Path $config_path)) {
            throw "Config file not found at $config_path"
        }

        # convert JSON config -> PowerShell object
        $config = Get-Content -Raw -Path $config_path -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop

        Write-Host "Configuration file loaded successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "ERROR loading configuration: $($_.Exception.Message)" -ForegroundColor DarkRed
        Write-Host "Script cannot continue without a valid config file." -ForegroundColor Cyan
        return
    }
    

    # load defaults from config
    $server = $config.vcenter_server
    $folder = $config.vm_folder
    $esxi = $config.esxi_host
    $datastore = $config.default_datastore
    $snapshot = $config.default_snapshot
    $network = $config.default_network

   # allow server override
    $user_server = Read-Host "What server would you like to connect to? [$server]"
    if ([string]::IsNullOrWhiteSpace($user_server)) {
        $user_server = $server
    }
   #connects to vceneter
    480connect -server $user_server
   
    # allpw ESXi override + verify

do {
  $user_esxi = Read-Host "Enter ESXi host [$esxi]"
  if ([string]::IsNullOrWhiteSpace($user_esxi)) {
    $user_esxi = $esxi
  }

  # test if esxi exists 
    $esxi_test = Get-VMHost -Name $user_esxi -ErrorAction SilentlyContinue
    if (-not $esxi_test) {
        Write-Host "ESXi host '$user_esxi' not found in vCenter. Please enter a valid host." -ForegroundColor DarkRed
    }

} while ($null -eq $esxi_test)


# Allow datastore override
do {
$user_datastore = Read-Host "Enter datastore [$datastore]"
if ([string]::IsNullOrWhiteSpace($user_datastore)) {
    $user_datastore = $datastore
}
     # test if datastore exists
    $ds_test = Get-Datastore -Name $user_datastore -ErrorAction SilentlyContinue
    if (-not $ds_test) {
        Write-Host "Datastore '$user_datastore' not found. Please enter a valid datastore." -ForegroundColor DarkRed
    }

} while ($null -eq $ds_test)

    # Select VM
    $selected_vm = select-vm -folder $folder

   # validate snapshot exists
do {
    $user_snapshot = Read-Host "What snapshot would you like to use? [$snapshot]"

    # if enter is input, use default
    if ([string]::IsNullOrWhiteSpace($user_snapshot)) {
        $user_snapshot = $snapshot
    }

    # attempt to retrieve snapshot from selected VM
    $snapshot_test = Get-Snapshot -VM $selected_vm -Name $user_snapshot -ErrorAction SilentlyContinue

    if (-not $snapshot_test) {
        Write-Host "Snapshot '$user_snapshot' not found on VM '$($selected_vm.Name)'" -ForegroundColor DarkRed
    }

} while (-not $snapshot_test)

Write-Host "Using snapshot '$user_snapshot'" -ForegroundColor Green
      
    try {

        # makes sure input is unique VM name
        $new_vm_name = $null
        while ([string]::IsNullOrWhiteSpace($new_vm_name) -or (Get-VM -Name $new_vm_name -ErrorAction SilentlyContinue)) {

            if ($new_vm_name) {
                Write-Warning "VM '$new_vm_name' already exists."
            }

            $new_vm_name = Read-Host "Enter a new, unique VM name"
        }

        Write-Host "Using '$new_vm_name' as New VM Name" -ForegroundColor Green

        # selecting type of clone
        $clone_type = Read-Host "Enter 'F' for Full clone or 'L' for Linked clone"
        while ($clone_type -ne 'F' -and $clone_type -ne 'L') {
            $clone_type = Read-Host "Enter 'F' for Full clone or 'L' for Linked clone"
        }

      # linked clone setup
        if ($clone_type -eq "L") {

            Write-Host "Creating linked clone..." -ForegroundColor DarkMagenta

            $newvm = New-VM -LinkedClone `
                            -Name $new_vm_name `
                            -VM $selected_vm `
                            -ReferenceSnapshot $user_snapshot `
                            -VMHost $user_esxi `
                            -Datastore $user_datastore `
                            -ErrorAction Stop

            $newvm | New-Snapshot -Name "base" -ErrorAction Stop
        }

       # full clone set up
         
        elseif ($clone_type -eq "F") {

            Write-Host "Creating full clone..." -ForegroundColor DarkMagenta

            $tempName = "{0}.linked-temp" -f $selected_vm.Name

            # create temporary linked clone first
            $linkedvm = New-VM -LinkedClone `
                               -Name $tempName `
                               -VM $selected_vm `
                               -ReferenceSnapshot $user_snapshot `
                               -VMHost $user_esxi `
                               -Datastore $user_datastore `
                               -ErrorAction Stop

            # create full clone from temporary VM
            $newvm = New-VM -Name $new_vm_name `
                            -VM $linkedvm `
                            -VMHost $user_esxi `
                            -Datastore $user_datastore `
                            -ErrorAction Stop

            $newvm | New-Snapshot -Name "base" -ErrorAction Stop

            # remove temporary linked clone
            $linkedvm | Remove-VM -Confirm:$false -ErrorAction Stop
        }

        Write-Host "Clone process completed successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "ERROR during clone process: $($_.Exception.Message)" -ForegroundColor DarkRed
        Write-Host "Clone operation failed. Please review the error above." -ForegroundColor Magenta
    }
    
}



# function for creating new virtual switch and portgroup

  function New-Network([string] $config_path) 
    {

        try {

        $config = Get-Content -Raw -Path $config_path -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        $esxi = $config.esxi_host


        # ESXi host
        do {
            $vmhost = Read-Host "Enter ESXi host [$esxi]"
            if ([string]::IsNullOrWhiteSpace($vmhost)) {
                $vmhost = $esxi
            }

            # make sure host exists
            $esxiObj = Get-VMHost -Name $vmhost -ErrorAction SilentlyContinue
            if (-not $esxiObj) {
                Write-Host "ESXi host '$vmhost' not found in vCenter. Please enter a valid host." -ForegroundColor DarkRed
            }

        } while (-not $esxiObj)

        # virtual switch
        
        
        
        function switchname(){
            $goodswitch = $false
        do{
            $vswitchName = Read-Host "Enter name for new Virtual Switch"

            if ([string]::IsNullOrWhiteSpace($vswitchName)) {
            Write-Host "Virtual Switch name cannot be empty." -ForegroundColor DarkRed
             $goodswitch = $false
             }
            else { 
        # see if switch already exists
        $existingSwitch = Get-VirtualSwitch -VMHost $esxiObj -Name $vswitchName -ErrorAction SilentlyContinue
        if ($existingSwitch) {
            Write-Host "Virtual Switch '$vswitchName' already exists." -ForegroundColor Yellow
        } else {
            $newSwitch = New-VirtualSwitch -Name $vswitchName -VMHost $esxiObj -ErrorAction Stop
            Write-Host "Virtual Switch '$vswitchName' created successfully." -ForegroundColor Green
            $goodswitch = $true
            return $newSwitch
        }
        }
        }while ($goodswitch -eq $false)
    }
    $vswitchName = switchname
    function portgroup([string] $vswitchName)
        {
        # portgroup
         $goodport = $false
        do{
            Write-Host "vSwitch $vswitchName"
            $portgroupName = Read-Host "Enter name for new Portgroup"

        if ([string]::IsNullOrWhiteSpace($portgroupName)) {
            Write-Host "Portgroup name cannot be empty." -ForegroundColor DarkRed
        $goodport = $false
        }
        else {
        # see if portgroup exists
        $existingPG = Get-VirtualPortGroup -VMHost $esxiObj -Name $portgroupName -ErrorAction SilentlyContinue
        if ($existingPG) {
            Write-Host "Portgroup '$portgroupName' already exists." -ForegroundColor Cyan
        } 
        else {
            
            New-VirtualPortGroup -Name $portgroupName -VirtualSwitch $vswitchName -ErrorAction Stop
            Write-Host "Portgroup '$portgroupName' created successfully." -ForegroundColor Green
            Write-Host "Network configuration complete." -ForegroundColor Green
            $goodport = $true
        }

            }
        }while ($goodport -eq $false)
    }

    portgroup -vswitchname $vswitchName
    }catch{
        Write-Host "An error occurred while creating network components." -ForegroundColor DarkRed
        Write-Host $_.Exception.Message -ForegroundColor DarkRed
    }
    }

# function for getting the IP and MAC address for the first interface of a named VM
function Get-IP {

    

   Write-Host -BackgroundColor Green -ForegroundColor Blue "Starting process for retrieval of  IP and MAC Address"
    
       try {

        # get all VMs and sort by name
        $vms = Get-VM | Sort-Object Name

        if ($null -eq $vms -or $vms.Count -eq 0) {
            Write-Host "No VMs found." -ForegroundColor DarkRed
            return
        }

        # show list of VMs with numbers
        Write-Host ""
        for ($i = 0; $i -lt $vms.Count; $i++) {
            Write-Host "[$($i + 1)] $($vms[$i].Name)"
        }

        Write-Host ""

        # get VM via  number
        $selection = Read-Host "Select a VM by number"

        # make sure input is good
        if (-not ($selection -as [int])) {
            Write-Host "Invalid selection. Must be a number." -ForegroundColor DarkRed
            return
        }

        $index = [int]$selection - 1

        if ($index -lt 0 -or $index -ge $vms.Count) {
            Write-Host "Selection out of range." -ForegroundColor DarkRed
            return
        }

        # get the proper VM
        $vm = $vms[$index]

        # get first network adapter from the VM
        $adapter = Get-NetworkAdapter -VM $vm -ErrorAction Stop | Select-Object -First 1

        # make sure adapter actually exists
        if ($null -eq $adapter) {
            Write-Host "No network adapters found on VM." -ForegroundColor DarkRed
            return
        }

        # keep the MAC address
        $mac = $adapter.MacAddress


        # get IP addresses - could grab more than one
        # take only the first
        $ip = $vm.Guest.IPAddress | Select-Object -First 1

        # alert if no IP found 
        if ($null -eq $ip) {
            $ip = "No IP Address Found"
        }


        # display results
        Write-Host "---------------"
        Write-Host "VM Name: $vmName" -ForegroundColor Green
        Write-Host "MAC Address: $mac"
        Write-Host "IP Address: $ip"
    }

    catch {
        # catches any errors (invalid host, creation failure, and more)
        Write-Host "An error occurred while getting VM network info." -ForegroundColor DarkRed
        Write-Host $_.Exception.Message -ForegroundColor DarkRed
    }
}

# function for turning off VM
function KillVM {

    $vms = Get-VM

    if (-not $vms) {
        Write-Host "No VMs found." -ForegroundColor DarkRed
        return
    }

    Write-Host "Available VMs:" -ForegroundColor Cyan

    for ($i = 0; $i -lt $vms.Count; $i++) {
        Write-Host "[$($i+1)] $($vms[$i].Name) - $($vms[$i].PowerState)"
    }

    $selection = Read-Host "Select VM to poweroff"

    if (-not ($selection -as [int]) -or 
        $selection -lt 1 -or 
        $selection -gt $vms.Count) {

        Write-Host "Invalid selection." -ForegroundColor DarkRed
        continue
    }

    $vm = $vms[$selection - 1]

    if ($vm.PowerState -eq "PoweredOff") {
        Write-Host "VM '$($vm.Name)' is already powered off." -ForegroundColor Yellow
        return
    }
    else {
        Stop-VM -VM $vm -Confirm:$false
        Write-Host "VM '$($vm.Name)' stopped successfully." -ForegroundColor Green
        Write-Host -ForegroundColor Black -BackgroundColor Red "
        
    
                ⣴⣾⣿⣿⣿⣿⣷⣦ 
                ⣿⣿⣿⣿⣿⣿⣿⣿           
                ⡟⠛⠽⣿⣿⠯⠛⢻            
                ⣧⣀⣀⡾⢷⣀⣀⣼           
                 ⡏⢽⢴⡦⡯⢹                
                 ⠙⢮⣙⣋⡵⠋               
        "
        return
    }
}
# function for turning on VM
function AliveVM {

    $vms = Get-VM

    # error handling for server having no VMs

    if (-not $vms) {
        Write-Host "No VMs found." -ForegroundColor DarkRed
        return
    }

    Write-Host "Available VMs:" -ForegroundColor Cyan
    # spits out list of VMs
    for ($i = 0; $i -lt $vms.Count; $i++) {
        Write-Host "[$($i+1)] $($vms[$i].Name) - $($vms[$i].PowerState)"
    }

    $selection = Read-Host "Select VM you would like to start" 

    if (-not ($selection -as [int]) -or 
        $selection -lt 1 -or 
        $selection -gt $vms.Count) {

        Write-Host "Invalid selection." -ForegroundColor DarkRed
        continue
    }

    $vm = $vms[$selection - 1]

    if ($vm.PowerState -eq "PoweredOn") {
        Write-Host "VM '$($vm.Name)' is already powered on." -ForegroundColor Yellow
        return
    }
    else {
        Start-VM -VM $vm -Confirm:$false
        Write-Host "VM '$($vm.Name)' started successfully." -ForegroundColor Green
        return
    }
}

function Set-Network {

    # get all VMs
    $vms = Get-VM

    # error handle if no VMs
    if (-not $vms) {
        Write-Host "No VMs found in vCenter." -ForegroundColor DarkRed
        return
    }

    # lists all VMs to be chose from
    Write-Host "Available VMs:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $vms.Count; $i++) {
        Write-Host "[$($i+1)] $($vms[$i].Name)"
    }

   
    $selection = Read-Host "Select a VM by number"

        # Try to cast to integer safely
    try {
    $index = [int]$selection
    }   
    catch {
    Write-Host "Invalid selection. Must be a number." -ForegroundColor DarkRed
    return
    }

    # Validate range
    if ($index -lt 1 -or $index -gt $vms.Count) {
    Write-Host "Invalid VM selection. Number out of range." -ForegroundColor DarkRed
    return
    }



    $vm = $vms[$selection - 1]

    # get all network adapters on the selected VM 
    $adapters = Get-NetworkAdapter -VM $vm -ErrorAction SilentlyContinue

    if (-not $adapters -or $adapters.Count -eq 0) {
        Write-Host "No network adapters found on VM '$($vm.Name)'." -ForegroundColor DarkRed
        return
    }

    # show all available networks
    $networks = Get-VirtualNetwork

    if (-not $networks -or $networks.Count -eq 0) {
        Write-Host "No networks found in vCenter." -ForegroundColor DarkRed
        return
    }

    Write-Host "Available Networks:" -ForegroundColor Cyan
    for ($j = 0; $j -lt $networks.Count; $j++) {
        Write-Host "[$($j+1)] $($networks[$j].Name)"
    }

    # goes through each adapter and lets you set network
    foreach ($adapter in $adapters) {

        Write-Host "Adapter '$($adapter.Name)' on VM '$($vm.Name)'" -ForegroundColor Cyan

        # get user to pick network
        $netSelection = Read-Host "Select network number to assign to this adapter"

        # validate network selection
        if (-not ($netSelection -as [int]) -or $netSelection -lt 1 -or $netSelection -gt $networks.Count) {
            Write-Host "Invalid network selection. Skipping adapter '$($adapter.Name)'." -ForegroundColor DarkRed
            continue
        }

        $selectedNetwork = $networks[$netSelection - 1]

        # attempt to set the network (with runtime error handling)
        try {
            Set-NetworkAdapter `
                -NetworkAdapter $adapter `
                -NetworkName $selectedNetwork.Name `
                -Confirm:$false -ErrorAction Stop

            Write-Host "Adapter '$($adapter.Name)' successfully set to network '$($selectedNetwork.Name)'." -ForegroundColor DarkGreen
        }
        catch {
            Write-Host "Failed to set adapter '$($adapter.Name)' to network '$($selectedNetwork.Name)'." -ForegroundColor DarkRed
            Write-Host $_.Exception.Message -ForegroundColor DarkRed
        }
    }

    Write-Host "Network assignment process complete for VM '$($vm.Name)'." -ForegroundColor DarkGreen -BackgroundColor DarkBlue
}
