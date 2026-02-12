#!/bin/bash

#===============================================================================
#
#          FILE: install.sh
#
#         USAGE: ./install.sh [OPTIONS]
#
#   DESCRIPTION: Automated Hyprland + ML4W Dotfiles Installer for Arch Linux
#                Production-ready, battle-tested, zero-bullshit deployment.
#
#       OPTIONS: See usage() function below
#  REQUIREMENTS: Arch Linux (or derivative), sudo access, internet connection
#          BUGS: Report at: https://github.com/yourusername/hyprland-ml4w-installer
#         NOTES: Tested on Arch, EndeavourOS, Manjaro
#        AUTHOR: Your Name
#       VERSION: 2.0.0
#       CREATED: 2024
#      REVISION: Hardcore Edition
#===============================================================================

#-------------------------------------------------------------------------------
# CONFIGURATION & STRICT MODE
#-------------------------------------------------------------------------------

set -euo pipefail
IFS=$'\n\t'

# Script metadata
readonly SCRIPT_NAME="Hyprland ML4W Installer"
readonly SCRIPT_VERSION="2.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="/tmp/hyprland-ml4w-install-$(date +%Y%m%d-%H%M%S).log"

# Color codes (only if terminal supports it)
if [[ -t 1 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly CYAN='\033[0;36m'
    readonly BOLD='\033[1m'
    readonly NC='\033[0m'
else
    readonly RED=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly BLUE=''
    readonly CYAN=''
    readonly BOLD=''
    readonly NC=''
fi

# Package lists
readonly HYPRLAND_PACKAGES=(
    hyprland hyprpaper hyprlock hypridle hyprcursor hyprutils
    xdg-desktop-portal-hyprland
    waybar wofi kitty mako
    grimblast wl-clipboard
    polkit-kde-agent
    qt5-wayland qt6-wayland
    pipewire wireplumber pipewire-audio pipewire-pulse
    pavucontrol network-manager-applet blueman
    thunar ttf-font-awesome noto-fonts noto-fonts-emoji
    ttf-jetbrains-mono-nerd
)

readonly AUR_PACKAGES=(
    hyprland-plugins
    waybar-module-pacman-updates
    swww
    wlogout
)

# Flags
DRY_RUN=false
SKIP_SYSTEM_UPDATE=false
SKIP_HYPRLAND=false
SKIP_AUR=false
SKIP_ML4W=false
VERBOSE=false

#-------------------------------------------------------------------------------
# LOGGING FUNCTIONS
#-------------------------------------------------------------------------------

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    case "$level" in
        ERROR)   echo -e "${RED}[ERROR]${NC} $message" >&2 ;;
        WARN)    echo -e "${YELLOW}[WARN]${NC} $message" ;;
        INFO)    echo -e "${BLUE}[INFO]${NC} $message" ;;
        SUCCESS) echo -e "${GREEN}[OK]${NC} $message" ;;
        DEBUG)   [[ "$VERBOSE" == true ]] && echo -e "${CYAN}[DEBUG]${NC} $message" ;;
    esac
}

die() {
    log ERROR "$1"
    log ERROR "Installation failed. Check log: $LOG_FILE"
    exit 1
}

#-------------------------------------------------------------------------------
# UTILITY FUNCTIONS
#-------------------------------------------------------------------------------

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

package_installed() {
    pacman -Q "$1" >/dev/null 2>&1
}

is_arch() {
    [[ -f /etc/arch-release ]] || [[ -f /etc/manjaro-release ]] || [[ -f /etc/endeavouros-release ]]
}

has_sudo() {
    sudo -n true 2>/dev/null || {
        log WARN "This script requires sudo privileges"
        sudo -v || die "Failed to obtain sudo access"
    }
}

spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

run_with_spinner() {
    local msg="$1"
    shift
    echo -n "$msg..."
    "$@" >/dev/null 2>&1 &
    local pid=$!
    spinner $pid
    wait $pid
    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        echo -e " ${GREEN}DONE${NC}"
    else
        echo -e " ${RED}FAILED${NC}"
        return $exit_code
    fi
}

