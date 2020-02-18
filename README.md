# Scripts

## Get-AllVIServerClients.ps1
This function accepts an array of IPv4 addresses represented as strings i.e. "192.168.0.1" in parameter position 0 as well as an optional PSCredential object to authenticate against the VMWare ESX host.  It is assumed that the same credentials can be used across all hosts if 2 or more hosts are included in the array that is passed to parameter 0.

## RenameFolderToTTName.ps1
This function is a fun script I wrote to process folder names that represent movie titles.  It queries the Open Movie Database and attempts to find a match.  If a match is found, the folder is renamed to the titleId of the movie. 
