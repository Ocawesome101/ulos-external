-- USysD init system.  --
-- Copyright (c) 2021 Ocawesome101 under the DSLv2.

local usd = {}

--#include "src/version.lua"
--#include "src/logger.lua"
--#include "src/serviceapi.lua"
--#include "src/shutdown.lua"

while true do
  coroutine.yield()
end
