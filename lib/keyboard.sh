#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# ==============================
# Configure US International keyboard with accents (TTY)
# ==============================
configure_us_intl_tty() {
    print_info "Configuring TTY keyboard layout for US International (with accents/dead keys)..."

    case "$DISTRO_FAMILY" in
        debian|ubuntu)
            run_with_spinner "Installing kbd and console-setup" sudo apt install -y kbd console-setup
            ;;
    esac

    case "$DISTRO_FAMILY" in
        arch|debian|ubuntu|redhat|suse|alpine)
            print_info "Setting persistent keyboard layout for $DISTRO_FAMILY..."
            case "$DISTRO_FAMILY" in
                arch)
                    run_with_spinner "Setting KEYMAP in /etc/vconsole.conf" \
                        sudo bash -c "echo 'KEYMAP=us-intl' > /etc/vconsole.conf"
                    print_info "Persistent configuration set in /etc/vconsole.conf. Reboot to take full effect."
                    ;;
                debian|ubuntu)
                    echo "keyboard-configuration keyboard-configuration/layoutcode string us" | sudo debconf-set-selections
                    echo "keyboard-configuration keyboard-configuration/variantcode string intl" | sudo debconf-set-selections
                    echo "keyboard-configuration keyboard-configuration/xkb-keymap select us" | sudo debconf-set-selections
                    run_with_spinner "Reconfiguring keyboard-configuration" sudo dpkg-reconfigure -f noninteractive keyboard-configuration
                    run_with_spinner "Applying setupcon" sudo setupcon --force
                    print_info "Keyboard configuration updated. It should persist across reboots."
                    ;;
                redhat)
                    if command -v localectl &>/dev/null; then
                        run_with_spinner "Setting keymap via localectl" sudo localectl set-keymap us-intl
                    else
                        run_with_spinner "Setting KEYMAP in /etc/vconsole.conf" \
                            sudo bash -c "echo 'KEYMAP=us-intl' > /etc/vconsole.conf"
                    fi
                    ;;
                suse)
                    if command -v localectl &>/dev/null; then
                        run_with_spinner "Setting keymap via localectl" sudo localectl set-keymap us-intl
                    else
                        print_warn "Please use YaST to set keyboard to 'US International (with dead keys)' for persistence."
                    fi
                    ;;
                alpine)
                    run_with_spinner "Setting KEYMAP in /etc/conf.d/keymaps" \
                        sudo sed -i 's/^keymap=.*/keymap="us-intl"/' /etc/conf.d/keymaps
                    ;;
            esac
            ;;
        *)
            print_warn "Unsupported distribution for persistent keyboard configuration."
            print_warn "You may need to manually add 'loadkeys us-intl' to your startup scripts (e.g., ~/.zshrc, /etc/rc.local)."
            ;;
    esac

    print_info "Keyboard configuration for TTY completed."
}