#!/bin/bash
# Watch the neptune-core proof directory for new files
# Store this file as `~/bin/watch_and_sync.sh` and add `~/bin/` to your $PATH.

inotifywait -m -r -e create -e moved_to <neptune-core-directory>/test_data/ |
while read path action file; do
    echo "New file detected: $file. Syncing..."
    rsync -avz --ignore-existing --no-perms --no-group --no-times <neptune-core-directory>/test_data/ <user>@<ip-or-url-of-server>:/var/www/triton-vm-proofs/
done
