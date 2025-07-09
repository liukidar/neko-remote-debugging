#!/bin/bash

# Neko Docker Runner Script
# A script to run Neko (browser sharing) in a Docker container with configurable options

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# =============================================================================
# CONSTANTS AND DEFAULTS
# =============================================================================

readonly SCRIPT_NAME="$(basename "$0")"
readonly DEFAULT_SERVER_PORT=8080
readonly DEFAULT_DEBUG_PORT=9223
readonly DEFAULT_CHROME_PROFILE="./chrome-profile"
readonly DEFAULT_IMAGE_NAME="neko-debug"

# Chrome flags
readonly WSL_CHROME_FLAGS="--no-sandbox --no-zygote"

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Print colored output
print_info() {
    echo -e "\033[34m[INFO]\033[0m $1"
}

print_success() {
    echo -e "\033[32m[SUCCESS]\033[0m $1"
}

print_warning() {
    echo -e "\033[33m[WARNING]\033[0m $1"
}

print_error() {
    echo -e "\033[31m[ERROR]\033[0m $1" >&2
}

# Check if running in WSL environment
is_wsl() {
    [[ -n "${WSL_DISTRO_NAME:-}" ]] || [[ -f /proc/version ]] && grep -qi "microsoft\|wsl" /proc/version 2>/dev/null
}

# Check if a port is available
check_port_available() {
    local port=$1
    
    if command -v nc >/dev/null 2>&1; then
        ! nc -z localhost "$port" 2>/dev/null
    elif command -v netstat >/dev/null 2>&1; then
        ! netstat -tuln | grep -q ":$port "
    elif command -v ss >/dev/null 2>&1; then
        ! ss -tuln | grep -q ":$port "
    else
        # Fallback: try to bind to the port
        ! timeout 1 bash -c "exec 3<>/dev/tcp/localhost/$port" 2>/dev/null
    fi
}

# Find next available port starting from given port
find_available_port() {
    local start_port=$1
    local port=$start_port
    
    while ! check_port_available "$port"; do
        ((port++))
        if [ "$port" -gt 65535 ]; then
            print_error "No available ports found starting from $start_port"
            exit 1
        fi
    done
    
    echo "$port"
}

# Get local IP address for NAT configuration
get_local_ip() {
    if command -v ip >/dev/null 2>&1; then
        ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+' | head -1
    elif command -v hostname >/dev/null 2>&1; then
        hostname -I | awk '{print $1}'
    else
        echo "127.0.0.1"
    fi
}

# =============================================================================
# DOCKER FUNCTIONS
# =============================================================================

# Check if Docker is running
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker is not running or not accessible"
        exit 1
    fi
}

# Build Docker image if needed
build_image_if_needed() {
    local image_name=$1
    local force_build=$2
    
    if $force_build || ! docker image inspect "$image_name" >/dev/null 2>&1; then
        if $force_build; then
            print_info "Force rebuilding Docker image '$image_name'..."
        else
            print_warning "Docker image '$image_name' not found locally"
            print_info "Building image '$image_name' from Dockerfile..."
        fi

        if [ ! -f Dockerfile ]; then
            print_error "No Dockerfile found in $(pwd). Cannot build image."
            exit 1
        fi

        if ! docker build -t "$image_name" .; then
            print_error "Failed to build Docker image '$image_name'"
            exit 1
        fi

        print_success "Successfully built image '$image_name'"
    fi
}

# Clean up all Neko-related containers and images
cleanup_neko() {
    print_info "Stopping and removing all Neko-related Docker containers and images..."
    
    # Remove chrome profile directory
    rm -rf "$DEFAULT_CHROME_PROFILE"
    
    # Find and stop all containers with 'neko' in their image or name
    local containers
    containers=$(docker ps -a --filter "ancestor=neko-debug" --filter "ancestor=neko-debug2" --filter "ancestor=neko" --format "{{.ID}}" 2>/dev/null || true)
    
    if [ -n "$containers" ]; then
        print_info "Stopping containers: $containers"
        docker stop $containers
        print_info "Removing containers..."
        docker rm $containers
    else
        print_success "No running Neko containers found."
    fi

    # Remove all images with neko in the name
    local images
    images=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep neko || true)
    
    if [ -n "$images" ]; then
        print_info "Removing images: $images"
        docker rmi -f $images
    else
        print_success "No Neko images found."
    fi

    print_success "Neko cleanup completed."
}

# =============================================================================
# MAIN FUNCTIONS
# =============================================================================

# Display help message
show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Run Neko (browser sharing) in a Docker container with configurable options.

Options:
  -s, --server-port PORT     Neko server port (default: $DEFAULT_SERVER_PORT)
  -d, --debug-port PORT      Remote debugging port (default: $DEFAULT_DEBUG_PORT)
  -p, --chrome-profile PATH  Chrome profile path (default: $DEFAULT_CHROME_PROFILE)
  -i, --image NAME           Docker image name (default: $DEFAULT_IMAGE_NAME)
  -c, --chrome-flags FLAGS   Additional Chrome flags to append
  --host-network             Use host networking (default, better for WebRTC)
  --no-host-network          Use bridge networking with port mapping
  --clear                    Stop and remove all Neko containers and images
  -b, --build                Force rebuild Docker image
  -h, --help                 Show this help message

