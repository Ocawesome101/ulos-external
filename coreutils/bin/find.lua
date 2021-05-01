-- find --

local futil = require("futil")

local args, opts = require("argutil").parse(...)

for i=1, #args, 1 do
  local tree, err = futil.tree(args[i])
  
  if not tree then
    io.stderr:write("find: ", err, "\n")
    os.exit(1)
  end

  for i=1, #tree, 1 do
    print(tree[i])
  end
end
