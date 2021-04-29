-- file --

local fs = require("filesystem")
local path = require("path")
local filetypes = require("filetypes")

local args, opts = require("argutil").parse(...)

if #args == 0 or opts.help then
  io.stderr:write([[
usage: file <file1> [<file2> ...]
   or: file [--help]
]])
  os.exit(0)
end

for i=1, #args, 1 do
  local full = path.canonical(args[i])
  local ok, err = fs.stat(full)
  if not ok then
    io.stderr:write("file: cannot stat '", args[i], "': ", err, "\n")
    os.exit(1)
  end
  local ftype = "data"
  for k, v in pairs(filetypes) do
    if v == ok.type then
      ftype = k
      break
    end
  end
  io.write(args[i], ": ", ftype, "\n")
end
