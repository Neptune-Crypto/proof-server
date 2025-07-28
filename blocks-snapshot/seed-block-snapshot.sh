#!/bin/bash

set -euo pipefail

SOURCE_DIR="$HOME/.local/share/neptune/main/blocks/"
DEST_DIR="/srv/torrents"
TRACKERS=(
    "udp://tracker.openbittorrent.com:80/announce"
    "udp://tracker.opentrackr.org:1337/announce"
    "udp://tracker.coppersurfer.tk:6969/announce"
    "udp://tracker.leechers-paradise.org:6969/announce"
)

KEEP_COUNT=1
TIMESTAMP=$(date +%Y-%m-%d)
FILENAME_PREFIX="neptune-mainnet-blocks-<tag>"
TARBALL="${DEST_DIR}/${FILENAME_PREFIX}-${TIMESTAMP}.tar.gz"
TORRENT="${TARBALL}.torrent"
AUTH="<transmission-user>:<transmission-password>"

mkdir -p "$DEST_DIR" # Make sure you have the priviliges to do this


# Step 1: Create tarball
# tar -czf "$TARBALL" -C "$SOURCE_DIR" .
echo "Creating tarball"
tar cvf - "$SOURCE_DIR" -P | pv -s $(du -sb "$SOURCE_DIR" | awk '{print $1}') > "$TARBALL"
echo "Done creating tarball"


# Step 2: Remove old torrents, allow for empty --list output with `|| true`.
echo "Getting list. AUTH is '$AUTH'"
TORRENT_LIST=$(transmission-remote -n "$AUTH" --list || true | grep -v "ID\|Sum:" | awk '{print $1}' | sed 's/\*//g' | grep -E '^[0-9]+$')

echo "Removing old torrents"
if [ -n "$TORRENT_LIST" ]; then
    # Remove existing torrents
    echo "$TORRENT_LIST" | xargs -I{} -n 1 transmission-remote -n "$AUTH" -t {} --remove || {
        echo "Failed to remove existing torrents"
        exit 1
    }
else
    echo "No torrents to remove"
fi

# Step 3: Create torrent with multiple trackers
TRACKER_ARGS=()
for TRACKER in "${TRACKERS[@]}"; do
    TRACKER_ARGS+=(-t "$TRACKER")
done

echo "Creating torrent"
transmission-create -n "$AUTH" -o "$TORRENT" "${TRACKER_ARGS[@]}" "$TARBALL"
echo "Done creating torrent"


# Step 3: Move files to seeding directory
echo "Moving files to seeding directory"
SEED_DIR="/var/lib/transmission-daemon/downloads"
cp "$TARBALL" "$SEED_DIR"
echo "Done moving files"


# Step 4: Reload transmission-daemon to pick up new torrent
echo "Reloading transmission daemon to pick up new torrent"
transmission-remote -n "$AUTH" --add "$TORRENT"
echo "Done reloading"


# Step 5: Serve torrent file from "proof server"
PUBLIC_TORRENT="/var/www/<http-server-name>/latest-snapshot.torrent"
echo "Copy torrent file to file server directory"
cp "$TORRENT" "$PUBLIC_TORRENT"
chmod 664 "$PUBLIC_TORRENT"
echo "Done copying torrent file to file server directory"


# Step 6: Cleanup old tarballs and torrents (keep last $KEEP_COUNT)
echo "Cleaning up old tarballs in $DEST_DIR"
cd "$DEST_DIR"
(ls -tp | grep -E "^${FILENAME_PREFIX}-.*\.tar\.gz$" | tail -n +$((KEEP_COUNT + 1)) | xargs -r rm)
(ls -tp | grep -E '^${FILENAME_PREFIX}-.*\.tar\.gz\.torrent$' | tail -n +$((KEEP_COUNT + 1)) | xargs -r rm)
cd "$SEED_DIR"
(ls -tp | grep -E "^${FILENAME_PREFIX}-.*\.tar\.gz$" | tail -n +$((KEEP_COUNT + 1)) | xargs -r rm)
echo "Done cleaning up"
