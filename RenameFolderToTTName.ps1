param 
(     
    [switch]$executionmode,
    [switch]$queryomdb,
    [string]$root = ".\",
    [string]$log_filename = "log.txt",
    [Parameter(Mandatory=$true)][string]$OMDBAPIKey
)

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
    $temp = $null

    #region begin remove ()[]- characters and trim
    foreach ($clean_me in $clean_strings)
    { 
        $temp = $to_be_cleaned -ireplace $clean_me, " "
    }
    return $temp.Trim()
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
    WriteLog (-join("ParseName: Found $split_on_count matches for ", $delimiters[$split_on])) $log_filename
    
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
    return @($movie.Trim(),$year)
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
        if ($response.Response -eq $null -or $response.Response -eq "False")
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
        $year = $null
        #endregion

        #region begin Execute write commands - Rename folder using new clean string with title and year values.
        if ($response.Response -eq "True")
        {
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
                    New-Item -ItemType file $movie_name_file_path
                    rename-Item -path $file.FullName -NewName $new_foldername
                    if (-not $?)
                    {
                        WriteLog ("Compare '" + $file.FullName + "' to '$new_foldername'")  $log_fullpath
                        WriteLog $error[0].ErrorDetails $log_fullpath
                    }
                    else
                    {
                        
                        WriteLog "`nrenamed to `n`t $new_foldername`n***********`n`n" $log_fullpath
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


