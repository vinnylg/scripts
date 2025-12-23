#!/bin/bash
# ============================
# vscreen Integration Contract: Exhaustion
# ============================
# Scope:  Robustness and System Integration
# Target: bin/vscreen (Local artifact)
# Output: logs/integration/vscreen/
# ============================

set -o pipefail

# 1. Dynamic Path Resolution
# Locates the script directory to find the project root regardless of CWD
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"

# 2. Artifact Definition
# We do not rely on global PATH. We test the built binary explicitly.
VSCREEN_BIN="$PROJECT_ROOT/bin/vscreen"

# Defensive Validation
if [[ ! -x "$VSCREEN_BIN" ]]; then
    echo "❌ Error: Binary not found or not executable at: $VSCREEN_BIN"
    echo "   Please run the build process or check permissions."
    exit 1
fi

# 3. Log Configuration
LOG_DIR="$PROJECT_ROOT/logs/integration/vscreen"
mkdir -p "$LOG_DIR"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOGFILE="$LOG_DIR/exhaust_${TIMESTAMP}.log"
LATEST_LINK="$LOG_DIR/exhaust_latest.log"

# Updates the symlink to point to the most recent run
ln -sf "$(basename "$LOGFILE")" "$LATEST_LINK"

echo "🏁 Starting exhaustion test..."
echo "📍 Target: $VSCREEN_BIN"
echo "📝 Log: $LOGFILE"

# ============================
# Test Logic Begins
# ============================
TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================
# Logging Functions
# ============================
log() {
  echo -e "$*" | tee -a "$LOGFILE"
}

log_section() {
  local msg="$1"
  log "\n${CYAN}========================================${NC}"
  log "${CYAN}$msg${NC}"
  log "${CYAN}========================================${NC}"
}

log_test() {
  ((TEST_COUNT++))
  log "\n${BLUE}[TEST $TEST_COUNT]${NC} $*"
}

log_pass() {
  ((PASS_COUNT++))
  log "${GREEN}✓ PASS${NC}: $*"
}

log_fail() {
  ((FAIL_COUNT++))
  log "${RED}✗ FAIL${NC}: $*"
}

log_info() {
  log "${YELLOW}ℹ INFO${NC}: $*"
}

log_cmd() {
  log "  $ $*"
}

# ============================
# Test Utilities
# ============================
run_test() {
  local description="$1"
  shift
  local cmd="$*"
  
  log_test "$description"
  log_cmd "$cmd"
  
  local output
  local exit_code
  
  output=$($cmd 2>&1)
  exit_code=$?
  
  if [[ -n "$output" ]]; then
    echo "$output" | while IFS= read -r line; do
      log "    $line"
    done
  fi
  
  echo "$exit_code"
}

expect_success() {
  local description="$1"
  shift
  local exit_code
  
  exit_code=$(run_test "$description" "$@")
  
  if [[ $exit_code -eq 0 ]]; then
    log_pass "$description"
    return 0
  else
    log_fail "$description (exit code: $exit_code)"
    return 1
  fi
}

expect_failure() {
  local description="$1"
  shift
  local exit_code
  
  exit_code=$(run_test "$description" "$@")
  
  if [[ $exit_code -ne 0 ]]; then
    log_pass "$description (correctly failed)"
    return 0
  else
    log_fail "$description (should have failed but didn't)"
    return 1
  fi
}

get_active_virtuals() {
  xrandr 2>/dev/null | awk '/^VIRTUAL[0-9]+ connected/{print $1}' | wc -l
}

get_virtual_list() {
  xrandr 2>/dev/null | awk '/^VIRTUAL[0-9]+ connected/{print $1}'
}

wait_for_xrandr() {
  sleep 0.5
}

# ============================
# Test Setup
# ============================
log_section "TEST SUITE INITIALIZATION"
log "Starting vscreen comprehensive test suite"
log "Date: $(date)"
log "Logfile: $LOGFILE"
log "vscreen location: $VSCREEN"

# Check if vscreen exists
if [[ ! -f "$VSCREEN" ]]; then
  log_fail "vscreen script not found at $VSCREEN"
  exit 1
fi

# Make it executable
chmod +x "$VSCREEN"

# Clear any existing virtual displays
log_info "Cleaning up any existing virtual displays"
$VSCREEN --off-all &>> "$LOGFILE"
$VSCREEN --purge-modes &>> "$LOGFILE"

# ============================
# TEST 1: Help and Version
# ============================
log_section "TEST SECTION 1: Basic Commands"

expect_success "Display help" "$VSCREEN" --help
expect_success "Display version" "$VSCREEN" --version
expect_success "List all virtual outputs" "$VSCREEN" --list all
expect_success "List active virtual outputs" "$VSCREEN" --list active
expect_success "List free virtual outputs" "$VSCREEN" --list free

