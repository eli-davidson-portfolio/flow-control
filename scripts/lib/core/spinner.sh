#!/bin/bash

# Spinner Library
# Provides animated spinners for long-running operations

# Spinner styles
declare SPINNER_STYLE_DEFAULT=( "|" "/" "-" "\\" )
declare SPINNER_STYLE_DOTS=( "⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏" )
declare SPINNER_STYLE_ARROWS=( "←" "↖" "↑" "↗" "→" "↘" "↓" "↙" )

# Default settings
SPINNER_STYLE=("${SPINNER_STYLE_DEFAULT[@]}")
SPINNER_DELAY=0.1
SPINNER_ENABLED=true

# Internal state
_SPINNER_PID=""
_SPINNER_MESSAGE=""
_SPINNER_RUNNING=false

# Rest of the existing code...