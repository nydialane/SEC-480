

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
