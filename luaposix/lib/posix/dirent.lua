-- posix.dirent --

local paths = require("path")
local filesystem = require("filesystem")

local dirent = {}

function dirent.dir(path)
  checkArg(1, path, "string", "nil")
  path = path or "."
  local opath = path
  path = paths.canonical(path)
  local files, err = filesystem.list(path)
  if not files then
    error("bad argument #1 to 'dir' ("..path..": " .. err .. ")")
  end
  table.insert(files, ".")
  table.insert(files, "..")
  return files
end

function dirent.files(path)
  checkArg(1, path, "string", "nil")
  path = path or "."
  local opath = path
  path = paths.canonical(path)
  local files, err = filesystem.list(path)
  if not files then
    error("bad argument #1 to 'files' ("..path..": " .. err .. ")")
  end
  table.insert(files, ".")
  table.insert(files, "..")
  local fi = 0
  return function()
    fi = fi + 1
    return files[fi]
  end
end

return dirent