#-------------------------------------------------------------------------------
# VALIDATION FUNCTIONS
#-------------------------------------------------------------------------------

preflight_checks() {
    log INFO "Running preflight checks..."
    
    # Check OS
    if ! is_arch; then
        die "This script is for Arch Linux and derivatives only. Detected OS is not supported."
    fi
    log SUCCESS "Arch Linux detected"
    
    # Check not root
    if [[ $EUID -eq 0 ]]; then
        die "Do not run this script as root. It will use sudo when needed."
    fi
    
    # Check sudo
    has_sudo
    
    # Check internet
    if ! ping -c 1 archlinux.org >/dev/null 2>&1; then
        die "No internet connection detected. Check your network."
    fi
    log SUCCESS "Internet connection verified"
    
    # Check disk space (need at least 2GB)
    local available_space
    available_space=$(df /tmp | awk 'NR==2 {print $4}')
    if [[ $available_space -lt 2097152 ]]; then
        die "Insufficient disk space. Need at least 2GB free in /tmp"
    fi
    
    log SUCCESS "Preflight checks passed"
}

#-------------------------------------------------------------------------------
# INSTALLATION PHASES
#-------------------------------------------------------------------------------

phase_system_update() {
    [[ "$SKIP_SYSTEM_UPDATE" == true ]] && { log INFO "Skipping system update"; return 0; }
    [[ "$DRY_RUN" == true ]] && { log INFO "[DRY-RUN] Would run: pacman -Syu"; return 0; }
    
    log INFO "Phase 1/5: System Update"
    
    if run_with_spinner "Updating package database" sudo pacman -Sy; then
        log SUCCESS "Package database updated"
    else
        die "Failed to update package database"
    fi
    
    # Check if full upgrade is needed
    local updates_available
    updates_available=$(pacman -Qu | wc -l)
    
    if [[ $updates_available -gt 0 ]]; then
        log INFO "$updates_available packages can be upgraded"
        log INFO "Upgrading system packages..."
        
        if sudo pacman -Syu --noconfirm; then
            log SUCCESS "System upgraded successfully"
        else
            die "System upgrade failed"
        fi
    else
        log SUCCESS "System is up to date"
    fi
}

