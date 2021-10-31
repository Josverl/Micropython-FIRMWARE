#Requires -Version 5
param (

    [string]$serialport ,

    [ValidateSet("v1.9.4", "v1.10", "v1.11", "v1.12", "v1.14", "v1.15", "v1.16", "v1.17", "v1.18", "custom")]
    $version = "v1.17"  
)

$Savedir = $PWD
Import-Module $PSScriptRoot\..\..\get-serialport.ps1 -Force

if ([string]::IsNullOrEmpty($serialport)) {
    # Select the first port 
    #Get-SerialPorts | where Service -in ('silabser','CH341SER_A64')
    $serialport = (Get-SerialPort | where Service -ine 'BTHMODEM' | select -First 1).Port
}
if ( [string]::IsNullOrEmpty($serialport) ) {
    Write-error "No active port or likely serial device could be detected" 
    exit(-1)   
}
Write-host -f Green "Using port ${serialport}:"



CD .\LVGL\micropython_v1_17
esptool.py -p $serialport erase_flash
esptool.py -p $serialport -b 460800 --before default_reset --after hard_reset --chip esp32 write_flash --flash_mode dio --flash_size detect --flash_freq 40m 0x1000 bootloader.bin 0x8000 partition-table.bin 0x10000 micropython.bin

cd $Savedir
