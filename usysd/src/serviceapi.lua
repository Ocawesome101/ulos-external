-- service API --

do
  usd.log(usd.statii.ok, "initializing service management")

  local config = require("config").bracket
  local fs = require("filesystem")
  local users = require("users")
  local process = require("process")

  local autostart = "/etc/usysd/autostart.cfg"
  local svc_dir = "/etc/usysd/enabled/"
  local svc_from = "/etc/usysd/installed/"

  local api = {}
  local running = {}
  usd.running = {}

  function api.start(name)
    usd.log(usd.statii.wait, "starting service ", name)
    local cfg = config:load(svc_dir .. name)
    if not cfg then
      usd.log("\27[A\27[G", usd.statii.fail, "service ", name, " not found!")
      return nil
    end
    if not (cfg["usysd-service"] and cfg["usysd-service"].file) then
      usd.log("\27[A\27[G", usd.statii.fail, "service ", name, " has bad configuration")
      return nil
    end
    local file = cfg["usysd-service"].file
    local user = cfg["usysd-service"].user or "root"
    local uid, err = users.get_uid(user)
    if not uid then
      usd.log("\27[A\27[G", usd.statii.fail, "service ", name, " is configured to run as ",
        user, " but: ", err)
      return nil
    end
    if user ~= process.info().owner and process.info().owner ~= 0 then
      usd.log("\27[A\27[G", usd.statii.fail, "service ", name, " cannot be started as ",
        user, ": insufficient permissions")
      return nil
    end
    local ok, err = loadfile(file)
    if not ok then
      usd.log("\27[A\27[G", usd.statii.fail, "failed to start ", name, ": ", err)
      return nil
    end
    local pid, err = users.exec_as(uid, "", ok, "["..name.."]")
    if not pid then
      ust.log("\27[A\27[G", usd.statii.fail, "failed to start ", name, ": ", err)
      return nil
    end
    running[name] = pid
    return true
  end

  function api.stop()
  end

  function api.list()
  end

  usd.api = api
  package.loaded.usysd = api

  -- autostart is a file with each line being a service to start
  for line in io.lines(autostart) do
    api.start(line)
  end
end
