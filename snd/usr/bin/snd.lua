-- sound format:
-- header:
-- 3 bytes signature "\19\14\4"
-- 4 bits number of channels
-- 4 bits unused
-- data (repeat for each channel):
-- 4 bits channel
-- 4 bits voice
-- 1 byte note (0 = A0, 1 = A#0, 2 = B0, 3 = C1, ...)

local args, opts = require("argutil").parse(...)

if #args == 0 or opts.help then
  io.stderr:write([[
usage: snd <FILE>
]])
  os.exit(1)
end

-- all notes in octave 0
-- assume note 0 is A
local o0 = {
  [0] = 27.5, -- a0
  29.135, -- a#0
  30.868, -- b0
  32.703, -- c1
  34.648, -- c#1
  36.708, -- d1
  38.891, -- d#1
  41.203, -- e1
  43.654, -- f1
  46.249, -- f#1
  48.999, -- g1
  51.913, -- g#1
}

local names = {
  "A",
  "A#",
  "B",
  "C",
  "C#",
  "D",
  "D#",
  "E",
  "F",
  "F#",
  "G",
  "G#"
}

local function getNote(index)
  local absolute = index % 12
  return names[absolute]
end

local function getFrequency(index)
  local freq = o0[index % 12]
  local times = index // 12
  for i=1, times, 1 do freq = freq * 2 end
  return freq
end

print(getNote(0), getFrequency(0))
print(getNote(12), getFrequency(12))
print(getNote(24), getFrequency(24))
