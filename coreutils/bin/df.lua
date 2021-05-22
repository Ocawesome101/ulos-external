-- df --

local filesystem = require("filesystem")

local args, opts = require("argutil").parse(...)

local mounts = fs.mounts()
