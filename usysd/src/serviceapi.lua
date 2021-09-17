-- service API --

do
  usd.log(usd.statii.ok, "initializing service management")

  local config = require("config").bracket
  local fs = require("filesystem")
  local users = require("users")
  local process = require("process")

  local autostart = "/etc/usysd/autostart"
  local svc_dir = "/etc/usysd/services/"

  local api = {}
  local running = {}
  local requests = {}
  usd.running = running
  usd.requests = requests

  local starting = {}
  local ttys = {[0] = io.stderr}

  local function request(name, op)
    local n = #requests+1
    requests[n] = {name = name, op = op}
    repeat until requests[n].performed
    requests[n].clear = true
    return table.unpack(requests[n], 1, requests[n].n)
  end

  function api.start(name)
    checkArg(1, name, "string")
    return request(name, "internal_start")
  end

  function api.stop(name)
    checkArg(1, name, "string")
    return request(name, "internal_stop")
  end
  
  function api.enable(name)
    checkArg(1, name, "string")
    return request(name, "internal_enable")
  end

  function api.disable(name)
    checkArg(1, name, "string")
    return request(name, "internal_disable")
  end

  function usd.internal_start(name)
    if running[name] or starting[name] then return true end

    local full_name = name
    local tty = io.stderr.tty
    do
      local _name, _tty = name:match("(.+)@tty(%d+)")
      name = _name or name
      tty = tonumber(_tty) or tty
      if not ttys[tty] then
        local hnd, err = io.open("/sys/dev/tty" .. tty)
        if not hnd then
          usd.log(usd.statii.fail, "cannot open tty", tty, ": ", err)
          return nil
        end
        ttys[tty] = hnd
        hnd.tty = tty
      end
    end
    
    usd.log(usd.statii.wait, "starting service ", name)
    local cfg = config:load(svc_dir .. name)
    
    if not cfg then
      usd.log("\27[A\27[G\27[2K", usd.statii.fail, "service ", name, " not found!")
      return nil
    end
    
    if not (cfg["usysd-service"] and cfg["usysd-service"].file) then
      usd.log("\27[A\27[G\27[2K", usd.statii.fail, "service ", name,
        " has invalid configuration")
      return nil
    end
    
    local file = cfg["usysd-service"].file
    local user = cfg["usysd-service"].user or "root"
    local uid, err = users.get_uid(user)
    
    if not uid then
      usd.log("\27[A\27[G\27[2K", usd.statii.fail, "service ", name,
        " is configured to run as ", user, " but: ", err)
      return nil
    end
    
    if user ~= process.info().owner and process.info().owner ~= 0 then
      usd.log("\27[A\27[G\27[2K", usd.statii.fail, "service ", name,
        " cannot be started as ", user, ": insufficient permissions")
      return nil
    end

    starting[full_name] = true
    if cfg["usysd-service"].depends then
      for i, svc in ipairs(cfg["usysd-service"].depends) do
        local ok = api.start(svc)
        if not ok then
          usd.log(usd.statii.fail, "failed starting dependency ", svc)
          starting[name] = false
          return nil
        end
      end
    end
    
    local ok, err = loadfile(file)
    if not ok then
      usd.log("\27[A\27[G\27[2K", usd.statii.fail, "failed to load ", name, ": ", err)
      return nil
    end

    starting[full_name] = false
    local pid, err = users.exec_as(uid, "", ok, "["..name.."]", nil, ttys[tty])
    if not pid and err then
      usd.log("\27[A\27[G\27[2K", usd.statii.fail, "failed to start ", full_name, ": ", err)
      return nil
    end

    usd.log("\27[A\27[G\27[2K", usd.statii.ok, "started service ", full_name)
    
    running[full_name] = pid
    return true
  end

  function usd.internal_stop()
    usd.log(usd.statii.ok, "stopping service ", name)
    if not running[name] then
      usd.log(usd.statii.warn, "service ", name, " is not running")
      return nil
    end
    local ok, err = process.kill(running[name], process.signals.quit)
    if not ok then
      usd.log(usd.statii.fail, "service ", name, " failed to stop: ", err, "\n")
      return nil
    end
    running[name] = nil
    return true
  end

  function api.list(enabled, running)
    enabled = not not enabled
    running = not not running
    if running then
      local list = {}
      for name in pairs(usd.running) do
        list[#list + 1] = name
      end
      return list
    end
    if enabled then
      local list = {}
      for line in io.lines(autostart,"l") do
        list[#list + 1] = line
      end
      return list
    end
    return fs.list(svc_dir)
  end

  function usd.internal_enable(name)
    local enabled = api.list(true)
    local handle, err = io.open(autostart, "w")
    if not handle then return nil, err end
    table.insert(enabled, math.min(#enabled + 1, math.max(1, #enabled - 1)), name)
    handle:write(table.concat(enabled, "\n"))
    handle:close()
    return true
  end

  function usd.internal_disable(name)
    local enabled = api.list(true)
    local handle, err = io.open(autostart, "w")
    if not handle then return nil, err end
    for i=1, #enabled, 1 do
      if enabled[i] == name then
        table.remove(enabled, i)
        break
      end
    end
    handle:write(table.concat(enabled, "\n"))
    handle:close()
    return true
  end

  usd.api = api
  package.loaded.usysd = package.protect(api)

  for line in io.lines(autostart, "l") do
    usd.internal_start(line)
  end
end
