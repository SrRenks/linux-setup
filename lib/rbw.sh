#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/tools.sh"

# ==============================
# Setup rbw (Bitwarden SSH agent)
# ==============================
setup_rbw() {
    print_info "Setting up rbw..."

    if ! command -v pinentry-tty &>/dev/null; then
        case "$DISTRO_FAMILY" in
            debian) run_with_spinner "Installing pinentry-tty" sudo apt install -y pinentry-tty ;;
            redhat) run_with_spinner "Installing pinentry" sudo dnf install -y pinentry ;;
            arch)   run_with_spinner "Installing pinentry" sudo pacman -S --noconfirm pinentry ;;
            suse)   run_with_spinner "Installing pinentry" sudo zypper install -y pinentry ;;
            alpine) run_with_spinner "Installing pinentry" sudo apk add pinentry ;;
            *) print_warn "Please install pinentry-tty manually." ;;
        esac
    fi

    mkdir -p "$HOME/.config/rbw"
    touch "$HOME/.config/rbw/config.toml"

    rbw config set pinentry pinentry-tty

    echo ""
    print_info "rbw requires your Bitwarden email address."
    echo -n "Enter your email: "
    read -r email
    if [[ -n "$email" ]]; then
        rbw config set email "$email"
    else
        print_error "Email is required. Aborting."
        return 1
    fi

    print_info "Bitwarden server URL (press Enter to use official server):"
    echo -n "URL [https://api.bitwarden.com]: "
    read -r server_url
    if [[ -n "$server_url" ]]; then
        rbw config set base_url "$server_url"
        if [[ "$server_url" == "https://api.bitwarden.com" ]]; then
            rbw config set identity_url "https://identity.bitwarden.com"
        else
            print_warn "Using custom server. You may need to set identity_url manually if different."
        fi
    else
        rbw config set base_url "https://api.bitwarden.com"
        rbw config set identity_url "https://identity.bitwarden.com"
    fi

    print_info "Attempting to log in with rbw (if fails, will guide through registration)..."
    if ! rbw login >/dev/null; then
        print_warn "rbw login failed. This may require device registration with your API key."
        print_info "The Bitwarden CLI will be needed to proceed."
        echo "It will be installed temporarily to perform the device registration."
        echo "Make sure you have already stored your API key in your Vault as a login item named 'bw-api':"
        echo "  - Use the client_id as the username"
        echo "  - Use the client_secret as the password"
        echo "You can find your API key at: https://vault.bitwarden.com → Settings → Security → API Key"
        echo ""
        echo -n "Proceed with automated registration and temporary Bitwarden CLI installation? (Y/n) "
        read -r register_choice
        if [[ -z "$register_choice" || "$register_choice" =~ ^[Yy]$ ]]; then
            local bw_installed_by_script=false

            if ! command -v bw &>/dev/null; then
                print_info "Installing Bitwarden CLI (bw) temporarily for registration..."
                install_package "bw"
                if command -v bw &>/dev/null; then
                    bw_installed_by_script=true
                else
                    print_error "Failed to install bw. Please run 'rbw register' manually."
                    return 1
                fi
            fi

            print_info "Checking Bitwarden CLI login status..."
            if ! bw login --check &>/dev/null; then
                print_info "Please log in to Bitwarden CLI (follow the prompts)..."
                NODE_NO_WARNINGS=1 bw login >/dev/null
            fi

            print_info "Unlocking Bitwarden vault to retrieve API keys..."
            local BW_SESSION
            BW_SESSION=$(NODE_NO_WARNINGS=1 bw unlock --raw)
            if [[ -z "$BW_SESSION" ]]; then
                print_error "Failed to unlock bw."
                return 1
            fi

            if ! bw list items --search bw-api --session "$BW_SESSION" 2>/dev/null | grep -q '"id"'; then
                print_error "Item 'bw-api' not found in your Bitwarden vault."
                echo "Please create a secure note named 'bw-api' with:"
                echo "  username: your client_id"
                echo "  password: your client_secret"
                echo "Then run this script again."
                return 1
            fi

            local client_id client_secret
            client_id=$(bw get username bw-api --session "$BW_SESSION" 2>/dev/null)
            client_secret=$(bw get password bw-api --session "$BW_SESSION" 2>/dev/null)
            if [[ -z "$client_id" || -z "$client_secret" ]]; then
                print_error "Could not retrieve API key from bw. Please check the item 'bw-api'."
                return 1
            fi

            if ! command -v expect &>/dev/null; then
                print_warn "expect not installed. Please run 'rbw register' manually."
                return 1
            fi

            print_info "Running rbw register with retrieved API key..."
            local temp_expect
            temp_expect=$(mktemp)
            if ! expect << EOF > "$temp_expect" 2>&1; then
spawn rbw register
expect "API key client__id:"
send -- "$client_id\r"
expect "API key client__secret:"
send -- "$client_secret\r"
expect eof
catch wait result
exit [lindex \$result 3]
EOF
                cat "$temp_expect"
                print_error "Registration failed. See output above."
                rm -f "$temp_expect"
                return 1
            else
                rm -f "$temp_expect"
            fi

            print_info "Registration successful. Now logging in with rbw..."
            if ! rbw login >/dev/null; then
                print_error "rbw login failed after registration. Please check manually."
                return 1
            fi

            if $bw_installed_by_script; then
                sudo rm -f "$(command -v bw)"
                print_info "Temporary bw installation removed."
            fi
        else
            print_error "Login failed and registration skipped. Exiting."
            return 1
        fi
    fi

    run_with_spinner "Syncing vault" rbw sync

    if command -v systemctl &>/dev/null && systemctl --user list-units &>/dev/null 2>&1; then
        print_info "Setting up systemd user service for rbw-agent..."
        local service_dir="$HOME/.config/systemd/user"
        local service_file="$service_dir/rbw.service"
        mkdir -p "$service_dir"

        cat > "$service_file" <<EOF
[Unit]
Description=rbw agent daemon
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart=$(command -v rbw-agent)
Restart=on-failure

[Install]
WantedBy=graphical-session.target
EOF

        run_with_spinner "Reloading systemd" systemctl --user daemon-reload
        run_with_spinner "Enabling rbw service" systemctl --user enable rbw.service
        run_with_spinner "Starting rbw service" systemctl --user start rbw.service
        print_info "rbw-agent started via systemd."
    else
        print_warn "systemd user services not available. Starting rbw-agent manually."
        rbw-agent --daemon
    fi

    echo ""
    print_info "To use the SSH agent, add to your ~/.zshrc:"
    echo "  export SSH_AUTH_SOCK=\"\$XDG_RUNTIME_DIR/rbw/ssh-agent-socket\""
    echo ""
    echo "Test with: ssh-add -l"
}
