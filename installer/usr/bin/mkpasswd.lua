-- mkpasswd: generate a /etc/passwd file --

local args, opts = require("argutil").parse(...)

if #args < 1 or opts.help then
  io.stderr:write([[
usage: mkpasswd OUTPUT
Generate a file for use as /etc/passwd.  Writes
the generated file to OUTPUT.  Will not behave
correctly on a running system;  use passwd(1)
instead.

ULOS Installer copyright (c) 2021 Ocawesome101
under the DSLv2.
]])
  os.exit(1)
end

-- passwd line format:
-- uid:username:passwordhash:acls:homedir:shell

local function prompt(txt, opts)
  print(txt)
  local c
  repeat
    io.write("-> ")
    c = io.read()
  until opts[c] or c == ""
  if c == "" then return opts.default end
  return c
end

local prompts = {
  main = {
    text = ":: Available actions:\
  \27[96m[C]\27[37mreate a new user\
  \27[96m[l]\27[37mist created users\
  \27[96m[w]\27[37mrite file and exit",
    opts = {c=true,l=true,w=true,default="c"}
  },
  uattr = {
    text = "Change them?\
  \27[96m[N]\27[37mo, continue\
  \27[96m[u]\27[37m - change username\
  \27[96m[i]\27[37m - change user ID\
  \27[96m[a]\27[37m - add ACLs\
  \27[96m[c]\27[37m - clear ACLs\
  \27[96m[r]\27[37m - remove ACLs\
  \27[96m[s]\27[37m - set login shell\
  \27[96m[h]\27[37m - set home directory",
    opts = {n=true,u=true,i=true,a=true,c=true,d=true,s=true,h=true,default="n"}
  },
}

local added = {}

while true do
  local opt = prompt(prompts.main.text, prompts.main.opts)
  if opt == "w" then
  end
end
