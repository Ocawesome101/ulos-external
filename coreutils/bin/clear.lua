-- coreutils: clear --

local args, opts = require("argutils").parse(...)

if opts.help then
  io.stderr:write([[
usage: clear
Clears the screen by writing to standard output.
]])
  os.exit(1)
end

if io.stdout.tty then io.stdout:write("\27[2J\27[1H") end
