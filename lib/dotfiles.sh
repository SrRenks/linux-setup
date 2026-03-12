#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

setup_dotfiles() {
    echo ""
    print_info "Do you want to clone and apply dotfiles from GitHub?"
    echo -n "Use default repository (https://github.com/SrRenks/dotfiles)? (Y/n) "
    read -r use_default
    local repo_url=""
    if [[ -z "$use_default" || "$use_default" =~ ^[Yy]$ ]]; then
        repo_url="https://github.com/SrRenks/dotfiles.git"
    else
        echo -n "Enter the full GitHub repository URL (e.g., https://github.com/username/dotfiles.git): "
        read -r repo_url
        if [[ -z "$repo_url" ]]; then
            print_info "No repository provided. Skipping dotfiles setup."
            return 0
        fi
        # Validate URL by checking if it's a git repository
        print_info "Validating repository URL..."
        if ! git ls-remote "$repo_url" &>/dev/null; then
            print_error "Invalid or inaccessible repository URL. Please check and try again."
            return 1
        fi
    fi

    local dest="$HOME/dotfiles"
    if [[ -d "$dest" ]]; then
        print_warn "Directory $dest already exists. Skipping clone."
    else
        run_with_spinner "Cloning dotfiles repository" git clone --depth=1 "$repo_url" "$dest"
    fi

    if [[ -d "$dest" ]]; then
        print_info "Applying dotfiles with stow..."
        pushd "$dest" >/dev/null
        for dir in */; do
            if [[ -d "$dir" ]]; then
                run_with_spinner "Stowing ${dir%/}" stow "${dir%/}"
            fi
        done
        popd >/dev/null
        print_info "Dotfiles applied successfully."
    else
        print_error "Dotfiles directory not found. Clone may have failed."
    fi
}
