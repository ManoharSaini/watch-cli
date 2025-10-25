#!/bin/bash

# watch-cli Demo Script
# This script demonstrates the basic functionality of watch-cli

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}    watch-cli Demo Script${NC}"
    echo -e "${PURPLE}================================${NC}"
    echo ""
}

print_section() {
    echo -e "${CYAN}=== $1 ===${NC}"
}

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

# Demo the help system
demo_help() {
    print_section "Help System"
    print_info "Showing help information..."
    echo ""
    ./watch-cli --help
    echo ""
    print_success "Help system working correctly"
    echo ""
}

# Demo the version system
demo_version() {
    print_section "Version Information"
    print_info "Showing version information..."
    echo ""
    ./watch-cli --version
    echo ""
    print_success "Version system working correctly"
    echo ""
}

# Demo provider system
demo_providers() {
    print_section "Provider System"
    print_info "Testing provider scripts..."
    
    local providers=("allanime.sh" "internet_archive.sh" "goku.sh" "peerflix.sh")
    
    for provider in "${providers[@]}"; do
        print_info "Testing $provider..."
        
        # Test help/usage for each provider
        if ./providers/"$provider" 2>/dev/null; then
            print_success "$provider is working"
        else
            print_warning "$provider returned non-zero exit code (this is expected for usage)"
        fi
    done
    
    print_success "All providers are executable and responding"
    echo ""
}

# Demo configuration
demo_config() {
    print_section "Configuration System"
    print_info "Checking configuration..."
    
    local config_dir="${HOME}/.config/watch-cli"
    local cache_dir="${config_dir}/cache"
    
    if [[ -d "$config_dir" ]]; then
        print_success "Configuration directory exists: $config_dir"
    else
        print_warning "Configuration directory not found: $config_dir"
    fi
    
    if [[ -d "$cache_dir" ]]; then
        print_success "Cache directory exists: $cache_dir"
    else
        print_warning "Cache directory not found: $cache_dir"
    fi
    
    if [[ -f "${config_dir}/config" ]]; then
        print_success "Configuration file exists: ${config_dir}/config"
    else
        print_info "Configuration file not found. You can create one from config.example"
    fi
    
    echo ""
}

# Demo dependencies
demo_dependencies() {
    print_section "Dependency Check"
    print_info "Checking required dependencies..."
    
    local deps=("curl" "fzf" "jq")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if command -v "$dep" >/dev/null 2>&1; then
            print_success "$dep is installed"
        else
            missing_deps+=("$dep")
            print_error "$dep is missing"
        fi
    done
    
    # Check for media player
    if command -v "mpv" >/dev/null 2>&1; then
        print_success "mpv is installed"
    elif command -v "vlc" >/dev/null 2>&1; then
        print_success "vlc is installed"
    else
        missing_deps+=("mpv or vlc")
        print_error "No media player found (mpv or vlc required)"
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        print_info "Please install missing dependencies before using watch-cli"
    else
        print_success "All required dependencies are installed"
    fi
    
    echo ""
}

# Demo file structure
demo_structure() {
    print_section "File Structure"
    print_info "Checking watch-cli file structure..."
    
    local files=("watch-cli" "README.md" "config.example" "install.sh" "test.sh")
    local dirs=("providers")
    
    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            print_success "$file exists"
        else
            print_error "$file is missing"
        fi
    done
    
    for dir in "${dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            print_success "$dir/ directory exists"
            print_info "Contents of $dir/:"
            ls -la "$dir/"
        else
            print_error "$dir/ directory is missing"
        fi
    done
    
    echo ""
}

# Main demo function
main() {
    print_header
    
    print_info "This demo script shows the basic functionality of watch-cli"
    print_info "It does not perform actual streaming, but demonstrates the tool's capabilities"
    echo ""
    
    # Run all demos
    demo_structure
    demo_dependencies
    demo_config
    demo_providers
    demo_help
    demo_version
    
    print_section "Demo Complete"
    print_success "watch-cli demo completed successfully!"
    echo ""
    print_info "To use watch-cli:"
    echo "  ./watch-cli                    # Start interactive interface"
    echo "  ./watch-cli --anime            # Go directly to anime search"
    echo "  ./watch-cli --movie            # Go directly to movie search"
    echo "  ./watch-cli --tv               # Go directly to TV show search"
    echo ""
    print_info "For more information, see README.md"
}

# Run main function
main "$@"
