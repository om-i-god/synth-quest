-- HDMIMirror — streams the OLED contents to a viewer process so an
-- external display shows the game scaled up. Module name kept for
-- backwards compatibility; the viewer now lives anywhere on the LAN.
--
-- Pipeline:
--   1) viewer/synth-quest-viewer.py runs somewhere reachable: on the
--      norns itself (Pi @ TV) or on a LAN machine (Mac, second Pi).
--   2) M.start() reads ~/.config/synth-quest/viewer.conf for HOST:PORT
--      (default 127.0.0.1:7777) and opens a TCP connection. If the
--      viewer isn't up yet, retries every 3s while M.active is true.
--   3) clock.run() ticks at TARGET_FPS. Each tick reads the OLED buffer
--      via screen.peek and ships it to the viewer.
--
-- Wire format per frame: [4-byte big-endian length=8192][8192 bytes payload]
-- where each payload byte is one OLED pixel (0..15) in row-major order.

local socket = require("socket")

local M = {
  active = false,    -- true while the mirror loop is running
  sock = nil,
  clock_id = nil,
  host = "127.0.0.1",
  port = 7777,
  status = "stopped",
}

local OLED_W, OLED_H = 128, 64
local FRAME_BYTES = OLED_W * OLED_H  -- 8192
local TARGET_FPS = 12        -- was 20; lower bandwidth + less per-frame work
local RECONNECT_S = 5        -- was 3; calmer when the viewer is offline
-- 4-byte big-endian length prefix. norns runs LuaJIT (no string.pack), so
-- build the bytes manually. FRAME_BYTES is a compile-time constant 8192
-- = 0x00002000, hence high byte 0x20 in the 3rd slot.
local HDR = string.char(0, 0, 0x20, 0)

-- Read HOST:PORT from ~/.config/synth-quest/viewer.conf if present.
-- File format: a single line "host:port" (e.g. "192.168.1.29:7777").
local function read_target()
  local home = os.getenv("HOME") or "/home/we"
  local path = home .. "/.config/synth-quest/viewer.conf"
  local f = io.open(path, "r")
  if not f then return "127.0.0.1", 7777 end
  local line = f:read("*l") or ""
  f:close()
  line = line:gsub("%s+", "")
  local h, p = line:match("^([^:]+):(%d+)$")
  if h and p then return h, tonumber(p) end
  return "127.0.0.1", 7777
end

local function try_connect()
  local s, err = socket.tcp()
  if not s then return nil, err end
  s:settimeout(0.5)
  local ok, cerr = s:connect(M.host, M.port)
  if not ok then s:close(); return nil, cerr end
  -- Disable Nagle so each frame is flushed promptly. Use a short send
  -- timeout (not zero) so partial sends actually progress instead of
  -- spinning. The send loop below handles timeout-resume.
  pcall(function() s:setoption("tcp-nodelay", true) end)
  s:settimeout(0.05)
  return s
end

-- Robust TCP send: keeps writing until the full payload is delivered or
-- a real (non-timeout) error happens. luasocket's tcp:send returns the
-- index of the LAST byte sent (1-based), or (nil, err, last) on failure
-- where `last` is the same — so the next send call resumes from
-- `last + 1`. Without this loop, partial sends desync the receiver and
-- the viewer ends up trying to parse pixel bytes as length headers.
local function send_all(sock, data)
  local total = #data
  local i = 1
  while i <= total do
    local n, err, last = sock:send(data, i)
    if n then
      i = n + 1
    elseif err == "timeout" then
      -- Small backoff so we don't burn cycles waiting for the kernel
      -- send buffer to drain. Resume from the last byte the kernel did
      -- accept (or wherever we were if `last` is missing).
      i = (last or i - 1) + 1
      clock.sleep(0.01)
    else
      return false, err
    end
  end
  return true, nil
end

function M.start()
  if M.active then return true end
  M.host, M.port = read_target()
  M.active = true
  M.status = "connecting"
  print("synth-quest video stream: target " .. M.host .. ":" .. M.port)
  M.clock_id = clock.run(function()
    while M.active do
      -- (re)connect loop
      while M.active and not M.sock do
        local s, err = try_connect()
        if s then
          M.sock = s
          M.status = "connected"
          print("synth-quest video stream: connected to " .. M.host .. ":" .. M.port)
        else
          M.status = "retrying (" .. tostring(err) .. ")"
          clock.sleep(RECONNECT_S)
        end
      end
      if not M.active then break end
      -- frame loop
      while M.active and M.sock do
        clock.sleep(1 / TARGET_FPS)
        local ok2, frame = pcall(screen.peek, 0, 0, OLED_W, OLED_H)
        if ok2 and type(frame) == "string" and #frame == FRAME_BYTES then
          local ok3, serr = send_all(M.sock, HDR .. frame)
          if not ok3 then
            print("synth-quest video stream: send failed (" .. tostring(serr) .. "), reconnecting")
            pcall(function() M.sock:close() end)
            M.sock = nil
            M.status = "reconnecting"
          end
        end
      end
    end
  end)
  return true
end

function M.stop()
  M.active = false
  M.status = "stopped"
  if M.clock_id then
    clock.cancel(M.clock_id)
    M.clock_id = nil
  end
  if M.sock then
    pcall(function() M.sock:close() end)
    M.sock = nil
  end
end

-- Returns a one-line human-readable status string. Surfaced by the param
-- read-out so the user can confirm where frames are going.
function M.target_string()
  local h, p = read_target()
  return h .. ":" .. p
end

return M
