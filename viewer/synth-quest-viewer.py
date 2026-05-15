#!/usr/bin/env python3
"""
Synth Quest video stream viewer.

Receives the OLED contents from the running synth-quest Lua script over
TCP and renders it scaled-up on this machine's display. Two flavors:

  Pi @ TV (fullscreen, kmsdrm):
      python3 synth-quest-viewer.py --port 7777
      (the synth-quest-viewer.service unit launches it this way)

  Mac dev / couch laptop (windowed; press F to toggle fullscreen):
      python3 synth-quest-viewer.py --windowed --scale 4

Run --help for full options. The viewer listens on 0.0.0.0 by default so
the norns can connect across the LAN; pass --listen 127.0.0.1 to restrict.

Keyboard:
  F      toggle fullscreen / windowed (works mid-stream)
  ESC/Q  quit

Wire format (per frame):
  [4-byte big-endian length, always 8192][8192 bytes payload]
where each payload byte is a single OLED pixel value 0..15 in row-major
order (128 cols x 64 rows). Mirrors what `screen.peek(0, 0, 128, 64)`
returns inside norns' Lua API.
"""

import argparse
import os
import platform
import socket
import struct
import sys

# macOS fullscreen behaviour: by default SDL2 uses Cocoa "spaces" for
# fullscreen-desktop windows, which means focusing another app flips
# the user back to their previous space and reveals the menu bar +
# window chrome on the viewer. Disabling spaces tells SDL to use a
# pure borderless full-display window instead — stays put on focus
# loss, menu bar stays hidden. Must be set BEFORE pygame.init().
os.environ.setdefault("SDL_VIDEO_MAC_FULLSCREEN_SPACES", "0")

OLED_W, OLED_H = 128, 64
FRAME_BYTES = OLED_W * OLED_H  # 8192


def parse_args():
    p = argparse.ArgumentParser(description="Synth Quest video stream viewer")
    p.add_argument("--listen", default="0.0.0.0",
                   help="address to bind (default 0.0.0.0; use 127.0.0.1 to restrict)")
    p.add_argument("--port", type=int, default=7777,
                   help="port to listen on (default 7777)")
    p.add_argument("--windowed", action="store_true",
                   help="windowed mode (default on macOS, fullscreen elsewhere)")
    p.add_argument("--fullscreen", action="store_true",
                   help="force fullscreen at startup")
    p.add_argument("--scale", type=int, default=0,
                   help="integer pixel scale for windowed mode (0 = auto: 4x)")
    p.add_argument("--width", type=int, default=0,
                   help="window width override")
    p.add_argument("--height", type=int, default=0,
                   help="window height override")
    return p.parse_args()


