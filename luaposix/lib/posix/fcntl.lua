-- posix.fcntl --

local fcntl = {
  O_RDONLY = 1,
  O_WRONLY = 2,
  O_RDWR,
  O_APPEND,
  O_CREAT,
  O_DSYNC,
  O_EXCL,
  O_NOCTTY,
  O_NONBLOCK,
  O_RSYNC,
  O_SYNC,
  O_TRUNC,
  O_CLOEXEC
}

local fds = {}
function fcntl.fcntl(fd, cmd, arg)
  checkArg(1, fd, "number")
  checkArg(2, cmd, "number")
  checkArg(3, arg, "number", "flock")
  -- TODO: implement this properly
  return fd
end

local function tconf(b)
  assert(not b, "must select one of (O_RDONLY, O_RDWR, O_WRONLY) but multiple specified")
end

function fcntl.open(path, oflags, __mode)
  checkArg(1, path, "string")
  checkArg(2, oflags, "number")
  -- mode does nothing, it's just here for compatibility
  checkArg(3, __mode, "number", "nil")
  local n = #fds + 1
  local mode
  local has_conflict = false
  if oflags & fcntl.O_RDONLY ~= 0 then
    mode = "r"
    has_conflict = true
  end
  if oflags & fcntl.O_WRONLY ~= 0 then
    tconf(has_conflict)
    mode = "w"
    has_conflict = true
  end
  if oflags & O_RDWR ~= 0 then
    tconf(has_conflict)
    mode = "rw"
    has_conflict = true
    if oflags & O_APPEND ~= 0 then
      error("O_RDWR and O_APPEND are incompatible")
    end
  end
  if not has_conflict then
    error("must select one of (O_RDONLY, O_RDWR, O_WRONLY) but none specified")
  end
  if mode == "w" and oflags & O_APPEND ~= 0 then
    mode = "a"
  end
  if then
  end
  local handle, err = io.open(path, mode)
end

function fcntl.posix_fadvise(fd, offset, len, advice)
end

return fcntl
