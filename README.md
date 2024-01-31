# WindowsEventLogMonitor #

## Use Case ##

This extension monitors the number of times that a Windows Event Log event has occurred during the desired time window.

## Prerequisites ##

Windows PowerShell 5.1 or later is required. It is installed by default on all current versions of Windows clients and servers.
Since it uses Windows specific functions, PowerShell Core will not work.

## Microsoft Documentation for Get-WinEvent ##

<a href="https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.diagnostics/get-winevent?view=powershell-5.1">Get-WinEvent</a>

<a href="https://learn.microsoft.com/en-us/powershell/scripting/samples/creating-get-winevent-queries-with-filterhashtable?view=powershell-5.1">Get-WinEvent -FilterHashtable</a>

<a href="https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.eventing.reader.standardeventlevel?view=dotnet-plat-ext-8.0">Event Level Mapping to Enumerated Integer Value</a>

<a href="https://devblogs.microsoft.com/scripting/working-with-enums-in-powershell-5">Scripting Guy Blog: Get-EnumAndValues function</a>

## Installation ##

1. Download and unzip.
2. Move the Health Rule Example and generate_test_event folders to a folder outside of `<MACHINE_AGENT_HOME>` as they are used for testing only.
3. Copy ONLY the WindowsEventLogMonitor directory to `<MACHINE_AGENT_HOME>/monitors`.
4. Validate that the WindowsEventLogMonitor.cmd batch file can run the WindowsEventLogMonitor.ps1 PowerShell script as expected from the command line.

## Configuration ##

1. Update monitor.xml execution properties as desired.
2. Update WindowsEventLogMonitorQueryCriteria.csv with the desired event queries. The sample file includes several different examples.

## Event Query Parameters ##

CSV Input file: WindowsEventLogMonitorQueryCriteria.csv in the same directory as the extension script ($PSScriptRoot).

- Delimiters
	* LogName;ProviderName;Id;Level;minutesStartTime;minutesEndTime;MetricPath
	* Semicolon (;) for field separator.
	* Comma (,) for ID and Level array separator.

Note: Although the FilterHashtable filter allows an array for Log and Provider, this script limits them to single values.

- Single value strings
	* LogName
	* ProviderName

- Single or multiple integers
	* Event IDs
	* Event severity Levels
	
- Time Window - DateTime
	* StartTime - Negative number representing the number of minutes prior to script execution
	* EndTime - Negative number or 0 (zero) to represent the current time (now).


## Query Examples ##

### Single Event ID with Single Event Level for the last 10 minutes ###
"System";"Event Log";6008;2;-10;0;UnexpectedReboot_6008

### Multiple Event IDs with Multiple Event Levels for the last 30 minutes ###
"Windows PowerShell";"PowerShell";400,600;1,2,3,4;-30;0;PowerShell_400_and_600

## Metrics ##

### Status ###
The status of the extension is based upon the existence of the CSV file and the validity of each field. Status is based on Bitwise value for each of the steps.

Bitwise Error Flags for Status.

EventQueryErrorFlags

- OK = 0
- File = 1
- Log = 2
- Provider = 4
- SeverityLevel = 8
- EventID = 16
- TimeSpan = 32
- Query = 64


### Count ###
QUERY_NAME|Count represents the actual number of events found.
If will either be an integer greater than or equal to 0.
For the count of the events found, 0 represents No events found.
If the event query fails, the bitwise flag value of 64 will be added, but the eventcount will remain as 0.



## Testing ##

### Health Rule Example folder ###
JSON formatted files for a health rule definition and a violation.

- HR Definition.json

- HR Violation.JSON


### generate_test_event folder ###

- PowerShell script to generate a test event with Write-EventLog.
	* generate_test_windows_event.ps1

- Example of a bad filter to create an error log message in the machine-agent.log to demonstrate what would be written if an event query is invalid.
	* BAD_FILTER_WindowsEventLogMonitorQueryCriteria.csv
	


