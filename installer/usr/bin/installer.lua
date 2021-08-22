-- fancy TUI installer --

local component = require("component")
local computer = require("computer")
local termio = require("termio")
local tui = require("tui")

local w, h = termio.getTermSize()
local div = true
if w == 50 and h == 16 then div = false end
local page, sel = 1, 2
local pages = {
  { -- [1] intro
    tui.Text {
      x = (div and w // 8) or 1,
      y = (div and h // 8) or 1,
      width = (div and (w // 2) + (w // 4)) or w,
      height = ((div and (h // 2) + (h // 4)) or h) - 1,
      text = [[
Welcome to the ULOS installer.  This program will help you
install ULOS on your computer, set up a user account, and
install extra programs.  Use the arrow keys to navigate
and ENTER to select.]]
    },
    tui.Selectable {
      x = (div and (w // 8 + math.floor(w * 0.75)) or w) - 8,
      y = (div and (h - (h // 8) - 4)) or (h - 1),
      text = " Next ",
      selected = true
    }
  },
  { -- [2] disk selection
    tui.Text {
      x = (div and w // 8) or 1,
      y = (div and h // 8) or 1,
      width = (div and (w // 2) + (w // 4)) or w,
      height = ((div and (h // 2) + (h // 4)) or h) - 1,
      text = "Please select the disk on which you would like to install ULOS:"
    },
    tui.Selectable {
      x = (div and (w // 8 + math.floor(w * 0.75)) or w) - 8,
      y = (div and (h - (h // 8) - 4)) or (h - 1),
      text = " Back ",
      selected = false
    },
  },
  { -- [3] installation method
    tui.Text {
      x = (div and w // 8) or 1,
      y = (div and h // 8) or 1,
      width = (div and (w // 2) + (w // 4)) or w,
      height = ((div and (h // 2) + (h // 4)) or h) - 1,
      text = "Select your desired installation method."
    },
    tui.Selectable {
      x = (div and w // 8 or 0) + 2,
      y = (div and h // 8 or 1) + 3,
      text = require("text").padLeft(math.floor(w * 0.75) - 4,
        "Online (recommended, requires internet card)")
    },
    tui.Selectable {
      x = (div and w // 8 or 0) + 2,
      y = (div and h // 8 or 1) + 4,
      text = require("text").padLeft(math.floor(w * 0.75) - 4,
        "Offline")
    }
  },
  { -- [4] finished!
  }
}

do
  local _fs = component.list("filesystem")

  for k, v in pairs(_fs) do
    if k ~= computer.tmpAddress() then
      table.insert(pages[2], tui.Selectable {
        x = (div and w // 8 or 0) + 2,
        y = (div and h // 8 or 1) + #pages[2] + 2,
        text = require("text").padLeft(math.floor(w * 0.75) - 4, k)
      })
    end
  end
end

local function clear()
  io.write("\27[44;97m\27[2J\27[" .. math.floor(h) .. ";1HUP/DOWN select or scroll / ENTER selects")
  if div then
    local ln = "\27[47m" .. string.rep(" ", math.floor(w * 0.75)) .. "\27[40m "
    io.write("\27[47m")
    for i=1, math.floor(h * 0.75), 1 do
      io.write(string.format("\27[%d;%dH%s", h // 8 + i - 1, w // 8, ln))
    end
    io.write(string.format("\27[%d;%dH%s", h // 8 + math.floor(h * 0.75),
      w // 8, ln:sub(6) .. "\27[47;97m"))
  end
end

local function refresh()
  local wrbuf = ""
  for i, obj in ipairs(pages[page]) do
    obj.selected = sel == i
    wrbuf = wrbuf .. obj:refresh(1, 1)
  end
  io.write(wrbuf)
end

local sel_fs
local function preinstall()
  os.execute("mount -u /mnt")
  os.execute("mount " .. sel_fs .. " /mnt")
  
  -- this is the easiest way to do this
  local gpuproxy = require("gpuproxy")
  local tty = require("tty")
  local __gpu = tty.getgpu(io.stderr.tty)
  local wrapped

  if div then
    wrapped = gpuproxy.area(__gpu, w // 8 + 1, h // 8 + 1,
      math.floor(w * 0.75) - 1, math.floor(h * 0.75) - 1)
  else
    wrapped = gpuproxy.area(__gpu, 2, 2, w - 2, h - 2)
  end

  return tty.create(wrapped)
end

local function install_online(wrapped)
  local pklist = {
    "cldr",
    "cynosure",
    "refinement",
    "coreutils",
    "corelibs",
    "upm"
  }
  local upm = loadfile("/bin/upm.lua")

  local oi, oo, oe = io.stdin, io.stdout, io.stderr
  io.stdin, io.stdout, io.stderr = wrapped
  io.input(wrapped)
  io.output(wrapped)
  wrapped:write("\27[2J")

  pcall(upm, "install", "-fy", table.unpack(pklist))
  
  io.stdin, io.stdout, io.stderr = oi, oo, oe
  io.input(oi)
  io.output(oo)

  return true
end

local function install_offline(wrapped)
  local dirs = {
    "bin",
    "etc",
    "lib",
    "sbin",
    "usr",
    "init.lua"
  }
  wrapped:write("\27[2Jthis is a test\n")
  require("tty").delete(wrapped.tty)
end

clear()
while true do
  refresh()
  local key, flags = termio.readKey()
  if flags.ctrl then
    if key == "q" then
      io.write("\27[m\27[2J\27[1;1H")
      os.exit()
    elseif key == "m" then
      if page == 1 then
        if sel == 2 then
          page = page + 1
          clear()
        end
      elseif page == 2 then
        if sel == 2 then
          page = page - 1
          clear()
        elseif sel > 2 then
          sel_fs = pages[2][sel].text:gsub(" +", "")
          page = page + 1
          sel = 2
          clear()
        end
      elseif page == 3 then
        if sel == 2 then
          install_online(preinstall())
          page = page + 1
        elseif sel == 3 then
          install_offline(preinstall())
          page = page + 1
        end
      elseif page == 4 then
      end
    end
  elseif key == "up" then
    if sel > 1 then
      sel = sel - 1
    end
  elseif key == "down" then
    if sel < #pages[page] then
      sel = sel + 1
    end
  end
end
