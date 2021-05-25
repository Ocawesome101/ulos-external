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
Mount the filesystem node NODE at LOCATION.  If
FSTYPE is either "overlay" or unset, NODE will
be mounted as an overlay at LOCATION.  Otherwise,
if NODE points to a filesystem in /sys/dev, mount
will try to read device information from the file.
If both of these cases fail, NODE will be treated
as a component address.
]])
  os.exit(1)
end

if #args == 0 then
  print(readFile("/sys/mounts"))
  os.exit(0)
end

local fstype = args[3] or ""
