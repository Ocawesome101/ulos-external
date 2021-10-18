--  usysd versioning stuff --

usd._VERSION_MAJOR = 1
usd._VERSION_MINOR = 0
usd._VERSION_PATCH = 8
usd._RUNNING_ON = "unknown"

io.write(string.format("USysD version %d.%d.%d\n", usd._VERSION_MAJOR, usd._VERSION_MINOR,
  usd._VERSION_PATCH))

do
  local handle, err = io.open("/etc/os-release")
  if handle then
    local data = handle:read("a")
    handle:close()

    local name = data:match("PRETTY_NAME=\"(.-)\"")
    local color = data:match("ANSI_COLOR=\"(.-)\"")
    if name then usd._RUNNING_ON = name end
    if color then usd._ANSI_COLOR = color end
  end
end

io.write("\n  \27[97mWelcome to \27[" .. (usd._ANSI_COLOR or "96") .. "m" .. usd._RUNNING_ON .. "\27[97m!\27[37m\n\n")
