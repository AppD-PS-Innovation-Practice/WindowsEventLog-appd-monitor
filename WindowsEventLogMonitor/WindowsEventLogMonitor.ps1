#WindowsEventLogMonitor

# Microsoft Documentation References
<#
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

#>

#Input validation logic
<#
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

Set metric path for all status parameters
Status metrics are set using Unix style exit codes
0 - OK
1 - NOTOK
Health Rule criteria can then be set for any value greater than 0

If Status fails, status is set to 1 and EventCount is -1.
EventCount will be one of the following
-1: Query Failure
0: No events found in timespan
>0: Number of events in the timespan
Custom Metrics|WindowsEventLogMonitor|UnexpectedShutdown_6008|EventCount
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
        'Count'
    ),
    $statusCode = 0
)

function Get-EnumValues
{
    # 

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

<#
Create a Hash Table for each query so that value can be updated in script
#>
function Set-AppDMetricPath
{
    param (
        $parentMetricPath = 'Custom Metrics|WindowsEventLogMonitor',
        $metricPath = 'UnexpectedReboot_6008',
        $extensionMetrics = @(
            'Log'
            'Provider'
            'Severity'
            'ID'
            'Time'
            'Query'
            'Count'
        ),
        $statusCode = 0
    )

    $metricPathStringHashTable = @{}

    foreach ($extensionMetric in $extensionMetrics)
    {
        $metricString = "name=$($parentMetricPath)|$($metricPath)|$($extensionMetric),value=$($statusCode),aggregator=OBSERVATION"
        $metricPathStringHashTable[$extensionMetric] = $metricString
    }

    $metricPathStringHashTable    
}

<#
Normally, you want to Test-Path $eventQueryCriteriaFile
but try Import-Csv will generate Exception.
This simplifies code block as if/else and try/catch can be collapsed to try/catch
#>

try
{
    $itemType = 'File'
    $eventQueries = Import-Csv $eventQueryCriteriaFile -Delimiter ';' -ErrorAction Stop
    $metricString = "name=$($parentMetricPath)|Status|$($itemType),value=1,aggregator=OBSERVATION"
    Write-Output $metricString    
}
catch
{    
    $metricString = "name=$($parentMetricPath)|Status|$($itemType),value=0,aggregator=OBSERVATION"
    Write-Output "Error: $($Error[0].FullyQualifiedErrorId)"
    Write-Output "Filename: $($eventQueryCriteriaFile)"
    exit
}

$enumHashTable = Get-EnumValues -enum 'System.Diagnostics.Eventing.Reader.StandardEventLevel'
$severityLevels = $enumHashTable.Values

# Array for all of the Metric Strings
[System.Collections.ArrayList]$extensionMetricsArrayList = @()

foreach ($query in $eventQueries)
{
    $LogName = $query.LogName
    $ProviderName = $query.ProviderName
    $Id = $query.Id -split ','
    $Level = $query.Level -split ','
    $minutesStartTime = $query.minutesStartTime
    $minutesEndTime = $query.minutesEndTime
    $metricPath = $query.MetricPath
    
    $metricPathStringHashTable = Set-AppDMetricPath -parentMetricPath $parentMetricPath -metricPath $metricPath -extensionMetrics $extensionMetrics -statusCode $statusCode
    [void]$extensionMetricsArrayList.Add($metricPathStringHashTable)

    try
    {
        $logDetails = (Get-WinEvent -ListLog $LogName -ErrorAction Stop)
        if ($logDetails)
        {
            $itemType = 'Log'
            $metricPathStringHashTable[$itemType] = $metricPathStringHashTable[$itemType] -replace "value=$($statusCode)", 'value=1'

            $providerDetails = $logDetails `
            | Where-Object {
                $_.ProviderNames -contains $ProviderName
            }
            if ($providerDetails)
            {
                $itemType = 'Provider'
                $metricPathStringHashTable[$itemType] = $metricPathStringHashTable[$itemType] -replace "value=$($statusCode)", "value=1"
            }
            else
            {
                # "$ProviderName not found for $LogName"
                continue
            }
        }
    }
    catch
    {
        # "$LogName not found"
        continue
    }
    
    if ($Level | Where-Object { $_ -in $severityLevels })
    {
        $itemType = 'Severity'
        $metricPathStringHashTable[$itemType] = $metricPathStringHashTable[$itemType] -replace "value=$($statusCode)", 'value=1'      
    }
    else
    {
        ##Throw "$Level is not a valid integer array in StandardEventLevel enumeration list."
        continue
    }
    
    <#
    If any eventId isn't integer, then need to immediately continue to next event
    -split creates a string array so need to check each Id and cast to [int]
    Reset statusCode for events as it will be decremented for each invalid ID
    #>
    
    # Need to copy original statusCode to iterate over event IDs
    $eventStatusCode = $statusCode

    #
    foreach ($eventId in $Id)
    {
        try
        {
            [int]$eventId | Out-Null
            
        }
        catch
        {
            $eventStatusCode--
        }
    }
    
    if ($eventStatusCode -eq $statusCode)
    {    
        $itemType = 'ID'
        $metricPathStringHashTable[$itemType] = $metricPathStringHashTable[$itemType] -replace "value=$($statusCode)", "value=1"
    }
    else
    {
        #Throw "$eventId is not a valid integer array."
        continue
    }

    try
    {
        $minutesStartTime = [int]$minutesStartTime
        $minutesEndTime = [int]$minutesEndTime
        if ((($minutesStartTime -lt 0) `
                    -and ($minutesStartTime -lt $minutesEndTime)) `
                -and ($minutesEndTime -le 0))
        {
            $itemType = 'Time'
            $metricPathStringHashTable[$itemType] = $metricPathStringHashTable[$itemType] -replace "value=$($statusCode)", "value=1"
        }
        else
        {
            #Throw 'Invalid Timespan - start must be before end'
            continue
        }
    }
    catch
    {
        #Throw 'Invalid Timespan - minutes must be integers'
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
    
    #$filterHash
    <#
        Need try/catch to prevent Non-Terminating error from writing to I/O stream
        If no events are found, then it throws an Exception

        | No events were found that match the specified selection criteria.
    #>

    try
    {
        $filteredEvents = Get-WinEvent -FilterHashtable $filterHash -ErrorAction Stop #-Verbose
        $eventCount = $filteredEvents.Count
        $eventQuery = 1
    }

    catch #[System.Management.Automation.MethodException]
    {
        if ($_.Exception -match 'No events were found that match the specified selection criteria')
        {
            $eventCount = 0
            $eventQuery = 1
        }
        else
        {
            # Write-Output 'Invalid Query'
            $eventQuery = 0
            $eventCount = 0
        }
    }

    $itemType = 'Query'
    $metricPathStringHashTable[$itemType] = $metricPathStringHashTable[$itemType] -replace "value=$($statusCode)", "value=$($eventQuery)"
    
    $itemType = 'Count'
    $metricPathStringHashTable[$itemType] = $metricPathStringHashTable[$itemType] -replace "value=$($statusCode)", "value=$($eventCount)"

    
}

Write-Output  $extensionMetricsArrayList.Values
'End for debugging' | Out-Null
