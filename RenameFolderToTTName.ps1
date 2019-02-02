param 
(     
    [switch]$executionmode,
    [switch]$queryomdb,
    [string]$root = ".\",
    [string]$log_filename = "log.txt",
    [Parameter(Mandatory=$true)][string]$OMDBAPIKey
)
<#
$root = "x:\"
$log_filename = "logme.txt"
$OMDBAPIKey = "24dd0d05"
#>

Add-Type -AssemblyName System.Web
$Matches= $null
$year = $null
$response = $null
$log_fullpath = $root + $log_filename
$log_oldfullpath = $log_fullpath + ".old"
$dir = gci $root -Directory

function WriteLog {
    Param([string]$log, [string]$log_file)
    Write-Host $log
    Add-Content $log_file $log
}

function CleanString {
    Param([string]$to_be_cleaned, [string]$log_file)
    $clean_strings = @("\(","\)","\[","]","-","\#")

    #region begin remove ()[]- characters and trim
    foreach ($clean_me in $clean_strings)
    { 
        $to_be_cleaned = $to_be_cleaned -ireplace $clean_me, " "
    }
    return $to_be_cleaned.Trim()
}

function ParseName {
    Param([string]$folder_name, [string]$log_filename)
    #used to get the date out of the path name sting
    $date_expr =  @("\b\d{4}\b")
    $delimiters = @("\.","-","_"," ")
    $split_on_count = 0
    $split_on = 0
    $matches_count = 0
    
    #finds the character that is most likely to be the delimeter.  Problem with junk in front of movie title that needs to be solved.
    for ($i = 0; $i -lt $delimiters.Count; $i++)
    {
        $matches_count = ([regex]::Matches($folder_name, $delimiters[$i])).count
        if ($split_on_count -lt $matches_count)
        {
            $split_on = $i
            $split_on_count = $matches_count
        }
    }
    WriteLog (-join("ParseName: Found $split_on_count tokens split by '",$delimiters[$split_on],"'")) $log_filename
    
    $tokens = $folder_name.Split($delimiters[$split_on])
    $movie = $null
    $year = $null

    for ($i = 0; $i -lt $tokens.Count; $i++)
    {
        WriteLog (-join("ParseName: Evaluating '",$tokens[$i],"'" )) $log_filename
        if ( $tokens[$i] -match $date_expr)
        {
            #if date match is first token then probably not release date.
            if ($i -eq 0 -and $tokens[$i])
            {
                $movie = -join( $movie, " ", $tokens[$i]) 
            }
            else
            {
                $year = CleanString $tokens[$i]
                $i = $tokens.Count
            }
        }
        else
        {
            $movie = -join( $movie, " ", $tokens[$i])
        }
    }
    if (-not $year -match $date_expr[0]) { $year = $year.Substring(1,4) } 
    WriteLog "ParseName: `n`t`tTitle: $movie`n`t`tReleased:$year" $log_filename
    return @(([System.Web.HttpUtility]::UrlEncode($movie.Trim())),$year)
}

