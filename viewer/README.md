# synth quest viewer

Mirrors the norns OLED to another screen over TCP (port 7777).

**Mac / laptop (windowed):**

```
python3 synth-quest-viewer.py --windowed --scale 4
```

F toggles fullscreen; ESC/Q quits. Needs python3 + pygame
(`mac-run.sh` sets up a venv and runs it).

**Pi at a TV (fullscreen service):** run `./install.sh` on the Pi.

**On the norns:** create `~/.config/synth-quest/viewer.conf`
containing one line, `HOST:PORT` (e.g. `192.168.1.29:7777`), then set
PARAMS > SYNTH QUEST > **video stream: on**.

**If the picture stops appearing after a while:** the viewer machine's
LAN IP probably changed. Update viewer.conf, then toggle **video
stream** off and back on — the config is only re-read when the stream
starts. The `viewer:` line in the params menu shows the configured
target but only refreshes on script reload.

Leave **video stream** off when no viewer is running: while on and
unreachable, the script retries every 5s at a ~100ms cost per attempt.