Examples:
  $SCRIPT_NAME                                    # Use defaults
  $SCRIPT_NAME -s 8080 -d 9223                   # Specify ports
  $SCRIPT_NAME -p /path/to/chrome-profile        # Custom profile path
  $SCRIPT_NAME -i neko-custom                    # Custom Docker image
  $SCRIPT_NAME -c "--disable-gpu --disable-dev-shm-usage"  # Additional Chrome flags
  $SCRIPT_NAME --clear                           # Clean up all Neko resources

Environment Detection:
  - Automatically detects WSL environment and applies appropriate Chrome flags
  - WSL: $WSL_CHROME_FLAGS + additional flags
  - Normal: additional flags

EOF
}

# Parse command line arguments
parse_arguments() {
    # Initialize variables
    SERVER_PORT=""
    DEBUG_PORT=""
    CHROME_PROFILE=""
    IMAGE_NAME="$DEFAULT_IMAGE_NAME"
    USE_HOST_NETWORK=true
    FORCE_BUILD=false
    CLEAR=false
    ADDITIONAL_CHROME_FLAGS=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--server-port)
                SERVER_PORT="$2"
                shift 2
                ;;
            -d|--debug-port)
                DEBUG_PORT="$2"
                shift 2
                ;;
            -p|--chrome-profile)
                CHROME_PROFILE="$2"
                shift 2
                ;;
            -i|--image)
                IMAGE_NAME="neko-$2"
                shift 2
                ;;
            -c|--chrome-flags)
                ADDITIONAL_CHROME_FLAGS="$2"
                shift 2
                ;;
            --host-network)
                USE_HOST_NETWORK=true
                shift
                ;;
            --no-host-network)
                USE_HOST_NETWORK=false
                shift
                ;;
            --clear)
                CLEAR=true
                shift
                ;;
            -b|--build)
                FORCE_BUILD=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                print_error "Use -h or --help for usage information"
                exit 1
                ;;
        esac
    done
}

# Set default values for unspecified options
set_defaults() {
    if [ -z "$SERVER_PORT" ]; then
        SERVER_PORT=$(find_available_port $DEFAULT_SERVER_PORT)
        print_info "Using server port: $SERVER_PORT"
    fi

    if [ -z "$DEBUG_PORT" ]; then
        DEBUG_PORT=$(find_available_port $DEFAULT_DEBUG_PORT)
        print_info "Using debug port: $DEBUG_PORT"
    fi

    if [ -z "$CHROME_PROFILE" ]; then
        CHROME_PROFILE="$DEFAULT_CHROME_PROFILE"
    fi
}

# Validate configuration
validate_config() {
    # Validate that ports are available if explicitly provided
    if ! check_port_available "$SERVER_PORT"; then
        print_error "Server port $SERVER_PORT is not available"
        exit 1
    fi

    if ! check_port_available "$DEBUG_PORT"; then
        print_error "Debug port $DEBUG_PORT is not available"
        exit 1
    fi
}

# Setup Chrome profile directory
setup_chrome_profile() {
    local chrome_profile_abs
    chrome_profile_abs=$(readlink -f "$CHROME_PROFILE")
    
    if [ ! -d "$chrome_profile_abs" ]; then
        print_info "Creating chrome profile directory: $chrome_profile_abs"
        mkdir -p "$chrome_profile_abs"
    fi
    
    CHROME_PROFILE_ABS="$chrome_profile_abs"
}

# Run the Neko container
run_neko_container() {
    local local_ip
    local_ip=$(get_local_ip)
    
    # Build Chrome flags based on environment
    local chrome_flags=""
    
    if is_wsl; then
        chrome_flags="$WSL_CHROME_FLAGS"
        print_info "Detected WSL environment, using WSL-specific Chrome flags"
    fi

    # Add additional Chrome flags if provided
    if [ -n "$ADDITIONAL_CHROME_FLAGS" ]; then
        chrome_flags="$chrome_flags $ADDITIONAL_CHROME_FLAGS"
        print_info "Adding additional Chrome flags: $ADDITIONAL_CHROME_FLAGS"
    fi
    
    print_info "Starting Neko with:"
    print_info "  Server port: $SERVER_PORT"
    print_info "  Debug port: $DEBUG_PORT"
    print_info "  Chrome profile: $CHROME_PROFILE_ABS"
    print_info "  Local IP: $local_ip"
    print_info "  Chrome flags: $chrome_flags"
    print_info "  Environment: $(is_wsl && echo "WSL" || echo "Normal")"
    echo ""

    # Build Docker run command
    local docker_args=(
        run
        -p "$SERVER_PORT:8080"
        -p "$DEBUG_PORT:9223"
        -e "NEKO_WEBRTC_NAT1TO1=$local_ip"
        -e "NEKO_CHROME_FLAGS=$chrome_flags"
    )

    if [ "$USE_HOST_NETWORK" = true ]; then
        print_info "Using host networking mode for better WebRTC connectivity"
    else
        print_info "Using bridge networking mode with port mapping"
    fi

    # Run the container
    exec docker "${docker_args[@]}" "$IMAGE_NAME"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    parse_arguments "$@"
    
    # Handle cleanup option
    if [ "$CLEAR" = true ]; then
        cleanup_neko
        exit 0
    fi
    
    # Setup and validation
    check_docker
    set_defaults
    validate_config
    setup_chrome_profile
    build_image_if_needed "$IMAGE_NAME" "$FORCE_BUILD"
    
    # Run the container
    run_neko_container
}

# Run main function with all arguments
main "$@"