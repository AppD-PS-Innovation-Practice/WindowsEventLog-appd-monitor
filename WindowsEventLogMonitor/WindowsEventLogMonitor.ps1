#WindowsEventLogMonitor

<#
References for Get-WinEvent -FilterHashtable
https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.diagnostics/get-winevent?view=powershell-5.1
https://learn.microsoft.com/en-us/powershell/scripting/samples/creating-get-winevent-queries-with-filterhashtable?view=powershell-5.1

StandardEventLevel Enum
https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.eventing.reader.standardeventlevel?view=dotnet-plat-ext-8.0
LogAlways
0
This value indicates that not filtering on the level is done during the event publishing.

Critical
1
This level corresponds to critical errors, which is a serious error that has caused a major failure.

Error
2
This level corresponds to normal errors that signify a problem.

Warning
3
This level corresponds to warning events. For example, an event that gets published because a disk is nearing full capacity is a warning event.

Informational
4
This level corresponds to informational events or messages that are not errors. These events can help trace the progress or state of an application.

Verbose
5
This level corresponds to lengthy events or messages.

Level values can be converted from Text to corresponding enumerated integer as well.
$C = [System.Diagnostics.Eventing.Reader.StandardEventLevel]::Informational
Level=$C.Value__

#>

$eventQueryCriteriaFile = "$PSScriptRoot\WindowsEventLogMonitorQueryCriteria.csv"
$eventQueries = Import-Csv $eventQueryCriteriaFile -Delimiter ';'
foreach ($query in $eventQueries)
{
    $eventCount = 0
    $metricPath = $query.MetricPath
    $LogName = $query.LogName
    $ProviderName = $query.ProviderName
    $ID = $query.Id -split ','
    $Level = $query.Level -split ','
    $now = Get-Date
    $StartTime = $now.AddMinutes($query.minutesStartTime)
    $EndTime = $now.AddMinutes($query.minutesEndTime)

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
        Only need try/catch to prevent Non-Terminating error
        from writing to I/O stream

        | No events were found that match the specified selection criteria.
    #>
    
    try
    {
        $filteredEvents = Get-WinEvent -FilterHashtable $filterHash -ErrorAction Stop    
        if ($filteredEvents.Count)
        {
            $eventCount = $filteredEvents.Count
        }
    }
    catch
    {


    }
    
    $metricString = "name=$($metricPath),value=$($eventCount),aggregator=OBSERVATION"
    Write-Output $metricString

}
