<#
Testing script to validate Event Log retrieval operations
Write-EventLog to generate test events
Get-WinEvent -FilterHashtable to retrieve events

If events already exist, switch for -existing can be used, but Start and End need to be replaced with actual values

Retrieved events will be output to a raw XML file and then a prettified version
Since ToXml returns the events separately, header and footer are added
Header and footer copied from Event Viewer Save Selected Events as XML
Raw file matches output of Event Viewer
Raw file is read and new prettified version created for easier viewing.
#>

param (
    $LogName = 'System',
    $Source = 'EventLog', #Ensure exact string is used.
    $ID = 6008,
    $EntryType = 'ERROR',
    $minutesStartTime = -2,
    $minutesEndTime = 0,
    $numEvents = 5,
    $outputFolder = 'E:\eventTest\output',
    $outputXmlFile = "event$($ID).xml",
    $prettyPrintXmlFile = "event$($ID)_prettyprint.xml",
    [switch]$existing,
    $existingEventStart = '1/18/2024 11:20 AM',
    $existingEventEnd = '1/18/2024 11:23 AM'
)

if (!(Test-Path $outputFolder))
{
    New-Item -ItemType Directory -Path $outputFolder | Out-Null
}
$timestamp = (Get-Date).ToString('yyyy_MM_dd_HH_mm_ss')
$outputFilename = Join-Path $outputFolder "$($timestamp)_$($outputXmlFile)"
$xmlHeader = '<?xml version="1.0" encoding="utf-8" standalone="yes"?><Events>'
$xmlHeader | Out-File $outputFilename

<#
Event message string format that an actual event generates.
The previous system shutdown at 11:17:46 AM on 1/18/2024 was unexpected.

The time listed will be before the timestamp of the generated event
because the event isn't generated until system is rebooted.
The above is an example of the event created at '1/18/2024 11:20 AM'

Although the Write-EventLog parameter is -Message, the actual text string will exist under
<EventData>
    <Data>The previous system shutdown at 11:17:46 AM on 1/18/2024 was unexpected.</Data> 
</EventData>
#>

$message = Get-Date -UFormat 'The previous system shutdown at %I:%M %p on %m/%d/%Y was unexpected.'

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

$filterHashEvents = Get-WinEvent -FilterHashtable $filterHash -ErrorAction Stop
$filterHashEvents.ToXml() | Out-File $outputFilename -Append
$eventCount = $filterHashEvents.Count
Write-Output "`n$($eventCount) new events were found."
Write-Output 'Events created with Write-EventLog have message embedded in <EventData>.'
$filterHashEventsDataMessage = $filterHashEvents `
| Select-Object -Property TimeCreated, Id, LevelDisplayName, @{l = 'Message'; e = { $_.Properties.Value } }
Write-Output $filterHashEventsDataMessage

if ($existing)
{
    $filterHash = @{
        LogName      = $LogName
        ProviderName = $Source
        ID           = $ID
        StartTime    = Get-Date($existingEventStart)
        EndTime      = Get-Date($existingEventEnd)
    }

    $existingEvents = Get-WinEvent -FilterHashtable $filterHash -ErrorAction Stop
    $existingEvents.ToXml() | Out-File $outputFilename -Append
    $existingEventsCount = $existingEvents.Count
    Write-Output "`n$($existingEventsCount) existing events were found."
    Write-Output "Events created by the OS will use Message supplied by DLL message file.`n"
    $existingEvents = $existingEvents     `
    | Select-Object -Property TimeCreated, Id, LevelDisplayName, Message
    Write-Output $existingEvents
}



$xmlFooter = '</Events>'
$xmlFooter | Out-File $outputFilename -Append

$xml = [xml](Get-Content $outputFilename)
$prettyPrintXmlFileName = Join-Path $outputFolder "$($timestamp)_$($prettyPrintXmlFile)"
$xml.Save($prettyPrintXmlFileName)
