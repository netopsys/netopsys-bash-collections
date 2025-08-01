#!/bin/bash
#
# ==============================================================================
# Script Name : usb-control.sh
# Description : Manage USB Access with USBGuard.
# Author      : netopsys
# License     : GPL-3.0 
# ============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Banner
# ------------------------------------------------------------------------------
print_banner() {
  echo -e "${CYAN}"
  echo "==========================================================="
  echo -e "🛡️  ${CYAN}NETOPSYS${RESET} - Bash Collections          "
  echo "                                                           "
  echo "   Script : Manage USB Access with USBGuard                "
  echo "   Author : netopsys (https://github.com/netopsys)         "
  echo "==========================================================="
  echo -e "${RESET}"
}

# ------------------------------------------------------------------------------
# Logging Helpers
# ------------------------------------------------------------------------------
readonly RED="\033[0;31m"
readonly GREEN="\033[0;32m"
readonly YELLOW="\033[0;33m"
readonly CYAN="\033[0;36m"
readonly RESET="\033[0m"
 
log_info()  { echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] ${CYAN}[INFO]${RESET} $*"; }
log_ok()    { echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] ${GREEN}[OK]${RESET} $*"; }
log_warn()  { echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] ${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] ${RED}[ERROR]${RESET} $*"; }

# ------------------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------------------

check_root() {
  if [[ "$EUID" -ne 0 ]]; then
    log_error "Please run this script as root."
    exit 1
  fi
}

check_dependencies() {
  local dependencies=(usbguard)
  local missing=()

  log_info "Checking dependencies..."

  for cmd in "${dependencies[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
      missing+=("$cmd")
    fi
  done

  if (( ${#missing[@]} > 0 )); then
    log_error "Missing packages: ${missing[*]}"
    echo -e "\nTo install them:\n  sudo apt install ${missing[*]}"
    exit 1
  else
    log_ok "All dependencies are met."
  fi
}

list_devices() {
  log_info "List devices"
  if [[ "$OUTPUT_JSON" == true ]]; then
    usbguard list-devices | awk '
      BEGIN {
        print "["
      }
      {
        gsub(/^ *- /, "")
        id = $1
        $1 = ""
        printf "  {\"id\": \"%s\", \"info\": \"%s\"},\n", id, substr($0, 2)
      }
      END {
        print "]"
      }
    '
  else
    usbguard list-devices
  fi

  if [[ "$LIST" == true ]]; then
    log_info "Exit..."
    exit 0
  fi
}

select_action() {
  echo
  read -rp "➤ Action: Allow or Block device? (a/b): " CHOICE

  if [[ "$CHOICE" == "a" && "$CHOICE" == "b" ]]; then
    log_error "Invalid choice"; exit 1; 
  fi

  read -rp "➤ Select device ID: " DEVICE_ID
  read -rp "➤ Confirm $([[ $CHOICE == "a" ]] && echo allow || echo block) device ID=$DEVICE_ID? [Y/n] : " CONFIRM
  CONFIRM="${CONFIRM:-y}"

  if [[ "$CONFIRM" != "y" ]]; then
    log_warn "Operation aborted by user."
    exit 0
  fi

  if [[ "$CHOICE" == "a" ]]; then
    usbguard allow-device "$DEVICE_ID" 
    log_ok "Status: $(usbguard list-devices | grep "$DEVICE_ID:")"
  else
    usbguard block-device "$DEVICE_ID" 
    log_ok "Status: $(usbguard list-devices | grep "$DEVICE_ID:")"
  fi

  if [[ "$LIST" != true ]]; then
    log_info "Exit..."
    exit 0
  fi

}

# Print usage help.
print_usage() {
  cat << EOF
Usage:
 $(basename "$0") [options]

Options:
  -h, --help        Show this help message
  --list            Only list USB devices, take no action

Examples:
  $(basename "$0")             Interactively allow/block USB devices
  $(basename "$0") --list      Just list USB devices 

EOF
  exit 0
}

# ------------------------------------------------------------------------------
# Main script logic
# ------------------------------------------------------------------------------
main() {
  OUTPUT_JSON=true
  LIST=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) print_usage ;;
      --list) LIST=true ;;
    esac
    shift
  done

  print_banner  
  check_root
  check_dependencies
  list_devices 
  select_action 
}

main "$@"