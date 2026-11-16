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
SPACE_MARGIN_BYTES=$((20 * 1024 * 1024 * 1024))   # refuse to run if less than this would be left free
TIMESTAMP=$(date +%Y-%m-%d)
FILENAME_PREFIX="neptune-mainnet-blocks-<username>"
TARBALL="${DEST_DIR}/${FILENAME_PREFIX}-${TIMESTAMP}.tar.gz"   # note: not actually gzipped (tar cf, no z)
TORRENT="${TARBALL}.torrent"
PARTIAL="${TARBALL}.partial"
PUBLIC_TORRENT="/var/www/neptune-core-proofs/latest-snapshot.torrent"
AUTH="transmission:<password>"
 
mkdir -p "$DEST_DIR"
 
# Never leave a half-written tarball behind, whatever step fails.
trap 'rm -f "$PARTIAL"' EXIT
 
 
# Step 0: Pre-flight space check. Fail early instead of filling the disk
# (a full disk can also take down the running neptune node).
SOURCE_BYTES=$(du -sb "$SOURCE_DIR" | awk '{print $1}')
AVAIL_BYTES=$(df --output=avail -B1 "$DEST_DIR" | tail -n 1 | tr -d ' ')
if (( AVAIL_BYTES < SOURCE_BYTES + SPACE_MARGIN_BYTES )); then
    echo "Not enough space in $DEST_DIR: need $SOURCE_BYTES + margin, have $AVAIL_BYTES. Aborting." >&2
    exit 1
fi
 
 
# Step 1: Create tarball. Write to a .partial file and rename only on success.
echo "Creating tarball"
tar cf - -P "$SOURCE_DIR" | pv -s "$SOURCE_BYTES" > "$PARTIAL"
mv "$PARTIAL" "$TARBALL"
chmod 644 "$TARBALL"   # transmission-daemon's user must be able to read it
echo "Done creating tarball"
 
 
# Step 2: Create torrent with multiple trackers
TRACKER_ARGS=()
for TRACKER in "${TRACKERS[@]}"; do
    TRACKER_ARGS+=(-t "$TRACKER")
done
 
echo "Creating torrent"
rm -f "$TORRENT"   # transmission-create refuses to overwrite on a same-day re-run
transmission-create -o "$TORRENT" "${TRACKER_ARGS[@]}" "$TARBALL"
echo "Done creating torrent"
 
 
# Step 3: Drop old torrents from transmission. Use --remove (not
# --remove-and-delete): the data lives in $DEST_DIR and is cleaned up in
# Step 6.
TORRENT_LIST=$(transmission-remote -n "$AUTH" --list | grep "$FILENAME_PREFIX" | awk '{print $1}' | sed 's/\*//g' | grep -E '^[0-9]+$' || true)
if [ -n "$TORRENT_LIST" ]; then
    echo "Removing old torrents from transmission"
    echo "$TORRENT_LIST" | xargs -I{} -n 1 transmission-remote -n "$AUTH" -t {} --remove
else
    echo "No torrents to remove"
fi
 
 
# Step 4: Seed directly from $DEST_DIR -- no copy into transmission's
# downloads dir. -w together with --add sets this torrent's download dir;
# transmission verifies the existing file and starts seeding.
echo "Adding torrent to transmission"
transmission-remote -n "$AUTH" --add "$TORRENT" -w "$DEST_DIR"
echo "Done adding torrent"
 
 
# Step 5: Serve torrent file from "proof server"
echo "Copy torrent file to file server directory"
cp "$TORRENT" "$PUBLIC_TORRENT"
chmod 664 "$PUBLIC_TORRENT"
echo "Done copying torrent file to file server directory"
 
 
# Step 6: Cleanup old tarballs and torrents (keep last $KEEP_COUNT)
echo "Cleaning up old tarballs in $DEST_DIR"
cd "$DEST_DIR"
ls -tp | grep -E "^${FILENAME_PREFIX}-.*\.tar\.gz$"         | tail -n +$((KEEP_COUNT + 1)) | xargs -r rm -f
ls -tp | grep -E "^${FILENAME_PREFIX}-.*\.tar\.gz\.torrent$" | tail -n +$((KEEP_COUNT + 1)) | xargs -r rm -f
echo "Done cleaning up"
