-- coreutils: text formatter --

local args, opts = require("argutil").parse(...)

local colors = {
  bold = "97",
  regular = "39",
  italic = "92"
}

local patterns = {
  {"%*(%b{})", "bold"},
  {"_(%b{})", "italic"},
}

for i=1, #args, 1 do
  local handle, err = io.open(args[i], "r")
  if not handle then
    io.stderr:write("tfmt: ", args[i], ": ", err, "\n")
    os.exit(1)
  end
  local data = handle:read("a")
  handle:close()

  for i=1, #patterns, 1 do
    data = data:gsub(patterns[i][1], function(x)
      return string.format("\27[%sm%s\27[%sm", colors[patterns[i][2]],
        x:sub(2, -2), colors.regular)
    end)
  end

  print(data)
end
