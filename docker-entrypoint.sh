#!/bin/bash
set -e

# Set correct ownership of mounted volumes
chown -R icecast2:icecast2 /recordings
chmod -R 755 /recordings

# Execute the main command
exec "$@"
