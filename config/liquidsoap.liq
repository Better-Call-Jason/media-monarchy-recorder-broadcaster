#!/usr/bin/liquidsoap

# Allow running as root (needed for Docker)
set("init.allow_root",true)

# Simple playlist with default sorting
# Get files and create playlist
recordings = playlist(
  reload=1,
  reload_mode="rounds",
  mode="normal",
  "/sorted_recordings"
)

source = mksafe(recordings)

# Output to Icecast
output.icecast(
  %mp3(bitrate=128),
  host="localhost",
  port=8000,
  password="source_password",
  mount="/stream",
  name="Radio Stream",
  description="Automated Radio Stream",
  source
)