def compute_layout(display_w, display_h):
    """Pick the largest integer scale that fits 128x64 inside the display
    while preserving aspect ratio, and center the result."""
    scale = max(1, min(display_w // OLED_W, display_h // OLED_H))
    scaled_w, scaled_h = OLED_W * scale, OLED_H * scale
    dest_x = (display_w - scaled_w) // 2
    dest_y = (display_h - scaled_h) // 2
    return scale, (scaled_w, scaled_h), (dest_x, dest_y)


def _macos_display_bounds():
    """Query CoreGraphics for the bounds of every active display.
    Returns a list of (x, y, w, h) tuples in CG coordinates (top-left
    origin of the main display = (0, 0); other displays have whatever
    origin macOS assigns based on the user's arrangement). Returns
    None if not on macOS or the call fails.

    pygame 2.6.1 from PyPI does NOT expose get_display_bounds — only
    pygame-ce does. Going directly through Quartz/ctypes avoids
    depending on a specific pygame fork."""
    if platform.system() != "Darwin":
        return None
    try:
        import ctypes
        from ctypes import c_double, c_uint32, c_int32, Structure, byref
        class CGPoint(Structure): _fields_ = [("x", c_double), ("y", c_double)]
        class CGSize(Structure):  _fields_ = [("w", c_double), ("h", c_double)]
        class CGRect(Structure):  _fields_ = [("origin", CGPoint), ("size", CGSize)]
        cg = ctypes.CDLL("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics")
        cg.CGGetActiveDisplayList.argtypes = [c_uint32, ctypes.POINTER(c_uint32), ctypes.POINTER(c_uint32)]
        cg.CGGetActiveDisplayList.restype  = c_int32
        cg.CGDisplayBounds.argtypes        = [c_uint32]
        cg.CGDisplayBounds.restype         = CGRect
        max_displays = 16
        ids = (c_uint32 * max_displays)()
        n = c_uint32(0)
        if cg.CGGetActiveDisplayList(max_displays, ids, byref(n)) != 0:
            return None
        out = []
        for i in range(n.value):
            r = cg.CGDisplayBounds(ids[i])
            out.append((int(r.origin.x), int(r.origin.y), int(r.size.w), int(r.size.h)))
        return out
    except Exception:
        return None


def _capsule_to_pointer(obj):
    """pygame.display.get_wm_info()['window'] on modern pygame returns
    the native window handle wrapped in a PyCapsule (an opaque Python
    object), not a raw integer. To pass it to objc_msgSend we have to
    crack the capsule open via Python's C-API helpers.

    Accepts: int (returns as-is), PyCapsule, or anything that quacks
    like one. Returns the pointer as a Python int, or None on failure."""
    if isinstance(obj, int):
        return obj
    try:
        import ctypes
        ctypes.pythonapi.PyCapsule_GetName.argtypes    = [ctypes.py_object]
        ctypes.pythonapi.PyCapsule_GetName.restype     = ctypes.c_char_p
        ctypes.pythonapi.PyCapsule_GetPointer.argtypes = [ctypes.py_object, ctypes.c_char_p]
        ctypes.pythonapi.PyCapsule_GetPointer.restype  = ctypes.c_void_p
        try:
            name = ctypes.pythonapi.PyCapsule_GetName(obj)
        except Exception:
            name = None
        ptr = ctypes.pythonapi.PyCapsule_GetPointer(obj, name)
        return int(ptr) if ptr else None
    except Exception:
        return None


def _macos_set_window_collection_behavior(ns_window_ptr, flags):
    """Set NSWindow collectionBehavior. Used to make the viewer's
    fullscreen window visible across ALL macOS Spaces. Without this,
    when the user switches to a different Space (e.g. Desktop 3 on
    the same display), our window stays bound to the Space it was
    created in and macOS reveals the menu bar / other windows
    underneath.

    Flag values (NSWindowCollectionBehavior):
       1  = CanJoinAllSpaces        — window appears on every Space
      16  = Stationary              — does not follow the active Space
     256  = FullScreenAuxiliary     — can appear in macOS fullscreen apps
    Combining 1|16|256 = 273 covers all the "stay visible" cases."""
    if platform.system() != "Darwin" or ns_window_ptr is None:
        return False
    ptr = _capsule_to_pointer(ns_window_ptr)
    if not ptr:
        return False
    try:
        import ctypes, ctypes.util
        objc = ctypes.cdll.LoadLibrary(ctypes.util.find_library("objc"))
        objc.sel_registerName.argtypes = [ctypes.c_char_p]
        objc.sel_registerName.restype  = ctypes.c_void_p
        sel = objc.sel_registerName(b"setCollectionBehavior:")
        send = objc.objc_msgSend
        send.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_uint64]
        send.restype  = ctypes.c_void_p
        send(ctypes.c_void_p(ptr), sel, ctypes.c_uint64(flags))
        return True
    except Exception as e:
        print(f"viewer: setCollectionBehavior failed: {e}", flush=True)
        return False


def _macos_set_window_level(ns_window_ptr, level):
    """Raise/lower an NSWindow above/below the macOS menu bar.

    macOS hides our window's menu bar slot when the viewer has focus,
    but the moment another app gains focus its menu bar (and any
    visible window chrome) appears at the top of every display by
    default. Setting the NSWindow level above NSMainMenuWindowLevel
    (24) tells the window server "always paint this window over the
    menu bar" — regardless of which app currently owns focus.

    Levels: 0 = normal, 24 = main menu, 25 = status, 101 = popup menu,
    1000 = screen saver. We use 101 by default: above the menu bar +
    dock, but below system overlays like keyboard-volume HUDs.

    Implemented via objc_msgSend through ctypes so we don't need to
    drag in PyObjC. ns_window_ptr is the integer NSWindow* from
    pygame.display.get_wm_info()['window']."""
    if platform.system() != "Darwin" or ns_window_ptr is None:
        return False
    ptr = _capsule_to_pointer(ns_window_ptr)
    if not ptr:
        return False
    try:
        import ctypes, ctypes.util
        objc = ctypes.cdll.LoadLibrary(ctypes.util.find_library("objc"))
        objc.sel_registerName.argtypes = [ctypes.c_char_p]
        objc.sel_registerName.restype  = ctypes.c_void_p
        sel = objc.sel_registerName(b"setLevel:")
        send = objc.objc_msgSend
        send.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_long]
        send.restype  = ctypes.c_void_p
        send(ctypes.c_void_p(ptr), sel, ctypes.c_long(level))
        return True
    except Exception as e:
        print(f"viewer: set_window_level failed: {e}", flush=True)
        return False


