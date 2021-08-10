-- basic TUI scheme --

local termio = require("termio")

local inherit
inherit = function(t, ...)
  t = t or {}
  local new = setmetatable({}, {__index = t, __call = inherit})
  if new.init then new:init(...) end
  return new
end

local function class(t)
  return setmetatable(t or {}, {__call = inherit})
end

local tui = {}

tui.List = class {
  init = function()
  end,
  refresh = function()
  end
}

return tui
