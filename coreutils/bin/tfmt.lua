-- coreutils: text formatter --

local args, opts = require("argutil").parse(...)

if #args == 0 or opts.help then
  io.stderr:write([[
usage: tfmt [options] FILE ...
Format FILE(s) according to a simple format
specification.

Options:
  --wrap=WD   Wrap output text at WD characters.

ULOS Coreutils copyright (c) 2021 Ocawesome101
under the DSLv2.
]])
  os.exit(1)
end

local colors = {
  bold = "97",
  regular = "39",
  italic = "36",
  link = "94"
}

local patterns = {
  {"%*(%b{})", "bold"},
  {"%$(%b{})", "italic"},
  {"@(%b{})", "link"}
}

opts.wrap = tonumber(opts.wrap)

for i=1, #args, 1 do
  local handle, err = io.open(args[i], "r")
  if not handle then
    io.stderr:write("tfmt: ", args[i], ": ", err, "\n")
    os.exit(1)
  end
  local data = handle:read("a")
  handle:close()

  if opts.wrap then
    -- TODO
  end

  for i=1, #patterns, 1 do
    data = data:gsub(patterns[i][1], function(x)
      return string.format("\27[%sm%s\27[%sm", colors[patterns[i][2]],
        x:sub(2, -2), colors.regular)
    end)
  end

  print(data)
end
