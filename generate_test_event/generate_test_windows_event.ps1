$demoTime = (Get-Date).AddMinutes(-1.5)
$message = "The previous system shutdown at $($demoTime) was unexpected."
Write-EventLog -LogName "System" -Source "Event Log" -EventID 6008 -EntryType ERROR -Message $message
Write-Output "Ten Minutes ago timeframe for 6008"
(Get-Date).AddMinutes(-10)

<#

"System"; - 
"Event Log";
6008;
2; 
-10; How many minutes back?
0; When does it end? 0 means NOW
Custom Metrics|WindowsEventLogMonitor|UnexpectedShutdown_6008|EventCount

#>

#