--  usysd versioning stuff --

usd._VERSION_MAJOR = 0
usd._VERSION_MINOR = 0
usd._VERSION_PATCH = 0
ust._RUNNING_ON = "unknown"

io.write(string.format("USysD version %d.%d.%d\n", usd._VERSION_MAJOR, usd._VERSION_MINOR,
  usd._VERSION_PATCH))

do
  local handle, err = io.open("/etc/os-release")
  if handle then
    local data = handle:read("a")
    handle:close()
  end
end
