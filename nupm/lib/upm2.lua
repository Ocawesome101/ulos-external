-- the ULOS Package Manager, version 2 --
-- major changes:  the API is now state-based using coroutines,
--    allowing custom frontends to properly display output.  this
--    does add complexity to the process of creating a frontend,
--    but is a worthwhile tradeoff for the flexibility it offers.

local fs = require("filesystem")
local path = require("path")
local mtar = require("mtar")
local size = require("size")
local config = require("config")
local network = require("network")
local computer = require("computer")
local filetypes = require("filetypes")

local api = {}

local in_use = false

local _upm = {}

function _upm:search(name, literal)
  local repos = self.config.Repositories
  local results = {}
  
  for k, v in pairs(repos) do
    local data, err = config.table:load(path.concat(self.opts.root,
      self.config.General.dataDirectory, k .. ".list"))

    if not data then
      coroutine.yield("warn", "list " .. k .. " is nonexistent (err: "
        .. err .. ")")
    else
      local found
      if literal then
        if data.packages[name] then
          return data.packages[name], k, name
        else
          coroutine.yield("error", "package " .. literal .. " not found")
          return
        end
      else
        for nk, v in pairs(data.packages) do
          if nk:match(name) then
            results[#results + 1] = {data = v, repo = k, name = nk,
              installed = not not self.installed[nk]}
          end
        end
      end
    end
  end

  return results
end

function _upm:update()
  for k, v in pairs(self.config.Repositories) do
    print("YIELD STATE")
    coroutine.yield("state", "refreshing list: " .. k)
    local url = v .. "/packages.list"
    self:download(url, path.concat(self.opts.root,
      self.config.General.dataDirectory, k .. ".list"))
  end
  return true
end

function _upm:download(url, dest, total)
  coroutine.yield("state", "downloading " .. url .. " as " .. dest)
  local out, err = io.open(dest, "w")
  if not out then
    coroutine.yield("error", dest .. ": " .. err)
    return
  end

  local handle, err = network.request(url)
  if not handle then
    out:close()
    coroutine.yield("error", err)
    return
  end

  local downloaded = 0
  local last_updated = 0

  repeat
    local chunk = handle:read(self.config.General.downloadChunkSize or 2048)
    if chunk then downloaded = downloaded + #chunk out:write(chunk) end
    if total then
      if computer.uptime() - last_updated >
          self.configGeneral.progressInterval then
        last_updated = computer.uptime()
        coroutine.yield("progress", downloaded, total, size.format(downloaded),
          size.format(total))
      end
    end
  until not chunk
  handle:close()
  out:close()
  return true
end

