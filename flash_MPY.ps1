#Requires -Version 5
param (

    [string]$port ,

    [ValidateSet("v1.9.4","v1.10","v1.11","v1.12","v1.13","custom")]
    $version = "v1.13"  ,
    
    [switch]$NoSpiram,

    [ValidateSet("115200","256000","512000","460800","750000","921600")]    
    $BaudRate = "921600",
    [switch]$KeepFlash,
    [ValidateSet('hard_reset','soft_reset','no_reset')]
    $after_reset = 'hard_reset',

    $Path = $PSScriptRoot,

    $firmware  = $null,

    [switch]$nightly

)
# if ($false){
#     Import-Module .\get-serialport.ps1 -Force
#     $version = "v1.11"
#     $path = "C:\develop\MyPython\FIRMWARE"
# }
Import-Module $PSScriptRoot\get-serialport.ps1 -Force

if ([string]::IsNullOrEmpty($port))
{
    # Select the first port 
    #Get-SerialPorts | where Service -in ('silabser','CH341SER_A64')
    $port =  (Get-SerialPort | where Service -ine 'BTHMODEM' | select -First 1).Port
}
if ( [string]::IsNullOrEmpty($port) ){
    Write-error "No active port or likely serial device could be detected" 
    exit(-1)   
}
Write-host -f Green "Using port ${port}:"

$Savedir = $PWD

if ($NoSpiram ){
    $spiram = ""
} else {
    $spiram = "spiram"
}

# Continuous reboots after programming: Ensure FLASH_MODE is correct for your
# board (e.g. ESP-WROOM-32 should be DIO).

if ($firmware -eq $null) {
    # new naming convention :   esp32-idf3-20190529-v1.11.bin
    #                           esp32spiram-idf3-20190529-v1.11.bin
    #                           esp32spiram-idf3-20191211-v1.11-633-gb310930db.bin
    if ($nightly) { $latest = '-*' } else { $latest = '' }
        
    $fwname = "esp32{0}-{1}-*-{2}{3}.bin" -f $spiram,'idf3',  $version , $latest
    $file = Get-ChildItem -Path (join-path -path $path -childpath ("ESP32_Micropython/" + $fwname) ) | sort | select -First 1

    if ($version -ieq "custom"){
        # custom fware in this folder 
        $fwname = 'mpy_esp32_josv_spiram.bin'
        $fwname = 'mpy_*.bin'
        $p = join-path -path $PSScriptRoot -childpath "custom"  -AdditionalChildPath $fwname
        Write-Host "Path : $p"
        $file = Get-ChildItem -Path $p | sort | select -First 1
    }
} else {
    # get the most recent firmware that matches the path 
    $file = Get-ChildItem -Path $firmware | sort LastWriteTime | select -First 1
}


if ($file){
    Write-host -f Green "Found firmware" $file.Name
    # Erase
    if(!$KeepFlash){
        Write-Host -f Green "Erasing Flash"
        esptool --chip esp32 --port $port erase_flash
    }
    
    cd $file.Directory

    Write-Host -f Green "LoadingFirmware $version $spiram from $($file.Name) to device op port: $port"
    # program the firmware starting at address 0x1000: 

    # TODO: check if esptool is install / can be started and 
    try {
        esptool --chip esp32 --port $port --baud $BaudRate --before default_reset --after $after_reset  write_flash --compress --flash_freq 80m --flash_size detect 0x1000  $file.Name
        #esptool.py --chip esp32 --port $port --baud $BaudRate write_flash -z 0x1000 $file.Name 
    } catch {
        Write-Warning "is esptool installed ? try running  > pip install esptool"
    }
    
    cd $Savedir
} else {
    Write-warning  "Firmware $version $spiram could not be found"
}

