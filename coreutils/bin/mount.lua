-- coreutils: mount --

local filesystem = require("filesystem")

local args, opts = require("argutil").parse(...)

local function readFile(f)
  local handle, err = io.open(f, "r")
  if not handle then
    io.stderr:write("mount: cannot open ", f, ": ", err, "\n")
    os.exit(1)
  end
  local data = handle:read("a")
  handle:close()

  return data
end

if opts.help then
  io.stderr:write([[
usage: mount NODE LOCATION [FSTYPE]
]])
  os.exit(1)
end

if #args == 0 then
  print(readFile("/sys/mounts"))
  os.exit(0)
end


