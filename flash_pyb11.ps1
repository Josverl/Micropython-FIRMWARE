# Flash a pyboard 1.1 
# - no com port needed 
# - detection based on DFU Device ID 
[CmdletBinding()]
param (
    #"erase all"
    [switch]$erase
)
function Flash_pybv11 {
    param (
        $filename ,
        $serialport = "COM7",
        [switch] $erase
    )
    
    # Put device into bootloader mode 
    python .\Tools\pyboard.py -d $serialPort --command "import time;time.sleep_ms(200);import pyb;pyb.bootloader()" --no-follow
    # give the board and USB stack some time to reset 
    start-sleep 1
    # fLASH PYBOARD 1.1 
    if ($erase) {
        .\Tools\dfu-util\dfu-util.exe --device 0483:df11 --alt 0 -s :mass-erase:force  --download $filename --reset
    }
    else {
        .\Tools\dfu-util\dfu-util.exe --device 0483:df11 --alt 0 --download $filename
    }
    #todo: Detect errors
    return $true
}


#Flash_pybv11 -erase:$erase -filename ".\PYB_11\pybv11-thread-20210902-v1.17.dfu"
Flash_pybv11 -filename ".\PYB_11\pybv11-network-20210902-v1.17.dfu"




