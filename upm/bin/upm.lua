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

local usage = "\
UPM - the ULOS Package Manager\
\
usage: \27[36mupm \27[39m[\27[93moptions\27[39m] \27[96mCOMMAND \27[39m[\27[96m...\27[39m]\
\
Available \27[96mCOMMAND\27[39ms:\
  \27[96minstall \27[91mPACKAGE ...\27[39m\
    Install the specified \27[91mPACKAGE\27[39m(s).\
\
  \27[96mremove \27[91mPACKAGE ...\27[39m\
    Remove the specified \27[91mPACKAGE\27[39m(s).\
\
  \27[96mupdate\27[39m\
    Update (refetch) the repository package lists.\
\
  \27[96msearch \27[91mPACKAGE\27[39m\
    Search local package lists for \27[91mPACKAGE\27[39m, and\
    display information about it.\
\
Available \27[93moption\27[39ms:\
  \27[93m-q\27[39m            Be quiet;  no log output.\
  \27[93m-v\27[39m            Be verbose;  overrides \27[93m-q\27[39m.\
  \27[93m--root\27[39m=\27[33mPATH\27[39m   Treat \27[33mPATH\27[39m as the root filesystem\
                instead of /.\
"

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

local installed, ipath
do
  ipath = path.concat(cfg.General.dataDirectory, "installed.list")
  local inst, err = config.table:load(ipath)
  if not inst and err then
    exit("cannot open installed.list: " .. err)
  end
  installed = inst
end

local search, update, download, extract, install_package, install

function search(name)
  log(pfx.info, "querying repositories for package")
  local repos = cfg.Repositories
  for k, v in pairs(repos) do
    log(pfx.info, "searching list ", k)
    local data, err = config.table:load(path.concat(cfg.General.dataDirectory, k .. ".list"))
    if not data then
      log(pfx.warn, "list ", k, " is nonexistent; run 'upm update' to refresh")
    else
      if data.packages[name] then
        return data.packages[name], k
      end
    end
  end
  exit("package ", name, " not found")
end

function update()
  log(pfx.info, "refreshing package lists")
  local repos = cfg.Repositories
  for k, v in pairs(repos) do
    log(pfx.info, "refreshing list: ", k)
    local url = v .. "/packages.list"
    download(url, path.concat(cfg.General.dataDirectory, k .. ".list"))
  end
end

function download(url, dest)
  log(pfx.warn, "downloading ", url, " as ", dest)
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

function extract(package)
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

function install_package(name)
  local data, err = search(name)--config.table:load(path.concat(cfg.General.cacheDirectory, name .. ".list"))
  if not data then
    exit("failed reading metadata for package " .. name .. ": " .. err)
  end
  local files = extract(path.concat(cfg.General.cacheDirectory, name .. ".mtar"))
  installed[name] = {info = data, files = files}
end

if opts.help or args[1] == "help" then
  io.stderr:write(usage)
  os.exit(1)
end

if #args == 0 then
  exit("an operation is required; see 'upm --help'")
end

if args[1] == "install" then
  if not args[2] then
    exit("command verb 'install' requires at least one argument")
  end
  for i=2, #args, 1 do
    local data, repo = search(args[i])
    if installed[args[i]] and installed[args[i]].version >= data.version and not opts.q then
      log(pfx.err, "package is already installed")
    else
      --download(cfg.Repositories[repo] .. data.metadata, path.concat(cfg.General.cacheDirectory, args[i] .. ".list"))
      download(cfg.Repositories[repo] .. data.mtar, path.concat(cfg.General.cacheDirectory, args[i] .. ".mtar"))
      install_package(args[i])
    end
  end
  config.table:save("installed.list", installed)
elseif args[1] == "remove" then
  exit("operation 'remove' not implemented yet")
elseif args[1] == "update" then
  update()
elseif args[1] == "search" then
  if not args[2] then
    exit("command verb 'search' requires at least one argument")
  end
  for i=2, #args, 1 do
    local data, repo = search(args[i])
    io.write("\27[94m", repo, "\27[39m/", args[i], "\n")
    io.write("  \27[92mAuthor: \27[39m", data.author or "(unknown)", "\n")
    io.write("  \27[92mDesc: \27[39m", data.description or "(no description)", "\n")
  end
else
  exit("operation '" .. args[1] .. "' is unrecognized")
end
