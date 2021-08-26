-- basc window manager --

local TERM_W, TERM_H = 65, 20

local tty = require("tty")
local fs = require("filesystem")
local process = require("process")
local gpuproxy = require("gpuproxy")
local gpu = tty.getgpu(io.stderr.tty)
local screen = gpu.getScreen()

if gpu.isProxy then
  io.stderr:write("\27[91mwm: not nestable\n\27[0m")
  os.exit(1)
end

require("component").invoke(gpu.getScreen(), "setPrecise", false)

local cfg = require("config").table:load("/etc/uwm.cfg") or {}
TERM_W = cfg.width or TERM_W
TERM_H = cfg.height or TERM_H
require("config").table:save("/etc/uwm.cfg", {width = TERM_W, height = TERM_H})

local w, h = gpu.getResolution()
gpu.setBackground(0xAAAAAA)
gpu.fill(1, 1, w, h, " ")

local windows = {}

local function call(i, method, ...)
  if windows[i] and windows[i].app and windows[i].app[method] then
    pcall(windows[i].app[method], windows[i], ...)
  end
end

local function unfocus_window()
  windows[1].gpu.setForeground(0xAAAAAA)
  windows[1].gpu.setBackground(0x444444)
  windows[1].gpu.set(1, windows[1].app.h+1, windows[1].app.__wintitle)
  gpu.bitblt(0, windows[1].x, windows[1].y, nil, nil, windows[1].buffer)
  call(1, "unfocus")
end

local n = 0
local function new_window(x, y, prog)
  if windows[1] then
    unfocus_window()
  end

  local ok, err = loadfile("/usr/share/apps/" .. prog .. ".lua")
  if not ok then
    gpu.set(1, 2, prog .. ": " .. err)
    os.sleep(5)
    return
  end
  local ok, app = pcall(ok)
  if not ok and app then
    gpu.set(1, 2, prog .. ": " .. app)
    os.sleep(5)
    return
  end

  app.w = app.w or TERM_W
  app.h = app.h or TERM_H

  local buffer, err = gpu.allocateBuffer(app.w, app.h + 1)
  if not buffer then return nil, err end
  local gpucontext = gpuproxy.buffer(gpu, buffer, nil, app.h)
  gpucontext.setForeground(0xFFFFFF)
  gpucontext.setBackground(0x444444)
  gpucontext.fill(1, app.h + 1, app.w, 1, " ")
  app.__wintitle = "Close | " .. (app.name or prog)
  gpucontext.set(1, app.h + 1, app.__wintitle)
  app.needs_repaint = true
  table.insert(windows, 1, {gpu = gpucontext, buffer = buffer, x = x or 1,
    y = y or 1, app = app})
end

local function menu(x, y)
  gpu.setForeground(0xFFFFFF)
  gpu.setBackground(0x444444)
  local files = fs.list("/usr/share/apps")
  gpu.fill(x, y, 16, #files + 1, " ")
  gpu.set(x, y, "**UWM Menu**")
  for i=1,#files,1 do
    files[i]=files[i]:gsub("%.lua$", "")
    gpu.set(x,y+i,files[i])
  end
  local sig, scr, _x, _y
  repeat
    sig, scr, _x, _y = coroutine.yield(0)
  until sig == "drop" and scr == screen
  if _x < x or _x > x+15 or _y < y or _y > y+#files then return
  elseif _y == y then -- do nothing
  else new_window(x, y, files[_y - y]) end
end

local function focus_window(id)
  unfocus_window()
  table.insert(windows, 1, table.remove(windows, id))
  windows[1].gpu.setForeground(0xFFFFFF)
  windows[1].gpu.setBackground(0x444444)
  windows[1].gpu.set(1, windows[1].app.h+1, windows[1].app.__wintitle)
  gpu.bitblt(0, windows[1].x, windows[1].y, nil, nil, windows[1].buffer)
  call(1, "focus")
end

local rf_a = true
local function refresh()
  if rf_a == true then
    gpu.setBackground(0xAAAAAA)
    gpu.fill(1, 1, w, h, " ")
  end
  for i=(rf_a and #windows or 1), 1, -1 do
    if windows[i] then
      if windows[i].app.refresh and (windows[i].app.needs_repaint or
          windows[i].app.active) and rf_a ~= 1 then
        call(i, "refresh", windows[i].gpu)
      end
      gpu.bitblt(0, windows[i].x, windows[i].y, nil, nil, windows[i].buffer)
    end
  end
  rf_a = false
  gpu.setBackground(0)
  gpu.setForeground(0xFFFFFF)
  gpu.set(1, 1, "Quit | ULOS Window Manager | Right-Click for menu")
end

io.write("\27?15c\27?1;2;3s")
io.flush()
local dragging, mk, xo, yo = false, false, 0, 0
while true do
  refresh()
  local sig, scr, x, y, button = coroutine.yield(0)
  for i=1, #windows, 1 do
    if windows[i] then
      if windows[i].closeme then
        call(i, "close")
        local win = table.remove(windows, i)
        if #windows > 0 then focus_window(1) end
        gpu.freeBuffer(win.buffer)
      else
        goto skipclose
      end
      closed = true
      gpu.setBackground(0xAAAAAA)
      gpu.fill(1, 1, w, h, " ")
      rf_a = true
      ::skipclose::
    end
  end
  if scr == screen then
    if sig == "touch" then
      if y == 1 and x < 6 then
        break
      elseif button == 1 then
        if not mk then mk = true menu(x, y) end
      else
        for i=1, #windows, 1 do
          if x >= windows[i].x and x <= windows[i].x + 6 and
             y == windows[i].y + windows[i].app.h then
            call(i, "close")
            gpu.freeBuffer(windows[i].buffer)
            rf_a = true
            table.remove(windows, i)
            if i == 1 and windows[1] then
              focus_window(1)
            end
            break
          elseif x >= windows[i].x and x < windows[i].x + windows[i].app.w and
              y >= windows[i].y and y <= windows[i].y + windows[i].app.h  then
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
      gpu.fill(windows[1].x, windows[1].y, windows[1].app.w,
        windows[1].app.h + 1, " ")
      windows[1].x = x - xo
      windows[1].y = y - yo
      rf_a = 1
      dragging = 1
    elseif sig == "drop" then
      if dragging ~= 1 and windows[1] then
        call(1, "click", x - windows[1].x + 1, y - windows[1].y + 1)
        windows[1].app.needs_repaint = true
      end
      dragging = false
      rf_a = true
      xo, yo = 0, 0
      mk = false
    elseif sig == "key_down" then
      if windows[1] then
        call(1, "key", x, y)
        windows[1].app.needs_repaint = true
      end
    end
  end
end

-- clean up unused resources
for i=1, #windows, 1 do
  call(i, "close", "UI_CLOSING")
  gpu.freeBuffer(windows[i].buffer)
end

io.write("\27?5c\27?0s\27[m\27[2J\27[1;1H")
io.flush()
