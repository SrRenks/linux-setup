#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# ==============================
# Logging and silent execution
# ==============================
ensure_rust() {
    if command -v rustc &>/dev/null && command -v cargo &>/dev/null; then
        print_info "Rust already installed."
        return 0
    fi
    print_info "Rust not found. Installing rustup..."
    if run_with_spinner "Installing rustup" bash -c "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y"; then
        source "$HOME/.cargo/env"
        print_info "Rust installed successfully."
    else
        print_error "Rust installation failed."
        return 1
    fi
}
