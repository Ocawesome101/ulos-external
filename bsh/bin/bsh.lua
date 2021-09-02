-- bsh: Bourne Shell --

local pipe = require("pipe")
local process = require("process")
local readline = require("readline")

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
        simplified[#simplified]=simplified[#simplified]..table.concat(seq)
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
    output = (captureOutput and _cout_pipe or io.stdout), err = io.stderr}}
  local i = 0
  while i < #simplified do
    i = i + 1
    if simplified[i] == ";" then
      if #struct[#struct].command == 0 then
        return nil, "syntax error near unexpected token `;'"
      else
        struct[#struct+1] = {{command = {}, }}
      end
    end
  end
end

while true do
  io.write("$ ")
  print(eval(mkrdr(tokenize(io.read()))))
end
