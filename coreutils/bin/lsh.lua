-- lsh: the Lispish SHell

-- Shell syntax is heavily Lisp-inspired but not entirely Lisp-like.
-- String literals with spaces are supported between double-quotes - otherwise,
-- tokens are separated by whitespace.  A semicolon or EOF marks separation of
-- commands.
-- Everything inside () is evaluated as an expression (or subcommand);  the
-- program's output is tokenized by line and passed to the parent command as
-- arguments, such that `echo 1 2 (seq 3 6) 7 8` becomes `echo 1 2 3 4 5 6 7 8`.
-- This behavior is supported recursively.
-- [] behaves identically to (), except that the exit status of the child
-- command is inserted in place of its output.  An exit status of 0 is generally
-- assumed to mean success, and all non-zero exit statii to indicate failure.
-- Variables may be set with the 'set' builtin, and read with the 'get' builtin.
-- Functions may be declared with the 'def' builtin, e.g.:
-- def example (dir) (cd (get dir); print (get PWD));.
-- Comments are preceded by a # and continue until the next newline character
-- or until EOF.

local process = require("process")
local fs = require("filesystem")
local paths = require("path")

local args, opts = require("argutil").parse(...)

if opts.help then
  io.stderr:write([[
usage: lsh
The Lisp-like SHell.  See lsh(1) for details.
]])
  os.exit(1)
end

-- Initialize environment --
os.setenv("PWD", os.getenv("PWD") or os.getenv("HOME") or "/")
os.setenv("PS1", os.getenv("PS1") or 
  "<(get USER)@(or (get HOSTNAME) localhost): (or (match (get PWD) \"([^/]+)/?$\") /)> ")
os.setenv("PATH", os.getenv("PATH") or "/bin:/sbin:/usr/bin")

local splitters = {
  ["["] = true,
  ["]"] = true,
  ["("] = true,
  [")"] = true,
}

