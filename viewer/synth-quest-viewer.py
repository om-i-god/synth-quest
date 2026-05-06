#!/usr/bin/env python3
"""
Synth Quest HDMI viewer.

Runs on the norns (or any Pi) and displays the OLED's contents on the
attached HDMI monitor at 1280x720, scaled up nearest-neighbor (preserves
the chunky pixel aesthetic). Listens for frames on a local TCP socket;
the synth-quest Lua script connects and streams.

Wire format (per frame):
  [4-byte big-endian length, always 8192][8192 bytes payload]
where each payload byte is a single OLED pixel value 0..15 in row-major
order (128 cols x 64 rows). Mirrors what `screen.peek(0, 0, 128, 64)`
returns inside norns' Lua API.

Run standalone for testing:
  python3 synth-quest-viewer.py
The systemd unit (synth-quest-viewer.service) starts it at Pi boot.
"""

import os
import socket
import struct
import sys

# headless-friendly init: pick the first available video driver
os.environ.setdefault("SDL_VIDEO_CENTERED", "1")
import pygame  # noqa: E402

LISTEN_HOST = "127.0.0.1"
LISTEN_PORT = 5556
OLED_W, OLED_H = 128, 64
FRAME_BYTES = OLED_W * OLED_H  # 8192

# 1280x720 = 16:9, scale factor 10x for OLED (height) — leaves a 1280x80
# letterbox top + bottom that stays black. Chunky, faithful, readable.
DISPLAY_W, DISPLAY_H = 1280, 720
SCALE = 10  # 128*10 = 1280 wide, 64*10 = 640 tall (centered vertically)
SCALED_W, SCALED_H = OLED_W * SCALE, OLED_H * SCALE
DEST_X = (DISPLAY_W - SCALED_W) // 2
DEST_Y = (DISPLAY_H - SCALED_H) // 2


def init_display():
    pygame.init()
    pygame.mouse.set_visible(False)
    flags = pygame.FULLSCREEN | pygame.SCALED | pygame.DOUBLEBUF
    try:
        screen = pygame.display.set_mode((DISPLAY_W, DISPLAY_H), flags)
    except pygame.error:
        # fall back to windowed for desktop testing
        screen = pygame.display.set_mode((DISPLAY_W, DISPLAY_H))
    pygame.display.set_caption("Synth Quest")
    screen.fill((0, 0, 0))
    pygame.display.flip()
    return screen


def render_splash(screen, msg):
    screen.fill((0, 0, 0))
    font = pygame.font.SysFont("monospace", 36)
    surf = font.render(msg, True, (255, 200, 80))
    rect = surf.get_rect(center=(DISPLAY_W // 2, DISPLAY_H // 2))
    screen.blit(surf, rect)
    pygame.display.flip()


def decode_and_blit(screen, payload, oled_surf):
    # payload: 8192 bytes, each byte = pixel level 0..15
    # write directly into oled_surf's pixel buffer
    pixels = pygame.surfarray.pixels2d(oled_surf)
    # decode column-major into 2d array — payload is row-major (y * 128 + x)
    for y in range(OLED_H):
        row_offset = y * OLED_W
        for x in range(OLED_W):
            v = payload[row_offset + x] & 0x0F
            # map 0..15 -> 0..255 brightness, packed as RGB 24-bit
            b = v * 17  # 15 * 17 = 255
            # pixels[x, y] uses an integer color; for 32-bit surface this is RGBA packed
            pixels[x, y] = (b << 16) | (b << 8) | b
    del pixels  # release the surfarray lock
    scaled = pygame.transform.scale(oled_surf, (SCALED_W, SCALED_H))
    screen.fill((0, 0, 0))
    screen.blit(scaled, (DEST_X, DEST_Y))
    pygame.display.flip()


def recv_exact(sock, n):
    """Receive exactly n bytes or return None on disconnect."""
    buf = bytearray()
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            return None
        buf.extend(chunk)
    return bytes(buf)


def serve(screen, oled_surf):
    listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    listener.bind((LISTEN_HOST, LISTEN_PORT))
    listener.listen(1)
    listener.settimeout(0.5)
    print(f"synth-quest-viewer: listening on {LISTEN_HOST}:{LISTEN_PORT}", flush=True)
    render_splash(screen, "Synth Quest -- waiting for game...")

    while True:
        # accept loop — stays responsive to keyboard quit + reconnects
        client = None
        while client is None:
            for ev in pygame.event.get():
                if ev.type == pygame.QUIT:
                    return
                if ev.type == pygame.KEYDOWN and ev.key in (pygame.K_ESCAPE, pygame.K_q):
                    return
            try:
                client, _addr = listener.accept()
            except socket.timeout:
                continue
        client.settimeout(2.0)
        print("synth-quest-viewer: game connected", flush=True)
        try:
            while True:
                hdr = recv_exact(client, 4)
                if hdr is None:
                    break
                length = struct.unpack(">I", hdr)[0]
                if length != FRAME_BYTES:
                    # protocol mismatch; drain & disconnect
                    print(f"viewer: unexpected length {length}, dropping", flush=True)
                    break
                payload = recv_exact(client, length)
                if payload is None:
                    break
                decode_and_blit(screen, payload, oled_surf)
                # also poll keyboard so ESC during play exits
                for ev in pygame.event.get():
                    if ev.type == pygame.QUIT or (
                        ev.type == pygame.KEYDOWN and ev.key in (pygame.K_ESCAPE, pygame.K_q)
                    ):
                        client.close()
                        return
        except (socket.timeout, ConnectionResetError, BrokenPipeError):
            pass
        finally:
            client.close()
            print("synth-quest-viewer: game disconnected, awaiting reconnect", flush=True)
            render_splash(screen, "Synth Quest -- game disconnected")


def main():
    screen = init_display()
    oled_surf = pygame.Surface((OLED_W, OLED_H))
    try:
        serve(screen, oled_surf)
    finally:
        pygame.quit()


if __name__ == "__main__":
    sys.exit(main() or 0)
