--  usysd versioning stuff --

usd._VERSION_MAJOR = 1
usd._VERSION_MINOR = 0
usd._VERSION_PATCH = 3
usd._RUNNING_ON = "unknown"

io.write(string.format("USysD version %d.%d.%d\n", usd._VERSION_MAJOR, usd._VERSION_MINOR,
  usd._VERSION_PATCH))

do
  local handle, err = io.open("/etc/os-release")
  if handle then
    local data = handle:read("a")
    handle:close()

    local name = data:match("PRETTY_NAME=\"(.-)\"")
    if name then usd._RUNNING_ON = name end
  end
end

io.write("\n  \27[97mWelcome to \27[96m" .. usd._RUNNING_ON .. "\27[97m!\27[37m\n\n")