# ============================
# TEST 2: Invalid Arguments
# ============================
log_section "TEST SECTION 2: Invalid Arguments"

expect_failure "Invalid resolution ID" "$VSCREEN" -r 99
expect_failure "Invalid resolution name" "$VSCREEN" -r NOTEXIST
expect_failure "Invalid size format" "$VSCREEN" --size 1920
expect_failure "Invalid orientation" "$VSCREEN" --output 1 -r 1 -o INVALID
expect_failure "Invalid position format" "$VSCREEN" --output 1 -r 1 --pos 1920
expect_failure "Missing resolution argument" "$VSCREEN" -r
expect_failure "Missing size argument" "$VSCREEN" --size
expect_failure "Both -r and --size" "$VSCREEN" --output 1 -r 1 --size 1920x1080
expect_failure "Output without resolution" "$VSCREEN" --output 1
expect_failure "Invalid output number" "$VSCREEN" --output ABC -r 1

# ============================
# TEST 3: Predefined Resolutions
# ============================
log_section "TEST SECTION 3: Predefined Resolutions"

log_info "Testing all predefined resolutions by ID"
for id in 1 2 3 4 5 6; do
  expect_success "Activate VIRTUAL$id with resolution ID $id" "$VSCREEN" --output "$id" -r "$id"
  wait_for_xrandr
done

log_info "Current active displays:"
get_virtual_list | tee -a "$LOGFILE"

log_info "Deactivating all displays"
expect_success "Deactivate all displays" "$VSCREEN" --off-all
wait_for_xrandr

log_info "Testing predefined resolutions by name"
declare -A res_names=(
  [1]="FHD"
  [2]="HD+"
  [3]="HD"
  [4]="HD10"
  [5]="HD+10"
  [6]="SD"
)

for id in 1 2 3; do
  name="${res_names[$id]}"
  expect_success "Activate VIRTUAL$id with resolution name $name" "$VSCREEN" --output "$id" -r "$name"
  wait_for_xrandr
done

expect_success "Deactivate all displays" "$VSCREEN" --off-all
wait_for_xrandr

# ============================
# TEST 4: Custom Resolutions
# ============================
log_section "TEST SECTION 4: Custom Resolutions"

declare -a custom_resolutions=(
  "1920x1080"
  "2560x1440"
  "3840x2160"
  "1024x768"
  "800x600"
  "1680x1050"
  "2048x1152"
)

for i in "${!custom_resolutions[@]}"; do
  res="${custom_resolutions[$i]}"
  output=$((i + 1))
  expect_success "Activate VIRTUAL$output with custom size $res" "$VSCREEN" --output "$output" --size "$res"
  wait_for_xrandr
done

expect_success "Deactivate all displays" "$VSCREEN" --off-all
wait_for_xrandr

# ============================
# TEST 5: Orientations
# ============================
log_section "TEST SECTION 5: Orientations"

declare -a orientations=(
  "normal:L"
  "right:PR"
  "left:PL"
  "inverted:LF"
)

for orient in "${orientations[@]}"; do
  IFS=':' read -r mode alias <<< "$orient"
  
  expect_success "Activate with orientation $mode" "$VSCREEN" --output 1 -r 1 -o "$mode"
  wait_for_xrandr
  expect_success "Deactivate" "$VSCREEN" --off 1
  wait_for_xrandr
  
  expect_success "Activate with orientation alias $alias" "$VSCREEN" --output 1 -r 1 -o "$alias"
  wait_for_xrandr
  expect_success "Deactivate" "$VSCREEN" --off 1
  wait_for_xrandr
done

# ============================
# TEST 6: Change Command
# ============================
log_section "TEST SECTION 6: Change Command"

expect_success "Activate VIRTUAL1 with FHD" "$VSCREEN" --output 1 -r FHD
wait_for_xrandr

expect_success "Change VIRTUAL1 to HD" "$VSCREEN" --change 1 -r HD
wait_for_xrandr

expect_success "Change VIRTUAL1 orientation to right" "$VSCREEN" --change 1 -o right
wait_for_xrandr

expect_success "Change VIRTUAL1 orientation back to normal" "$VSCREEN" --change 1 -o normal
wait_for_xrandr

expect_failure "Change inactive VIRTUAL2" "$VSCREEN" --change 2 -r 2

expect_success "Deactivate VIRTUAL1" "$VSCREEN" --off 1
wait_for_xrandr

# ============================
# TEST 7: Positioning
# ============================
log_section "TEST SECTION 7: Positioning"

# Get primary output
PRIMARY=$(xrandr | awk '/primary|connected/ && /^[A-Z]/ {print $1; exit}')
log_info "Primary output detected: ${PRIMARY:-none}"

