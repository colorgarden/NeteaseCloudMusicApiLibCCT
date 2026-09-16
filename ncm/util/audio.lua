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
--   Both `playUrl` and `playFlacUrl` fetch over HTTP through `ncm.util.httpx`
--   (cc_big_http Range chunks), NOT the built-in `http.get`: NetEase audio
--   exceeds CC:Tweaked's 16 MiB (`http_max_download`) single-response cap. The
--   response object still supports `read(n)`, so the streaming decoders below
--   stay memory-bounded while the file is assembled.
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
local httpx = require("ncm.util.httpx")

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
  local h, err = httpx.get(url, nil, true)
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
  local h, err = httpx.get(url, nil, true)
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

-- Decode a whole FLAC (HTTP(S) URL or local path) into a .dfpwm file at
-- 48 kHz mono. Playing the result costs no decoding at all, so this is how to
-- get smooth audio on a computer whose per-tick CPU budget cannot decode FLAC
-- in real time.
--
-- It is also the decoder-only test: convert once, then listen. If the
-- converted file plays smoothly but streaming did not, the decoder is fine and
-- the machine was simply too slow to keep up. If the converted file is *also*
-- choppy, the decode itself is at fault.
--
-- Returns the number of samples written, or nil, err.
function M.decodeToDfpwm(source, dest, opts)
  opts = opts or {}

  local getChunk, closeSource
  local readSize = opts.downloadChunk or 64 * 1024

  if type(source) == "string" and source:match("^https?://") then
    if not http then return nil, "http API unavailable" end
    local h, err = httpx.get(source, nil, true)
    if not h then return nil, err end
    getChunk = function() return h.read(readSize) end
    closeSource = function() h.close() end
  else
    local f = fs.open(source, "rb")
    if not f then return nil, "cannot open " .. tostring(source) end
    getChunk = function() return f.read(readSize) end
    closeSource = function() pcall(function() f.close() end) end
  end

  local ok, result = pcall(function()
    local dec = flac.newStream(getChunk)
    local resample = newResampler(dec.sampleRate, dec.channels)
    local encode = dfpwm.make_encoder()
    local out = assert(fs.open(dest, "wb"))
    local written = 0
    while true do
      local frame = dec.nextFrame()
      if not frame then break end
      local n = #frame[1]
      local samples = resample(frame, n)
      -- The encoder carries state, so writing its output incrementally keeps
      -- the DFPWM bitstream continuous.
      out.write(encode(to8bit(samples)))
      written = written + #samples
      if opts.onProgress then opts.onProgress(written, dec) end
      sleep(0)
    end
    out.close()
    return written
  end)
  closeSource()

  if not ok then return nil, result end
  return result
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
