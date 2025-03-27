#!/bin/bash

# Stop any existing tmate sessions
pkill -9 tmate 2>/dev/null

# Start tmate session
TMATE_SOCKET="/tmp/tmate.sock"
nohup ./tmate-2.4.0/tmate -S "$TMATE_SOCKET" new-session -d >/dev/null 2>&1 &
sleep 2

# Wait for tmate to be ready
for i in {1..10}; do
    if ./tmate-2.4.0/tmate -S "$TMATE_SOCKET" wait tmate-ready 2>/dev/null; then
        break
    fi
    sleep 2
done

# Get SSH URL
SSH_URL=$("./tmate-2.4.0/tmate" -S "$TMATE_SOCKET" display -p "#{tmate_ssh}")
if [ -z "$SSH_URL" ]; then
    echo "Error: Failed to retrieve SSH URL!"
    exit 1
fi

echo "Tmate session established: $SSH_URL"
echo "$SSH_URL" > ssh_url.txt