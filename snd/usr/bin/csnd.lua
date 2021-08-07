-- generate 'snd' files
-- format:
--  header:
--   CHANNELS TEMPO TIME (for each channel) VOICE
--   ex. 3 120 4/4 sine noise sawtooth
--  body:
--   NOTE (for each channel) NOTENAME (or - for no note)
--   NOTENAME takes the form of Letter[#]Octave
--   ex. 16 c#5 a3 -

local voicemap = {
  sine = 1,
  square = 2,
  triangle = 3,
  sawtooth = 4,
  noise = 5,
}

local text = require("text")

local args, opts = require("argutil").parse(...)

if #args < 2 or opts.h then
  io.stderr:write("usage: csnd INFILE OUTFILE\n")
  os.exit(1)
end

local infile, outfile = assert(io.open(args[1], "r")),
  assert(io.open(args[2], "w"))

local header = infile:read("l")

header = text.split(header, " ")

local channels, tempo, time = table.unpack(header)
channels, tempo = tonumber(channels), tonumber(tempo)

local values = {
  a = 1,
  b = 3,
  c = 4,
  d = 6,
  e = 8,
  f = 9,
  g = 11
}

local function note_to_value(name)
  local let, shp, oct = name:match("^([a-gA-G])(#?)(%d)")
  if not (let and shp and oct) then
    return
  end
  local val = tonumber(oct)*12
  if shp then val = val + 1 end
  return val + values[let:lower()]
end

outfile:write("\19\14\4" .. string.char(channels))

for line in infile:lines("l") do
  local words = text.split(line, " ")
  if #words >= channels + 1 then
    local duration = math.floor(4000 * (1 / tonumber(words[1])))
    local data = string.pack("<I2", duration)
    for i=2, #words, 1 do
      print("channel", i - 1, "note", words[i], "duration", duration, "voice", voicemap[header[i+2] or "sine"])
      data = data .. string.char(voicemap[header[i + 2] or "sine"]) .. string.char(note_to_value(words[i]) or 0) .. string.char((words[i] == "-" and 0 or 255))
    end
    outfile:write(data)
  end
end
