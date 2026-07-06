#!/bin/bash

# Define the base directory to search within
BASE_DIR="/home/<user>/repos/neptune-core"
DEST="<dest>:/var/www/neptune-core-proofs/"

echo "Searching for 'test_data' directories in $BASE_DIR..."

# 1. Find all directories named "test_data" and store them in an array
# We use mapfile (readarray) so this safely handles paths even if they contain spaces
mapfile -t WATCH_DIRS < <(find "$BASE_DIR" -type d -name "test_data")

# 2. Check if we actually found any directories before proceeding
if [ ${#WATCH_DIRS[@]} -eq 0 ]; then
    echo "Error: No 'test_data' directories found. Exiting."
    exit 1
fi

echo "Found ${#WATCH_DIRS[@]} directories. Starting monitor..."
for dir in "${WATCH_DIRS[@]}"; do
    echo " - $dir"
done

# 3. Pass the entire array to inotifywait
inotifywait -m -r -e create -e moved_to "${WATCH_DIRS[@]}" |
while read -r path action file; do
    echo "New file detected: $file in $path. Syncing..."

    # 4. Determine which base test_data directory this event belongs to
    for watch_dir in "${WATCH_DIRS[@]}"; do
        # Add a trailing slash for safe string matching
        watch_dir_trailing="${watch_dir%/}/"

        # If the event path starts with our watched directory path, trigger the sync
        if [[ "$path" == "$watch_dir_trailing"* ]]; then
            rsync -avz --ignore-existing --no-perms --no-group --no-times "$watch_dir_trailing" "$DEST"
            break # Exit the loop once we find the match and sync
        fi
    done
done