if [[ -n "$PRIMARY" ]]; then
  expect_success "Position right of $PRIMARY" "$VSCREEN" --output 1 -r 1 --right-of "$PRIMARY"
  wait_for_xrandr
  expect_success "Deactivate" "$VSCREEN" --off 1
  wait_for_xrandr
  
  expect_success "Position left of $PRIMARY" "$VSCREEN" --output 1 -r 1 --left-of "$PRIMARY"
  wait_for_xrandr
  expect_success "Deactivate" "$VSCREEN" --off 1
  wait_for_xrandr
  
  expect_success "Position above $PRIMARY" "$VSCREEN" --output 1 -r 1 --above "$PRIMARY"
  wait_for_xrandr
  expect_success "Deactivate" "$VSCREEN" --off 1
  wait_for_xrandr
  
  expect_success "Position below $PRIMARY" "$VSCREEN" --output 1 -r 1 --below "$PRIMARY"
  wait_for_xrandr
  expect_success "Deactivate" "$VSCREEN" --off 1
  wait_for_xrandr
fi

expect_success "Absolute position 1920x0" "$VSCREEN" --output 1 -r 1 --pos 1920x0
wait_for_xrandr
expect_success "Deactivate" "$VSCREEN" --off 1
wait_for_xrandr

expect_success "Absolute position 0x1080" "$VSCREEN" --output 1 -r 1 --pos 0x1080
wait_for_xrandr
expect_success "Deactivate" "$VSCREEN" --off 1
wait_for_xrandr

# Test auto-positioning with multiple displays
expect_success "Activate VIRTUAL1" "$VSCREEN" --output 1 -r 1
wait_for_xrandr
expect_success "Activate VIRTUAL2 (auto-position)" "$VSCREEN" --output 2 -r 2
wait_for_xrandr
expect_success "Activate VIRTUAL3 (auto-position)" "$VSCREEN" --output 3 -r 3
wait_for_xrandr

log_info "Current display layout:"
xrandr --listmonitors | tee -a "$LOGFILE"

expect_success "Deactivate all" "$VSCREEN" --off-all
wait_for_xrandr

# ============================
# TEST 8: Stress Test - Many Displays
# ============================
log_section "TEST SECTION 8: Stress Test - Multiple Displays"

log_info "Attempting to activate 20 virtual displays"

STRESS_SUCCESS=0
STRESS_FAIL=0

for i in {1..20}; do
  log_test "Activate VIRTUAL$i"
  if $VSCREEN --output "$i" -r $((i % 6 + 1)) --debug 2>&1 | tee -a "$LOGFILE"; then
    ((STRESS_SUCCESS++))
    log_pass "VIRTUAL$i activated"
  else
    ((STRESS_FAIL++))
    log_fail "VIRTUAL$i failed to activate"
  fi
  wait_for_xrandr
done

log_info "Stress test results: $STRESS_SUCCESS successful, $STRESS_FAIL failed"
log_info "Active displays:"
ACTIVE_COUNT=$(get_active_virtuals)
log_info "Total active displays: $ACTIVE_COUNT"
get_virtual_list | tee -a "$LOGFILE"

# ============================
# TEST 9: Extreme Resolutions
# ============================
log_section "TEST SECTION 9: Extreme Resolutions"

# First clear existing displays
expect_success "Clear displays before extreme test" "$VSCREEN" --off-all
wait_for_xrandr

declare -a extreme_resolutions=(
  "640x480:Small"
  "7680x4320:8K"
  "320x240:Tiny"
  "5120x2880:5K"
  "11520x6480:12K"
  "15360x8640:16K"
)

EXTREME_SUCCESS=0
EXTREME_FAIL=0

for i in "${!extreme_resolutions[@]}"; do
  IFS=':' read -r res desc <<< "${extreme_resolutions[$i]}"
  output=$((i + 1))
  
  log_test "Test extreme resolution: $desc ($res)"
  if $VSCREEN --output "$output" --size "$res" --debug 2>&1 | tee -a "$LOGFILE"; then
    ((EXTREME_SUCCESS++))
    log_pass "Extreme resolution $desc succeeded"
    wait_for_xrandr
  else
    ((EXTREME_FAIL++))
    log_fail "Extreme resolution $desc failed"
  fi
done

log_info "Extreme resolution test: $EXTREME_SUCCESS successful, $EXTREME_FAIL failed"

# ============================
# TEST 10: Rapid Operations
# ============================
log_section "TEST SECTION 10: Rapid Operations"

log_info "Testing rapid activation and deactivation"

for i in {1..10}; do
  log_test "Rapid cycle $i: Activate and deactivate VIRTUAL1"
  $VSCREEN --output 1 -r 1 &>> "$LOGFILE"
  sleep 0.2
  $VSCREEN --off 1 &>> "$LOGFILE"
  sleep 0.2
