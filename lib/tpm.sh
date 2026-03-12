#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# ==============================
# TPM setup
#===============================
setup_tpm() {
    local tpm_path="$HOME/.tmux/plugins/tpm"
    if [[ ! -d "$tpm_path" ]]; then
        print_info "Cloning TPM..."
        run_with_spinner "Cloning tpm" git clone --depth=1 https://github.com/tmux-plugins/tpm "$tpm_path"
    fi
    print_info "TPM ready."
}