#!/bin/bash

# A program to share the burden of seeding the blocks snapshot
# Example use in crontab:
# 20 2 * * 0 <home-dir>/bin/update-torrent.sh >> /var/log/torrent-update.log 2>&1

TORRENT_URL="http://neptunefundamentals.org:42580/latest-snapshot.torrent"
TORRENT_FILE="/tmp/latest.torrent"
DOWNLOAD_DIR="/var/lib/transmission-daemon/downloads/"

# Download the latest .torrent file
echo "Downloading latest .torrent file"
curl -o "$TORRENT_FILE" "$TORRENT_URL" || {
    echo "Failed to download torrent file from $TORRENT_URL"
    exit 1
}

# Verify torrent file
if ! file "$TORRENT_FILE" | grep -q "BitTorrent"; then
    echo "Error: $TORRENT_FILE is not a valid torrent file"
    exit 1
fi

# Check if there are torrents to remove
TORRENT_LIST=$(transmission-remote --list | grep -v "ID\|Sum:" | awk '{print $1}' | sed 's/\*//g' | grep -E '^[0-9]+$')

if [ -n "$TORRENT_LIST" ]; then
    # Remove existing torrents
    echo "$TORRENT_LIST" | xargs -I{} -n 1 transmission-remote -t {} --remove || {
        echo "Failed to remove existing torrents"
        exit 1
    }
else
    echo "No torrents to remove"
fi

# Add the new torrent
transmission-remote -a "$TORRENT_FILE" || {
    echo "Failed to add new torrent"
    exit 1
}

# Clean up
rm -f "$TORRENT_FILE"

KEEP_COUNT=1
FILENAME_PREFIX="neptune-mainnet-blocks"
cd "$DOWNLOAD_DIR"
(ls -tp | grep -E "^${FILENAME_PREFIX}-.*\.tar\.gz$" | tail -n +$((KEEP_COUNT + 1)) | xargs -r rm)
(ls -tp | grep -E '^${FILENAME_PREFIX}-.*\.tar\.gz\.torrent$' | tail -n +$((KEEP_COUNT + 1)) | xargs -r rm)
echo "Done cleaning up"
