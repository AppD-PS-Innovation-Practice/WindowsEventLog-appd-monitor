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

## Installation ##

1. Download and unzip.
2. Move the Health Rule Example and generate_test_event folders to a folder outside of `<MACHINE_AGENT_HOME>` as they are used for testing only.
3. Copy ONLY the WindowsEventLogMonitor directory to `<MACHINE_AGENT_HOME>/monitors`.

## Configuration ##

1. Update monitor.xml to point to the correct MACHINE_AGENT_HOME directory. Windows directory \ will need to be escaped with \\.

<argument name="file_path" default-value="`<MACHINE_AGENT_HOME>\\monitors\\WindowsEventLogMonitor\\WindowsEventLogMonitor.ps1"></argument>

2. Update WindowsEventLogMonitorQueryCriteria.csv with the desired event queries. The sample file includes several different examples.

3. Update execution properties as desired.
<execution-frequency-in-seconds>60</execution-frequency-in-seconds>
<execution-timeout-in-secs>45</execution-timeout-in-secs> 

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
"System";"Event Log";6008;2;-10;0;Custom Metrics|WindowsEventLogMonitor|UnexpectedShutdown_6008|EventCount

### Multiple Event IDs with Multiple Event Levels for the last 30 minutes ###
"Windows PowerShell";"PowerShell";400,600;1,2,3,4;-30;0;Custom Metrics|WindowsEventLogMonitor|PowerShell_400_and_600|EventCount

## Testing ##

### Health Rule Example folder ###
JSON formatted files for a health rule definition and a violation.

- HR Definition.json

- HR Violation.JSON


### generate_test_event folder ###

- PowerShell script to generate a test event with Write-EventLog.
	* generate_test_windows_event.ps1
	* Write-EventLog -LogName "System" -Source "Event Log" -EventID 6008 -EntryType ERROR -Message $message

- Example of a bad filter to create an error log message in the machine-agent.log to demonstrate what would be written if an event query is invalid.
	* BAD_FILTER_WindowsEventLogMonitorQueryCriteria.csv
	* "Application";".NET Runtime";1022;3;-60;ERROR_MUST_BE_INTEGER_ENUM_VALUE;Custom Metrics|WindowsEventLogMonitor|dotNET_Runtime_Invalid_Filter|EventCount