function Rename-MovieFolder
{
    Param
    (
        [switch]$executionmode,
        [object]$response,
        [string]$root, 
        [string]$log_fullpath
    )
    WriteLog  (-join ("Found on OMDB!`nTitle:`t",$response.Title,"`nYear :`t",$response.Year)) $log_fullpath
    #$title = "American Pie      Something"
    $title = $response.Title -replace ":", "-"
    $movie_name = -join ($title, " (",$response.Year,")")
    $movie_name_file_path = -join($file.FullName, "\", $movie_name, ".txt")
    $new_foldername  = -join ($root, $response.imdbID)
    if (-not ($file.FullName -like $folder_name) )
    {
        if ($executionmode.IsPresent)
        {
            if ([System.IO.File]::Exists($movie_name_file_path)) 
            {
                Remove-Item -LiteralPath $movie_name_file_path -Force
                if ($?)
                {
                    WriteLog ($movie_name_file_path + " removed from filesystem.") $log_fullpath
                }
                else
                {
                    WriteLog ($error[0]) $log_fullpath
                }
            }
            New-Item -ItemType file $movie_name_file_path
            Rename-Item -LiteralPath $file.FullName $new_foldername
            if ($?)
            {
                WriteLog "`nrenamed to `n`t $new_foldername`n***********`n`n" $log_fullpath
            }
            else
            {
                WriteLog ("Compare '" + $file.FullName + "' to '$new_foldername'")  $log_fullpath
                WriteLog $error[0].ErrorDetails $log_fullpath                        
            }
        } 
        else
        {
            WriteLog "Execution mode is disabled." $log_fullpath
        }
    }
    else
    {
        WriteLog "`nrenamed to `n`t $folder_name`n***********`n`n" $log_fullpath
    }
}

#region begin  Handle the Log file setup
# .NET version of testing existance, alternative to Test-Path
if ([System.IO.File]::Exists($log_fullpath))
{
    if ([System.IO.File]::Exists($log_oldfullpath)) { Remove-Item -Path $log_oldfullpath -Force }
    if ([System.IO.File]::Exists($log_fullpath)) { Rename-Item -Path $log_fullpath -NewName $log_oldfullpath }
}
New-Item -Path $root -Name $log_filename -Force
#endregion

foreach ($file in $dir) 
{
    #$file = $dir[885]
    WriteLog "`n***********`nFound:`n`t$file" $log_fullpath
    $response = $null

    if ($file -match "^tt\d{7}\b")
    {
        WriteLog "Title has been processed.  No need to query OMDB." $log_fullpath
    }
    else
    {
        $movie_details = ParseName $file $log_fullpath
        $movie = $movie_details[0]
        $year = $movie_details[1]
    
        #region begin Query the OMDB service.
        # If year value extraction was successful, then use the value in the query. Else, take chances with just a title (mutiple matches possible and potentially problematic)
        if ($year)
        {
            WriteLog "Searching for: $movie & $year" $log_fullpath
            if ($queryomdb.IsPresent) 
            {
                $query = "http://www.omdbapi.com/?apikey=$OMDBAPIKey&t=$movie&y=$year"
                $response = Invoke-RestMethod -Uri $query
                WriteLog "Query mode on. `nSearching with Title and Year`nQuery: $query" $log_fullpath 
            }
            else
            {
                WriteLog "Query mode off. URL that would be submitted: http://www.omdbapi.com/?apikey=$OMDBAPIKey&t=$movie&y=$year" $log_fullpath
            }
        } 
        #sometime the year is incorrect in the foldername - so drop it if nothing was found.
        if ($response.Response -eq "False" -or $response -eq $null)
        {
            WriteLog "Searching for: $movie" $log_fullpath
            if ($queryomdb.IsPresent) 
            {
                $query = "http://www.omdbapi.com/?apikey=$OMDBAPIKey&t=$movie"
                $response = Invoke-RestMethod -Uri $query
                WriteLog "Query mode on. `nSearching with Title`nQuery: $query" $log_fullpath
            }
            else
            {
                WriteLog "Query mode off. URL that would be submitted: http://www.omdbapi.com/?apikey=$OMDBAPIKey&t=$movie" $log_fullpath
            }
        }
        #still couldn't find anything so trying by removing tokens from the start of the string.
        if ($response.Response -eq "False")
        {
            $tokens = ([System.Web.HttpUtility]::UrlDecode($movie)).Split(" ")
            $start = 1
            $search_string = $null
            $impossible_match = $false
            WriteLog "Trying to find a possible match by removing tokens from the start of the string." $log_fullpath
            while ($response.Response -eq "False")
            {
                # break out cases
                if ($start -ge $tokens.Count) 
                {
                    WriteLog "Unable to find a match." $log_fullpath
                    break
                }
                elseif ($response.Response -eq "True") 
                {
                    WriteLog ("Found something: "+$response.totalResults+" results.") $log_fullpath
                    break
                }
                
                #create string minus first token
                for ($i = $start; $i -lt $tokens.Count; $i++)
                {
                    $search_string = $search_string + " " + $tokens[$i]
                }
                $search_string = [System.Web.HttpUtility]::UrlEncode($search_string.trim())
                $query = "http://www.omdbapi.com/?apikey=$OMDBAPIKey&s=$search_string"
                WriteLog "Query`n`t$query" $log_fullpath
                $response = Invoke-RestMethod -Uri $query

                $start++
                $search_string = $null
            }
        }
        $year = $null
        #endregion

        #region begin Execute write commands - Rename folder using new clean string with title and year values.

        if ($response.Response -eq "True")
        {
            if ($response.totalResults)
            {
                if  ($response.totalResults -eq 1)
                {
                    $search_string =  $response.Search[0].imdbID
                    $query = "http://www.omdbapi.com/?apikey=$OMDBAPIKey&i=$search_string"
                    $response = Invoke-RestMethod -Uri $query
                    Rename-MovieFolder -executionmode -response $response -root $root -log_fullpath $log_fullpath
                }
                else
                {
                    WriteLog "Too many results returned." $log_fullpath
                }
            }
            else
            {
                Rename-MovieFolder -executionmode -response $response -root $root -log_fullpath $log_fullpath
            }
        }
        else 
        {
            if ($queryomdb.IsPresent)
            {
                WriteLog "Error, you're not doing it right. The search critera did not find anything." $log_fullpath
            }
            else
            {
                WriteLog "No response returned since Query Mode is OFF." $log_fullpath
            }   
        }            
    }
    #endregion
} #End Loop
