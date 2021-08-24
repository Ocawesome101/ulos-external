-- basc window manager --

local TERM_W, TERM_H = 65, 20

local tty = require("tty")
local process = require("process")
local gpuproxy = require("gpuproxy")
local gpu = tty.getgpu(io.stderr.tty)

if gpu.isProxy then
  io.stderr:write("\27[91mwm: not nestable\n\27[0m")
  os.exit(1)
end

local cfg = require("config").table:load("/etc/wm.cfg") or {}
TERM_W = cfg.width or TERM_W
TERM_H = cfg.height or TERM_H
require("config").table:save("/etc/wm.cfg", {width = TERM_W, height = TERM_H})

local w, h = gpu.getResolution()
gpu.setBackground(0xAAAAAA)
gpu.fill(1, 1, w, h, " ")

local windows = {}

local shell = assert(loadfile("/bin/lsh.lua"))

local function new_window(x, y)
  local buffer, err = gpu.allocateBuffer(TERM_W, TERM_H)
  if not buffer then return nil, err end
  local gpucontext = gpuproxy.buffer(gpu, buffer)
  local ttystream = tty.create(gpucontext)
  local proc = {
    func = shell,
    name = "lsh",
    stdin = ttystream,
    stdout = ttystream,
    stderr = ttystream,
    input = ttystream,
    output = ttystream
  }
  if windows[1] then windows[1].stream:write("\27?15c") end
  table.insert(windows, 1, {stream = ttystream, buffer = buffer, x = x or 1,
    y = y or 1, pid = process.spawn(proc)})
end

local function focus_window(id)
  windows[1].stream:write("\27?15c")
  table.insert(windows, 1, table.remove(windows, id))
  windows[1].stream:write("\27?5c")
end

local rf_a = true
local function refresh()
  for i=(rf_a and #windows or 1), 1, -1 do
    if windows[i] then
      gpu.bitblt(0, windows[i].x, windows[i].y, nil, nil, windows[i].buffer)
    end
  end
  rf_a = false
  gpu.setBackground(0)
  gpu.setForeground(0xFFFFFF)
  gpu.set(1, 1, "Quit | ULOS Terminal Manager | Right-Click create/remove")
end

io.write("\27?15c\27?1;2;3s")
io.flush()
local screen = gpu.getScreen()
local dragging, xo, yo = false, 0, 0
while true do
  refresh()
  local sig, scr, x, y, button = coroutine.yield(0)
  for i=1, #windows, 1 do
    if windows[i] and not process.info(windows[i].pid) then
      local win = table.remove(windows, i)
      if #windows > 0 then focus_window(1) end
      tty.delete(win.stream.tty)
      gpu.freeBuffer(win.buffer)
      win.stream:close()
      closed = true
      gpu.setBackground(0xAAAAAA)
      gpu.fill(1, 1, w, h, " ")
      rf_a = true
    end
  end
  if scr == screen then
    if sig == "touch" then
      if y == 1 and x < 6 then
        break
      elseif button == 1 then
        local closed
        for i=1, #windows, 1 do
          if x >= windows[i].x and y >= windows[i].x + TERM_W and
             y >= windows[i].y and y <= windows[i].y + TERM_H then
            local win = table.remove(windows, i)
            if #windows > 0 then focus_window(1) end
            tty.delete(win.stream.tty)
            gpu.freeBuffer(win.buffer)
            win.stream:close()
            closed = true
            gpu.setBackground(0xAAAAAA)
            gpu.fill(1, 1, w, h, " ")
            rf_a = true
          end
        end
        if not closed then new_window(x, y) end
      else
        for i=1, #windows, 1 do
          if x >= windows[i].x and x <= windows[i].x + TERM_W and
             y >= windows[i].y and y <= windows[i].y + TERM_H then
            focus_window(i)
            rf_a = true
            dragging = true
            xo, yo = x - windows[i].x, y - windows[i].y
            break
          end
        end
      end
    elseif sig == "drag" and dragging then
      gpu.setBackground(0xAAAAAA)
      gpu.fill(windows[1].x, windows[1].y, TERM_W, TERM_H, " ")
      windows[1].x = x - xo
      windows[1].y = y - yo
      rf_a = true
    elseif sig == "drop" then
      dragging = false
      rf_a = true
      xo, yo = 0, 0
    end
  end
end

-- clean up unused resources
for i=1, #windows, 1 do
  process.kill(windows[i].pid, process.signals.hangup)
  tty.delete(windows[i].stream.tty)
  gpu.freeBuffer(windows[i].buffer)
end

io.write("\27?5c\27?0s\27[m\27[2J\27[1;1H")
io.flush()
