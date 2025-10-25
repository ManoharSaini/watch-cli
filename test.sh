#!/bin/bash

# Simple test script for watch-cli

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

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Test dependencies
test_dependencies() {
    print_info "Testing dependencies..."
    
    local missing_deps=()
    local required_deps=("curl" "fzf" "jq")
    
    for dep in "${required_deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        return 1
    fi
    
    print_success "All dependencies found"
    return 0
}

# Test provider scripts
test_providers() {
    print_info "Testing provider scripts..."
    
    local providers=("allanime.sh" "internet_archive.sh" "goku.sh" "peerflix.sh")
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    for provider in "${providers[@]}"; do
        local provider_path="${script_dir}/providers/${provider}"
        
        if [[ -f "$provider_path" ]]; then
            if [[ -x "$provider_path" ]]; then
                print_success "Provider $provider is executable"
            else
                print_error "Provider $provider is not executable"
                return 1
            fi
        else
            print_error "Provider $provider not found"
            return 1
        fi
    done
    
    print_success "All provider scripts found and executable"
    return 0
}

# Test main script
test_main_script() {
    print_info "Testing main script..."
    
    local script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/watch-cli"
    
    if [[ -f "$script_path" ]]; then
        if [[ -x "$script_path" ]]; then
            print_success "Main script is executable"
        else
            print_error "Main script is not executable"
            return 1
        fi
    else
        print_error "Main script not found"
        return 1
    fi
    
    # Test help option
    if "$script_path" --help >/dev/null 2>&1; then
        print_success "Help option works"
    else
        print_error "Help option failed"
        return 1
    fi
    
    # Test version option
    if "$script_path" --version >/dev/null 2>&1; then
        print_success "Version option works"
    else
        print_error "Version option failed"
        return 1
    fi
    
    return 0
}

# Test configuration
test_config() {
    print_info "Testing configuration..."
    
    local config_dir="${HOME}/.config/watch-cli"
    local cache_dir="${config_dir}/cache"
    
    # Create directories if they don't exist
    mkdir -p "$config_dir"
    mkdir -p "$cache_dir"
    
    if [[ -d "$config_dir" ]]; then
        print_success "Configuration directory exists"
    else
        print_error "Configuration directory not found"
        return 1
    fi
    
    if [[ -d "$cache_dir" ]]; then
        print_success "Cache directory exists"
    else
        print_error "Cache directory not found"
        return 1
    fi
    
    return 0
}

# Run all tests
main() {
    echo "watch-cli Test Suite"
    echo "===================="
    echo ""
    
    local tests_passed=0
    local tests_total=0
    
    # Test dependencies
    tests_total=$((tests_total + 1))
    if test_dependencies; then
        tests_passed=$((tests_passed + 1))
    fi
    
    # Test providers
    tests_total=$((tests_total + 1))
    if test_providers; then
        tests_passed=$((tests_passed + 1))
    fi
    
    # Test main script
    tests_total=$((tests_total + 1))
    if test_main_script; then
        tests_passed=$((tests_passed + 1))
    fi
    
    # Test configuration
    tests_total=$((tests_total + 1))
    if test_config; then
        tests_passed=$((tests_passed + 1))
    fi
    
    echo ""
    echo "Test Results: $tests_passed/$tests_total tests passed"
    
    if [[ $tests_passed -eq $tests_total ]]; then
        print_success "All tests passed! watch-cli is ready to use."
        return 0
    else
        print_error "Some tests failed. Please check the errors above."
        return 1
    fi
}

# Run main function
main "$@"
