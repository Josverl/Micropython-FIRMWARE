param (

    [string]$port ,
    $version = "v3.2.24"  ,
    [ValidateSet("esp32",'esp32_all', 'esp_psram',"esp32_psram_all_bt","esp32_psram_ota","esp32_psram_all")]
    [string]$prebuilt = "esp32_psram_all",
    #  
    $BaudRate = "460800",
    [switch]$KeepFlash,
    [ValidateSet('hard_reset','soft_reset','no_reset')]
    $after_reset = 'hard_reset',

    $Path = 'C:\develop\MyPython\FIRMWARE\'
)

Import-Module $PSScriptRoot\get-serialport.ps1 -Force

if ([string]::IsNullOrEmpty($port))
{
    # Select the first port 
    #Get-SerialPorts | where Service -in ('silabser','CH341SER_A64')
    $port =  (Get-SerialPort | where Service -ine 'BTHMODEM' | select -First 1).Port
}
Write-host -f Green "Using port $port"


$Savedir = $PWD
#full version
$version = "ESP32_LoBo_$version"
Write-host -f Green "Looking for Firmware LoBo $version $prebuilt" 
$folder = Get-ChildItem -Path $path -Recurse | where { $_.PSisContainer -and $_.Fullname -match $versions -and $_.Fullname.endsWith($prebuilt) }

#$folder = "C:\develop\MyPython\FIRMWARE\ESP32_LoBo_v3.2.24\esp32_all"
if ($folder){
    Write-host -f Green "Found"
    # Erase
    if(!$KeepFlash){
        Write-Host -f Green "Erasing Flash"
        esptool --chip esp32 --port $port erase_flash
    }
    
    cd $folder.FullName
    Write-Host -f Green "LoadingFirmware $version $prebuilt from $($folder.FullName)"
    # From then on program the firmware starting at address 0x1000: 
    
    esptool --chip esp32 --port $port --baud $BaudRate --before default_reset --after $after_reset write_flash -z --flash_mode dio --flash_freq 40m --flash_size detect 0x1000 bootloader/bootloader.bin 0xf000 phy_init_data.bin 0x10000 MicroPython.bin 0x8000 partitions_mpy.bin
    
    cd $Savedir
} else {
    Write-warning  "Firmware LoBo $version $prebuilt could not be found"
}