def _macos_mouse_position():
    """Returns (x, y) of the global mouse cursor on macOS via Quartz,
    in the same CG coordinate space as _macos_display_bounds(). None
    if not on macOS / call fails."""
    if platform.system() != "Darwin":
        return None
    try:
        import ctypes
        from ctypes import c_double, Structure
        class CGPoint(Structure): _fields_ = [("x", c_double), ("y", c_double)]
        cg = ctypes.CDLL("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics")
        cg.CGEventCreate.argtypes      = [ctypes.c_void_p]
        cg.CGEventCreate.restype       = ctypes.c_void_p
        cg.CGEventGetLocation.argtypes = [ctypes.c_void_p]
        cg.CGEventGetLocation.restype  = CGPoint
        cf = ctypes.CDLL("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")
        cf.CFRelease.argtypes = [ctypes.c_void_p]
        event = cg.CGEventCreate(None)
        loc = cg.CGEventGetLocation(event)
        cf.CFRelease(event)
        return int(loc.x), int(loc.y)
    except Exception:
        return None


def current_display_index(pygame):
    """Best-effort: return the index of the display the window currently
    sits on. On macOS this routes through Quartz (the user's mouse
    cursor + CGDisplayBounds) because pygame 2.6.1 from PyPI doesn't
    expose window-position or display-bounds APIs. The mouse-position
    heuristic works because the user has just dragged the viewer
    window — their cursor is naturally on that display when they
    press F."""
    bounds = _macos_display_bounds()
    mouse = _macos_mouse_position()
    if bounds and mouse:
        mx, my = mouse
        for i, (x, y, w, h) in enumerate(bounds):
            if x <= mx < x + w and y <= my < y + h:
                return i
    # Non-mac fallbacks via pygame (older API surface).
    try:
        wx, wy = pygame.display.get_window_position()
    except (AttributeError, pygame.error):
        return 0
    try:
        n = pygame.display.get_num_displays()
        for i in range(n):
            r = pygame.display.get_display_bounds(i)
            if r.collidepoint(wx, wy):
                return i
    except (AttributeError, pygame.error):
        pass
    try:
        sizes = pygame.display.get_desktop_sizes()
        cum = 0
        for i, (w, h) in enumerate(sizes):
            if cum <= wx < cum + w:
                return i
            cum += w
    except (AttributeError, pygame.error):
        pass
    return 0


def target_display_bounds(pygame, idx):
    """Return (x, y, w, h) for the given display index. Prefers
    Quartz (macOS) → pygame-ce get_display_bounds → desktop_sizes
    fallback. The Quartz path is the only one that returns real
    origins on stock pygame (PyPI build) under macOS."""
    macos = _macos_display_bounds()
    if macos and 0 <= idx < len(macos):
        return macos[idx]
    try:
        r = pygame.display.get_display_bounds(idx)
        return r.x, r.y, r.width, r.height
    except (AttributeError, pygame.error):
        pass
    try:
        sizes = pygame.display.get_desktop_sizes()
        if 0 <= idx < len(sizes):
            w, h = sizes[idx]
            cum_x = 0
            for i in range(idx):
                cum_x += sizes[i][0]
            return cum_x, 0, w, h
    except (AttributeError, pygame.error):
        pass
    return 0, 0, 1280, 720


