

function Get-SerialPort()
{
    $RE_port = [regex]"\(COM(.*)\)"
    $SerialPorts = Get-CimInstance -Query 'SELECT * FROM Win32_PnPEntity WHERE ClassGuid="{4d36e978-e325-11ce-bfc1-08002be10318}"' | 
        Select Description, Name,  PNPClass , Service , Status | 
        ForEach-Object {
            #Split out the comport
            $re = $RE_port.Match($_.Name)

            $port = $re.Captures[0].value
            $port = $port.Substring( 1,$port.Length-2)
            Add-Member -InputObject $_ -MemberType NoteProperty -Name "Port" -Value $port -PassThru
    
        }
    return $SerialPorts
}
