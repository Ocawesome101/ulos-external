-- lua REPL --

local args = table.pack(...)
local notopts, opts = require("argutil").parse(...)

opts.i = opts.i or #args == 0

if opts.help then
  io.stderr:write([=[
usage: lua [options] [script [args ...]]
Available options are:
  -e stat  execute string 'stat'
  -i       enter interactive mode after executing 'script'
  -l name  require library 'name' into global 'name'
]=])
  os.exit(1)
end

-- prevent some pollution of _G
local prog_env = {}
for k, v in pairs(_G) do prog_env[k] = v end
setmetatable(prog_env, {__index = _G})

if opts.v then
  if _VERSION == "Lua 5.2" then
    io.write(_VERSION, "  Copyright (C) 1994-2015 Lua.org, PUC-Rio\n")
  else
    io.write(_VERSION, "  Copyright (C) 1994-2020 Lua.org, PUC-Rio\n")
  end
end

for i=1, #args, 1 do
  if args[i] == "-e" then
    opts.e = args[i + 1]
    if not opts.e then
      io.stderr:write("lua: '-e' needs argument")
    end
    break
  end
end

if opts.e then
  local ok, err = load(opts.e, "=(command line)", "bt", env)
  if not ok then
    io.stderr:write(err, "\n")
    if not opts.i then os.exit(1) end
  else
    local result = table.pack(xpcall(ok, debug.traceback))
    if not result[1] and result[2] then
      io.stderr:write(result[2], "\n")
      if not opts.i then os.exit(1) end
    elseif result[1] then
      print(table.unpack(result, 2, result.n))
    end
  end
end

if opts.i then
  while true do
    io.write("> ")
    local eval = io.read("l")
    local ok, err = load(eval, "=stdin", "bt", env)
    if not ok then
      ok, err = load("return " ..eval, "=stdin", "bt", env)
    end
    if not ok then
      io.stderr:write(err, "\n")
    else
      local result = table.pack(xpcall(ok, debug.traceback))
      if not result[1] and result[2] then
        io.stderr:write(result[2], "\n")
      elseif result[1] then
        print(table.unpack(result, 2, result.n))
      end
    end
  end
end
