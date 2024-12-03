#!/usr/bin/env bash

# Test framework configuration

# Test levels and their descriptions
declare -A TEST_LEVELS=(
    ["L0"]="Visual Tests"
    ["L1"]="Core Platform Tests"
    ["L2"]="Environment Tests"
    ["L3"]="Operation Tests"
    ["L5"]="Application Tests"
)

# Test timeouts (in seconds)
declare -A TEST_TIMEOUTS=(
    ["L0"]=30
    ["L1"]=60
    ["L2"]=120
    ["L3"]=180
    ["L5"]=300
)

# Test dependencies
declare -A TEST_DEPENDENCIES=(
    ["L0"]=""
    ["L1"]="docker"
    ["L2"]="docker go"
    ["L3"]="docker go curl"
    ["L5"]="docker go curl jq"
)

# Test environment variables
export TEST_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export TEST_FRAMEWORK_DIR="$TEST_ROOT_DIR/framework"
export TEST_DATA_DIR="$TEST_ROOT_DIR/data"
export TEST_LOG_DIR="$TEST_ROOT_DIR/logs"

# Test flags
export FAIL_FAST=${FAIL_FAST:-true}
export DEBUG=${DEBUG:-false}
export VERBOSE=${VERBOSE:-false}

# Color configuration
export COLOR_ENABLED=${COLOR_ENABLED:-true}
export NO_COLOR=${NO_COLOR:-false} 