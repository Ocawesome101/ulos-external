-- lua REPL --

local args = table.pack(...)
local notopts, opts = require("argutil").parse(...)

opts.i = #notopts == 0

if opts.help then
  io.stderr:write([=[
usage: lua [options] [script [args ...]]
Available options are:
  -e stat  execute string 'stat'
  -i       enter interactive mode after executing 'script'
  -l name  require library 'name' into global 'name'
]=])
end

-- prevent some pollution of _G
local prog_env = {}
for k, v in pairs(_G) do prog_env[k] = v end

if opts.i then
  while true do
  end
end
