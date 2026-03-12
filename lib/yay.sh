#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# ==============================
# install yay for Arch-based distros
# ==============================
install_yay() {
    if [[ "$DISTRO_FAMILY" != "arch" ]]; then
        return 0
    fi
    if command -v yay &>/dev/null; then
        print_info "yay already installed."
        return
    fi
    print_info "Installing yay from AUR..."
    run_with_spinner "Cloning yay repository" git clone --depth=1 https://aur.archlinux.org/yay.git /tmp/yay
    (cd /tmp/yay && run_with_info "Building yay (this may take a while and ask for sudo)..." makepkg -si --noconfirm)
    run_with_spinner "Cleaning up" rm -rf /tmp/yay
    print_info "yay installed successfully."
}