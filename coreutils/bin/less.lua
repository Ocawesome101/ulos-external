-- coreutils: more --

local termio = require("termio")

local args, opts = require("argutil").parse(...)

if #args == 0 or opts.help then
  io.stderr:write([[
usage: less FILE ...
Page through FILE(s).  They will be concatenated.
]])
  os.exit(1)
end

local lines = {}
local scr = 0

local w, h = termio.getTermSize()

local function scroll(n)
  local l
  if n and scr+h < #lines then
    scr=scr+1
    local ln = lines[scr+h-1]
    io.write("\27[", h, ";H", #ln==0 and" "or ln, "\27[S\27[", h, ";1H")
    l = lines[scr+h]
  elseif scr > 0 then
    scr=scr-1
    io.write("\27[T\27[1H")
    l = lines[scr]
  end
  if (not l) or #l == 0 then l = " " end
  io.write(l or " ")
  io.flush()
end

for i=1, #args, 1 do
  for line in io.lines(args[i], "l") do
    lines[#lines+1] = line
  end
end

io.write("\27[1;1H")
for i=1, h, 1 do
  io.write(lines[i], "\n")
end

local prompt = string.format("\27[%d;1H\27[2K:", h)

io.write(prompt)
while true do
  local key, flags = termio.readKey()
  if key == "c" and flags.control then
    -- interrupted
    io.write("interrupted\n")
    os.exit(1)
  elseif key == "q" then
    io.write("\27[2J\27[1;1H")
    io.flush()
    os.exit(0)
  elseif key == "up" then
    scroll(false)
  elseif key == "down" then
    scroll(true)
  elseif key == " " then
    for i=1, h, 1 do scroll(true) end
  end
  io.write(prompt)
end
