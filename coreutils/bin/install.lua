-- install to a writable medium. --

local args, opts = require("argutil").parse(...)

if opts.help then
  io.stderr:write([[
usage: install
Install ULOS to a writable medium.  Only present
in the live system image.

ULOS Coreutils (c) 2021 Ocawesome101 under the
DSLv2.
]])
  os.exit(1)
end

local component = require("component")
local computer = require("computer")

local fs = {}
do
  local _fs = component.list("filesystem")

  for k, v in pairs(_fs) do
    if k ~= computer.tmpAddress() then
      fs[#fs+1] = k
    end
  end
end

print("Available filesystems:")
for k, v in ipairs(fs) do
  print(string.format("%d. %s", k, v))
end

print("Please input your selection.")

local choice
repeat
  io.write("> ")
  choice = io.read("l")
until fs[tonumber(choice) or 0]

os.execute("mount -u /mnt")
os.execute("mount " .. fs[tonumber(choice)] .. " /mnt")

-- TODO: do this some way other than hard-coding it
local dirs = {
  "bin",
  "etc",
  "init.lua",
  "lib",
  "sbin",
  "usr"
}

for i, dir in ipairs(dirs) do
  os.execute("cp -rv /"..dir.." /mnt/"..dir)
end

os.execute("rm /mnt/bin/install.lua")
