-- bsh: Better Shell --

local path = require("path")
local pipe = require("pipe")
local text = require("text")
local fs = require("filesystem")
local process = require("process")
local readline = require("readline")

os.setenv("PATH", os.getenv("PATH") or "/bin:/sbin:/usr/bin")
os.setenv("PS1", os.getenv("PS1") or "<\\u@\\h: \\W> ")
os.setenv("SHLVL", tostring(math.floor((os.getenv("SHLVL") or "0" + 1))))

local logError = function(err)
  if not err then return end
  io.stderr:write(err .. "\n")
end

local shenv = process.info().data.env
local builtins = {
  cd = function(dir)
    if dir == "-" then
      if not shenv.OLDPWD then
        logError("sh: cd: OLDPWD not set")
        return 1
      end
      dir = shenv.OLDPWD
      print(dir)
    elseif not dir then
      if not shenv.HOME then
        logError("sh: cd: HOME not set")
        return 1
      end
      dir = shenv.HOME
    end

    local full = path.canonical(dir)
    local ok, err = fs.stat(full)
    
    if not ok then
      logError("sh: cd: " .. dir .. ": " .. err)
      return 1
    else
      shenv.OLDPWD = shenv.PWD
      shenv.PWD = full
    end
    return 0
  end,
  set = function()
    for k, v in pairs(shenv) do
      print(k.."="..v)
    end
  end
}

local function exists(file)
  if fs.stat(file) then return file
  elseif fs.stat(file .. ".lua") then return file .. ".lua" end
end

