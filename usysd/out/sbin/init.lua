-- USysD init system.  --
-- Copyright (c) 2021 Ocawesome101 under the DSLv2.

local usd = {}

--  usysd versioning stuff --

usd._VERSION_MAJOR = 0
usd._VERSION_MINOR = 0
usd._VERSION_PATCH = 0
usd._RUNNING_ON = "unknown"

io.write(string.format("USysD version %d.%d.%d\n", usd._VERSION_MAJOR, usd._VERSION_MINOR,
  usd._VERSION_PATCH))

do
  local handle, err = io.open("/etc/os-release")
  if handle then
    local data = handle:read("a")
    handle:close()

    local name = data:match("PRETTY_NAME=\"(.-)\"")
    if name then usd._RUNNING_ON = name end
  end
end

io.write("\n\n  \27[97mWelcome to \27[96m" .. usd._RUNNING_ON .. "\27[97m!\27[37m\n\n")
--#include "src/version.lua"
-- logger stuff --

usd.statii = {
  ok = "\27[97m[\27[92m OK \27[97m] ",
  warn = "\27[97m[\27[93mWARN\27[97m] ",
  fail = "\27[97m[\27[91mFAIL\27[97m] ",
}

function usd.log(...)
  io.write(...)
  io.write("\n")
end
--#include "src/logger.lua"
-- service API --

do
  usd.log(usd.statii.ok, "initializing service management")

  local config = require("config").bracket
  local fs = require("filesystem")

  local autostart = "/etc/usysd/autostart.cfg"
  local svc_dir = "/etc/usysd/enabled/"
  local svc_from = "/etc/usysd/installed/"

  local api = {}
  local running = {}

  function api.start(name)
  end

  function api.stop()
  end

  function api.list()
  end

  usd.api = api
  package.loaded.usysd = api
end
--#include "src/serviceapi.lua"
--#include "src/shutdown.lua"

while true do
  coroutine.yield()
end
