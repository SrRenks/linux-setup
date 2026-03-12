#!/usr/bin/env bash

# ==============================
# Logging and silent execution
# ==============================

if ! { true >&3; } 2>/dev/null; then
  exec 3>&1 4>&2
fi

print_info() { echo -e "\033[0;32m[INFO]\033[0m $1" >&3; }
print_warn() { echo -e "\033[0;33m[WARN]\033[0m $1" >&3; }
print_error() { echo -e "\033[0;31m[ERROR]\033[0m $1" >&3; }

run_with_spinner() {
    local desc="$1"
    shift
    local log_file
    log_file=$(mktemp)
    local pid

    echo -n "$desc... " >&3

    "$@" &> "$log_file" &
    pid=$!

    local spin='-\|/'
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i+1) % 4 ))
        printf "\b${spin:$i:1}" >&3
        sleep 0.1
    done
    printf "\b" >&3

    wait "$pid"
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        echo -e "\033[0;32mOK\033[0m" >&3
        rm -f "$log_file"
        return 0
    else
        echo -e "\033[0;31mFAILED\033[0m" >&3
        echo "Error running: $*" >&3
        echo "Exit code: $exit_code" >&3
        echo "--- Output ---" >&3
        cat "$log_file" >&3
        echo "--------------" >&3
        rm -f "$log_file"
        return $exit_code
    fi
}

run_with_info() {
    local desc="$1"
    shift
    echo ""
    print_info "$desc"
    "$@"
}

run_interactive() {
    "$@"
}

detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_ID="$ID"
    else
        print_error "Cannot detect Linux distribution."
        exit 1
    fi

    case "$OS_ID" in
        debian|ubuntu|linuxmint|pop|elementary|zorin)
            DISTRO_FAMILY="debian"
            ;;
        fedora|rhel|centos|rocky|alma)
            DISTRO_FAMILY="redhat"
            ;;
        arch|manjaro|endeavouros|garuda)
            DISTRO_FAMILY="arch"
            ;;
        opensuse*|suse)
            DISTRO_FAMILY="suse"
            ;;
        alpine)
            DISTRO_FAMILY="alpine"
            ;;
        *)
            print_error "Unsupported distribution: $OS_ID"
            exit 1
            ;;
    esac
    print_info "Detected distribution family: $DISTRO_FAMILY"
}

install_packages() {
    local packages=("$@")
    print_info "Installing system packages: ${packages[*]}"

    case "$DISTRO_FAMILY" in
        debian)
            run_with_spinner "Updating package lists" sudo apt update
            run_with_spinner "Installing packages" sudo apt install -y "${packages[@]}"
            if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
                run_with_spinner "Creating bat symlink" sudo ln -sf "$(command -v batcat)" /usr/local/bin/bat
            fi
            ;;
        redhat)
            run_with_spinner "Installing packages" sudo dnf install -y "${packages[@]}"
            ;;
        arch)
            run_with_spinner "Installing packages" sudo pacman -S --noconfirm "${packages[@]}"
            ;;
        suse)
            run_with_spinner "Installing packages" sudo zypper install -y "${packages[@]}"
            ;;
        alpine)
            run_with_spinner "Installing packages" sudo apk add "${packages[@]}"
            ;;
        *) print_error "Unsupported package manager"; exit 1 ;;
    esac
}