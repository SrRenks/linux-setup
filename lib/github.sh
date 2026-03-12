#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

_install_github_binary() {
    local repo="$1"
    local binary_name="$2"
    local version_pattern="$3"
    local asset_pattern="$4"
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64)  arch="x86_64" ;;
        aarch64) arch="aarch64" ;;
        armv7l)  arch="armv7" ;;
        *)       print_error "Unsupported architecture: $arch"; return 1 ;;
    esac

    print_info "Installing $binary_name from GitHub releases..."

    local version
    version=$(curl -s "https://api.github.com/repos/$repo/releases/latest" | grep -Po '"tag_name": *"v\K[^"]*')
    if [[ -z "$version" ]]; then
        print_error "Could not fetch latest version for $repo"
        return 1
    fi

    local asset
    asset=$(echo "$asset_pattern" | sed -e "s/{version}/$version/g" -e "s/{arch}/$arch/g")
    local url="https://github.com/$repo/releases/download/v${version}/$asset"

    local tmp_dir
    tmp_dir=$(mktemp -d)
    pushd "$tmp_dir" >/dev/null

    if ! run_with_spinner "Downloading $binary_name" curl -L -o "$binary_name" "$url"; then
        print_error "Download failed for $url"
        popd >/dev/null; rm -rf "$tmp_dir"
        return 1
    fi

    if [[ "$asset" == *.tar.gz ]]; then
        run_with_spinner "Extracting $binary_name" tar xzf "$binary_name" || { print_error "Extraction failed"; popd >/dev/null; rm -rf "$tmp_dir"; return 1; }
        if [[ ! -f "$binary_name" ]]; then
            local found
            found=$(find . -type f -name "$binary_name" | head -n1)
            if [[ -n "$found" ]]; then
                mv "$found" "$binary_name"
            else
                print_error "Binary not found in extracted files"
                popd >/dev/null; rm -rf "$tmp_dir"
                return 1
            fi
        fi
    fi

    run_with_spinner "Installing $binary_name to /usr/local/bin" sudo install -Dm755 "$binary_name" "/usr/local/bin/$binary_name"
    popd >/dev/null
    rm -rf "$tmp_dir"
    print_info "$binary_name installed successfully."
}
