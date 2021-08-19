-- UPM: the ULOS Package Manager v2 --

local upm = require("upm")

local args, opts = require("argutil").parse(...)

local usage = "\
UPM - the ULOS Package Manager\
\
usage: \27[36mupm \27[39m[\27[93moptions\27[39m] \27[96mCOMMAND \27[39m[\27[96m...\27[39m]\
\
Available \27[96mCOMMAND\27[39ms:\
  \27[96minstall \27[91mPACKAGE ...\27[39m\
    Install the specified \27[91mPACKAGE\27[39m(s).\
\
  \27[96mremove \27[91mPACKAGE ...\27[39m\
    Remove the specified \27[91mPACKAGE\27[39m(s).\
\
  \27[96mupdate\27[39m\
    Update (refetch) the repository package lists.\
\
  \27[96mupgrade\27[39m\
    Upgrade installed packages.\
\
  \27[96msearch \27[91mPACKAGE\27[39m\
    Search local package lists for \27[91mPACKAGE\27[39m, and\
    display information about it.\
\
  \27[96mlist\27[39m [\27[91mTARGET\27[39m]\
    List packages.  If \27[91mTARGET\27[39m is 'all',\
    then list packages from all repos;  if \27[91mTARGET\27[37m\
    is 'installed', then print all installed\
    packages;  otherewise, print all the packages\
    in the repo specified by \27[91mTARGET\27[37m.\
    \27[91mTARGET\27[37m defaults to 'installed'.\
\
Available \27[93moption\27[39ms:\
  \27[93m-q\27[39m            Be quiet;  no log output.\
  \27[93m-f\27[39m            Skip checks for package version and\
                              installation status.\
  \27[93m-v\27[39m            Be verbose;  overrides \27[93m-q\27[39m.\
  \27[93m-y\27[39m            Automatically assume 'yes' for\
                              all prompts.\
  \27[93m--root\27[39m=\27[33mPATH\27[39m   Treat \27[33mPATH\27[39m as the root filesystem\
                instead of /.\
\
The ULOS Package Manager is copyright (c) 2021\
Ocawesome101 under the DSLv2.\
"

local pfx = {
  info = "\27[92m::\27[39m ",
  warn = "\27[93m::\27[39m ",
  err = "\27[91m::\27[39m "
}

local function log(...)
  if opts.v or not opts.q then
    io.stderr:write(...)
    io.stderr:write("\n")
  end
end

local function exit(reason)
  log(pfx.err, reason)
  os.exit(1)
end

if opts.help or args[1] == "help" then
  io.stderr:write(usage)
  os.exit(1)
end

if #args == 0 then
  exit("an operation is required; see 'upm --help'")
end

local state, err = upm.newState(opts)
if not state then
  exit(err)
end

local function progress(na, nb, a, b)
  local n = math.floor(0.3 * (na / nb * 100))
  io.stdout:write("\27[G[" ..
    ("#"):rep(n) .. ("-"):rep(30 -  n)
    .. "] (" .. a .. "/" .. b .. ")")
  io.stdout:flush()
end

local last_call_progress = false

local function do_operation(op, ...)
  local result = table.pack(coroutine.resume(state, op, ...))
  while true do
    --print(table.unpack(result, 1, result.n))
    if result[1] == "status" or result[1] == "state" then
      log(pfx.info, result[2])
    elseif result[1] == "warn" then
      log(pfx.warn, result[2])
    elseif result[1] == "error" then
      repeat
        coroutine.resume(state, "close")
      until coroutine.status(state) == "dead"
      exit(result[2])
    end
    if result[1] == "progress" then
      if not last_call_progress then
        io.write("\27[G\27[2K")
        last_call_progress = true
      end
      progress(table.unpack(result, 2, result.n))
    elseif last_call_progress then
      last_call_progress = false
      io.write("\27[G\27[2K")
    end
    
    if result[1] == "prompt" then
      io.write(result[2])
      
      repeat
        local c = io.read("l")
        if c ~= "y" and c ~= "n" and c ~= "" then
          io.write("please enter 'y' or 'n': ")
        end
      until c == "y" or c == "n" or c == ""

      result = table.pack(coroutine.resume(state, c ~= "n"))
    elseif result[1] == "result" then
      -- next will be get_operation
      coroutine.resume(state)
      return table.unpack(result, 2, result.n)
    elseif result[1] == "get_operation" then
      break
    else
      result = table.pack(coroutine.resume(state))
    end
  end
end

if args[1] == "install" then
  if not args[2] then
    exit("command verb 'install' requires at least one argument")
  end
  
  table.remove(args, 1)
  do_operation("install", args)
elseif args[1] == "upgrade" then
  do_operation("upgrade")
elseif args[1] == "remove" then
  if not args[2] then
    exit("command verb 'remove' requires at least one argument")
  end

  table.remove(args, 1)
  do_operation("remove", args)
elseif args[1] == "update" then
  do_operation("update")
elseif args[1] == "search" then
  if not args[2] then
    exit("command verb 'search' requires at least one argument")
  end

  table.remove(args, 1)
  local result = do_operation("search", args[1])
  for i, pk in ipairs(result) do
    io.write(string.format("\27[94m%s/\27[39m%s %s\n  %s\n", pk.repo, pk.name,
      pk.installed and "\27[96m[installed]\27[39m" or "",
      pk.data.description or "(no description)"))
  end
elseif args[1] == "list" then
  table.remove(args, 1)
  print(table.concat(do_operation("list", args), "\n"))
else
  exit("operation '" .. args[1] .. "' is unrecognized")
end