function _upm:extract(package)
  local base, err = io.open(package, "r")
  if not base then
    coroutine.yield("error", package .. ": " .. err)
    return
  end
  
  local files = {}

  for file, diter, len in mtar.unarchive(base) do
    files[#files + 1] = file
    if self.opts.v then
      coroutine.yield("status", "extracting file: " .. file .. " (length "
        .. len .. ")")
    end

    local absolute = path.concat(self.opts.root, file)
    local segments = path.split(absolute)

    for i=1, #segments - 1, 1 do
      local create = table.concat(segments, "/", 1, i)
      if not fs.stat(create) then
        local ok, err = fs.touch(create, filetypes.directory)
        if not ok and err then
          coroutine.yield("error", "failed to create directory " .. create
            .. ": " .. err .. " (manual cleanup may be required!!)")
          return
        end
      end
    end
    
    local handle, err = io.open(absolute, "w")
    if not handle then
      coroutine.yield("error", absolute .. ": " .. err)
      return
    end

    while len > 0 do
      local chunk = diter(math.min(len, 2048))
      if not chunk then break end
      len = len - #chunk
      handle:write(chunk)
    end
    handle:close()
  end
  base:close()
  return files
end

function _upm:install_package(name)
  local data = self:search(name, true)
  if #data == 0 then
    coroutine.yield("error", "package not found")
    return
  end

  local old_data = self.installed[name] or {info={version=0},files={}}
  local files = self:extract(path.concat(self.opts.root,
    self.config.General.cacheDirectory, name .. ".mtar"))

  installed[name] = {info = data, files = files}
  config.table:save(self.ipath, self.installed)

  -- TODO: check file ownership by other packages,
  --    and remove empty directories
  local to_remove = {}
  local map = {}
  for k, v in pairs(files) do map[v] = true end
  for i, check in ipairs(old_data.files) do
    if not map[check] then to_remove[#to_remove+1] = check end
  end
  if #to_remove > 0 then
    os.execute("rm -rf " .. table.concat(to_remove, " "))
  end

  return true
end

function _upm:dl_pkg(name, repo, data)
  download(self.config.Repositories[repo] .. data.mtar,
    path.concat(self.opts.root, self.config.General.cacheDirectory,
      name .. ".mtar"),
    data.size)
end

function _upm:install(packages)
  if #packages == 0 then
    coroutine.yield("error", "no packages to install")
    return
  end

  local to_install, total_size = {}, 0
  local resolve, resolving = nil, {}
  resolve = function(pkg)
    local data, repo = self:search(pkg, true)
    if self.installed[pkg] and self.installed[pkg].info.version >= data.version
        and not self.opts.f then
      coroutine.yield("warn", pkg .. ": package is already installed")
    elseif resolving[pkg] then
      coroutine.yield("warn", pkg .. ": circular dependency detected")
    else
      to_install[pkg] = {data = data, repo = repo}
      if data.dependencies then
        local orp = resolving[pkg]
        resolving[pkg] = true
        for i, dep in pairs(data.dependencies) do
          resolve(dep)
        end
        resolving[pkg] = orp
      end
    end
  end

  coroutine.yield("status", "resolving dependencies")
  for i=1, #packages, 1 do
    resolve(packages[i])
  end

  local largest = 0
  local ptext =  "packages to install:\n"
  for k, v in pairs(to_install) do
    total_size = total_size + (v.data.size or 0)
    largest = math.max(largest, v.data.size)
    ptext = ptext .. "  " .. k .. "-" .. v.data.version
  end

  ptext = ptext .. "\n\nTotal download size: " .. size.format(total_size)
    .. "\n"
    .. "Space required: " .. size.format(total_size + largest) .. "\n"

  coroutine.yield("status", ptext)

  if not self.opts.y then
    local cont = coroutine.yield("prompt", "\nContinue? [Y/n] ")
    if not cont then return end
  end

  coroutine.yield("status", "downloading packages")
  for k, v in pairs(to_install) do
    self:dl_pkg(k, v.repo, v.data)
  end

  coroutine.yield("status", "installing packages")
  for k, v in pairs(to_install) do
    self:install_package(k, v)
    -- remove package mtar - it just takes up space now
    fs.remove(path.concat(self.pts.root, self.config.General.cacheDirectory,
      k .. ".mtar"))
  end
end

function _upm:remove(args)
  local rm = assert(loadfile("/bin/rm.lua"))

  local ptext = "packages to remove:\n  " .. table.concat(args, "  ") .. "\n"

  if not self.opts.y then
    local cont = coroutine.yield("prompt", "\nContinue? [Y/n]")
  end

  for i=1, #args, 1 do
    local ent = self.installed[args[i]]
    if not ent then
      coroutine.yield("status", "package ", args[i], " is not installed")
    else
      coroutine.yield("status", "removing files")
      local removed = 0
      for i, file in ipairs(ent.files) do
        removed = removed + 1
        rm("-rf", path.concat(self.opts.root, file))
        coroutine.yield("progress", removed, #ent.files, tostring(removed),
          tostring(#ent.files))
      end
      coroutine.yield("status", "unregistering package")
      self.installed[args[i]] = nil
    end
  end
  config.table:save(self.ipath, self.installed)
end

function _upm:upgrade()
  local to_upgrade = {}
  for k, v in pairs(self.installed) do
    local data, repo = self:search(k, true)
    if not (self.installed[k] and self.installed[k].info.version >= data.version
        and not opts.f) then
      coroutine.yield("status", "upgrading ", k)
      to_upgrade[#to_upgrade+1] = k
    end
  end
  self:install(to_upgrade)
end

function _upm:list(args)
  local result = {}
  if args[1] == "installed" then
    for k in pairs(self.installed) do
      result[#result+1] = k
    end
  elseif args[1] == "all" or not args[1] then
    for k, v in pairs(self.config.Repositories) do
      local data, err = config.table:load(path.concat(self.opts.root,
        self.config.General.dataDirectory, k .. ".list"))
      if not data then
        coroutine.yield("warn", "list " .. k .. " is nonexistent (err: "
          .. err .. ")")
      else
        for p in pairs(data.packages) do
          result[#result+1] = p
        end
      end
    end
  elseif self.config.Repositories[args[1]] then
    local data, err = config.table:load(path.concat(self.opts.root,
      self.config.General.dataDirectory, args[1] .. ".list"))
    if not data then
      coroutine.yield("warn", "list " .. args[1] .. " is nonexistent (err: "
        .. err .. ")")
    else
      for p in pairs(data.packages) do
        result[#result+1] = p
      end
    end
  else
    coroutine.yield("error", "cannot determine target '" .. args[1] .. "'")
  end

  table.sort(result)

  return result
end

local function state_base(opts)
  local state = setmetatable({opts = opts}, {__index = _upm})
  
  local cfg = config.bracket:load("/etc/upm.cfg") or
    {__load_order={"General","Repositories"}}

  cfg.General = cfg.General or {__load_order={"dataDirectory","cacheDirectory",
    "downloadChunkSize", "progressInterval"}}
  cfg.General.dataDirectory = cfg.General.dataDirectory or "/etc/upm"
  cfg.General.cacheDirectory = cfg.General.cacheDirectory or "/etc/upm/cache"
  cfg.General.downloadChunkSize = cfg.General.downloadChunkSize or 2048
  cfg.General.progressInterval = cfg.General.progressInterval or 1.0
  cfg.Repositories = cfg.Repositories or {__load_order={"main"},
    main = "https://oz-craft.pickardayune.com/upm/main/"}
  
  config.bracket:save("/etc/upm.cfg", cfg)
  state.config = cfg
  
  if type(opts.root) ~= "string" then opts.root = "/" end
  opts.root = path.canonical(opts.root)
  
  -- create directories
  os.execute("mkdir -p " .. path.concat(opts.root, cfg.General.dataDirectory))
  os.execute("mkdir -p " .. path.concat(opts.root, cfg.General.cacheDirectory))
  
  if opts.root ~= "/" then
    config.bracket:save(path.concat(opts.root, "/etc/upm.cfg"), cfg)
  end

  local ipath = path.concat(opts.root, cfg.General.dataDirectory,
    "installed.list")
  
  if not fs.stat(ipath) then
    local handle, err = io.open(ipath, "w")
    if not handle then
      coroutine.yield("error", "cannot create installed.list: " .. err)
      return
    end
    handle:write("{}")
    handle:close()
  end

  local inst, err = config.table:load(ipath)
  if not inst and err then
    coroutine.yield("error", "cannot open installed.list: " .. err)
    return
  end

  state.ipath = ipath
  state.installed = inst
  
  while true do
    local op = table.pack(coroutine.yield("get_operation"))
    print("OPERATION", table.unpack(op))
    if op[1] == "close" then
      in_use = false
      break
    elseif not api[op[1]] then
      coroutine.yield("error", "unrecognized command: " .. op[1])
    else
      coroutine.yield("result", state[op[1]](state, table.unpack(op, 2, op.n)))
    end
  end
  coroutine.yield("status", "finished")
end

function api.newState(opts)
  if in_use then
    return nil, "another UPM state is already running"
  end

  in_use = true
  
  local coro = coroutine.create(function()return state_base(opts)end)
  return coro
end

return api
