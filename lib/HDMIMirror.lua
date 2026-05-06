-- HDMIMirror — streams the OLED contents to a local viewer process so an
-- attached HDMI monitor shows the game scaled up.
--
-- Pipeline:
--   1) viewer/synth-quest-viewer.py runs at Pi boot (systemd) and listens
--      on 127.0.0.1:5556
--   2) M.start() opens a TCP connection. If the viewer isn't running we
--      silently bail — Synth Quest plays normally on the OLED only.
--   3) clock.run() ticks at TARGET_FPS. Each tick reads the current OLED
--      buffer via screen.peek and ships it to the viewer.
--
-- Wire format per frame: [4-byte big-endian length=8192][8192 bytes payload]
-- where each payload byte is one OLED pixel (0..15) in row-major order.

local socket = require("socket")

local M = {
  active = false,    -- true while the mirror loop is running
  sock = nil,
  clock_id = nil,
}

local HOST = "127.0.0.1"
local PORT = 5556
local OLED_W, OLED_H = 128, 64
local FRAME_BYTES = OLED_W * OLED_H
local TARGET_FPS = 20  -- mirror cadence (game still redraws at full speed)
local HDR = string.pack(">I4", FRAME_BYTES)

function M.start()
  if M.active then return true end
  local s, err = socket.tcp()
  if not s then
    print("HDMIMirror: socket() failed: " .. tostring(err))
    return false
  end
  s:settimeout(0.25)
  local ok, cerr = s:connect(HOST, PORT)
  if not ok then
    -- viewer not running; bail quietly. The user can call start() again later.
    s:close()
    return false
  end
  s:settimeout(0)  -- non-blocking sends from now on
  M.sock = s
  M.active = true
  M.clock_id = clock.run(function()
    while M.active and M.sock do
      clock.sleep(1 / TARGET_FPS)
      local ok2, frame = pcall(screen.peek, 0, 0, OLED_W, OLED_H)
      if ok2 and type(frame) == "string" and #frame == FRAME_BYTES then
        local sent, serr = M.sock:send(HDR .. frame)
        if not sent then
          -- ECONNRESET / EPIPE / etc. — viewer probably went away.
          if serr ~= "timeout" then
            print("HDMIMirror: send failed (" .. tostring(serr) .. "), stopping")
            M.stop()
            return
          end
        end
      end
    end
  end)
  print("HDMIMirror: connected to viewer at " .. HOST .. ":" .. PORT)
  return true
end

function M.stop()
  M.active = false
  if M.clock_id then
    clock.cancel(M.clock_id)
    M.clock_id = nil
  end
  if M.sock then
    pcall(function() M.sock:close() end)
    M.sock = nil
  end
end

return M
