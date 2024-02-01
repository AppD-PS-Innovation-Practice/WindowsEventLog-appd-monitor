param (
    $minutesBack = -1.5,
    $demoTime = (Get-Date).AddMinutes($minutesBack),
    $message = "The previous system shutdown at $($demoTime) was unexpected.",
    $LogName = 'System',
    $Source = 'EventLog',
    $ID = 6008,
    $EntryType = 'ERROR',
    $minutesStartTime = -2,
    $minutesEndTime = 0,
    $numEvents = 5
)

for ($i = 0; $i -lt $numEvents; $i++)
{
    Write-EventLog -LogName $LogName -Source $Source -EventId $ID -EntryType $EntryType -Message $message
}

Write-Output 'Sleeping for 30 seconds to allow events to be created.'
Start-Sleep 30

$now = Get-Date
$StartTime = $now.AddMinutes($minutesStartTime)
$EndTime = $now.AddMinutes($minutesEndTime)
        
$filterHash = @{
    LogName      = $LogName
    ProviderName = $Source
    ID           = $ID
    StartTime    = $StartTime
    EndTime      = $EndTime
}

#$filterHash


$filteredEvents = Get-WinEvent -FilterHashtable $filterHash -ErrorAction Stop #-Verbose
$eventCount = $filteredEvents.Count

Write-Output "$($eventCount) events were found."
