#!/usr/bin/env pwsh

# Version and program info (declare before parameters)
$VERSION = "1.0.0"
$PROGRAM_NAME = "clog.ps1"

# Color mappings for different platforms
$Colors = @{
    "INFO"    = "Blue"
    "WARNING" = "Yellow"  
    "ERROR"   = "Red"
    "SUCCESS" = "Green"
    "DEBUG"   = "Magenta"
    "TRACE"   = "Cyan"
}

# ANSI color codes for non-Windows or when needed
$AnsiColors = @{
    "INFO"    = "`e[1;34m"
    "WARNING" = "`e[1;33m"
    "ERROR"   = "`e[1;31m"
    "SUCCESS" = "`e[1;32m"
    "DEBUG"   = "`e[1;35m"
    "TRACE"   = "`e[1;36m"
    "RESET"   = "`e[0m"
}

<#
.SYNOPSIS
    clog.ps1 - Cross-platform colorized logging utility (PowerShell version)

.DESCRIPTION
    PowerShell version of clog for Windows/PowerShell users
    Fully compatible with bash version features

.PARAMETER Level
    Log level: INFO, WARNING, ERROR, SUCCESS, DEBUG, TRACE

.PARAMETER Message
    The message to log

.PARAMETER Timestamp
    Include timestamp in output

.PARAMETER Pid
    Include process ID in output

.PARAMETER Json
    Output in JSON format

.PARAMETER NoSyslog
    Don't log to system log

.PARAMETER NoColor
    Disable colored output

.PARAMETER Tag
    Set syslog/event log tag

.EXAMPLE
    clog.ps1 INFO "Application started"

.EXAMPLE
    clog.ps1 -Level ERROR -Message "Connection failed" -Timestamp

.EXAMPLE
    clog.ps1 WARNING "Disk space low" -Json
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0)]
    [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS", "DEBUG", "TRACE")]
    [string]$Level,
    
    [Parameter(Mandatory=$true, Position=1, ValueFromRemainingArguments=$true)]
    [string[]]$Message,
    
    [switch]$Timestamp,
    [switch]$IncludePid,
    [switch]$Json,
    [switch]$NoSyslog,
    [switch]$NoColor,
    [string]$Tag = $env:CLOG_TAG ?? "clog",
    [switch]$Version,
    [switch]$Help
)

function Show-Help {
    @"
$PROGRAM_NAME v$VERSION - Cross-platform colorized logging utility

USAGE:
    $PROGRAM_NAME [OPTIONS] LEVEL "message"

LEVELS:
    INFO        Informational messages (blue)
    WARNING     Warning messages (yellow)
    ERROR       Error messages (red)
    SUCCESS     Success messages (green)
    DEBUG       Debug messages (magenta)
    TRACE       Trace messages (cyan)

OPTIONS:
    -Timestamp          Include timestamp in output
    -IncludePid         Include process ID in output
    -Json               Output in JSON format
    -NoSyslog           Don't log to system log
    -NoColor            Disable colored output
    -Tag <string>       Set system log tag (default: clog)
    -Version            Show version information
    -Help               Show this help message

ENVIRONMENT VARIABLES:
    CLOG_TAG           Default system log tag
    NO_COLOR           Disable colors if set
    CLOG_NO_SYSLOG     Disable system logging if set

EXAMPLES:
    $Script:PROGRAM_NAME INFO "Application started successfully"
    $Script:PROGRAM_NAME WARNING "Disk space is low"
    $Script:PROGRAM_NAME ERROR "Failed to connect to database"
    $Script:PROGRAM_NAME SUCCESS "Backup completed"
    $Script:PROGRAM_NAME -Timestamp -IncludePid DEBUG "Debug information"
    $Script:PROGRAM_NAME -Json INFO "Status update"

COMPATIBILITY:
    - Windows PowerShell 5.1+
    - PowerShell 7+ (Windows/macOS/Linux)
    - Works with Windows Event Log and Unix syslog
"@
}

