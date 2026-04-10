#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

configure_us_intl_tty() {
    print_info "Configuring TTY keyboard layout..."

    KEYMAP="us"

    case "$DISTRO_FAMILY" in
        arch)
            KEYMAP="us-acentos"

            run_with_spinner "Ensuring kbd is installed" \
                sudo pacman -S --needed --noconfirm kbd
            ;;
        debian|ubuntu)
            run_with_spinner "Installing keyboard tools" \
                sudo apt install -y kbd console-setup

            echo "keyboard-configuration keyboard-configuration/layoutcode string us" | sudo debconf-set-selections
            echo "keyboard-configuration keyboard-configuration/variantcode string intl" | sudo debconf-set-selections
            echo "keyboard-configuration keyboard-configuration/xkb-keymap select us" | sudo debconf-set-selections

            run_with_spinner "Reconfiguring keyboard" \
                sudo dpkg-reconfigure -f noninteractive keyboard-configuration

            run_with_spinner "Applying setupcon" sudo setupcon --force
            ;;
        redhat)
            if command -v localectl &>/dev/null; then
                run_with_spinner "Setting keymap" sudo localectl set-keymap us
            else
                run_with_spinner "Writing vconsole config" \
                    sudo bash -c "echo 'KEYMAP=us' > /etc/vconsole.conf"
            fi
            ;;
        suse)
            if command -v localectl &>/dev/null; then
                run_with_spinner "Setting keymap" sudo localectl set-keymap us
            else
                print_warn "Use YaST to configure keyboard"
            fi
            ;;
        alpine)
            run_with_spinner "Setting keymap" \
                sudo sed -i 's/^keymap=.*/keymap="us"/' /etc/conf.d/keymaps
            ;;
    esac

    run_with_spinner "Setting KEYMAP in /etc/vconsole.conf" \
        sudo bash -c "echo \"KEYMAP=$KEYMAP\" > /etc/vconsole.conf"

    if command -v loadkeys &>/dev/null; then
        run_with_spinner "Applying keymap immediately" sudo loadkeys "$KEYMAP"
    fi

    print_info "Keyboard configured: $KEYMAP"
}
