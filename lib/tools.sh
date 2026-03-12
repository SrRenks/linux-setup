#!/usr/bin/env bash

declare -A SYSTEM_PACKAGES=(
    [lazygit]="arch:lazygit;fedora:lazygit"
    [yazi]="arch:yazi"
    [bw]="arch:bitwarden-cli;debian:bitwarden-cli;ubuntu:bitwarden-cli"
    [rbw]=""
)

declare -A CARGO_PACKAGES=(
    [rbw]="rbw"
)

declare -A GITHUB_PACKAGES=(
    [lazygit]="jesseduffield/lazygit:lazygit_{version}_Linux_{arch}.tar.gz"
    [yazi]="sxyazi/yazi:yazi-{arch}-unknown-linux-musl.zip"
    [bw]="bitwarden/clients:bw-linux{arch_suffix}-{version}.zip"
)

install_package() {
    local pkg="$1"
    local pkg_info

    # 1. Tentar via sistema
    pkg_info="${SYSTEM_PACKAGES[$pkg]:-}"
    if [[ -n "$pkg_info" ]]; then
        local pkg_name=""
        IFS=';' read -ra pairs <<< "$pkg_info"
        for pair in "${pairs[@]}"; do
            local distro="${pair%%:*}"
            local name="${pair#*:}"
            if [[ "$distro" == "$DISTRO_FAMILY" || "$distro" == "$OS_ID" ]]; then
                pkg_name="$name"
                break
            fi
        done
        if [[ -n "$pkg_name" ]]; then
            print_info "Installing $pkg via system package ($pkg_name)..."
            case "$DISTRO_FAMILY" in
                debian) run_with_spinner "Installing $pkg" sudo apt install -y "$pkg_name" && return 0 ;;
                redhat) run_with_spinner "Installing $pkg" sudo dnf install -y "$pkg_name" && return 0 ;;
                arch)   run_with_spinner "Installing $pkg" sudo pacman -S --noconfirm "$pkg_name" && return 0 ;;
                suse)   run_with_spinner "Installing $pkg" sudo zypper install -y "$pkg_name" && return 0 ;;
                alpine) run_with_spinner "Installing $pkg" sudo apk add "$pkg_name" && return 0 ;;
            esac
            print_warn "System package installation failed for $pkg, trying next method..."
        fi
    fi

    # 2. Tentar via cargo
    pkg_info="${CARGO_PACKAGES[$pkg]:-}"
    if [[ -n "$pkg_info" ]]; then
        print_info "Installing $pkg via cargo..."
        ensure_rust || return 1
        if run_with_spinner "Installing $pkg" cargo install --locked "$pkg_info"; then
            return 0
        else
            print_warn "Cargo installation failed for $pkg, trying next method..."
        fi
    fi

    # 3. Tentar via GitHub
    pkg_info="${GITHUB_PACKAGES[$pkg]:-}"
    if [[ -n "$pkg_info" ]]; then
        print_info "Installing $pkg from GitHub releases..."
        local repo="${pkg_info%%:*}"
        local pattern="${pkg_info#*:}"

        local arch
        arch=$(uname -m)
        local arch_suffix=""
        case "$arch" in
            x86_64)  arch="x86_64"; arch_suffix="" ;;
            aarch64) arch="aarch64"; arch_suffix="-arm64" ;;
            armv7l)  arch="armv7"; arch_suffix="" ;;
            *)       print_error "Unsupported architecture: $arch"; return 1 ;;
        esac

        pattern=$(echo "$pattern" | sed "s/{arch_suffix}/$arch_suffix/g")

        if _install_github_binary "$repo" "$pkg" "v{version}" "$pattern"; then
            return 0
        else
            print_error "GitHub installation failed for $pkg"
            return 1
        fi
    fi

    print_error "No installation method found for $pkg"
    return 1
}