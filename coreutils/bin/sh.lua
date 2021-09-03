-- this is the closest thing to a symlink possible with OpenComputers
local shell = os.getenv("SHELL")
if shell == "/bin/sh" then shell = "/bin/lsh" end
assert(loadfile((shell or "/bin/lsh") .. ".lua"))()
