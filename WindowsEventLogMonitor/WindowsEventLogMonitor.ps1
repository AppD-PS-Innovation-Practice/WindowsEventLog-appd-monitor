#WindowsEventLogMonitor Custom Extension

<#
Microsoft Documentation References

References for Get-WinEvent -FilterHashtable
https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.diagnostics/get-winevent?view=powershell-5.1
https://learn.microsoft.com/en-us/powershell/scripting/samples/creating-get-winevent-queries-with-filterhashtable?view=powershell-5.1

Get-WinEvent uses the System.Diagnostics.Eventing.Reader Namespace
https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.eventing.reader?view=netframework-4.8

Standard event levels that are used in the Event Log service are integers mapped to event severity levels.
If you view the Details for an event with XML View, it will display this numeric level as well.

StandardEventLevel Enum
https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.eventing.reader.standardeventlevel?view=netframework-4.8

LogAlways - 0
This value indicates that not filtering on the level is done during the event publishing.

Critical - 1
This level corresponds to critical errors, which is a serious error that has caused a major failure.

Error - 2
This level corresponds to normal errors that signify a problem.

Warning - 3
This level corresponds to warning events. For example, an event that gets published because a disk is nearing full capacity is a warning event.

Informational - 4
This level corresponds to informational events or messages that are not errors. These events can help trace the progress or state of an application.

Verbose - 5
This level corresponds to lengthy events or messages.

Level values can be converted from Text to corresponding enumerated integer as well.
$C = [System.Diagnostics.Eventing.Reader.StandardEventLevel]::Informational
$Level=$C.Value__
$Level

Input validation logic

File Existence and then HashFilterTable fields
Semicolon is field separator so that Id and Level can be comma separated arrays
LogName;ProviderName;Id;Level;minutesStartTime;minutesEndTime;MetricPath
PowerShell standard naming conventions not followed for field variables.
Variable capitilaztion matches Get-WinEvent Parameters 

LogName and ProviderName are both strings and must exist on the system.

Id is one or more event IDs

Level is one or more severity levels that must match the allowable integers
Custom event levels can be defined beyond these standard levels.

Archived "Hey, Scripting Guys! blog 
https://devblogs.microsoft.com/scripting/working-with-enums-in-powershell-5/
function Get-EnumValues
Get-EnumValues -enum "System.Diagnostics.Eventing.Reader.StandardEventLevel"
[Enum]::GetValues( 'System.Diagnostics.Eventing.Reader.StandardEventLevel')

minutesStartTime is the start of the time window.
Start must be a negative number.

minutesEndTime is the end of the time window.
If 0, then it is now.
Otherwise, it must be a negative number

Status is based on Bitwise value for each of the steps

Bitwise Error Flags for Status

File is a global validation which results in Terminal error with Throw
Normally, you want to Test-Path $eventQueryCriteriaFile
but try Import-Csv will generate Exception.
This simplifies code block as if/else and try/catch can be collapsed to try/catch

All other errors are per event query.
If any queries fail, then the bit for that operation is set.
If there are any errors, then each event query line will need to be checked.
This decreases the number of reported metrics, load on system, and scaling.

EventCount will be one of the following
0: No events found in timespan
>0: Number of events in the timespan
Custom Metrics|WindowsEventLogMonitor|UnexpectedReboot_6008|EventCount
#>

param (
    $eventQueryCriteriaFile = "$($PSScriptRoot)\WindowsEventLogMonitorQueryCriteria.csv",
    $parentMetricPath = 'Custom Metrics|WindowsEventLogMonitor',
    $metricPath = 'UnexpectedReboot_6008',
    $extensionMetrics = @(
        'Log'
        'Provider'
        'Severity'
        'ID'
        'Time'
        'Query'
    ),
    $statusCode = 0
)

