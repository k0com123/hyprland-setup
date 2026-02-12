#!/bin/bash

#===============================================================================
#
#          FILE: install.sh
#
#         USAGE: ./install.sh [options]
#
#   DESCRIPTION: Automated Hyprland + ML4W Dotfiles Installer for Arch Linux
#                "Rice hard or go home"
#
#       OPTIONS: See usage() function below
#  REQUIREMENTS: Arch Linux (or derivative), internet connection, sudo access
#          BUGS: Report at https://github.com/k0com123/hyprland-setup/issues
#         NOTES: Tested on Arch, EndeavourOS, Garuda, Manjaro
#        AUTHOR: k0com123 (https://github.com/k0com123)
#       VERSION: 2.0.0
#       CREATED: 2024
#      REVISION: Hardcore Edition
#      LICENSE: MIT (see LICENSE file)
#
#===============================================================================

#-------------------------------------------------------------------------------
# CONFIGURATION & VARIABLES
#-------------------------------------------------------------------------------

set -euo pipefail  # Strict mode: exit on error, undefined var, pipe fail

readonly SCRIPT_VERSION="2.0.0"
readonly SCRIPT_NAME="Hyprland ML4W Installer"
readonly REPO_URL="https://github.com/k0com123/hyprland-setup"
readonly ISSUES_URL="https://github.com/k0com123/hyprland-setup/issues"
readonly LOG_FILE="/tmp/hyprland-install-$(date +%Y%m%d-%H%M%S).log"
readonly BACKUP_DIR="$HOME/.config/backup-$(date +%Y%m%d-%H%M%S)"

# Colors
readonly C_RED='\033[0;31m'
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[1;33m'
readonly C_BLUE='\033[0;34m'
readonly C_CYAN='\033[0;36m'
readonly C_MAGENTA='\033[0;35m'
readonly C_NC='\033[0m'

# Package lists
readonly PACMAN_PACKAGES=(
    hyprland hyprpaper hyprlock hypridle hyprcursor hyprutils
    xdg-desktop-portal-hyprland
    waybar wofi kitty mako grimblast wl-clipboard
    polkit-kde-agent qt5-wayland qt6-wayland
    pipewire wireplumber pipewire-audio pipewire-pulse pavucontrol
    network-manager-applet blueman
    thunar gvfs tumbler
    ttf-font-awesome noto-fonts noto-fonts-emoji 
    ttf-jetbrains-mono-nerd ttf-fira-code
    starship zsh zsh-completions
    swww
    wlogout
    swappy
    slurp
    brightnessctl
    pamixer
)

readonly AUR_PACKAGES=(
    hyprland-plugins
    waybar-module-pacman-updates
    wofi-calc
    sddm-sugar-candy-git
)

readonly FLATPAK_PACKAGES=(
    "com.ml4w.dotfilesinstaller"
)

#-------------------------------------------------------------------------------
# UTILITY FUNCTIONS
#-------------------------------------------------------------------------------

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

print_error() { echo -e "${C_RED}[ERROR]${C_NC} $*" | tee -a "$LOG_FILE"; }
print_success() { echo -e "${C_GREEN}[OK]${C_NC} $*"; }
print_warning() { echo -e "${C_YELLOW}[WARN]${C_NC} $*"; }
print_info() { echo -e "${C_BLUE}[INFO]${C_NC} $*"; }
print_header() { echo -e "${C_CYAN}$*${C_NC}"; }
print_step() { echo -e "\n${C_MAGENTA}[PHASE]${C_NC} ${C_YELLOW}$*${C_NC}"; }

show_banner() {
    clear
    echo -e "${C_CYAN}"
    cat << 'EOF'
    ╔══════════════════════════════════════════════════════════════════╗
    ║                                                                  ║
    ║   ██╗  ██╗██╗   ██╗██████╗ ██████╗ ██╗      █████╗ ███╗   ██╗██████╗  ║
    ║   ██║  ██║╚██╗ ██╔╝██╔══██╗██╔══██╗██║     ██╔══██╗████╗  ██║██╔══██╗ ║
    ║   ███████║ ╚████╔╝ ██████╔╝██████╔╝██║     ███████║██╔██╗ ██║██║  ██║ ║
    ║   ██╔══██║  ╚██╔╝  ██╔═══╝ ██╔══██╗██║     ██╔══██║██║╚██╗██║██║  ██║ ║
    ║   ██║  ██║   ██║   ██║     ██║  ██║███████╗██║  ██║██║ ╚████║██████╔╝ ║
    ║   ╚═╝  ╚═╝   ╚═╝   ╚═╝     ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═════╝  ║
    ║                                                                  ║
    ║              ██╗███╗   ██╗███████╗████████╗ █████╗ ██╗     ██╗      ║
    ║              ██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██║      ║
    ║              ██║██╔██╗ ██║███████╗   ██║   ███████║██║     ██║      ║
    ║              ██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██║      ║
    ║              ██║██║ ╚████║███████║   ██║   ██║  ██║███████╗███████╗ ║
    ║              ╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝ ║
    ║                                                                  ║
    ║                    ML4W DOTFILES EDITION v2.0                    ║
    ║                                                                  ║
    ╚══════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${C_NC}"
    echo -e "${C_YELLOW}    GitHub: https://github.com/k0com123/hyprland-setup${C_NC}"
    echo -e "${C_YELLOW}    Issues: https://github.com/k0com123/hyprland-setup/issues${C_NC}"
    echo -e "${C_YELLOW}    License: MIT (see LICENSE file)${C_NC}"
    echo -e "${C_YELLOW}    Logs: $LOG_FILE${C_NC}\n"
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Hyprland + ML4W Dotfiles Installer for Arch Linux
Repository: https://github.com/k0com123/hyprland-setup
License: MIT

OPTIONS:
    -h, --help          Show this help message
    -v, --verbose       Verbose output (set -x)
    -n, --no-aur        Skip AUR packages (yay not needed)
    -f, --force         Force reinstall even if packages exist
    -b, --backup        Create backup of existing configs (default: true)
    -s, --skip-update   Skip system update (not recommended)
    -u, --uninstall     Uninstall everything (DANGEROUS)
    --dry-run           Show what would be installed without installing

EXAMPLES:
    $0                  # Standard installation
    $0 --verbose        # Debug mode with full output
    $0 --no-aur         # Skip AUR packages (minimal install)
    $0 --uninstall      # Remove everything (rip rice)

Report bugs at: https://github.com/k0com123/hyprland-setup/issues

EOF
}

command_exists() { command -v "$1" &> /dev/null; }

check_arch() {
    if [[ ! -f /etc/arch-release ]]; then
        print_error "This script is for Arch Linux only."
        print_error "Detected: $(cat /etc/os-release 2>/dev/null | grep -oP '(?<=^NAME=).*' || echo 'Unknown')"
        log "ERROR: Not Arch Linux"
        exit 1
    fi
    print_success "Arch Linux detected: $(pacman -Qq linux 2>/dev/null || echo 'kernel unknown')"
}

check_not_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "Do not run as root!"
        print_error "The script uses sudo when needed. Running as root is insecure."
        log "ERROR: Script run as root"
        exit 1
    fi
    
    if ! sudo -n true 2>/dev/null; then
        print_warning "Sudo access required. Please enter password when prompted."
        sudo -v || { print_error "Sudo access denied"; exit 1; }
    fi
    
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    
    print_success "Sudo access confirmed"
}

