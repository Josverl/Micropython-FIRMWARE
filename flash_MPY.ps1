#Requires -Version 5
param (

    [string]$serialport ,

    [ValidateSet("v1.9.4", "v1.10", "v1.11", "v1.12", "v1.13", "v1.14", "v1.15", "v1.16", "v1.17", "v1.18", "v1.19.1", "custom")]
    $version = "v1.19.1"  ,
    
    [switch]$NoSpiram,

    [ValidateSet("115200", "256000", "512000", "460800", "750000", "921600", "1152000")]    
    $BaudRate = "921600",
    [switch]$KeepFlash,

    [ValidateSet('hard_reset', 'soft_reset', 'no_reset')]
    $after_reset = 'hard_reset',

    $Path = $PSScriptRoot,

    $firmware = $null,

    [ValidateSet('idf3', 'idf4')]
    $idf = 'idf4',
    # [--chip {auto,esp8266,esp32,esp32s2,esp32s3beta2,esp32s3,esp32c3,esp32c6beta,esp32h2,esp8684}]
    [ValidateSet("esp32", "esp8266")]
    $chip = "esp32"  ,

    [switch]$nightly
)

# Set spiram option 
if ($NoSpiram -or $chip -eq "esp8266") {
    $spiram = ""
}
else {
    $spiram = "spiram"
}

Push-Location
# $Savedir = $PWD

# load serialport detection 
Import-Module $PSScriptRoot\get-serialport.ps1 -Force

# ---------------------------------------------
# get serial port for flashing 
# ---------------------------------------------

if ([string]::IsNullOrEmpty($serialport)) {
    
    $allports = Get-SerialPort -chip
    # Select the first port of the right type
    $mcu = $allports | Where-Object chip -ieq $chip | Select-Object -First 1
    $serialport = $mcu.Port
}
if ( [string]::IsNullOrEmpty($serialport) ) {
    Write-error "No active port or likely serial device could be detected" 
    exit(-1)   
}
Write-host -f Green "Using port ${serialport}:"

function find_standard_firmware {
    param (
        [ValidateSet("esp32", "esp8266")]
        $chip = "esp32"  ,
        $folder 
    )
    # new naming convention :   esp32-idf3-20190529-v1.11.bin
    #                           esp32spiram-idf3-20190529-v1.11.bin
    #                           esp32spiram-idf3-20191211-v1.11-633-gb310930db.bin
    if (-not $folder) {
        $folder = join-path $PSScriptRoot ( "{0}_Micropython" -f $chip.toUpper())
    }

    # re-uses the global parameters
    if ($nightly) { $latest = '-*' } else { $latest = '' }

    # idf version is no longer part of the filename starting from v1.15
    $idf_part = ""
    if ($version -lt "v.15") {
        $idf_part = "-" + $idf
    }

    $fwname = "{0}{1}{2}-*-{3}{4}.bin" -f $chip, $spiram, $idf_part, $version , $latest 
    $fw_path = join-path -path $folder -childpath  $fwname 
    Write-Host "Looking for firmware in $fw_path"
    $files = Get-ChildItem -Path $fw_path -ErrorAction SilentlyContinue 
    # select the highest version 
    $file = $files | Sort-Object -Property Name -Descending | Select-Object -First 1
    return $file
}

function find_custom_firmware {
    param( 
        $folder = "custom"
    )
    # custom fware in this folder 
    $fwname = 'mpy_*.bin'
    $p = join-path -path $PSScriptRoot -childpath $folder  -AdditionalChildPath $fwname
    Write-Host "Path : $p"
    $file = Get-ChildItem -Path $p | Sort-Object | Select-Object -First 1
    return $file
}


function get-firmware {
    param (
        $firmware,
        [ValidateSet("esp32", "esp8266")]
        $chip = "esp32" 
    )
    if ($null -eq $firmware) {

        if ($version -ieq "custom") {
            $file = find_custom_firmware
        }
        else {
            $file = find_standard_firmware -chip $chip
        }
    }
    else {
        # get the most recent firmware that matches the path 
        $file = Get-ChildItem -Path $firmware | sort-object LastWriteTime | Select-Object -First 1
    }
    return $file        
}


$file = get-firmware -firmware $firmware -chip $chip
if (-not $file) {
    Write-warning  "Firmware $version $spiram could not be found"
    return "Firmware not found"
}

Write-host -f Green "Found firmware:" $file.Name
# Erase
if (!$KeepFlash) {
    Write-Host -f Green "Erasing Flash"
    esptool --chip $chip --port $serialport erase_flash | out-host
}

Write-Host -F Green "Changing to $file"
Set-Location $file.Directory

# program the firmware starting at address 0x1000: 

# TODO: check if esptool is install / can be started and 
try {
    switch ($chip) {
        "esp32" { 
            Write-Host -f Green "Loading Firmware $version $spiram from $($file.Name) to device op port: $serialport"
            Write-Host "esptool --chip esp32 --port $serialport --baud $BaudRate --before default_reset --after $after_reset  write_flash --compress --flash_freq 80m --flash_size detect 0x1000  $file" 
            esptool --chip esp32 --port $serialport --baud $BaudRate --before default_reset --after $after_reset  write_flash --compress --flash_freq=keep --flash_size=keep 0x1000  $file.Name | out-host

        }
        "esp8266" { 
            $BaudRate = 460800
            Write-Host -f Green "Loading Firmware $version $spiram from $($file.Name) to device op port: $serialport"
            esptool --chip esp8266 --port $serialport --baud $BaudRate --before default_reset --after $after_reset write_flash --flash_size=detect 0 $file.Name | out-host
        }
        Default {
            Write-Error  "Could not Load Firmware $version $spiram from $($file.Name) to device op port: $serialport"
            return "Unknown chip $chip"
        }
    }
    #esptool.py --chip esp32 --port $serialport --baud $BaudRate write_flash -z 0x1000 $file.Name 
}
catch {
    Write-Warning "is esptool installed ? try running  > pip install esptool"
    return "ESPtool not found"
}

# cd $Savedir
Pop-Location
return "OK"
# Continuous reboots after programming: Ensure FLASH_MODE is correct for your
# board (e.g. ESP-WROOM-32 should be DIO).