local rdr = {
  peek = function(s)
    return s.tokens[s.i]
  end,
  next = function(s)
    s.i = s.i + 1
    return s.tokens[s.i-1]
  end,
  sequence = function(s, b, e)
    local seq = {}
    local bl = 1
    repeat
      local tok = s:next()
      seq[#seq+1] = tok
      if s:peek() == b then bl = bl + 1
      elseif s:peek() == e then bl = bl - 1 end
    until bl == 0 or not s:peek()
    s:next()
    return seq
  end,
}

-- split a command into tokens
local function tokenize(str)
  local tokens = {}
  local token = ""
  local in_str = false

  for c in str:gmatch(".") do
    if c == "\"" then
      in_str = not in_str
      if #token > 0 or not in_str then
        if not in_str then
          token = token
            :gsub("\\e", "\27")
            :gsub("\\n", "\n")
            :gsub("\\a", "\a")
            :gsub("\\27", "\27")
            :gsub("\\t", "\t")
        end
        tokens[#tokens+1] = token
        token = ""
      end
    elseif in_str then
      token = token .. c
    elseif c:match("[ \n\t\r]") then
      if #token > 0 then
        tokens[#tokens+1] = token
        token = ""
      end
    elseif splitters[c] then
      if #token > 0 then tokens[#tokens+1] = token token = "" end
      tokens[#tokens+1] = c
    else
      token = token .. c
    end
  end

  if #token > 0 then tokens[#tokens+1] = token end

  return setmetatable({
    tokens = tokens,
    i = 1
  }, {__index = rdr})
end

local processCommand

-- Call a function, return its exit status,
-- and if 'sub' is true return its output.
local sub = false
local function call(name, func, args)
  local fauxio
  local function proc()
    local old_exit = os.exit
    local old_exec = os.execute

    function os.exit()
      os.exit = old_exit
      os.execute = old_exec
      old_exit(n)
    end

    os.execute = processCommand

    if fauxio then
      io.output(fauxio)
      io.stdout = fauxio
    end

    local ok, err, ret = xpcall(func, debug.traceback, table.unpack(args))

    if (not ok and err) or (not err and ret) then
      io.stderr:write(name, ": ", err or ret, "\n")
      os.exit(127)
    end

    os.exit(0)
  end

  if sub then
    fauxio = setmetatable({
      buffer = "",
      write = function(s, ...)
        s.buffer = s.buffer .. table.concat(table.pack(...)) end,
      read = function() return nil, "bad file descriptor" end,
      seek = function() return nil, "bad file descriptor" end,
      close = function() return true end
    }, {__name = "FILE*"})
  end

  local pid = process.spawn {
    func = proc,
    name = name,
    stdin = io.stdin,
    stdout = fauxio or io.stdout,
    stderr = io.stderr,
    input = io.input(),
    output = fauxio or io.output()
  }

  local exitStatus, exitReason = process.await(pid)

  if exitStatus ~= 0 and exitReason ~= "__internal_process_exit" then
    io.stderr:write(name, ": ", exitReason, "\n")
  end

  local out
  if fauxio then
    out = {}
    for line in fauxio.buffer:gmatch("[^\n]+") do
      out[#out+1] = line
    end
  end

  return exitStatus, out
end

local shenv = process.info().data.env

local builtins = {
  ["or"] = function(a, b)
    if #tostring(a) == 0 then a = nil end
    if #tostring(b) == 0 then b = nil end
    print(a or b or "")
  end,
  ["get"] = function(k)
    if not k then
      io.stderr:write("get: usage: get NAME\nRead environment variables.\n")
      os.exit(1)
    end
    print(shenv[k] or "")
  end,
  ["set"] = function(k, v)
    if not k then
      for k,v in pairs(shenv) do
        print(string.format("%s=%q", k, v))
      end
    else
      shenv[k] = tonumber(v) or v
    end
  end,
  ["cd"] = function(dir)
    if dir == "-" then
      if not shenv.OLDPWD then
        io.stderr:write("cd: OLDPWD not set\n")
        os.exit(1)
      end
      dir = shenv.OLDPWD
      print(dir)
    elseif not dir then
      if not shenv.HOME then
        io.stderr:write("cd: HOME not set\n")
        os.exit(1)
      end
      dir = shenv.HOME
    end
    local cdir = paths.canonical(dir)
    local ok, err = fs.stat(cdir)
    if ok then
      shenv.OLDPWD = shenv.PWD
      shenv.PWD = cdir
    else
      io.stderr:write("cd: ", dir, ": ", err, "\n")
      os.exit(1)
    end
  end,
  ["match"] = function(str, pat)
    if not (str and pat) then
      io.stderr:write("match: usage: match STRING PATTERN\nMatch STRING against PATTERN.\n")
      os.exit(1)
    end
    print(table.concat(table.pack(string.match(str, pat)), "\n"))
  end,
  ["gsub"] = function(str, pat, rep)
    if not (str and pat and rep) then
      io.stderr:write("gsub: usage: gsub STRING PATTERN REPLACE\nReplace all matches of PATTERN with REPLACE.\n")
      os.exit(1)
    end
    print(table.concat(table.pack(string.gsub(str,pat,rep)), "\n"))
  end,
  ["sub"] = function(str, i, j)
    if not (str and tonumber(i) and tonumber(j)) then
      io.stderr:write("sub: usage: sub STRING START END\nPrint a substring of STRING, beginning at index\nSTART and ending at END.\n")
      os.exit(1)
    end
    print(string.sub(str, tonumber(i), tonumber(j)))
  end,
  ["print"] = function(...)
    print(table.concat(table.pack(...), " "))
  end,
  ["time"] = function(...)
    local computer = require("computer")
    local start = computer.uptime()
    os.execute(table.concat(table.pack(...), " "))
    print("\ntook " .. (computer.uptime() - start) .. "s")
  end,
  ["+"] = function(a, b) print((tonumber(a) or 0) + (tonumber(b) or 0)) end,
  ["-"] = function(a, b) print((tonumber(a) or 0) + (tonumber(b) or 0)) end,
  ["/"] = function(a, b) print((tonumber(a) or 0) + (tonumber(b) or 0)) end,
  ["*"] = function(a, b) print((tonumber(a) or 0) + (tonumber(b) or 0)) end,
  ["="] = function(a, b) os.exit(a == b and 0 or 1) end,
  ["into"] = function(f, ...)
    if not f then
      io.stderr:write("into: usage: into FILE ...\nWrite all arguments to FILE.\n")
    end
    local name, mode = f:match("(.-):(.)")
    name = name or f
    local handle, err = io.open(name, mode or "w")
    if not handle then
      io.stderr:write("into: ", name, ": ", err, "\n")
      os.exit(1)
    end
    handle:write(table.concat(table.pack(...), "\n"))
    handle:close()
  end,
  ["seq"] = function(start, finish)
    for i=tonumber(start), tonumber(finish), 1 do
      print(i)
    end
  end
}

local shebang_pattern = "^#!(/.-)\n"

local function loadCommand(path)
  local handle, err = io.open(path, "r")
  if not handle then return nil, path .. ": " .. err end
  local data = handle:read("a")
  handle:close()
  if data:match(shebang_pattern) then
    local shebang = data:match(shebang_pattern)
    if not shebang:match("lua") then
      local executor = loadCommand(shebang)
      return function(...)
        return call(table.concat({shebang, path, ...}, " "), executor,
          {path, ...})
      end
    else
      data = data:gsub(shebang_pattern, "")
      return load(data, "="..path, "t", _G)
    end
  else
    return load(data, "="..path, "t", _G)
  end
end

local function resolveCommand(cmd)
  local path = os.getenv("PATH")

  local ogcmd = cmd

  if builtins[cmd] then
    return builtins[cmd]
  end

  -- if no file extension, then add .lua
  -- TODO: perhaps implement support/handling for longer file extensions?
  if not cmd:match("%.[^/%.][^/%.]?[^/%.]?$") then
    cmd = cmd .. ".lua"
  end

  local try = paths.canonical(cmd)
  if fs.stat(try) then
    return loadCommand(try)
  end

  for search in path:gmatch("[^:]+") do
    local try = paths.canonical(paths.concat(search, cmd))
    if fs.stat(try) then
      return loadCommand(try)
    end
  end

  return nil, ogcmd .. ": command not found"
end

local defined = {}

local processTokens
local function eval(set)
  local osb = sub
  sub = set.getOutput or sub
  local ok, err = processTokens(set)
  sub = osb
  return ok, err
end

processTokens = function(tokens, noeval)
  local sequence = {}

  if not tokens.next then tokens = setmetatable({i=1,tokens=tokens},
    {__index = rdr}) end
  
  repeat
    local tok = tokens:next()
    if tok == "(" then
      local subc = tokens:sequence("(", ")")
      subc.getOutput = true
      sequence[#sequence+1] = subc
    elseif tok == "[" then
      local subc = tokens:sequence("[", "]")
      sequence[#sequence+1] = subc
    elseif tok == ")" then
      return nil, "unexpected token ')'"
    elseif tok == "]" then
      return nil, "unexpected token ')'"
    elseif tok ~= ";" then
      if defined[tok] then
        sequence[#sequence+1] = defined[tok]
      else
        sequence[#sequence+1] = tok
      end
    end
  until tok == ";" or not tok

  if #sequence == 0 then return "" end

  if sequence[1] == "def" then
    defined[sequence[2]] = sequence[3]
    sequence = ""
  elseif sequence[1] == "if" then
    local ok, err = eval(sequence[2])
    if not ok then return nil, err end
    local _ok, _err
    if err == 0 then
      _ok, _err = eval(sequence[3])
    elseif sequence[4] then
      _ok, _err = eval(sequence[4])
    else
      _ok = ""
    end
    return _ok, _err
  elseif sequence[1] == "for" then
    local iter, err = eval(sequence[3])
    if not iter then return nil, err end
    local result = {}
    for i, v in ipairs(iter) do
      shenv[sequence[2]] = v
      local ok, _err = eval(sequence[4])
      if not ok then return nil, _err end
      result[#result+1] = ok
    end
    shenv[sequence[2]] = nil
    return result
  else
    for i=1, #sequence, 1 do
      if type(sequence[i]) == "table" then
        local ok, err = eval(sequence[i])
        if not ok then return nil, err end
        sequence[i] = ok
      elseif defined[sequence[i]] then
        local ok, err = eval(defined[sequence[i]])
        if not ok then return nil, err end
        sequence[i] = ok
      end
    end

    -- expand
    local i = 1
    while true do
      local s = sequence[i]
      if type(s) == "table" then
        table.remove(sequence, i)
        for n=#s, 1, -1 do
          table.insert(sequence, i, s[n])
        end
      end
      i = i + 1
      if i > #sequence then break end
    end

    if noeval then return sequence end
    -- now, execute it
    local name = sequence[1]
    if not name then return true end
    local ok, err = resolveCommand(table.remove(sequence, 1))
    if not ok then return nil, err end
    local old = sub
    sub = sequence.getOutput or sub
    local ex, out = call(name, ok, sequence)
    sub = old

    if out then
      return out, ex
    end

    return ex
  end

  return sequence
end

processCommand = function(text, ne)
  return processTokens(tokenize(text), ne)
end

local function processPrompt(text)
  for group in text:gmatch("%b()") do
    text = text:gsub(group:gsub("[%(%)%[%]%.%+%?%$%-%%]", "%%%1"),
      tostring(processCommand(group, true)[1] or ""))
  end
  return (text:gsub("\n", ""))
end

while true do
  io.write(processPrompt(os.getenv("PS1")))
  local ok, err = processCommand(io.read("l"))
  if not ok and err then
    io.stderr:write(err, "\n")
  end
end
