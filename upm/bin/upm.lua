-- UPM: the ULOS Package Manager --

local fs = require("filesystem")
local path = require("path")
local tree = require("futil").tree
local config = require("config")
local network = require("network")

local args, opts = require("argutil").parse(...)

local cfg = config.bracket:load("/etc/upm.cfg") or {}

cfg.General = cfg.General or {}
cfg.General.dataDirectory = cfg.General.dataDirectory or "/etc/upm"
cfg.General.cacheDirectory = cfg.General.cacheDirectory or "/etc/upm/cache"
cfg.Repositories = cfg.Repositories or {main = "https://oz-craft.pickardayune.com/upm/main/"}

config.bracket:save("/etc/upm.cfg", cfg)

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
  --root=PATH   Treat PATH as the root filesystem
                instead of /.
]]

local pfx = {
  info = "\27[92m::\27[39m ",
  warn = "\27[93m::\27[39m ",
  err = "\27[91m::\27[39m "
}

local function log(...)
  if not opts.q then
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
      end
    end
  end
end

local function download(url, dest)
  local handle, err = network.request(url)
  if not handle then
    exit(err)
  end
end

local function extract()
end

local function install(file)
end
