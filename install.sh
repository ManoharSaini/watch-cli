#!/bin/bash

# watch-cli Installation Script

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check dependencies
check_dependencies() {
    print_info "Checking dependencies..."
    
    local missing_deps=()
    local optional_deps=()
    
    # Required dependencies
    local required_deps=("curl" "fzf" "jq")
    
    for dep in "${required_deps[@]}"; do
        if ! command_exists "$dep"; then
            missing_deps+=("$dep")
        fi
    done
    
    # Check for media player
    local player_found=false
    if command_exists "mpv"; then
        player_found=true
        print_success "Found mpv"
    elif command_exists "vlc"; then
        player_found=true
        print_success "Found vlc"
    fi
    
    if [[ "$player_found" == false ]]; then
        missing_deps+=("mpv or vlc")
    fi
    
    # Optional dependencies
    if ! command_exists "node"; then
        optional_deps+=("node (for peerflix)")
    fi
    
    if ! command_exists "peerflix"; then
        optional_deps+=("peerflix (for torrent streaming)")
    fi
    
    # Report missing dependencies
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing required dependencies:"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        echo ""
        echo "Please install the missing dependencies and try again."
        echo ""
        echo "Ubuntu/Debian:"
        echo "  sudo apt update && sudo apt install curl fzf jq mpv"
        echo ""
        echo "macOS:"
        echo "  brew install curl fzf jq mpv"
        exit 1
    fi
    
    if [[ ${#optional_deps[@]} -gt 0 ]]; then
        print_warning "Optional dependencies not found:"
        for dep in "${optional_deps[@]}"; do
            echo "  - $dep"
        done
        echo ""
        echo "These are optional but recommended for full functionality."
    fi
    
    print_success "All required dependencies found"
}

# Install watch-cli
install_watch_cli() {
    local install_dir="/usr/local/bin"
    local script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/watch-cli"
    
    print_info "Installing watch-cli to $install_dir..."
    
    # Check if we have permission to write to /usr/local/bin
    if [[ -w "$install_dir" ]] || [[ "$EUID" -eq 0 ]]; then
        cp "$script_path" "$install_dir/"
        chmod +x "$install_dir/watch-cli"
        print_success "watch-cli installed to $install_dir"
    else
        print_warning "No permission to write to $install_dir"
        print_info "You can install manually by running:"
        echo "  sudo cp $script_path $install_dir/"
        echo "  sudo chmod +x $install_dir/watch-cli"
    fi
}

# Setup configuration
setup_config() {
    local config_dir="${HOME}/.config/watch-cli"
    local cache_dir="${config_dir}/cache"
    
    print_info "Setting up configuration..."
    
    # Create directories
    mkdir -p "$config_dir"
    mkdir -p "$cache_dir"
    
    # Copy example config if it doesn't exist
    local config_file="${config_dir}/config"
    local example_config="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/config.example"
    
    if [[ ! -f "$config_file" ]] && [[ -f "$example_config" ]]; then
        cp "$example_config" "$config_file"
        print_success "Configuration file created at $config_file"
        print_info "You can edit the configuration to customize settings"
    fi
    
    print_success "Configuration setup complete"
}

# Install peerflix (optional)
install_peerflix() {
    if command_exists "node" && ! command_exists "peerflix"; then
        print_info "Installing peerflix for torrent streaming..."
        
        if npm install -g peerflix; then
            print_success "peerflix installed successfully"
        else
            print_warning "Failed to install peerflix. You can install it manually with:"
            echo "  npm install -g peerflix"
        fi
    fi
}

# Main installation
main() {
    echo "watch-cli Installation Script"
    echo "=============================="
    echo ""
    
    # Check dependencies
    check_dependencies
    
    # Install watch-cli
    install_watch_cli
    
    # Setup configuration
    setup_config
    
    # Install peerflix if requested
    if [[ "${INSTALL_PEERFLIX:-false}" == "true" ]]; then
        install_peerflix
    fi
    
    echo ""
    print_success "Installation complete!"
    echo ""
    echo "Usage:"
    echo "  watch-cli                    # Start interactive interface"
    echo "  watch-cli --help             # Show help"
    echo "  watch-cli --anime            # Go directly to anime search"
    echo ""
    echo "Configuration:"
    echo "  ~/.config/watch-cli/config   # Edit configuration"
    echo ""
    echo "For more information, see the README.md file."
}

# Run main function
main "$@"