function Get-EnumValues
{

    param (
        [string]$enum
    )

    $enumValues = @{}

    [Enum]::GetValues([type]$enum) `
    | ForEach-Object { 
        $enumValues.add($_, $_.value__)
    }
    $enumValues
}


[flags()] enum EventQueryErrorFlags
{
    OK = 0
    File = 1
    Log = 2
    Provider = 4
    SeverityLevel = 8
    EventID = 16
    TimeSpan = 32
    Query = 64
}

$enumHashTable = Get-EnumValues -enum 'System.Diagnostics.Eventing.Reader.StandardEventLevel'
$severityLevels = $enumHashTable.Values
$queryErrorFlags = 0

try
{
    $eventQueries = Import-Csv $eventQueryCriteriaFile -Delimiter ';' -ErrorAction Stop
}
catch
{    
    # Write-Output "Error: $($Error[0].FullyQualifiedErrorId)"
    # Write-Output "Filename: $($eventQueryCriteriaFile)"
    # If File can't be read, then no other metrics can be set this run

    $queryErrorFlags = $queryErrorFlags -bor [EventQueryErrorFlags]::File
    $queryErrorStatus = "name=$($parentMetricPath)|Status,value=$($queryErrorFlags),aggregator=OBSERVATION"    
    Write-Output $queryErrorStatus
    exit
}

foreach ($query in $eventQueries)
{
    $LogName = $query.LogName
    $ProviderName = $query.ProviderName
    $Id = $query.Id -split ','
    $Level = $query.Level -split ','
    $minutesStartTime = $query.minutesStartTime
    $minutesEndTime = $query.minutesEndTime
    $metricPath = $query.MetricPath

    <#
    Check to ensure that all fields have been populated.
    If there aren't enough Import-Csv will still work but field will be empty
    #>
    if (!$metricPath) {
        $queryErrorFlags = $queryErrorFlags -bor [EventQueryErrorFlags]::File
        continue
    }

    $countMetricPath = "$($parentMetricPath)|$($metricPath)|Count"
    $eventCount = 0

    try
    {
        $logDetails = (Get-WinEvent -ListLog $LogName -ErrorAction Stop)
        $providerDetails = $logDetails `
        | Where-Object {
            $_.ProviderNames -contains $ProviderName
        }
        if (!$providerDetails)
        {
            # "$ProviderName not found for $LogName"
            $queryErrorFlags = $queryErrorFlags -bor [EventQueryErrorFlags]::Provider
            $countMetricString = "name=$($countMetricPath),value=$($eventCount),aggregator=OBSERVATION"
            Write-Output $countMetricString
            continue
        }
    }
    catch
    {
        # "$LogName not found"
        $queryErrorFlags = $queryErrorFlags -bor [EventQueryErrorFlags]::Log
        $countMetricString = "name=$($countMetricPath),value=$($eventCount),aggregator=OBSERVATION"
        Write-Output $countMetricString
        continue
    }
    
    if (!($Level | Where-Object { $_ -in $severityLevels }))
    {
        ## "$Level is not a valid integer array in StandardEventLevel enumeration list."
        $queryErrorFlags = $queryErrorFlags -bor [EventQueryErrorFlags]::SeverityLevel
        $countMetricString = "name=$($countMetricPath),value=$($eventCount),aggregator=OBSERVATION"
        Write-Output $countMetricString
        continue
    }
    
    <#
    -split creates a string array so need to check each Id and cast to [int]
    If any eventId isn't integer, then need to immediately continue to next event
    break will exit out of this internal loop
    Need a second variable to break out of outer loop
    #>

    $invalidId = 0
    foreach ($eventId in $Id)
    {
        try
        {
            [int]$eventId | Out-Null            
        }
        catch
        {
            # "$eventId is not a valid integer."
            $queryErrorFlags = $queryErrorFlags -bor [EventQueryErrorFlags]::EventID
            $countMetricString = "name=$($countMetricPath),value=$($eventCount),aggregator=OBSERVATION"
            Write-Output $countMetricString
            $invalidId = 1
            break
        }
    }

    if ($invalidId) {
        continue
    }
    
    try
    {
        $minutesStartTime = [int]$minutesStartTime
        $minutesEndTime = [int]$minutesEndTime
        if (($minutesStartTime -lt 0) `
                -and ($minutesStartTime -lt $minutesEndTime) `
                -and ($minutesEndTime -le 0))
        {
            # Valid TimeSpan
        }
        else
        {
            # 'Invalid Timespan - start must be before end'
            $queryErrorFlags = $queryErrorFlags -bor [EventQueryErrorFlags]::TimeSpan
            $countMetricString = "name=$($countMetricPath),value=$($eventCount),aggregator=OBSERVATION"
            Write-Output $countMetricString
            continue
        }
    }
    catch
    {
        # 'Invalid Timespan - minutes must be integers'
        $queryErrorFlags = $queryErrorFlags -bor [EventQueryErrorFlags]::TimeSpan
        $countMetricString = "name=$($countMetricPath),value=$($eventCount),aggregator=OBSERVATION"
        Write-Output $countMetricString
        continue
    }

    $now = Get-Date
    $StartTime = $now.AddMinutes($minutesStartTime)
    $EndTime = $now.AddMinutes($minutesEndTime)
        
    $filterHash = @{
        LogName      = $LogName
        ProviderName = $ProviderName
        ID           = $ID
        Level        = $Level
        StartTime    = $StartTime
        EndTime      = $EndTime
    }
    
    # $filterHash
    <#
        Need try/catch to prevent Non-Terminating error from writing to I/O stream
        If no events are found, then it throws an Exception

        | No events were found that match the specified selection criteria.
    #>

    try
    {
        $filteredEvents = Get-WinEvent -FilterHashtable $filterHash -ErrorAction Stop #-Verbose
        $eventCount = $filteredEvents.Count
    }
    catch #[System.Management.Automation.MethodException]
    {
        if ($_.Exception -match 'No events were found that match the specified selection criteria')
        {
            $eventCount = 0
        }
        else
        {
            # Write-Output 'Invalid Query'
            $eventCount = 0
            $queryErrorFlags = $queryErrorFlags -bor [EventQueryErrorFlags]::Query
        }
    }
    finally 
    {
        # Always set count after the try block regardless of whether an exception occurred or not
        $countMetricString = "name=$($countMetricPath),value=$($eventCount),aggregator=OBSERVATION"
        Write-Output $countMetricString
    }
}

#  [EventQueryErrorFlags]$queryErrorFlags
$queryErrorStatus = "name=$($parentMetricPath)|Status,value=$($queryErrorFlags),aggregator=OBSERVATION"
Write-Output $queryErrorStatus

# 'End for debugging to place breakpoint' | Out-Null

# To check that the EventQueryErrorFlags are set correctly, uncomment the below line

# [EventQueryErrorFlags]$queryErrorFlags



