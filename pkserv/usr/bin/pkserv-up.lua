-- update pkserv package cache --

local upm = require("upm")
os.execute("upm update") -- make sure upm is primed
os.execute("cp /etc/upm/main.list /etc/upm/extra.list /usr/share/pkserv/ -v")

local packages = {
  "cynosure",
  "cldr"
}

local config = require("config").bracket:load("/etc/upm.cfg")
for i=1, #packages, 1 do
  local data, repo = upm.search(config, {root="/"}, packages[i])
  upm.download_package(config, {root="/"}, packages[i], repo, data)
  os.execute("cp -v /etc/upm/cache/" .. packages[i] .. ".mtar /usr/share/pkserv/pkg/")
end
