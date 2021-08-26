-- labels --

local _item = {}

function _item:click(x, y)
  for i, item in ipairs(self.items) do
    if x >= item.x and x < item.x + item.w and
       y >= item.y and y < item.y + item.h then
      if item.click then item:click() end
    end
  end
end

function _item:key()
end

function _item:refresh()
  for i, item in ipairs(self.items) do
    if item.text then
      if item.foreground then self.window.gpu.setForeground(item.foreground) end
      if item.background then self.window.gpu.setBackground(item.background) end
      if type(item.text) == "string" then
        self.window.gpu.set(item.x, item.y, item.text)
      elseif type(item.text) == "table" then
        for n, line in pairs(item.text) do
          self.window.gpu.set(item.x, item.y, line)
        end
      end
    end
  end
end

function _item:add(args)
  args.x = args.x or 1
  args.y = args.y or 1
  args.w = args.w or 1
  args.h = args.h or 1
  args.text = args.text or {}
  table.insert(self.labels, args)
end

return function(win, x, y)
  return setmetatable({x = x, y = y, window = win, items = {}},
    {__index = _item})
end