function Write-JsonOutput {
    param(
        [string]$Level,
        [string]$Message
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ" -AsUTC
    $jsonObject = @{
        timestamp = $timestamp
        level = $Level
        message = $Message
        pid = $PID
        tag = $Tag
    }
    
    $jsonObject | ConvertTo-Json -Compress
}

function Write-SystemLog {
    param(
        [string]$Level,
        [string]$Message,
        [string]$Tag
    )
    
    if ($NoSyslog -or $env:CLOG_NO_SYSLOG) {
        return
    }
    
    try {
        if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6) {
            # Windows - use Event Log
            $EventLogLevel = switch ($Level) {
                "ERROR"   { "Error" }
                "WARNING" { "Warning" }
                default   { "Information" }
            }
            
            # Try to write to Application log, fallback silently if no permissions
            try {
                Write-EventLog -LogName Application -Source $Tag -EntryType $EventLogLevel -EventId 1 -Message "[$Level] $Message" -ErrorAction SilentlyContinue
            } catch {
                # Silently fail - no permissions or source not registered
            }
        } else {
            # Unix-like - use logger command if available
            $loggerPath = Get-Command logger -ErrorAction SilentlyContinue
            if ($loggerPath) {
                $priority = switch ($Level) {
                    "ERROR"   { "user.err" }
                    "WARNING" { "user.warning" }
                    "INFO"    { "user.info" }
                    "SUCCESS" { "user.notice" }
                    "DEBUG"   { "user.debug" }
                    "TRACE"   { "user.debug" }
                }
                
                & logger -t $Tag -p $priority "[$Level] $Message" 2>$null
            }
        }
    } catch {
        # Silently fail - logging should never break the application
    }
}

function Write-ColorizedOutput {
    param(
        [string]$Level,
        [string]$Message,
        [string]$Prefix
    )
    
    # Check if colors should be disabled
    $disableColor = $NoColor -or $env:NO_COLOR -or (-not [Console]::IsOutputRedirected -eq $false)
    
    if ($Json) {
        Write-JsonOutput -Level $Level -Message $Message
        return
    }
    
    if ($disableColor) {
        Write-Output "$Prefix $Message"
        return
    }
    
    # Use PowerShell's built-in color support when possible
    if ($Host.UI.SupportsVirtualTerminal -or $PSVersionTable.PSVersion.Major -ge 7) {
        if ($Timestamp) {
            # Split timestamp and tag for separate coloring
            $parts = $Prefix -split ' ', 2
            if ($parts.Count -eq 2) {
                $timestampPart = $parts[0]
                $tagPart = $parts[1]
                Write-Host "$timestampPart " -NoNewline
                Write-Host $tagPart -ForegroundColor $Script:Colors[$Level] -NoNewline
                Write-Host " $Message"
            } else {
                Write-Host $Prefix -ForegroundColor $Script:Colors[$Level] -NoNewline
                Write-Host " $Message"
            }
        } else {
            Write-Host $Prefix -ForegroundColor $Script:Colors[$Level] -NoNewline
            Write-Host " $Message"
        }
    } else {
        # Fallback to ANSI codes for older PowerShell
        $colorCode = $Script:AnsiColors[$Level]
        $resetCode = $Script:AnsiColors["RESET"]
        
        if ($Timestamp) {
            $parts = $Prefix -split ' ', 2
            if ($parts.Count -eq 2) {
                Write-Output "$($parts[0]) $colorCode$($parts[1])$resetCode $Message"
            } else {
                Write-Output "$colorCode$Prefix$resetCode $Message"
            }
        } else {
            Write-Output "$colorCode$Prefix$resetCode $Message"
        }
    }
}

# Handle help and version
if ($Help) {
    Show-Help
    exit 0
}

if ($Version) {
    Write-Output "$Script:PROGRAM_NAME v$Script:VERSION"
    exit 0
}

# Validate and process message
$messageText = $Message -join " "
if ([string]::IsNullOrWhiteSpace($messageText)) {
    Write-Error "Error: Message cannot be empty"
    Show-Help
    exit 1
}

# Build prefix
$prefix = "[$Level]"

if ($Timestamp) {
    $timestampStr = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $prefix = "$timestampStr $prefix"
}

if ($IncludePid) {
    $prefix = "$prefix[$PID]"
}

# Output the log message
Write-ColorizedOutput -Level $Level -Message $messageText -Prefix $prefix

# Log to system log
Write-SystemLog -Level $Level -Message $messageText -Tag $Tag