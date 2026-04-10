#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

set_default_shell() {
    local zsh_path
    zsh_path="$(command -v zsh)"
    if [[ "$SHELL" != "$zsh_path" ]]; then
        echo ""
        print_info "Do you want to change your default shell to zsh? (requires password)"
        read -r -p "Change shell? (Y/n) " resp
        if [[ -z "$resp" || "$resp" =~ ^[Yy]$ ]]; then
            print_info "Changing default shell to zsh (you may be prompted for your password)..."
            if run_interactive chsh -s "$zsh_path"; then
                print_info "Default shell changed to zsh. Please log out and back in."
            else
                print_error "Failed to change shell. You may need to run 'chsh -s $zsh_path' manually."
            fi
        else
            print_info "Skipping shell change."
        fi
    else
        print_info "zsh is already the default shell."
    fi
}

