# Produce blocks snapshot
Creates a tarball from the `blocks/` directory that can be used to bootstrap the state
of an archival node. Does not zip the blocks since the majority is proof data and only
~1.5 % data is saved if you zip. And zipping makes the script take 10 times longer to
run.

Uses a proof server to share the .torrent file.

## Requirements

```bash
sudo apt update
sudo apt install -y transmission-cli transmission-daemon tar
```

transmission-create is part of transmission-cli and is used to make .torrent files.

## Cron job
Run one of these scripts as a cron job:

```bash
crontab -e
```

Add this line to run the script every Sunday at 2:00 AM:
```cron
0 2 * * 0 /usr/local/bin/create_weekly_torrent.sh >> /var/log/create_weekly_torrent.log 2>&1
```

## Configure `transmission-daemon`
Stop the daemon. It doesn't work if you skip this step.
```bash
sudo systemctl start transmission-daemon
```

```bash
sudo systemctl start transmission-daemon
```

Ensure these lines are set:
```json
"rpc-enabled": true,
"rpc-authentication-required": false,
"download-dir": "/var/lib/transmission-daemon/downloads",
"incomplete-dir-enabled": false,
"watch-dir-enabled": false
```

Restart the daemon:
```bash
sudo systemctl start transmission-daemon
```