def apply_layout(state):
    """(Re)create the pygame display surface for the current fullscreen
    state and recompute the scaled-blit layout.

    "Fullscreen" here is implemented as a BORDERLESS window the size of
    the target display, positioned at that display's origin via
    SDL_VIDEO_WINDOW_POS. This avoids two macOS quirks of the exclusive
    `pygame.FULLSCREEN` mode:
      1) it always opened on display 0 even with display= kwarg, so the
         image landed in a corner of the wrong screen, and
      2) macOS exclusive-fullscreen auto-hides when focus shifts away
         (clicking the main window made the viewer vanish).

    Borderless covers the whole display, stays visible when focus moves,
    and centers the scaled OLED inside via compute_layout."""
    pygame = state["pygame"]
    if state["fullscreen"]:
        idx = current_display_index(pygame)
        dx, dy, w, h = target_display_bounds(pygame, idx)
        # Strip SDL_VIDEO_CENTERED — set at startup so the windowed
        # mode opens centered. With it set, SDL ignores
        # SDL_VIDEO_WINDOW_POS on some platforms.
        os.environ.pop("SDL_VIDEO_CENTERED", None)
        os.environ["SDL_VIDEO_WINDOW_POS"] = f"{dx},{dy}"
        flags = pygame.NOFRAME
        try:
            state["screen"] = pygame.display.set_mode((w, h), flags, display=idx)
        except TypeError:
            state["screen"] = pygame.display.set_mode((w, h), flags)
        except pygame.error as e:
            print(f"viewer: set_mode NOFRAME failed ({e}); falling back to windowed", flush=True)
            state["fullscreen"] = False
            w, h = state["win_w"], state["win_h"]
            state["screen"] = pygame.display.set_mode((w, h), 0)
        # Lower-level SDL window control: pygame._sdl2.video.Window
        # wraps the pygame-created SDL_Window so we can position +
        # resize directly. After positioning on the target display,
        # call set_fullscreen(desktop=True) which is SDL2's
        # FULLSCREEN_DESKTOP mode — covers the macOS menu bar without
        # changing the display resolution AND, unlike exclusive
        # fullscreen, doesn't auto-hide when focus shifts to another
        # app. Order matters: position first so the fullscreen call
        # targets the right display.
        try:
            from pygame._sdl2.video import Window
            win = Window.from_display_module()
            state["_sdl2_window"] = win
            win.position = (dx, dy)
            win.size = (w, h)
            try:
                win.set_fullscreen(desktop=True)
                print(f"viewer: F toggle → idx={idx} bounds=({dx},{dy},{w}x{h}) — FULLSCREEN_DESKTOP", flush=True)
            except Exception as fe:
                print(f"viewer: F toggle → idx={idx} bounds=({dx},{dy},{w}x{h}) — fullscreen_desktop unavailable ({fe}); staying borderless", flush=True)
        except Exception as e:
            print(f"viewer: F toggle → idx={idx} bounds=({dx},{dy},{w}x{h}) — _sdl2.Window unavailable: {e}", flush=True)
        # Two NSWindow tweaks to keep the viewer fullscreened across
        # focus + Space changes:
        #   (1) setLevel: NSPopUpMenuWindowLevel (101) — paint above the
        #       menu bar regardless of which app is frontmost.
        #   (2) setCollectionBehavior: CanJoinAllSpaces|Stationary|
        #       FullScreenAuxiliary (273) — the window appears on every
        #       Space, so switching to Desktop 3 doesn't leave the
        #       viewer behind in Desktop 5.
        try:
            info = pygame.display.get_wm_info()
            nsw = info.get("window")
            if nsw:
                # Use CGShieldingWindowLevel — the absolute highest level
                # macOS exposes, normally reserved for screen savers and
                # security dialogs. Modern macOS (Sequoia) draws its
                # menu bar at a level higher than NSPopUpMenuWindowLevel
                # (101), so we need to escalate to be sure we're above
                # it. The downside: system overlays like the volume HUD
                # may also be hidden. For a fullscreen viewer that's
                # acceptable.
                level = 1000  # NSScreenSaverWindowLevel fallback
                try:
                    import ctypes
                    cg = ctypes.CDLL("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics")
                    cg.CGShieldingWindowLevel.restype = ctypes.c_int
                    level = cg.CGShieldingWindowLevel() - 1
                except Exception:
                    pass
                ok_lvl = _macos_set_window_level(nsw, level)
                ok_cb  = _macos_set_window_collection_behavior(nsw, 1 | 16 | 256)
                print(f"viewer: NSWindow level={level} collectionBehavior=273 → level_ok={ok_lvl} cb_ok={ok_cb}", flush=True)
        except Exception as e:
            print(f"viewer: get_wm_info / NSWindow tweaks failed: {e}", flush=True)
    else:
        w, h = state["win_w"], state["win_h"]
        # Restore normal NSWindow level BEFORE exiting fullscreen so
        # the window doesn't briefly float over system UI while it's
        # shrinking back down.
        try:
            info = pygame.display.get_wm_info()
            nsw = info.get("window")
            if nsw:
                _macos_set_window_level(nsw, 0)
        except Exception:
            pass
        # Exit FULLSCREEN_DESKTOP mode on the current SDL window first;
        # otherwise the window keeps its fullscreen flag and the new
        # set_mode might not properly resize back to the windowed dims.
        try:
            from pygame._sdl2.video import Window
            win = Window.from_display_module()
            try:
                win.set_windowed()
            except Exception:
                pass
        except Exception:
            pass
        # Restore the centered-window hint for the windowed surface.
        os.environ.setdefault("SDL_VIDEO_CENTERED", "1")
        try:
            state["screen"] = pygame.display.set_mode((w, h), 0)
        except pygame.error as e:
            print(f"viewer: set_mode windowed failed ({e})", flush=True)
            state["screen"] = pygame.display.set_mode((w, h), 0)
    pygame.display.set_caption("Synth Quest")
    _, state["scaled_size"], state["dest"] = compute_layout(w, h)
    state["screen"].fill((0, 0, 0))
    pygame.display.flip()


