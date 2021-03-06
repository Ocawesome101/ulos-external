-- sound format:
-- header:
-- 3 bytes signature "\19\14\4"
-- 8 bits number of channels (max 8 in OpenComputers)
-- data header:
-- 2 bytes duration (in ms)
-- data (repeat for each channel):
-- 8 bits voice
-- 1 byte note (0 = A0, 1 = A#0, 2 = B0, 3 = C1, ...),
-- 1 byte volume

local SIG_DATA = "\19\14\4"

local args, opts = require("argutil").parse(...)

if #args == 0 or opts.help then
  io.stderr:write([[
usage: snd <FILE>
Plays back music stored in the specified FILE.
See snd(5) for format information.

'snd' utility and format (c) 2021 Ocawesome101
under the DSLv2.
]])
  os.exit(1)
end

-- get sound card
local sound = require("sound")

print("card type: " .. sound.CARD_TYPE)

local voices = {
  sound.voice.SINE,
  sound.voice.SQUARE,
  sound.voice.TRIANGLE,
  sound.voice.SAWTOOTH,
  sound.voice.NOISE
}

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
  local absolute = (index + 1) % 12
  return names[absolute] .. math.floor(index / 12)
end

local function getFrequency(index)
  local freq = o0[index % 12]
  local times = index // 12 - 1
  for i=1, times, 1 do freq = freq * 2 end
  return freq
end

local handle, err = io.open(args[1], "r")

if not handle then
  io.stderr:write("snd: ", args[1], ": ", err, "\n")
  os.exit(1)
end

local sig = handle:read(3)
if sig ~= SIG_DATA then
  io.stderr:write("snd: file has bad signature - exiting\n")
  os.exit(2)
end

-- up to 15 channels, minimum of 0
local channels = handle:read(1):byte()
if channels == 0 then
  io.stderr:write("snd: no channels - exiting\n")
  os.exit(0)
end

if channels > sound.MAX_CHANNELS then
  io.stderr:write(string.format("snd: too many channels (max %d, got %d)\n",
    sound.MAX_CHANNELS, channels))
  os.exit(3)
end

while true do
  local data = {}
  local _d = handle:read(2)
  if #_d < 2 then os.exit() end
  local duration = string.unpack("<I2", _d)
  for i=1, channels, 1 do
    local chunk = handle:read(3)
    if not chunk then os.exit() end
    local voice, note, volume = chunk:byte(1), chunk:byte(2), chunk:byte(3)
    if voice > 0 then
      data[i] = {
        getFrequency(note),
        duration,
        math.floor(volume / 2.55),
        voices[voice]
      }
      print(i, note, table.unpack(data[i], 2))
    end
  end
  sound.play(data)
  os.sleep(duration / 1000)
end
