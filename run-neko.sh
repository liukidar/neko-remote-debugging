#!/bin/bash

# Function to check if a port is available
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

# Function to find next available port starting from given port
find_available_port() {
    local start_port=$1
    local port=$start_port
    
    while ! check_port_available "$port"; do
        ((port++))
        if [ "$port" -gt 65535 ]; then
            echo "Error: No available ports found" >&2
            exit 1
        fi
    done
    
    echo "$port"
}

# Default values
DEFAULT_SERVER_PORT=8080
DEFAULT_DEBUG_PORT=9223
DEFAULT_CHROME_PROFILE="./chrome-profile"
USE_HOST_NETWORK=true  # Default to host network for better WebRTC connectivity

# Parse command line arguments
SERVER_PORT=""
DEBUG_PORT=""
CHROME_PROFILE=""

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
        --host-network)
            USE_HOST_NETWORK=true
            shift
            ;;
        --no-host-network)
            USE_HOST_NETWORK=false
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -s, --server-port PORT     Neko server port (default: 8080)"
            echo "  -d, --debug-port PORT      Remote debugging port (default: 9223)"
            echo "  -p, --chrome-profile PATH  Chrome profile path (default: ./chrome-profile)"
            echo "  --host-network             Use host networking (default, better for WebRTC)"
            echo "  --no-host-network          Use bridge networking with port mapping"
            echo "  -h, --help                 Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                                    # Use defaults"
            echo "  $0 -s 8080 -d 9223                  # Specify ports"
            echo "  $0 -p /path/to/chrome-profile       # Custom profile path"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Use -h or --help for usage information" >&2
            exit 1
            ;;
    esac
done

# Set defaults if not provided
if [ -z "$SERVER_PORT" ]; then
    SERVER_PORT=$(find_available_port $DEFAULT_SERVER_PORT)
    echo "Using server port: $SERVER_PORT"
fi

if [ -z "$DEBUG_PORT" ]; then
    DEBUG_PORT=$(find_available_port $DEFAULT_DEBUG_PORT)
    echo "Using debug port: $DEBUG_PORT"
fi

if [ -z "$CHROME_PROFILE" ]; then
    CHROME_PROFILE="$DEFAULT_CHROME_PROFILE"
fi

# Validate that ports are available if explicitly provided
if ! check_port_available "$SERVER_PORT"; then
    echo "Error: Server port $SERVER_PORT is not available" >&2
    exit 1
fi

if ! check_port_available "$DEBUG_PORT"; then
    echo "Error: Debug port $DEBUG_PORT is not available" >&2
    exit 1
fi

# Get absolute path for chrome profile
CHROME_PROFILE_ABS=$(readlink -f "$CHROME_PROFILE")

# Create chrome profile directory if it doesn't exist
if [ ! -d "$CHROME_PROFILE_ABS" ]; then
    echo "Creating chrome profile directory: $CHROME_PROFILE_ABS"
    mkdir -p "$CHROME_PROFILE_ABS"
fi

# Function to get local IP address
get_local_ip() {
    # Try to get the main interface IP
    if command -v ip >/dev/null 2>&1; then
        ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+' | head -1
    elif command -v hostname >/dev/null 2>&1; then
        hostname -I | awk '{print $1}'
    else
        echo "127.0.0.1"
    fi
}

# Get local IP for NAT1TO1 configuration
LOCAL_IP=$(get_local_ip)

# Build and run the Docker command
echo "Starting Neko with:"
echo "  Server port: $SERVER_PORT"
echo "  Debug port: $DEBUG_PORT"
echo "  Chrome profile: $CHROME_PROFILE_ABS"
echo "  Local IP: $LOCAL_IP"
echo ""

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "Error: Docker is not running or not accessible" >&2
    exit 1
fi

# Check if the image exists
if ! docker image inspect neko-debug >/dev/null 2>&1; then
    echo "Warning: Docker image 'neko-debug' not found locally"
    echo "You may need to build it first or use a different image name"
    echo ""
fi

# Run the Docker container with improved network configuration
if [ "$USE_HOST_NETWORK" = true ]; then
    echo "Using host networking mode for better WebRTC connectivity"
    exec docker run \
        -v "$CHROME_PROFILE_ABS:/home/neko/chrome-profile" \
        --shm-size=2gb \
        --cap-add=SYS_ADMIN \
        --rm \
        --network=host \
        -e "NEKO_DESKTOP_SCREEN=1920x1080@30" \
        -e "NEKO_MEMBER_MULTIUSER_USER_PASSWORD=neko" \
        -e "NEKO_MEMBER_MULTIUSER_ADMIN_PASSWORD=admin" \
        -e "NEKO_WEBRTC_EPR=52000-52100" \
        -e "NEKO_WEBRTC_ICELITE=1" \
        -e "NEKO_NAT1TO1=$LOCAL_IP" \
        -e "NEKO_WEBRTC_STUN=stun:stun.l.google.com:19302" \
        -e "NEKO_BIND=0.0.0.0:$SERVER_PORT" \
        neko-debug
else
    echo "Using bridge networking mode with port mapping"
exec docker run \
    -p "$SERVER_PORT:8080" \
    -p "$DEBUG_PORT:9223" \
        -p "52000-52100:52000-52100/udp" \
    -v "$CHROME_PROFILE_ABS:/home/neko/chrome-profile" \
    --shm-size=2gb \
    --cap-add=SYS_ADMIN \
    --rm \
        -e "NEKO_DESKTOP_SCREEN=1920x1080@30" \
        -e "NEKO_MEMBER_MULTIUSER_USER_PASSWORD=neko" \
        -e "NEKO_MEMBER_MULTIUSER_ADMIN_PASSWORD=admin" \
        -e "NEKO_WEBRTC_EPR=52000-52100" \
        -e "NEKO_WEBRTC_ICELITE=1" \
        -e "NEKO_NAT1TO1=$LOCAL_IP" \
        -e "NEKO_WEBRTC_STUN=stun:stun.l.google.com:19302" \
    neko-debug
fi