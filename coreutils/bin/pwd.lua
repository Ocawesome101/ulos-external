-- coreutils: pwd --

local args, opts = require("argutil").parse(...)

if opts.help then
  io.stderr:write([[
usage: pwd
Print the current working directory.
]])
  os.exit(1)
end

io.write(os.getenv("PWD"), "\n")
