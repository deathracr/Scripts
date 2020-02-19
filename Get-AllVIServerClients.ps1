#Requires -Module @{ ModuleName = 'VMware.VimAutomation.Core'; ModuleVersion = '11.3.0' }
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
        $ServerAddress,
        [Parameter(Mandatory=$true,
                    Position = 1)]
        [ValidateNotNull()]
        [pscredential]
        $Credential
    )

    #https://www.vmware.com/support/developer/PowerCLI/
    Begin
    {
        # https://www.powershelladmin.com/wiki/PowerShell_regex_to_accurately_match_IPv4_address_(0-255_only)
        $IPv4Regex = "^(?:(?:0?0?\d|0?[1-9]\d|1\d\d|2[0-5][0-5]|2[0-4]\d)\.){3}(?:0?0?\d|0?[1-9]\d|1\d\d|2[0-5][0-5]|2[0-4]\d)$"
        $ServerAddress | %{if ($_ -notmatch $IPv4Regex) { Throw "The parameter provided is not an IPv4 address." }}       
        $ReturnObject = New-Object -TypeName System.Collections.ArrayList
    }
    Process
    { 
        $ServerAddress | %{[void](connect-viserver –server $_ -Protocol https -Credential $Credential)}
        get-vm | %{[PSCustomObject]@{"Name"=$_.Name;"OS"=($_.guest).OSFullName;"PowerState"=$_.PowerState;"Host"=$_.VMHost} | %{[void]$ReturnObject.Add($_)}}
        $ServerAddress | %{ disconnect-viserver –server $_ -Confirm:$false -Force}
    }
    End
    {
        Return (, $ReturnObject)
    }
}