def init_display(args):
    """One-time pygame setup. Returns a state dict carried through the
    serve loop so runtime fullscreen toggling can mutate it."""
    is_mac = platform.system() == "Darwin"
    start_fullscreen = args.fullscreen or (not args.windowed and not is_mac)

    if not start_fullscreen:
        scale = args.scale or 4
        win_w = args.width or OLED_W * scale
        win_h = args.height or OLED_H * scale
    else:
        # Pi @ TV path: SDL kmsdrm driver + 1280x720 default.
        if not is_mac:
            os.environ.setdefault("SDL_VIDEODRIVER", "kmsdrm")
        win_w = args.width or 1280
        win_h = args.height or 720

    os.environ.setdefault("SDL_VIDEO_CENTERED", "1")
    import pygame
    pygame.init()
    pygame.mouse.set_visible(False)

    # Cache the actual desktop resolution BEFORE the first window exists.
    # Once a window is up, pygame.display.Info() returns the *window* size
    # on macOS, which is why a fullscreen toggle would otherwise reuse the
    # tiny windowed dims and stick the image in a corner of the real screen.
    desktop_w, desktop_h = win_w, win_h
    if hasattr(pygame.display, "get_desktop_sizes"):
        sizes = pygame.display.get_desktop_sizes()
        if sizes:
            desktop_w, desktop_h = sizes[0]
    else:
        info = pygame.display.Info()
        if info.current_w > 0 and info.current_h > 0:
            desktop_w, desktop_h = info.current_w, info.current_h

    state = {
        "pygame": pygame,
        "fullscreen": start_fullscreen,
        "win_w": win_w,
        "win_h": win_h,
        "desktop_w": desktop_w,
        "desktop_h": desktop_h,
        "screen": None,
        "scaled_size": None,
        "dest": None,
    }
    apply_layout(state)
    return state


