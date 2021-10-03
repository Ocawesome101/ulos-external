-- posix.errno --

local errno = {}

local _err = 0
function errno.errno(n)
  checkArg(1, n, "number", "nil")
  return "errno support not implemented", n or _err
end

function errno.set_errno(n)
  checkArg(1, n, "number")
  _err = n
  return true
end

return errno
