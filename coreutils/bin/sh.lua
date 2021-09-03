-- this is the closest thing to a symlink possible with OpenComputers
assert(loadfile((os.getenv("SHELL") or "/bin/lsh") .. ".lua"))()
