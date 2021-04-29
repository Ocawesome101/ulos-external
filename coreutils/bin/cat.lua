-- cat --

local args, opts = require("argutil").parse(...)

for i=1, #args, 1 do
  local handle, err = io.open(require("path").canonical(args[i]), "r")
  if not handle then
    io.stderr:write("cat: cannot open '", args[i], "': ", err)
    os.exit(1)
  else
    local data = handle:read("a")
    handle:close()
    io.write(data)
  end
end
