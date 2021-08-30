-- USysD init system.  --
-- Copyright (c) 2021 Ocawesome101 under the DSLv2.

if package.loaded.usysd then
  io.stderr:write("\27[97m[ \27[91mFAIL \27[97m] USysD is already running!\n")
  os.exit(1)
end

local usd = {}

--#include "src/version.lua"
--#include "src/logger.lua"
--#include "src/hostname.lua"
--#include "src/serviceapi.lua"
--#include "src/shutdown.lua"

local proc = require("process")
while true do
  coroutine.yield(2)
  for name, pid in pairs(usd.running) do
    if not proc.info(pid) then
      usd.running[name] = nil
    end
  end
  if usd.__should_shut_down then
    usd.shutdown()
  end
end
