#!/bin/bash
# Healthy once Android reports sys.boot_completed=1 over the in-container adb.
set -euo pipefail
adb -s emulator-5554 shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' | grep -q '^1$'
