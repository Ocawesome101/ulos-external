-- svcman: service manager --

local sv = require("sv")
local item = require("wm.item")
local tbox = require("wm.textbox")

local app = {
  w = 40,
  h = 4,
  name = "Service Manager"
}

local services = sv.list()
for k,v in pairs(services) do app.h=app.h+1 end

function app:init()
  self.page = 1
  self.tab_bar = item(self)
  self.tab_bar:add {
    x = 1, y = 1, text = " Toggle ", w = 8,
    foreground = self.app.wm.cfg.text_focused,
    background = self.app.wm.cfg.bar_color, click = function(b)
      self.page = 1
      b.foreground = self.app.wm.cfg.text_focused
      b.background = self.app.wm.cfg.bar_color
      self.tab_bar.items[2].background = 0
      self.tab_bar.items[2].foreground = self.app.wm.cfg.text_unfocused
    end
  }
  self.tab_bar:add {
    x = 9, y = 1, text = " Add ", w = 5,
    foreground = self.app.wm.cfg.text_unfocused,
    background = 0, click = function(b)
      self.page = 2
      b.foreground = self.app.wm.cfg.text_focused
      b.background = self.app.wm.cfg.bar_color
      self.tab_bar.items[1].background = 0
      self.tab_bar.items[1].foreground = self.app.wm.cfg.text_unfocused
    end
  }
  self.pages = {}
  self.pages[1] = item(self)
  self.pages[1]:add {
    x = 3, y = 3, text = "Services",
    foreground = self.app.wm.cfg.text_focused,
    background = self.app.wm.cfg.bar_color
  }

  local i = 0
  for service, running in pairs(services) do
    self.pages[1]:add {
      x = 3, y = 4 + i, text = service .. (running and "*" or ""),
      foreground = self.app.wm.cfg.text_focused, running = running,
      background = 0, click = function(b)
        local opts = {"Enable", "Cancel"}
        if b.running then opts[1] = "Disable" end
        local ed = self.app.wm.menu(self.x, self.y, "**Enable/Disable**", opts)
        if ed == "Enable" then
          if b.text:sub(-1) ~= "*" then b.text = b.text .. "*" end
          local ok, err = sv.enable(b.text:sub(1, -2))
          if not ok then
            self.app.wm.notify(err)
          end
        elseif ed == "Disable" then
          if b.text:sub(-1) == "*" then b.text = b.text:sub(1, -2) end
          local ok, err = sv.disable(b.text)
          if not ok then
            self.app.wm.notify(err)
          end
        end
      end
    }
    i = i + 1
  end

  self.pages[2] = item(self)

  self.pages[2]:add {
    x = 1, y = 2, text = "Name", foreground = self.app.wm.cfg.text_focused,
    background = self.app.wm.cfg.bar_color
  }

  self.pages[2]:add(tbox {
    x = 6, y = 2, w = 10, foreground = self.app.wm.cfg.bar_color,
    background = self.app.wm.cfg.text_focused, window = self, text = "TEST"
  })
end

function app:click(...)
  self.tab_bar:click(...)
  self.pages[self.page]:click(...)
end

function app:key(...)
  self.pages[self.page]:key(...)
end

function app:refresh()
  if not self.pages then self.app.init(self) end
  self.gpu.setBackground(self.app.wm.cfg.bar_color)
  self.gpu.fill(1, 1, self.app.w, self.app.h, " ")
  self.gpu.setBackground(0)
  self.gpu.fill(1, 1, self.app.w, 1, " ")
  if self.page == 1 then
    self.gpu.fill(3, 4, self.app.w - 4, self.app.h - 4, " ")
  end
  self.tab_bar:refresh()
  self.pages[self.page]:refresh()
end

return app
