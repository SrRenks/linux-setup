#!/usr/bin/env bash

# ==============================
# Hyprland package definitions
# ==============================

HYP_CORE_PACKAGES=(
    rofi-wayland
    waybar
    swaync

    mpv
    playerctl
    pamixer
    libnotify

    ueberzugpp
    imagemagick
    nsxiv

    ddcutil
    hyprlock

    pipewire
    pipewire-pulse
    pipewire-alsa
    pipewire-jack
    wireplumber
    rtkit
    xdg-desktop-portal-hyprland
)

HYP_BASIC_PACKAGES=(
    btop
    pavucontrol
    nwg-look
    lxappearance
    fastfetch
)

HYP_AUR_PACKAGES=(
    waybar-module-pacman-updates-git
    tela-circle-icon-theme-black
)

# ==============================
# Install functions
# ==============================

install_hyprland_core() {
    print_info "Installing Hyprland core packages..."
    install_packages "${HYP_CORE_PACKAGES[@]}"
}

install_hyprland_basic() {
    print_info "Installing Hyprland basic GUI tools..."
    install_packages "${HYP_BASIC_PACKAGES[@]}"
}

install_hyprland_aur() {
    print_info "Installing Hyprland AUR packages..."

    for pkg in "${HYP_AUR_PACKAGES[@]}"; do
        if command -v "$pkg" &>/dev/null; then
            print_info "$pkg already installed."
        else
            install_package "$pkg" || print_warn "Failed to install $pkg"
        fi
    done
}

# ==============================
# Main entry
# ==============================

setup_hyprland() {
    echo ""
    print_info "Do you want to install the Hyprland setup (Wayland WM)? (Y/n)"
    read -r install_hypr

    if [[ -n "$install_hypr" && ! "$install_hypr" =~ ^[Yy]$ ]]; then
        print_info "Skipping Hyprland setup."
        return
    fi

    install_hyprland_core

    echo ""
    print_info "Install extra GUI tools? (Y/n)"
    read -r extra

    if [[ -z "$extra" || "$extra" =~ ^[Yy]$ ]]; then
        install_hyprland_basic
    fi

    echo ""
    print_info "Install AUR extras for Hyprland? (y/N)"
    read -r aur

    if [[ "$aur" =~ ^[Yy]$ ]]; then
        install_hyprland_aur
    fi
}