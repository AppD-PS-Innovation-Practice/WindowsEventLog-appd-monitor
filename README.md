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

## Event Query Parameters ##

CSV Input file: WindowsEventLogMonitorQueryCriteria.csv in the same directory as the extension script ($PSScriptRoot).

- Delimiters
	* LogName;ProviderName;Id;Level;minutesStartTime;minutesEndTime;MetricPath
	* Semicolon (;) for field separator.
	* Comma (.,) for ID and Level array separator.

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

