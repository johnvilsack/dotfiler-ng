#!/usr/bin/env bash

# Demo script showing clog usage

echo "=== CLOG DEMO ==="
echo ""

echo "Basic usage:"
./clog INFO "Application started successfully"
./clog WARNING "Disk space is low" 
./clog ERROR "Failed to connect to database"
./clog SUCCESS "Backup completed"
./clog DEBUG "Debug information here"
./clog TRACE "Detailed trace data"

echo ""
echo "With timestamp:"
./clog --timestamp INFO "Timestamped message"

echo ""
echo "With PID:"
./clog --pid WARNING "Message with process ID"

echo ""
echo "JSON format:"
./clog --json INFO "JSON formatted message"

echo ""
echo "Combined options:"
./clog --timestamp --pid SUCCESS "All options enabled"

echo ""
echo "Custom tag (check syslog):"
./clog --tag "my-app" INFO "Custom tagged message"

echo ""
echo "=== END DEMO ==="