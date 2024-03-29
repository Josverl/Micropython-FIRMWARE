# Flash a pyboard 1.1 
# - no com port needed 
# - detection based on DFU Device ID 
[CmdletBinding()]
param (
    [ValidateSet("pybv11")]
    $board = "pybv11"  ,
    
    $port = "stm32",

    [ValidateSet("", "network", "thread", "dp")]
    $variant = ""  ,

    [switch]$erase,

    [ValidateSet( "v1.10", "v1.11", "v1.12", "v1.13", "v1.14", "v1.15", "v1.16", "v1.17", "v1.18", "v1.19.1", "custom")]
    $version = "v1.19.1",

    $serialport 
)




function find_standard_firmware {
    param (
        $port = "stm32",
        [ValidateSet("pybv11")]
        $board = "pybv11"  ,
        $variant = "",
        $version = "v1.18"
    
    )
    # naming convention :   
    # pybv11-20220117-v1.18.dfu
    # esp32-idf3-20190529-v1.11.bin
    # esp32spiram-idf3-20190529-v1.11.bin
    # esp32spiram-idf3-20191211-v1.11-633-gb310930db.bin

    $folder = join-path $PSScriptRoot $port.toUpper()
    if ($variant.Length -gt 0) {
        $variant = $variant + "-"
    }
    $fwname = "{0}-{1}*-{2}.dfu" -f $board, $variant, $version
    $fw_path = (join-path -path $folder -childpath  $fwname ) 
    $files = Get-ChildItem -Path $fw_path
    # select the highest version 
    $file = $files | Sort-Object -Property Name -Descending | Select-Object -First 1
    return $file
}

function Flash_pybv11 {
    param (
        [ValidateSet("v1.9.4", "v1.10", "v1.11", "v1.12", "v1.13", "v1.14", "v1.15", "v1.16", "v1.17", "v1.18", "v1.19", "custom")]
        $version = "v1.18"  ,
        
        [Parameter(mandatory = $true)]
        $serialport ,
        [Parameter(mandatory = $true)]
        $filename,
        [switch] $erase
    )
    

    # Put device into bootloader mode 
    python $PSScriptRoot\Tools\pyboard.py -d $serialPort --command "import time;time.sleep_ms(200);import pyb;pyb.bootloader()" --no-follow
    # give the board and USB stack some time to reset 
    start-sleep 1
    # fLASH PYBOARD 1.1 and :leave the bootloader 
    if ($erase) {
        echo "$PSScriptRoot\Tools\dfu-util\dfu-util.exe --device 0483:df11 --alt 0 -s :mass-erase:force:leave  --download $filename --reset"
        & $PSScriptRoot\Tools\dfu-util\dfu-util.exe --device 0483:df11 --alt 0 -s :mass-erase:force:leave  --download $filename --reset | out-host
    }
    else {
        echo "$PSScriptRoot\Tools\dfu-util\dfu-util.exe --device 0483:df11 --alt 0 -s :leave --download $filename"
        & $PSScriptRoot\Tools\dfu-util\dfu-util.exe --device 0483:df11 --alt 0 -s :leave --download $filename | out-host
    }
    #todo: Detect errors
    return $true
}




#Flash_pybv11 -erase:$erase -filename ".\PYB_11\pybv11-thread-20210902-v1.17.dfu"
# Flash_pybv11 -filename ".\PYB_11\pybv11-network-20210902-v1.17.dfu"
# Flash_pybv11 -filename $PSScriptRoot\STM32\pybv11-20220117-v1.18.dfu

# TODO: return error if not found 
$fw_image = find_standard_firmware -board $board -port $port -variant $variant -version $version
if (-not $fw_image) {
    return "Firmware not found"
}
else {
    echo "Found firmware $fw_image"
    $result = Flash_pybv11 -filename $fw_image -serialport $serialport
    if ($result) {
        Return "OK"
    }
    else {
        Return "Failed"
    }
}





