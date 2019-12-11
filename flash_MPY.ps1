param (

    [string]$port ,
    [ValidateSet("v1.9.4","v1.10","v1.11")]
    $version = "v1.11"  ,
    
    [switch]$NoSpiram,

    $BaudRate = "460800",
    [switch]$KeepFlash,
    [ValidateSet('hard_reset','soft_reset','no_reset')]
    $after_reset = 'hard_reset',

    $Path = 'C:\develop\MyPython\FIRMWARE\'
)

Import-Module .\get-serialport.ps1

if ([string]::IsNullOrEmpty($port))
{
    # Select the first port 
    #Get-SerialPorts | where Service -in ('silabser','CH341SER_A64')
    $port =  (Get-SerialPort | where Service -ine 'BTHMODEM' | select -First 1).Port
}
Write-host -f Green "Using port $port"

$Savedir = $PWD

if ($NoSpiram ){
    $spiram = ""
} else {
    $spiram = "spiram"
}

#full version
$fwname = "esp32{0}-*-{1}*.bin" -f $spiram, $version

$file = Get-ChildItem -Path (join-path $path "ESP32_Micropython" $fwname) | sort | select -First 1


if ($file){
    Write-host -f Green "Found firmware" $file.Name
    # Erase
    if(!$KeepFlash){
        Write-Host -f Green "Erasing Flash"
        esptool.py --chip esp32 --port $port erase_flash
    }
    
    cd $file.Directory

    Write-Host -f Green "LoadingFirmware $version $spiram from $($file.Name)"
    # program the firmware starting at address 0x1000: 
    esptool.py --chip esp32 --port $port --baud $BaudRate write_flash -z 0x1000 $file.Name 

    
    cd $Savedir
} else {
    Write-warning  "Firmware $version $spiram could not be found"
}

