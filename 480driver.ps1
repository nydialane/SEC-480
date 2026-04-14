
# import module
import-module "/home/champuser/SEC-480/modules/480-utils/480-utils.psm1" -force
#path to json file
$configpath = "/home/champuser/SEC-480/480.json"

480banner

function serverconnect() {
do {
    $hello = Read-Host "Would you like to connect to nydia's server? [y/n]"
    $valid = $false
    if ($hello -eq 'y'){
        480connect -server vcenter.nydia.local
        $valid = $true
    }
    elseif ($hello -eq 'n'){
        $awesome = Read-Host "Enter server you would like to connect to:"
        480connect -server $awesome
        $valid = $true
    } 
} while ($valid -eq $false)
}
serverconnect

Write-Host -ForegroundColor DarkMagenta "
[1] Clone VM
[2] New Virtual Switch and/or Portgroup
[3] Get IP & MAC address of first interface
[4] Turn on VM
[5] Turn off VM
[6] Set VM network adapter
[7] Set static IP
"


function choosing(){
    $valid = $false
    do{
        $choice = Read-Host "What would you like to do?[1-6]"

    if ($choice -eq 1){
        $valid = $true
        
        Write-Host -BackgroundColor Green -ForegroundColor Blue "Starting VM cloning process..."
        cloner -config_path $configPath
        
        }

    elseif ($choice -eq 2){
        
        $valid = $true
        Write-Host -BackgroundColor Green -ForegroundColor Blue "Starting New Virtual Switch and/or Portgroup process..."
        New-Network -config_path $configPath
    }

    elseif ($choice -eq 3){

        $valid = $true
        Write-Host -BackgroundColor Green -ForegroundColor Blue "Starting get IP & MAC process..."
        Get-IP 

    }
    elseif ($choice -eq 4){

        $valid = $true
        Write-Host -BackgroundColor Green -ForegroundColor Blue "Starting VM poweron process..."
        AliveVM

    }
    elseif ($choice -eq 5){

        $valid = $true
    Write-Host -BackgroundColor Green -ForegroundColor Blue "Starting VM poweroff process..."
        KillVM

    }
    elseif ($choice -eq 6){

        $valid = $true
        Write-Host -BackgroundColor Green -ForegroundColor Blue "Starting set VM network adapter process..."
        Set-Network

    }
    elseif ($choice -eq 7){
    $valid = $true
    Write-Host -BackgroundColor Green -ForegroundColor Blue "Starting set Windows static IP process..."
    Set-WindowsIP
}
    else {
    Write-Host -ForegroundColor DarkRed "Please give valid input [1-6]"

    }
    
} while ($valid -eq $false)
}
choosing