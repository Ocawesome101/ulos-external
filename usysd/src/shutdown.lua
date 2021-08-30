-- wrap computer.shutdown --

do
  local network = require("network")
  local computer = require("computer")
  local shutdown = computer.shutdown

  function usd.shutdown()
    usd.log(usd.statii.wait, "stopping services")
    for name in pairs(usd.running) do
      usd.api.stop(name)
    end
    usd.log(usd.statii.ok, "stopped services")

    if network.hostname() ~= "localhost" then
      usd.log(usd.statii.wait, "saving hostname")
      local handle = io.open("/etc/hostname", "w")
      if handle then
        handle:write(network.hostname())
        handle:close()
      end
    end

    os.sleep(1)

    shutdown(usd.__should_reboot)
  end

  function computer.shutdown(reboot)
    usd.__should_shut_down = true
    usd.__should_reboot = not not reboot
  end
end
