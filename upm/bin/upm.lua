-- UPM: the ULOS Package Manager --

local fs = require("filesystem")
local path = require("path")
local tree = require("futil").tree
local mtar = require("mtar")
local config = require("config")
local network = require("network")
local filetypes = require("filetypes")

local args, opts = require("argutil").parse(...)

local cfg = config.bracket:load("/etc/upm.cfg") or {}

cfg.General = cfg.General or {}
cfg.General.dataDirectory = cfg.General.dataDirectory or "/etc/upm"
cfg.General.cacheDirectory = cfg.General.cacheDirectory or "/etc/upm/cache"
cfg.Repositories = cfg.Repositories or {main = "https://oz-craft.pickardayune.com/upm/main/"}

config.bracket:save("/etc/upm.cfg", cfg)

if type(opts.root) ~= "string" then opts.root = "/" end
opts.root = path.canonical(opts.root)

local usage = [[
UPM - the ULOS Package Manager

usage: upm [options] COMMAND [...]

Available COMMANDs:
  install PACKAGE ...
    Install the specified PACKAGE(s).

  remove PACKAGE ...
    Remove the specified PACKAGE(s).

  update
    Update (refetch) the repository package lists.

  search PACKAGE
    Search local package lists for PACKAGE, and
    display information about it.

Available options:
  -q            Be quiet;  no log output.
  -v            Be verbose;  overrides -q.
  --root=PATH   Treat PATH as the root filesystem
                instead of /.
]]

local pfx = {
  info = "\27[92m::\27[39m ",
  warn = "\27[93m::\27[39m ",
  err = "\27[91m::\27[39m "
}

local function log(...)
  if opts.v or not opts.q then
    io.stderr:write(...)
    io.stderr:write("\n")
  end
end

local function exit(reason)
  log(pfx.err, reason)
  os.exit(1)
end

local installed
do
  local inst, err = config.table:load(path.concat(cfg.dataDirectory, "installed.list"))
  if not inst and err then
    exit(err)
  end
  installed = inst
end

local function search(name)
  log(pfx.info, "querying repositories for package")
  local repos = cfg.Repositories
  for k, v in pairs(repos) do
    log(pfx.info, "searching list ", k)
    local data, err = config.table:load(path.concat(cfg.dataDirectory, k .. ".list"))
    if not data then
      log(pfx.warn, "list ", k, " is nonexistent; run 'upm update' to refresh")
    else
      if data.packages[name] then
        return data.packages[name]
      end
    end
  end
  exit("package ", name, " not found")
end

local function download(url, dest)
  log("downloading ", url, " as ", dest)
  local out, err = io.open(dest, "w")
  if not out then
    exit(dest .. ": " .. err)
  end

  local handle, err = network.request(url)
  if not handle then
    out:close() -- just in case
    exit(err)
  end

  repeat
    local chunk = handle:read(2048)
    if chunk then out:write(chunk) end
  until not chunk
  handle:close()
  out:close()
end

local function extract(package)
  log(pfx.info, "extracting ", package)
  local base, err = io.open(package, "r")
  if not base then
    exit(package .. ": " .. err)
  end
  local stream = mtar.unarchive(base)
  local files = {}
  for file, data in function() return stream:readfile() end do
    files[#files+1] = file
    if opts.v then
      log("  ", pfx.info, "extract file: ", file)
    end
    local absolute = path.concat(opts.root, file)
    local segments = path.split(absolute)
    for i=1, #segments - 1, 1 do
      local create = table.concat(segments, 1, i, "/")
      local ok, err = fs.touch(create, filetypes.directory)
      if not ok and err then
        log(pfx.err, "failed to create directory " .. create .. ": " .. err)
        exit("leaving any already-created files - manual cleanup may be required!")
      end
    end
    local handle, err = io.open(absolute, "w")
    if not handle then
      exit(absolute .. ": " .. err)
    end
    handle:write(data)
    handle:close()
  end
  stream:close()
  log(pfx.info, "ok")
end

local function install_package(name)
  local data, err = config.table:load(path.concat(cfg.General.cacheDirectory, name .. ".list"))
  if not data then
    exit("failed reading metadata for package " .. name .. ": " .. err)
  end
  extract(path.concat(cfg.General.cacheDirectory, name .. ".mtar"))
end

if opts.help then
  io.stderr:write(usage)
  os.exit(1)
end
