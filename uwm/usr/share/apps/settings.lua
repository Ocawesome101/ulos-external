-- settings app --

local item = require("wm.item")
local tbox = require("wm.textbox")

local app = {
  w = 40,
  h = 10,
  name = "UWM Settings"
}

function app:init()
  self.gpu.setForeground(self.app.wm.cfg.text_focused)
  self.gpu.setBackground(self.app.wm.cfg.bar_color)
  self.gpu.fill(1, 1, self.app.w, self.app.h, " ")
  self.items = item(self, 1, 1)
  self.items:add {
    x = 1, y = 1,
    text = "Default window width",
    foreground = self.app.wm.cfg.text_focused,
    background = self.app.wm.cfg.bar_color
  }
  self.items:add(tbox {
    x = 30, y = 1, w = 10,
    foreground = 0,
    background = 0xFFFFFF, window = self, submit = function(txt)
      txt = tonumber(txt)
      if not txt then
        self.app.wm.notify("Invalid value (must be number)")
      else
        self.app.wm.cfg.width = txt
      end
    end, text = tostring(self.app.wm.cfg.width)
  })
  --[[self.items:add {
    x = 1, y = 2,
    text = "Default window height"
  }]]
end

function app:click(...)
  self.items:click(...)
end

function app:key(...)
  self.items:key(...)
end

function app:refresh()
  if not self.items then self.app.init(self) end
  self.items:refresh()
end

return app
