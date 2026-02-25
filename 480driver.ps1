
# import module
import-module "/home/nydia/SEC-480/SEC-480/modules/480-utils/480-utils.psm1" -force
#path to json file
$configpath = "/home/nydia/SEC-480/SEC-480/480.json"

Clear-Host
480banner

Write-Host -ForegroundColor DarkMagenta "
[1] Clone VM
[2] New Virtual Switch and/or Portgroup
[3] Get IP & MAC address of first interface
"


function choosing(){
    $valid = $false
    do{
        $choice = Read-Host "What would you like to do?[1-3]"

    if ($choice -eq 1){
        $valid = $true
        
        Write-Host -BackgroundColor Green -ForegroundColor Blue "Starting VM cloning process..."
        cloner -config_path $configPath
        $valid = $true 
        }

    elseif ($choice -eq 2){

        $valid = $true
    }

    elseif ($choice -eq 3){
        $valid = $true
    }
    else {
    Write-Host -ForegroundColor DarkRed "Please give valid input [1-3]"

    }
    
} while ($valid -eq $false)
}
choosing