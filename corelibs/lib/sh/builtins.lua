-- shell builtins

local path = require("path")
local users = require("users")
local fs = require("filesystem")

local builtins = {}

function builtins:cd(dir)
  if dir == "-" then
    if not self.env.OLDPWD then
      io.stderr:write("sh: cd: OLDPWD not set\n")
      os.exit(1)
    end
    dir = self.env.OLDPWD
    print(dir)
  elseif not dir then
    if not self.env.HOME then
      io.stderr:write("sh: cd: HOME not set\n")
      os.exit(1)
    end
    dir = self.env.HOME
  end
  local cdir = path.canonical(dir)
  local ok, err = fs.stat(cdir)
  if ok then
    self.env.OLDPWD = self.env.PWD
    self.env.PWD = cdir
  else
    io.stderr:write("sh: cd: ", dir, ": ", err, "\n")
    os.exit(1)
  end
end

function builtins:echo(...)
  print(table.concat(table.pack(...), " "))
end

function builtins:builtin(b, ...)
  if not builtins[b] then
    io.stderr:write("sh: builtin: ", b, ": not a shell builtin\n")
    os.exit(1)
  end
  builtins[b](self, ...)
end

function builtins:builtins()
  for k in pairs(builtins) do print(k) end
end

function builtins:exit(n)
  n = tonumber(n) or 0
  self.exit = n
end

return builtins
