#!/usr/bin/env bash
set -euo pipefail

# ==============================
# Source all library modules
# ==============================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/rust.sh"
source "$SCRIPT_DIR/lib/github.sh"
source "$SCRIPT_DIR/lib/tools.sh"
source "$SCRIPT_DIR/lib/yay.sh"
source "$SCRIPT_DIR/lib/rbw.sh"
source "$SCRIPT_DIR/lib/tpm.sh"
source "$SCRIPT_DIR/lib/shell.sh"
source "$SCRIPT_DIR/lib/dotfiles.sh"
source "$SCRIPT_DIR/lib/keyboard.sh"

# ==============================
# Configuration
#===============================
REQUIRED_COMMANDS=(
    zsh
    tmux
    nvim
    bat
    fzf
    zoxide
    lsd
    git
    curl
    wget
    kitty
    stow
    kbd
    wl-clipboard
    lazygit
    yazi
)

keep_sudo_alive() {
  while true; do
    sudo -v || exit 1
    sleep 60
  done
}


# ==============================
# Main
#===============================
main() {
    print_info "Checking sudo access (you may be asked for your password)..."


    if ! sudo -v; then
        print_error "This script requires sudo privileges."
        exit 1
    fi

    keep_sudo_alive &
    SUDO_KEEPALIVE_PID=$!

    trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT

    detect_distro

    local common_packages=("${REQUIRED_COMMANDS[@]}")

    case "$DISTRO_FAMILY" in
        debian)
            common_packages+=(build-essential openssh-client cargo)
            ;;
        redhat)
            common_packages+=(cargo)
            ;;
        arch)
            common_packages+=(base-devel openssh)
            ;;
        suse)
            common_packages+=(cargo)
            ;;
        alpine)
            common_packages+=(cargo)
            ;;
    esac

    install_yay
    install_packages "${common_packages[@]}"

    echo ""
    print_info "Do you want to configure the TTY keyboard for US International (accents, cedilla)?"
    echo -n "This enables ' + c = ç, etc. (Y/n) "
    read -r config_keyboard
    if [[ -z "$config_keyboard" || "$config_keyboard" =~ ^[Yy]$ ]]; then
        configure_us_intl_tty
    else
        print_info "Skipping TTY keyboard configuration."
    fi

    echo ""
    print_info "Do you want to use Bitwarden as your SSH agent (via rbw)?"
    echo
    echo -n "This will configure rbw and start the agent. (Y/n) "
    read -r use_bitwarden

    if [[ -z "$use_bitwarden" || "$use_bitwarden" =~ ^[Yy]$ ]]; then

        if ! command -v rbw &>/dev/null; then
            print_info "rbw not found. Installing..."
            install_package rbw || {
                print_error "Failed to install rbw"
                exit 1
            }
        fi

        setup_rbw
    else
        print_info "Skipping Bitwarden SSH agent setup."
    fi

    setup_tpm
    setup_dotfiles
    set_default_shell

    print_info "Installation complete!"
}

main
