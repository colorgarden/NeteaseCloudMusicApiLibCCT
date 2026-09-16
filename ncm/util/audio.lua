-- ncm/util/audio.lua
-- Play audio through a CC:Tweaked speaker.
--
-- Background
--   `speaker.playAudio` accepts 8-bit PCM samples (-128..127) at 48 kHz. CC
--   cannot decode MP3/AAC, but NetEase can return a FLAC direct link
--   (`song_url_v1{ level = "lossless" }`). FLAC is frame-based, so this module
--   can decode it *while downloading* and feed the speaker on the fly, without
--   ever holding the whole song in memory.
--
--   The compact alternative is DFPWM (1 bit/sample, decoded by the built-in
--   `cc.audio.dfpwm`); see tools/audio_to_dfpwm.sh to pre-convert on a PC.
--
-- Usage:
--   local audio = require("ncm.util.audio")
--
--   -- stream a FLAC link straight from the internet (slow, but pure CC):
--   audio.playFlacUrl(songUrl, { volume = 1.0 })
--
--   -- or a DFPWM file (much lighter; pre-converted on a PC):
--   audio.playUrl("http://host/song.dfpwm", { volume = 1.0 })

local dfpwm = require("cc.audio.dfpwm")
local flac = require("ncm.util.flac")

local M = {}

local OUT_RATE = 48000

local function resolveSpeaker(speaker)
  if speaker then return speaker end
  if peripheral and peripheral.find then return peripheral.find("speaker") end
  return nil
end

local function play(speaker, samples, volume)
  local played
  if volume ~= nil then
    played = speaker.playAudio(samples, volume)
  else
    played = speaker.playAudio(samples)
  end
  while not played do
    os.pullEvent("speaker_audio_empty")
    if volume ~= nil then
      played = speaker.playAudio(samples, volume)
    else
      played = speaker.playAudio(samples)
    end
  end
end

-- --------------------------------------------------------------- DFPWM path
local function streamDfpwm(speaker, nextChunk, opts)
  local chunkSize = opts.chunkSize or 16 * 1024
  local decoder = dfpwm.make_decoder()
  local total = 0
  while true do
    local chunk = nextChunk(chunkSize)
    if not chunk or #chunk == 0 then break end
    local buffer = decoder(chunk)
    play(speaker, buffer, opts.volume)
    total = total + #buffer
    if opts.onProgress then opts.onProgress(total) end
    sleep(0)
  end
  return total
end

function M.playFile(path, opts)
  opts = opts or {}
  local speaker = resolveSpeaker(opts.speaker)
  if not speaker then return nil, "no speaker attached" end
  local f = assert(fs.open(path, "rb"))
  local function nextChunk(n)
    local c = f.read(n)
    if not c then f.close() end
    return c
  end
  local ok, res = pcall(streamDfpwm, speaker, nextChunk, opts)
  pcall(function() f.close() end)
  if not ok then return nil, res end
  return res
end

function M.playUrl(url, opts)
  opts = opts or {}
  local speaker = resolveSpeaker(opts.speaker)
  if not speaker then return nil, "no speaker attached" end
  if not http then return nil, "http API unavailable" end
  local h, err = http.get(url, nil, true)
  if not h then return nil, err end
  local function nextChunk(n) return h.read(n) end
  local ok, res = pcall(streamDfpwm, speaker, nextChunk, opts)
  h.close()
  if not ok then return nil, res end
  return res
end

-- ---------------------------------------------------------------- FLAC path
-- Streaming linear resampler (inRate -> 48000), carrying state across frames so
-- frame boundaries stay continuous.
local function newResampler(inRate, channels)
  local step = inRate / OUT_RATE
  local state = { x = 0, prev = 0 }
  return function(frame, n)
    local mono
    if channels == 1 then
      mono = frame[1]
    else
      mono = {}
      for i = 1, n do
        local s = 0
        for c = 1, channels do s = s + (frame[c][i] or 0) end
        mono[i] = s / channels
      end
    end
    local out = {}
    local x, prev = state.x, state.prev
    while true do
      local i0 = math.floor(x)
      if i0 + 1 >= n then break end
      local a = (i0 < 0) and prev or mono[i0 + 1]
      local b = mono[i0 + 2]
      out[#out + 1] = a + (b - a) * (x - i0)
      x = x + step
    end
    state.x = x - n
    state.prev = mono[n] or prev
    return out
  end
end

local function to8bit(samples)
  local out = {}
  for i = 1, #samples do
    local v = math.floor(samples[i] * 128 + 0.5)
    if v > 127 then v = 127 elseif v < -128 then v = -128 end
    out[i] = v
  end
  return out
end

local function streamFlac(speaker, getChunk, opts)
  local dec = flac.newStream(getChunk)
  local resample = newResampler(dec.sampleRate, dec.channels)
  local total = 0
  while true do
    local frame = dec.nextFrame()
    if not frame then break end
    local n = #frame[1]
    local samples = resample(frame, n)
    play(speaker, to8bit(samples), opts.volume)
    total = total + #samples
    if opts.onProgress then opts.onProgress(total, dec) end
    sleep(0)
  end
  return total, dec
end

-- Stream + decode a FLAC file served over HTTP(S).
function M.playFlacUrl(url, opts)
  opts = opts or {}
  local speaker = resolveSpeaker(opts.speaker)
  if not speaker then return nil, "no speaker attached" end
  if not http then return nil, "http API unavailable" end
  local h, err = http.get(url, nil, true)
  if not h then return nil, err end
  local chunk = opts.downloadChunk or 16 * 1024
  local ok, res = pcall(streamFlac, speaker, function() return h.read(chunk) end, opts)
  h.close()
  if not ok then return nil, res end
  return res
end

-- Stream + decode a local .flac file.
function M.playFlacFile(path, opts)
  opts = opts or {}
  local speaker = resolveSpeaker(opts.speaker)
  if not speaker then return nil, "no speaker attached" end
  local f = assert(fs.open(path, "rb"))
  local chunk = opts.downloadChunk or 16 * 1024
  local ok, res = pcall(streamFlac, speaker, function() return f.read(chunk) end, opts)
  pcall(function() f.close() end)
  if not ok then return nil, res end
  return res
end

-- Play a table of raw samples (-128..127) directly.
function M.playPcm(samples, opts)
  opts = opts or {}
  local speaker = resolveSpeaker(opts.speaker)
  if not speaker then return nil, "no speaker attached" end
  play(speaker, samples, opts.volume)
  return #samples
end

M.encode = dfpwm.encode
M.makeEncoder = dfpwm.make_encoder
M.makeDecoder = dfpwm.make_decoder

return M