done

log_pass "Rapid operations completed"

# ============================
# TEST 11: Individual Off Commands
# ============================
log_section "TEST SECTION 11: Individual Deactivation"

log_info "Activating 5 displays"
for i in {1..5}; do
  expect_success "Activate VIRTUAL$i" "$VSCREEN" --output "$i" -r "$i"
  wait_for_xrandr
done

log_info "Deactivating displays one by one"
for i in {1..5}; do
  expect_success "Deactivate VIRTUAL$i" "$VSCREEN" --off "$i"
  wait_for_xrandr
  REMAINING=$(get_active_virtuals)
  log_info "Remaining active displays: $REMAINING"
done

# ============================
# TEST 12: Edge Cases
# ============================
log_section "TEST SECTION 12: Edge Cases"

expect_failure "Deactivate non-existent VIRTUAL99" "$VSCREEN" --off 99
expect_failure "Change non-existent VIRTUAL99" "$VSCREEN" --change 99 -r 1
expect_failure "Activate already active display" "$VSCREEN" --output 1 -r 1 && "$VSCREEN" --output 1 -r 2

# Clear for next test
$VSCREEN --off-all &>> "$LOGFILE"
wait_for_xrandr

expect_success "No-auto positioning" "$VSCREEN" --output 1 -r 1 --no-auto
wait_for_xrandr
expect_success "Deactivate" "$VSCREEN" --off 1
wait_for_xrandr

# ============================
# TEST 13: Debug and Dry-Run
# ============================
log_section "TEST SECTION 13: Debug and Dry-Run Modes"

expect_success "Dry-run mode" "$VSCREEN" --output 1 -r 1 --dry-run
expect_success "Debug mode" "$VSCREEN" --output 1 -r 1 --debug
wait_for_xrandr
expect_success "Deactivate (debug)" "$VSCREEN" --off 1 --debug
wait_for_xrandr

# ============================
# TEST 14: Complex Scenarios
# ============================
log_section "TEST SECTION 14: Complex Scenarios"

log_info "Scenario: Multiple displays with different configs"

expect_success "VIRTUAL1: FHD landscape" "$VSCREEN" --output 1 -r FHD -o normal
wait_for_xrandr

expect_success "VIRTUAL2: HD portrait right" "$VSCREEN" --output 2 -r HD -o right
wait_for_xrandr

expect_success "VIRTUAL3: Custom 2560x1440" "$VSCREEN" --output 3 --size 2560x1440 -o normal
wait_for_xrandr

log_info "Current complex setup:"
xrandr --listmonitors | tee -a "$LOGFILE"

expect_success "Change VIRTUAL2 to landscape" "$VSCREEN" --change 2 -o normal
wait_for_xrandr

expect_success "Change VIRTUAL1 to HD+" "$VSCREEN" --change 1 -r HD+
wait_for_xrandr

log_info "After changes:"
xrandr --listmonitors | tee -a "$LOGFILE"

# ============================
# FINAL CLEANUP
# ============================
log_section "FINAL CLEANUP"

log_info "Deactivating all virtual displays"
expect_success "Off all displays" "$VSCREEN" --off-all

log_info "Purging all custom modes"
expect_success "Purge modes" "$VSCREEN" --purge-modes

log_info "Final state verification"
FINAL_ACTIVE=$(get_active_virtuals)
log_info "Active virtual displays after cleanup: $FINAL_ACTIVE"

if [[ $FINAL_ACTIVE -eq 0 ]]; then
  log_pass "All displays successfully deactivated"
else
  log_fail "Some displays remain active: $FINAL_ACTIVE"
  get_virtual_list | tee -a "$LOGFILE"
fi

# ============================
# TEST SUMMARY
# ============================
log_section "TEST SUMMARY"

log ""
log "Total tests run: $TEST_COUNT"
log "${GREEN}Passed: $PASS_COUNT${NC}"
log "${RED}Failed: $FAIL_COUNT${NC}"

if [[ $FAIL_COUNT -eq 0 ]]; then
  log ""
  log "${GREEN}════════════════════════════════════════${NC}"
  log "${GREEN}   ALL TESTS PASSED SUCCESSFULLY! ✓${NC}"
  log "${GREEN}════════════════════════════════════════${NC}"
  exit 0
else
  PASS_RATE=$((PASS_COUNT * 100 / TEST_COUNT))
  log ""
  log "${YELLOW}════════════════════════════════════════${NC}"
  log "${YELLOW}   SOME TESTS FAILED${NC}"
  log "${YELLOW}   Pass rate: ${PASS_RATE}%${NC}"
  log "${YELLOW}════════════════════════════════════════${NC}"
  exit 1
fi
