-- text utilities

local lib = {}

function lib.escape(str)
  return (str:gsub("[%[%]%(%)%$%%%^%*%-%+%?%.]", "%%%1"))
end

function lib.split(text, split)
  checkArg(1, text, "string")
  checkArg(2, split, "string", "table")
  
  if type(split) == "string" then
    split = {split}
  end

  local words = {}
  local pattern = "[^" .. lib.escape(table.concat(split)) .. "]+"

  for word in text:gmatch(pattern) do
    words[#words + 1] = word
  end

  return words
end

function lib.padRight(n, text, c)
  return ("%s%s"):format((c or " "):rep(n - #text), text)
end

function lib.padLeft(n, text, c)
  return ("%s%s"):format(text, (c or " "):rep(n - #text))
end

function lib.mkcolumns(items, hook)
  -- TODO: improve (i.e. actually implement) logic here
  if hook then
    for i=1, #items, 1 do
      items[i] = hook(items[i])
    end
  end

  return table.concat(items, "\n")
end

return lib