local function resolveCommand(name)
  if builtins[name] then return builtins[name] end
  local try = {name}
  for ent in os.getenv("PATH"):gmatch("[^:]+") do
    try[#try+1] = path.concat(ent, name)
  end
  for i, check in ipairs(try) do
    local file = exists(check)
    if file then
      return file
    end
  end
  return nil, "command not found"
end

local function executeCommand(cstr, nowait)
  while (cstr.command[1] or ""):match("=") do
    local name = table.remove(cstr.command, 1)
    local assign
    if name:sub(-1) == "=" then
      name = name:sub(1, -2)
      assign = table.remove(cstr.command, 1)
    else
      name, assign = name:match("^(.-)=(.+)$")
    end
    if name then cstr.env[name] = assign end
  end
  
  if #cstr.command == 0 then for k,v in pairs(cstr.env) do os.setenv(k, v) end return 0, "exited" end
  
  local file, err = resolveCommand(cstr.command[1])
  if not file then logError("sh: " .. cstr.command[1] .. ": " .. err) return 1, err end
  local ok
  
  if type(file) == "function" then -- this means it's a builtin
    if cstr.input == io.stdin and cstr.output == io.stdout then
      local result = table.pack(pcall(file, table.unpack(cstr.command, 2)))
      if not result[1] and result[2] then
        logError("sh: " .. cstr.command[1] .. ": " .. result[2])
        return 1, result[2]
      elseif result[1] then
        return table.unpack(result, 2, result.n)
      end
    else
      ok = file
    end
  else
    ok, err = loadfile(file)
    if not ok then logError(cstr.command[1] .. ": " .. err) return 1, err end
  end

  local sios = io.stderr
  local pid = process.spawn {
    func = function()
      local result = table.pack(xpcall(ok, debug.traceback, table.unpack(cstr.command, 2)))
      if not result[1] then
        io.stderr:write(cstr.command[1], ": ", result[2], "\n")
        os.exit(127)
      else
        local errno = result[2]
        if type(errno) == "number" then
          os.exit(errno)
        else
          os.exit(0)
        end
      end
    end,
    name = cstr.command[1],
    stdin = cstr.input,
    input = cstr.input,
    stdout = cstr.output,
    output = cstr.output,
    stderr = cstr.err,
    env = cstr.env
  }
  
  if not nowait then
    return process.await(pid)
  end
end

local special = "['\" %[%(%$&#|%){}\n;]"

local function tokenize(text)
  text = text:gsub("$([a-zA-Z0-9_]+)", function(x)return os.getenv(x)or""end)
  local tokens = {}
  local idx = 0
  while #text > 0 do
    local index = text:find(special) or #text+1
    local token = text:sub(1, math.max(1,index - 1))
    if token == "'" then
      local nind = text:find("'", 2)
      if not nind then
        return nil, "unclosed string at index " .. idx
      end
      token = text:sub(1, nind)
    elseif token == '"' then
      local nind = text:find('"', 2)
      if not nind then
        return nil, "unclosed string at index " .. idx
      end
      token = text:sub(1, nind)
    end
    idx = idx + index
    text = text:sub(#token + 1)
    tokens[#tokens + 1] = token
  end
  return tokens
end

local mkrdr
do
  local r = {}
  function r:pop()
    self.i=self.i+1
    return self.t[self.i - 1]
  end
  function r:peek(n)
    return self.t[self.i+(n or 0)]
  end
  function r:get_until(c)
    local t={}
    repeat
      local _c=self:pop()
      t[#t+1]=_c
    until (_c and _c:match(c)) or not _c
    return mkrdr(t)
  end
  function r:get_balanced(s,e)
    local t={}
    local i=1
    self:pop()
    repeat
      local _c=self:pop()
      t[#t+1]=_c
      i=i+((c==s and 1)or(c==e and-1)or 0)
    until i==0 or not _c
    return t
  end
  mkrdr = function(t)
    return setmetatable({i=1,t=t},{__index=r})
  end
end

local eval
eval = function(tokens, captureOutput)
  -- first pass: simplify it all
  local simplified = {""}
  while true do
    local tok = tokens:pop()
    if not tok then break end
    if tok == "$" then
      if tokens:peek() == "(" then
        local seq = tokens:get_balanced("(",")")
        seq[#seq] = nil
        seq = eval(mkrdr(seq), true) or {}
        for i=1, #seq, 1 do
          if #simplified[#simplified]==0 then
            simplified[#simplified]=seq[i]
          else
            simplified[#simplified+1]=seq[i]
          end
        end
      elseif tokens:peek() == "{" then
        local seq = tokens:get_balanced("{","}")
        seq[#seq]=nil
        simplified[#simplified]=simplified[#simplified]..(os.getenv(table.concat(seq))or"")
      else
        simplified[#simplified] = simplified[#simplified] .. tok
      end
    elseif tok == "#" then
      tokens:get_until("\n")
    elseif tok:match("[ |;\n&]") and #simplified[#simplified] > 0 then
      if tok ~= " " and tok ~= "\n" then simplified[#simplified+1] = tok end
      if #simplified[#simplified] > 0 then simplified[#simplified + 1] = "" end
    elseif tok == "}" then
      return nil, "syntax error near unexpected token `}'"
    elseif tok == ")" then
      return nil, "syntax error near unexpected token `)'"
    else
      simplified[#simplified] = simplified[#simplified] .. tok
    end
  end
  if #simplified == 0 then return end
  local _cout_pipe
  if captureOutput then
    _cout_pipe = pipe.create()
  end
  -- second pass: set up command structure
  local struct = {{command = {}, input = io.stdin,
    output = (captureOutput and _cout_pipe or io.stdout), err = io.stderr, env = {}}}
  local i = 0
  while i < #simplified do
    i = i + 1
    if simplified[i] == ";" then
      if #struct[#struct].command == 0 then
        return nil, "syntax error near unexpected token `;'"
      elseif i ~= #simplified then
        struct[#struct+1] = ";"
        struct[#struct+1] = {command = {}, input = io.stdin,
          output = (captureOutput and _cout_pipe or io.stdout), err = io.stderr, env = {}}
      end
    elseif simplified[i] == "|" then
      if type(struct[#struct]) == "string" or #struct[#struct].command == 0 then
        return nil, "syntax error near unexpected token `|'"
      else
        local _pipe = pipe.create()
        struct[#struct].output = _pipe
        struct[#struct+1] = {command = {}, input = _pipe,
          output = (captureOutput and _cout_pipe or io.stdout), err = io.stderr, env = {}}
      end
    elseif simplified[i] == "&" then
      if type(struct[#struct]) == "string" or #struct[#struct].command == 0 then
        return nil, "syntax error near unexpected token `&'"
      elseif simplified[i+1] == "&" then
        i = i + 1
        struct[#struct+1] = "&&"
        struct[#struct+1] = {command = {}, input = io.stdin,
          output = (captureOutput and _cout_pipe or io.stdout), err = io.stderr, env = {}}
      else
        struct[#struct+1] = "&"
      end
    elseif #simplified[i] > 0 then
      if simplified[i]:sub(1,1):match("[\"']") then
        simplified[i] = simplified[i]:sub(2, -2)
      else
        simplified[i] = simplified[i]:gsub(" +", " ")
      end
      table.insert(struct[#struct].command, simplified[i])
    end
  end

  local srdr = mkrdr(struct)
  local lastExitStatus, lastExitReason, lastSeparator = 0, "", ";"
  for token in srdr.pop, srdr do
    if type(token) == "table" then
      if lastSeparator == "&&" then
        if lastExitStatus == 0 then
          local exitStatus, exitReason = executeCommand(token)
          lastExitStatus = exitStatus
          if exitReason ~= "__internal_process_exit" and exitReason ~= "exited"
              and exitReason and #exitReason > 0 then
            logError(err)
          end
        end
      elseif lastSeparator == "&" then
        executeCommand(token, true)
      elseif lastSeparator == "|" then
        if lastExitStatus == 0 then
          local exitStatus, exitReason = executeCommand(token)
          lastExitStatus = exitStatus
          if exitReason ~= "__internal_process_exit" and exitReason ~= "exited"
              and exitReason and #exitReason > 0 then
            logError(err)
          end
        end
      elseif lastSeparator == ";" then
        lastExitStatus = 0
        local exitStatus, exitReason = executeCommand(token)
        lastExitStatus = exitStatus
        if exitReason ~= "__internal_process_exit" and exitReason ~= "exited"
            and exitReason and #exitReason > 0 then
          logError(err)
        end
      end
    elseif type(token) == "string" then
      lastSeparator = token
    end
  end

  if captureOutput then
    local lines = {}
    for line in _cout_pipe:lines("l") do lines[#lines+1] = line end
    _cout_pipe:close()
    return lines
  else
    return lastExitStatus == 0
  end
end

local function process_prompt(ps)
  return (ps:gsub("\\(.)", {
    ["$"] = os.getenv("USER") == "root" and "#" or "$",
    ["a"] = "\a",
    ["A"] = os.date("%H:%M"),
    ["d"] = os.date("%a %b %d"),
    ["e"] = "\27",
    ["h"] = (os.getenv("HOSTNAME") or "localhost"):gsub("%.(.+)$", ""),
    ["h"] = os.getenv("HOSTNAME") or "localhost",
    ["j"] = "0", -- the number of jobs managed by the shell
    ["l"] = "tty" .. math.floor(io.stderr.tty or 0),
    ["n"] = "\n",
    ["r"] = "\r",
    ["s"] = "sh",
    ["t"] = os.date("%T"),
    ["T"] = os.date("%I:%M:%S"),
    ["@"] = os.date("%H:%M %p"),
    ["u"] = os.getenv("USER"),
    ["v"] = "0.5",
    ["V"] = "0.5.0",
    ["w"] = os.getenv("PWD"):gsub(
      "^"..text.escape(os.getenv("HOME")), "~"),
    ["W"] = (os.getenv("PWD") or "/"):gsub(
      "^"..text.escape(os.getenv("HOME")), "~"):match("([^/]+)/?$") or "/",
  }))
end

function os.execute(...)
  local cmd = table.concat({...}, " ")
  if #cmd > 0 then return eval(mkrdr(tokenize(cmd))) end
  return 0
end

if fs.stat("/etc/bshrc") then
  for line in io.lines("/etc/bshrc") do
    local ok, err = eval(mkrdr(tokenize(line)))
    if not ok and err then logError("sh: " .. err) end
  end
end

if fs.stat(os.getenv("HOME") .. "/.bshrc") then
  for line in io.lines(os.getenv("HOME") .. "/.bshrc") do
    local ok, err = eval(mkrdr(tokenize(line)))
    if not ok and err then logError("sh: " .. err) end
  end
end

local hist = {}
local rlopts = {history = hist}
while true do
  io.write(process_prompt(os.getenv("PS1")))
  local text = readline(rlopts)
  if #text > 0 then
    table.insert(hist, text)
    if #hist > 32 then table.remove(hist, 1) end
    local ok, err = eval(mkrdr(tokenize(text)))
    if not ok and err then logError("sh: " .. err) end
  end
end
