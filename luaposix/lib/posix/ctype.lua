-- posix ctype module --

local ctype = {}

local gpat = "[\0-\30 \127-\255]"
local ppat = "[\0-\30\127-\255]"

function ctype.isgraph(char)
  checkArg(1, char, "string")
  char = char:sub(1,1)
  return char:match(gpat) and 0 or 1
end

function ctype.isprint(char)
  checkArg(1, char, "string")
  char = char:sub(1,1)
  return char:match(ppat) and 0 or 1
end

return ctype
