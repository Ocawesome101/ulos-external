-- env

local args, opts = require("argutil").parse(...)

local program = table.concat(args, " ")

local pge = require("process").info().data.env

-- TODO: support short opts with arguments, and maybe more opts too

if opts.unset and type(opts.unset) == "string" then
  for v in opts.unset:gmatch("[^,]+") do
    pge[v] =  ""
  end
end

if opts.i then
  pge = {}
end

if opts.chdir and type(opts.chdir) then
  pge["PWD"] = opts.chdir
end

os.execute(program)