update_system() {
    print_step "Updating System"
    print_info "Running pacman -Syu..."
    
    if sudo pacman -Syu --noconfirm; then
        print_success "System updated successfully"
    else
        print_error "System update failed"
        exit 1
    fi
}

install_yay() {
    if [[ "${SKIP_AUR:-false}" == true ]]; then
        print_info "Skipping AUR (yay) installation as requested"
        return 0
    fi
    
    if command_exists yay; then
        print_success "yay already installed: $(yay --version | head -n1)"
        return 0
    fi
    
    print_step "Installing yay (AUR Helper)"
    
    sudo pacman -S --needed --noconfirm git base-devel || {
        print_error "Failed to install build dependencies"
        exit 1
    }
    
    local yay_dir="/tmp/yay-build-$$"
    mkdir -p "$yay_dir"
    cd "$yay_dir"
    
    git clone https://aur.archlinux.org/yay-bin.git . || {
        print_error "Failed to clone yay repository"
        exit 1
    }
    
    makepkg -si --noconfirm || {
        print_error "Failed to build yay"
        exit 1
    }
    
    cd - > /dev/null
    rm -rf "$yay_dir"
    
    print_success "yay installed successfully"
}

backup_configs() {
    [[ "${DO_BACKUP:-true}" != true ]] && return 0
    
    print_step "Creating Backup"
    print_info "Backup directory: $BACKUP_DIR"
    
    mkdir -p "$BACKUP_DIR"
    
    local configs=(hypr waybar wofi kitty mako)
    local backed_up=false
    
    for config in "${configs[@]}"; do
        local config_path="$HOME/.config/$config"
        if [[ -d "$config_path" ]]; then
            print_info "Backing up $config..."
            cp -r "$config_path" "$BACKUP_DIR/" || print_warning "Failed to backup $config"
            backed_up=true
        fi
    done
    
    if [[ "$backed_up" == true ]]; then
        print_success "Configs backed up to $BACKUP_DIR"
    else
        print_info "No existing configs to backup"
    fi
}

