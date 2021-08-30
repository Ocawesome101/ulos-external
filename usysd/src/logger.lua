-- logger stuff --

usd.statii = {
  ok = "\27[97m[\27[92m OK \27[97m] ",
  warn = "\27[97m[\27[93mWARN\27[97m] ",
  wait = "\27[97m[\27[93mWAIT\27[97m] ",
  fail = "\27[97m[\27[91mFAIL\27[97m] ",
}

function usd.log(...)
  io.write(...)
  io.write("\n")
end
