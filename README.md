# proof-server
Resources for running a proof server, serving Triton VM proofs and other cryptographic data for faster test suite execution.

The setup uses nginx to share the proofs, in cleartext, through HTTP. And it uses "rsync"
and "inotify" to upload the proof files from the workstation to the server. Due to scope
creep, this system now also serves block data.

## Setup
### Linux

#### Workstation, where the proofs are generated
1. Store the three files where described in the files, one nginx file on the server, and two files on the workstation. 
Then add the missing values to the files: username, ip or URLs, directory paths etc.

2. Install programs for automatically sending proof files from workstation to server:
- `sudo apt update`
- `sudo apt install rsync inotify-tools`

3. Set up SSH key-based authentication between your desktop and the remote machine. Use these instructions to set up a special-purpose SSH key that is only allowed to execute rsync-related commands on the remote server.
- `ssh-keygen -t ed25519 -N "" -f ~/.ssh/rsync-triton-vm`
- `cat ~/.ssh/rsync-triton-vm.pub` and copy the public key (the entire line).
- On the remove server, add the following line to `~/.ssh/authorized_keys`:

```
command="/usr/bin/rrsync /var/www/triton-vm-proofs",no-agent-forwarding,no-port-forwarding,no-pty ssh-ed25519 AAA... user@desktop-name; rsync-only key
```

4. Make the `watch_and_sync_script.sh` script executable
- `chmod +x ~/bin/watch_and_sync.sh`

5. Start the systemd daemon, you should have configured during step 1.
- `sudo systemctl daemon-reload`
- `sudo systemctl enable sync-triton-vm-proofs.service`
- `sudo systemctl start sync-triton-vm-proofs.service`

6. Verify status of syncing service
- `sudo systemctl status sync-triton-vm-proofs.service`

#### Server, where the proofs are shared
7. Install nginx
- `sudo apt update`
- `sudo apt install nginx`

8. Make the directory for the proofs, and set correct permissions
- `sudo mkdir -p /var/www/triton-vm-proofs/`
- `sudo chown -R www-data:www-data /var/www/triton-vm-proofs`
- `sudo chmod -R 775 /var/www/triton-vm-proofs`

9. Enable the webserver defined in step 1.
- `sudo ln -s /etc/nginx/sites-available/triton-vm-proofs /etc/nginx/sites-enabled/`

10. Test nginx for syntax errors and reload nginx
- `sudo nginx -t`
- `sudo systemctl reload nginx`

11. Add your ssh user to group www-data so it can write proof files
- `sudo usermod -g www-data <user>`

#### Other relevant commands
Check log of proof-syncing service, on workstation
- `journalctl -u sync-triton-vm-proofs.service -f`

Check log of proof server, on server
- `tail -f /var/log/nginx/access.triton-vm-proofs.log`

Summarize total data sent, on server
- `awk '{sum += $10} END {print sum / (1024 * 1024) " MB"}' /var/log/nginx/access.triton-vm-proofs.log`