install_pacman_packages() {
    print_step "Installing Core Packages ($((${#PACMAN_PACKAGES[@]})) packages)"
    
    local to_install=()
    for pkg in "${PACMAN_PACKAGES[@]}"; do
        if ! pacman -Qq "$pkg" &> /dev/null || [[ "${FORCE_REINSTALL:-false}" == true ]]; then
            to_install+=("$pkg")
        else
            [[ "${VERBOSE:-false}" == true ]] && print_info "$pkg already installed"
        fi
    done
    
    if [[ ${#to_install[@]} -eq 0 ]]; then
        print_success "All core packages already installed"
        return 0
    fi
    
    print_info "Installing: ${to_install[*]}"
    
    if sudo pacman -S --needed --noconfirm "${to_install[@]}"; then
        print_success "Installed ${#to_install[@]} packages"
    else
        print_error "Failed to install some packages"
        print_warning "Continuing anyway..."
    fi
}

install_aur_packages() {
    [[ "${SKIP_AUR:-false}" == true ]] && return 0
    
    print_step "Installing AUR Packages ($((${#AUR_PACKAGES[@]})) packages)"
    
    if ! command_exists yay; then
        print_error "yay not found, skipping AUR packages"
        print_warning "Install yay manually or run without --no-aur flag"
        return 1
    fi
    
    local to_install=()
    for pkg in "${AUR_PACKAGES[@]}"; do
        if ! yay -Qq "$pkg" &> /dev/null || [[ "${FORCE_REINSTALL:-false}" == true ]]; then
            to_install+=("$pkg")
        else
            [[ "${VERBOSE:-false}" == true ]] && print_info "$pkg already installed"
        fi
    done
    
    if [[ ${#to_install[@]} -eq 0 ]]; then
        print_success "All AUR packages already installed"
        return 0
    fi
    
    print_info "Installing from AUR: ${to_install[*]}"
    
    if yay -S --needed --noconfirm "${to_install[@]}"; then
        print_success "Installed ${#to_install[@]} AUR packages"
    else
        print_warning "Some AUR packages failed to install"
        print_info "You can install them manually later"
    fi
}

setup_flatpak() {
    print_step "Setting up Flatpak"
    
    if ! command_exists flatpak; then
        print_info "Installing Flatpak..."
        sudo pacman -S --needed --noconfirm flatpak || {
            print_error "Failed to install Flatpak"
            exit 1
        }
    fi
    
    if ! flatpak remotes | grep -q flathub; then
        print_info "Adding Flathub repository..."
        sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    fi
    
    print_success "Flatpak configured"
}

install_ml4w() {
    print_step "Installing ML4W Dotfiles Installer"
    
    if flatpak list | grep -q "com.ml4w.dotfilesinstaller"; then
        if [[ "${FORCE_REINSTALL:-false}" != true ]]; then
            print_success "ML4W Dotfiles Installer already installed"
            return 0
        fi
        print_info "Force reinstall requested..."
    fi
    
    print_info "Installing com.ml4w.dotfilesinstaller from Flathub..."
    
    if flatpak install -y flathub com.ml4w.dotfilesinstaller; then
        print_success "ML4W Dotfiles Installer installed successfully"
    else
        print_error "Failed to install ML4W Dotfiles Installer"
        print_info "You can try manually: flatpak install flathub com.ml4w.dotfilesinstaller"
        exit 1
    fi
}

post_install() {
    print_step "Post-Installation Setup"
    
    if ! groups "$USER" | grep -q video; then
        print_info "Adding user to 'video' group..."
        sudo usermod -aG video "$USER"
        print_warning "You may need to logout/login for video group changes to take effect"
    fi
    
    print_info "Enabling PipeWire services..."
    systemctl --user enable pipewire pipewire-pulse wireplumber 2>/dev/null || true
    
    print_info "Creating XDG directories..."
    xdg-user-dirs-update 2>/dev/null || true
    
    print_success "Post-installation complete"
}

uninstall_all() {
    print_step "UNINSTALL MODE - DANGER ZONE"
    print_error "This will remove Hyprland and all related packages!"
    
    read -rp "Are you sure? Type 'yes' to continue: " confirm
    if [[ "$confirm" != "yes" ]]; then
        print_info "Uninstall cancelled"
        exit 0
    fi
    
    print_warning "Removing packages..."
    
    sudo pacman -Rns --noconfirm "${PACMAN_PACKAGES[@]}" 2>/dev/null || true
    
    if command_exists yay; then
        sudo pacman -Rns --noconfirm yay-bin 2>/dev/null || true
    fi
    
    flatpak uninstall -y com.ml4w.dotfilesinstaller 2>/dev/null || true
    
    print_success "Uninstall complete (config files preserved in ~/.config)"
    print_info "Report issues at: https://github.com/k0com123/hyprland-setup/issues"
}

dry_run() {
    print_step "DRY RUN MODE - Nothing will be installed"
    
    echo -e "\n${C_CYAN}Pacman packages to install:${C_NC}"
    for pkg in "${PACMAN_PACKAGES[@]}"; do
        if ! pacman -Qq "$pkg" &> /dev/null; then
            echo "  [ ] $pkg"
        else
            echo -e "  ${C_GREEN}[✓]${C_NC} $pkg (installed)"
        fi
    done
    
    echo -e "\n${C_CYAN}AUR packages to install:${C_NC}"
    for pkg in "${AUR_PACKAGES[@]}"; do
        echo "  [ ] $pkg"
    done
    
    echo -e "\n${C_CYAN}Flatpak packages to install:${C_NC}"
    for pkg in "${FLATPAK_PACKAGES[@]}"; do
        echo "  [ ] $pkg"
    done
    
    echo -e "\n${C_YELLOW}Repository: $REPO_URL${C_NC}"
    echo -e "${C_YELLOW}Run without --dry-run to install${C_NC}"
}

show_summary() {
    echo -e "\n${C_CYAN}╔════════════════════════════════════════════════════════════════╗${C_NC}"
    echo -e "${C_GREEN}║                  INSTALLATION COMPLETE! 🎉                     ║${C_NC}"
    echo -e "${C_CYAN}╚════════════════════════════════════════════════════════════════╝${C_NC}"
    echo ""
    echo -e "${C_YELLOW}Installed Components:${C_NC}"
    echo -e "  ${C_GREEN}✓${C_NC} Hyprland Wayland Compositor"
    echo -e "  ${C_GREEN}✓${C_NC} Waybar (status bar)"
    echo -e "  ${C_GREEN}✓${C_NC} Wofi (application launcher)"
    echo -e "  ${C_GREEN}✓${C_NC} Kitty (terminal emulator)"
    echo -e "  ${C_GREEN}✓${C_NC} ML4W Dotfiles Installer"
    echo ""
    echo -e "${C_YELLOW}Next Steps:${C_NC}"
    echo -e "  1. ${C_CYAN}Reboot your system${C_NC} (recommended for group changes)"
    echo -e "  2. At login, select ${C_CYAN}Hyprland${C_NC} from your display manager"
    echo -e "  3. Or run: ${C_CYAN}Hyprland${C_NC} from TTY (Ctrl+Alt+F3)"
    echo -e "  4. Run ML4W installer: ${C_CYAN}flatpak run com.ml4w.dotfilesinstaller${C_NC}"
    echo ""
    echo -e "${C_YELLOW}Useful Commands:${C_NC}"
    echo -e "  ${C_CYAN}Super + Q${C_NC}          Open terminal"
    echo -e "  ${C_CYAN}Super + M${C_NC}          Open launcher"
    echo -e "  ${C_CYAN}Super + Shift + E${C_NC}  Exit Hyprland"
    echo ""
    echo -e "${C_MAGENTA}Logs saved to: ${C_NC}$LOG_FILE"
    echo -e "${C_MAGENTA}Configs backed up to: ${C_NC}$BACKUP_DIR"
    echo ""
    echo -e "${C_GREEN}Star the repo: ${C_CYAN}$REPO_URL${C_NC}"
    echo -e "${C_GREEN}Report bugs: ${C_CYAN}$ISSUES_URL${C_NC}"
    echo ""
    echo -e "${C_GREEN}Happy Ricing! 🍚${C_NC}"
}

cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        echo -e "\n${C_RED}[FAILED]${C_NC} Installation failed with exit code $exit_code"
        echo -e "${C_YELLOW}Check logs: $LOG_FILE${C_NC}"
        echo -e "${C_YELLOW}Report at: $ISSUES_URL${C_NC}"
    fi
    exit $exit_code
}

trap cleanup EXIT

#-------------------------------------------------------------------------------
# MAIN FUNCTION
#-------------------------------------------------------------------------------

main() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                set -x
                shift
                ;;
            -n|--no-aur)
                SKIP_AUR=true
                shift
                ;;
            -f|--force)
                FORCE_REINSTALL=true
                shift
                ;;
            -b|--backup)
                DO_BACKUP=true
                shift
                ;;
            -s|--skip-update)
                SKIP_UPDATE=true
                shift
                ;;
            -u|--uninstall)
                uninstall_all
                exit 0
                ;;
            --dry-run)
                dry_run
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    show_banner
    check_arch
    check_not_root
    
    [[ "${SKIP_UPDATE:-false}" != true ]] && update_system
    
    backup_configs
    install_yay
    install_pacman_packages
    install_aur_packages
    setup_flatpak
    install_ml4w
    post_install
    
    show_summary
}

main "$@"
