-- bsh: Bourne Shell --

local pipe = require("pipe")
local process = require("process")
local readline = require("readline")

os.setenv("PATH", os.getenv("PATH") or "/bin:/sbin:/usr/bin")
os.setenv("PS1", os.getenv("PS1") or "<\\u@\\h: \\W>")
os.setenv("SHLVL", tostring(math.floor((os.getenv("SHLVL") or "0" + 1))))

local logError = function(err)
  if not err then return end
  io.stderr:write(err .. "\n")
end

local function resolveCommand(name)
  return nil, "command not found"
end

local function executeCommand(cstr, nowait)
  local file, err = resolveCommand(cstr.command[1])
  if not file then logError("sh: " .. cstr.command[1] .. ": " .. err) return 1, err end
  local ok, err = loadfile(file)
  if not ok then logError(cstr.command[1] .. ": " .. err) return 1, err end
  local pid = process.spawn {
    func = function()return ok(table.unpack(cstr.command, 2)) end,
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
      simplified[#simplified + 1] = ""
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
        struct[#struct].output = pipe
        struct[#struct+1] = {command = {}, input = pipe,
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
    else
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
  else
    return lastExitStatus == 0
  end
end

while true do
  io.write("$ ")
  eval(mkrdr(tokenize(readline())))
end
