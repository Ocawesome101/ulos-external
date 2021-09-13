-- pkserv: serve files over minitel --

local net = require("network")
local mt = require("network.minitel")

os.execute("mkdir -p /usr/share/pkserv/pkg")

net.listen("localhost:80", function(sock, file)
  local handle = io.open("/usr/share/pkserv/" .. file, "r")
  sock:write(handle:read("a"))
  handle:close()
  sock:close()
end)



while true do coroutine.yield() end
