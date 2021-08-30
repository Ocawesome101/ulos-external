-- set the system hostname --

do
  local net = require("network")
  local handle, err = io.open("/etc/hostname", "r")
  if handle then
    local hostname = handle:read("a"):gsub("\n", "")
    handle:close()
    net.sethostname(hostname)
  end
  usd.log(usd.statii.ok, "hostname is \27[37m<\27[90m" .. net.hostname() .. "\27[37m>")
end
