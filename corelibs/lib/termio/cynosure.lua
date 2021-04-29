-- handler for the Cynosure terminal

local handler = {}

handler.keyBackspace = "\8"

function handler.setRaw(raw)
  if raw then
    io.write("\27?3c")
  else
    io.write("\27?13c")
  end
end

return handler
