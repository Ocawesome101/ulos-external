-- LuaPosix compatibility layer --

local posix = {}

setmetatable(posix, __index = function(t, k)
  local mod = require("posix."..k)
  posix[k] = mod
  return mod
end)

return posix