def toggle_fullscreen(state):
    target = not state["fullscreen"]
    state["fullscreen"] = target
    try:
        apply_layout(state)
    except Exception as e:
        # Don't take down the viewer if SDL refuses the toggle. Snap
        # back to whichever mode succeeds.
        print(f"viewer: toggle_fullscreen failed: {e}; reverting", flush=True)
        state["fullscreen"] = not target
        try:
            apply_layout(state)
        except Exception:
            pass
    print(f"viewer: fullscreen={'on' if state['fullscreen'] else 'off'}", flush=True)


def render_splash(state, msg):
    # pygame.font on Python 3.14 has a circular-import bug, so we don't
    # rely on it. Print the status to stdout (where mac-run.sh shows it)
    # and paint a small visual indicator on the screen.
    pygame = state["pygame"]
    screen = state["screen"]
    print(f"viewer: {msg}", flush=True)
    screen.fill((0, 0, 0))
    w, h = screen.get_width(), screen.get_height()
    pygame.draw.rect(screen, (255, 200, 80), (w // 2 - 8, h // 2 - 8, 16, 16))
    pygame.display.flip()


def decode_and_blit(state, payload, oled_surf):
    pygame = state["pygame"]
    pixels = pygame.surfarray.pixels2d(oled_surf)
    for y in range(OLED_H):
        row_offset = y * OLED_W
        for x in range(OLED_W):
            v = payload[row_offset + x] & 0x0F
            b = v * 17
            pixels[x, y] = (b << 16) | (b << 8) | b
    del pixels
    scaled = pygame.transform.scale(oled_surf, state["scaled_size"])
    state["screen"].fill((0, 0, 0))
    state["screen"].blit(scaled, state["dest"])
    pygame.display.flip()


def handle_input(state):
    """Pump pygame events. Returns True if we should quit."""
    pygame = state["pygame"]
    for ev in pygame.event.get():
        if ev.type == pygame.QUIT:
            return True
        if ev.type == pygame.KEYDOWN:
            if ev.key in (pygame.K_ESCAPE, pygame.K_q):
                return True
            if ev.key == pygame.K_f:
                toggle_fullscreen(state)
    return False


def recv_exact(sock, n):
    buf = bytearray()
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            return None
        buf.extend(chunk)
    return bytes(buf)


def serve(args):
    state = init_display(args)
    pygame = state["pygame"]
    oled_surf = pygame.Surface((OLED_W, OLED_H))

    listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    listener.bind((args.listen, args.port))
    listener.listen(1)
    listener.settimeout(0.5)
    print(f"synth-quest-viewer: listening on {args.listen}:{args.port}", flush=True)
    print("viewer: press F to toggle fullscreen, ESC/Q to quit", flush=True)
    render_splash(state, f"Synth Quest -- waiting on :{args.port}")

    while True:
        client = None
        while client is None:
            if handle_input(state):
                return
            try:
                client, addr = listener.accept()
            except socket.timeout:
                continue
        client.settimeout(2.0)
        print(f"synth-quest-viewer: game connected from {addr[0]}", flush=True)
        try:
            while True:
                hdr = recv_exact(client, 4)
                if hdr is None:
                    break
                length = struct.unpack(">I", hdr)[0]
                if length != FRAME_BYTES:
                    print(f"viewer: unexpected length {length}, dropping", flush=True)
                    break
                payload = recv_exact(client, length)
                if payload is None:
                    break
                decode_and_blit(state, payload, oled_surf)
                if handle_input(state):
                    client.close()
                    return
        except (socket.timeout, ConnectionResetError, BrokenPipeError):
            pass
        finally:
            client.close()
            print("synth-quest-viewer: game disconnected, awaiting reconnect", flush=True)
            render_splash(state, "Synth Quest -- game disconnected")


def main():
    args = parse_args()
    try:
        serve(args)
    finally:
        try:
            import pygame
            pygame.quit()
        except Exception:
            pass


if __name__ == "__main__":
    sys.exit(main() or 0)