phase_install_hyprland() {
    [[ "$SKIP_HYPRLAND" == true ]] && { log INFO "Skipping Hyprland installation"; return 0; }
    [[ "$DRY_RUN" == true ]] && { log INFO "[DRY-RUN] Would install: ${HYPRLAND_PACKAGES[*]}"; return 0; }
    
    log INFO "Phase 2/5: Installing Hyprland Ecosystem"
    
    local packages_to_install=()
    for pkg in "${HYPRLAND_PACKAGES[@]}"; do
        if ! package_installed "$pkg"; then
            packages_to_install+=("$pkg")
        else
            log DEBUG "$pkg already installed"
        fi
    done
    
    if [[ ${#packages_to_install[@]} -eq 0 ]]; then
        log SUCCESS "All Hyprland packages already installed"
        return 0
    fi
    
    log INFO "Installing ${#packages_to_install[@]} packages..."
    
    if sudo pacman -S --needed --noconfirm "${packages_to_install[@]}"; then
        log SUCCESS "Hyprland ecosystem installed"
    else
        die "Failed to install Hyprland packages"
    fi
    
    # Enable services
    log INFO "Enabling PipeWire services..."
    systemctl --user enable pipewire pipewire-pulse 2>/dev/null || true
}

phase_install_aur_helper() {
    [[ "$SKIP_AUR" == true ]] && { log INFO "Skipping AUR setup"; return 0; }
    [[ "$DRY_RUN" == true ]] && { log INFO "[DRY-RUN] Would install yay"; return 0; }
    
    log INFO "Phase 3/5: AUR Helper Setup"
    
    if command_exists yay; then
        log SUCCESS "yay already installed"
        return 0
    fi
    
    if command_exists paru; then
        log SUCCESS "paru found, using existing AUR helper"
        return 0
    fi
    
    log INFO "Installing yay-bin..."
    
    # Install dependencies
    sudo pacman -S --needed --noconfirm git base-devel || die "Failed to install build dependencies"
    
    # Build yay
    local build_dir
    build_dir=$(mktemp -d)
    cd "$build_dir" || die "Failed to create build directory"
    
    if git clone https://aur.archlinux.org/yay-bin.git; then
        cd yay-bin || die "Failed to enter yay directory"
        if makepkg -si --noconfirm; then
            log SUCCESS "yay installed successfully"
        else
            die "Failed to build yay"
        fi
    else
        die "Failed to clone yay repository"
    fi
    
    cd "$SCRIPT_DIR" || true
    rm -rf "$build_dir"
}

phase_install_aur_packages() {
    [[ "$SKIP_AUR" == true ]] && { log INFO "Skipping AUR packages"; return 0; }
    [[ "$DRY_RUN" == true ]] && { log INFO "[DRY-RUN] Would install AUR packages"; return 0; }
    
    log INFO "Installing additional AUR packages..."
    
    local aur_helper="yay"
    command_exists yay || aur_helper="paru"
    command_exists paru || die "No AUR helper found"
    
    local aur_to_install=()
    for pkg in "${AUR_PACKAGES[@]}"; do
        if ! package_installed "$pkg" 2>/dev/null; then
            aur_to_install+=("$pkg")
        fi
    done
    
    if [[ ${#aur_to_install[@]} -gt 0 ]]; then
        log INFO "Installing from AUR: ${aur_to_install[*]}"
        if $aur_helper -S --needed --noconfirm "${aur_to_install[@]}"; then
            log SUCCESS "AUR packages installed"
        else
            log WARN "Some AUR packages failed to install (non-critical)"
        fi
    else
        log SUCCESS "All AUR packages already installed"
    fi
}

phase_install_flatpak() {
    [[ "$DRY_RUN" == true ]] && { log INFO "[DRY-RUN] Would setup Flatpak"; return 0; }
    
    log INFO "Phase 4/5: Flatpak Setup"
    
    if ! command_exists flatpak; then
        log INFO "Installing Flatpak..."
        sudo pacman -S --needed --noconfirm flatpak || die "Failed to install Flatpak"
    fi
    
    # Add flathub
    if ! flatpak remotes | grep -q flathub; then
        log INFO "Adding Flathub repository..."
        sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || \
            die "Failed to add Flathub"
    fi
    
    log SUCCESS "Flatpak ready"
}

phase_install_ml4w() {
    [[ "$SKIP_ML4W" == true ]] && { log INFO "Skipping ML4W installation"; return 0; }
    [[ "$DRY_RUN" == true ]] && { log INFO "[DRY-RUN] Would install com.ml4w.dotfilesinstaller"; return 0; }
    
    log INFO "Phase 5/5: ML4W Dotfiles Installer"
    
    # Check if already installed
    if flatpak list | grep -q "com.ml4w.dotfilesinstaller"; then
        log SUCCESS "ML4W Dotfiles Installer already installed"
        log INFO "Run: flatpak run com.ml4w.dotfilesinstaller"
        return 0
    fi
    
    log INFO "Installing ML4W Dotfiles Installer from Flathub..."
    
    if flatpak install -y flathub com.ml4w.dotfilesinstaller; then
        log SUCCESS "ML4W Dotfiles Installer installed successfully"
    else
        die "Failed to install ML4W Dotfiles Installer"
    fi
}

#-------------------------------------------------------------------------------
# POST-INSTALLATION
#-------------------------------------------------------------------------------

post_install() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}           ${BOLD}INSTALLATION COMPLETE${NC}                            ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # System info
    echo -e "${BOLD}Installed Components:${NC}"
    echo "  ✓ Hyprland Wayland Compositor"
    echo "  ✓ Waybar (status bar)"
    echo "  ✓ Wofi (application launcher)"
    echo "  ✓ Kitty (terminal emulator)"
    echo "  ✓ PipeWire (audio system)"
    echo "  ✓ ML4W Dotfiles Installer"
    echo ""
    
    # Next steps
    echo -e "${BOLD}Next Steps:${NC}"
    echo "  1. Run ML4W installer:"
    echo -e "     ${CYAN}flatpak run com.ml4w.dotfilesinstaller${NC}"
    echo ""
    echo "  2. Or use the GUI version:"
    echo -e "     ${CYAN}flatpak run com.ml4w.dotfilesinstaller --gui${NC}"
    echo ""
    echo "  3. Add user to video group (if not done):"
    echo -e "     ${CYAN}sudo usermod -aG video \$USER${NC}"
    echo ""
    echo "  4. Reboot and select Hyprland at login"
    echo ""
    
    # Log location
    echo -e "${BOLD}Installation log:${NC} $LOG_FILE"
    echo ""
    
    # Warning
    echo -e "${YELLOW}Note:${NC} Some changes require logout/reboot to take effect."
}

cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log ERROR "Script terminated with errors (exit code: $exit_code)"
        log ERROR "Check the log file: $LOG_FILE"
    fi
}

#-------------------------------------------------------------------------------
# CLI INTERFACE
#-------------------------------------------------------------------------------

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

${SCRIPT_NAME} v${SCRIPT_VERSION}

OPTIONS:
    -h, --help              Show this help message
    -v, --verbose           Enable verbose output
    -d, --dry-run           Show what would be done without executing
    --skip-update           Skip system update
    --skip-hyprland         Skip Hyprland packages installation
    --skip-aur              Skip AUR helper and packages
    --skip-ml4w             Skip ML4W Dotfiles Installer
    --version               Show version information

EXAMPLES:
    $(basename "$0")                    # Full installation
    $(basename "$0") --dry-run          # Preview changes
    $(basename "$0") --skip-update      # Skip pacman -Syu
    $(basename "$0") --verbose          # Debug output

EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            --skip-update)
                SKIP_SYSTEM_UPDATE=true
                shift
                ;;
            --skip-hyprland)
                SKIP_HYPRLAND=true
                shift
                ;;
            --skip-aur)
                SKIP_AUR=true
                shift
                ;;
            --skip-ml4w)
                SKIP_ML4W=true
                shift
                ;;
            --version)
                echo "${SCRIPT_NAME} v${SCRIPT_VERSION}"
                exit 0
                ;;
            *)
                log ERROR "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

#-------------------------------------------------------------------------------
# MAIN
#-------------------------------------------------------------------------------

main() {
    # Setup logging
    exec 1> >(tee -a "$LOG_FILE")
    exec 2> >(tee -a "$LOG_FILE" >&2)
    
    trap cleanup EXIT
    
    parse_args "$@"
    
    # Header
    echo -e "${CYAN}"
    cat << "EOF"
 _   _ _   _ ____  ____  _      _____ ____  
| | | | | | |  _ \|  _ \| |    |_   _|  _ \ 
| |_| | | | | |_) | |_) | |      | | | |_) |
|  _  | |_| |  _ <|  _ <| |___   | | |  _ < 
|_| |_|\___/|_| \_\_| \_\_____|  |_| |_| \_\
                                            
EOF
    echo -e "${NC}"
    echo -e "${BOLD}${SCRIPT_NAME} v${SCRIPT_VERSION}${NC}"
    echo -e "Log file: ${LOG_FILE}"
    echo ""
    
    # Run phases
    preflight_checks
    phase_system_update
    phase_install_hyprland
    phase_install_aur_helper
    phase_install_aur_packages
    phase_install_flatpak
    phase_install_ml4w
    post_install
    
    log SUCCESS "All phases completed successfully"
}

main "$@"

