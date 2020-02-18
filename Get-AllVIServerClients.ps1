#Requires -Module @{ ModuleName = 'VMware.VimAutomation.Core'; ModuleVersion = '11.3.0' }
#https://www.vmware.com/support/developer/PowerCLI/

function Get-AllVIServerClients 
{
    [CmdletBinding()]
    Param 
    (
        [Parameter(Mandatory=$true,
                    Position = 0,
                    HelpMessage="Enter one or more IP addresses separated by commas.")           
        ]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $SeverAddress,
        [Parameter(Mandatory=$true,
                    Position = 1)]
        [pscredential]
        $Credential
    )
    Begin
    {
        #https://www.powershelladmin.com/wiki/PowerShell_regex_to_accurately_match_IPv4_address_(0-255_only)
        $IPv4Regex = "^(?:(?:0?0?\d|0?[1-9]\d|1\d\d|2[0-5][0-5]|2[0-4]\d)\.){3}(?:0?0?\d|0?[1-9]\d|1\d\d|2[0-5][0-5]|2[0-4]\d)$"
        if ($ServerAddress[0] -notmatch $IPv4Regex) { Throw "The parameter provided is not an IPv4 address." }
        $ReturnObject = New-Object -TypeName System.Collections.ArrayList
    }
    Process
    {
        $SeverAddress | %{[void](connect-viserver –server $_ -Protocol https -Credential $Credential) }

        get-vm | %{[PSCustomObject]@{"Name"=$_.Name;"OS"=($_.guest).OSFullName;"PowerState"=$_.PowerState;"Host"=$_.VMHost} | %{[void]$ReturnObject.Add($_)}}
        # ConvertTo-CSV -NoTypeInformation | Select-Object -Skip 1 | Add-Content -path ./vms.csv }
    }
    End
    {
        $SeverAddress | %{ disconnect-viserver –server $_ -Confirm:$false -Force}
        Return (, $ReturnObject)
    }

}
