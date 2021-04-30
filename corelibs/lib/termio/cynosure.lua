-- handler for the Cynosure terminal

local handler = {}

handler.keyBackspace = "\8"

function handler.setRaw(raw)
  if raw then
    io.write("\27?3;12c")
  else
    io.write("\27?13;2c")
  end
end

return handler
