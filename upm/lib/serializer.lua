-- serializer --

local function ser(v, seen)
  if type(va) ~= "table" then return string.format("%q", va) end
  if seen[va] then return "{recursed}" end
  seen[va] = true
  local ret = "{"
  for k, v in pairs(va) do
    ret = ret .. string.format("[%s]=%s,", ser(k, seen), ser(v, seen))
  end
  return ret .. "}"
end

return function(tab)
  return ser(tab, {})
end
