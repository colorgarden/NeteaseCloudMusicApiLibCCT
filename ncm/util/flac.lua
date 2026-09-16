-- ncm/util/flac.lua
-- Streaming FLAC decoder (pure Lua) for CC:Tweaked.
--
-- FLAC is frame-based: after the "fLaC" magic + metadata blocks, the audio is a
-- sequence of self-contained frames. That makes it possible to decode *while*
-- still downloading: this module pulls bytes from a source on demand and hands
-- back one decoded frame at a time, so the whole file never has to fit in
-- memory.
--
-- The frame decoder is adapted from JackMacWindows' AUKit (MIT), which in turn
-- ports Project Nayuki's "Simple FLAC implementation" (MIT).
--
-- Usage:
--   local flac = require("ncm.util.flac")
--   local dec = flac.newStream(function() return handle.read(16384) end)
--   -- dec.sampleRate / dec.channels / dec.bitsPerSample
--   local frame = dec.nextFrame()   -- { [ch] = { float samples -1..1 }, ... }
--
-- Lua 5.2 / CC:Tweaked compatible (uses bit32).
--
-- Verified bit-exact against ffmpeg for 8/16/24-bit FLAC (mono/stereo, various
-- sample rates, LPC/fixed/verbatim subframes). 32-bit FLAC is NOT supported
-- (double-precision limits); real files (and everything NetEase serves) are
-- 16/24-bit.

local M = {}

local FIXED_PREDICTION_COEFFICIENTS = {
  {},
  { 1 },
  { 2, -1 },
  { 3, -3, 1 },
  { 4, -6, 4, -1 },
}

-- ---------------------------------------------------------------- byte source
-- Pulls chunks via `getChunk()` and serves individual bytes. Keeps only the
-- unconsumed tail of the last chunk in memory.
local function makeByteReader(getChunk)
  local buf, pos, eof = "", 1, false
  local R = {}

  local function ensure(n)
    while (#buf - pos + 1) < n do
      if eof then return false end
      local chunk = getChunk()
      if not chunk or #chunk == 0 then
        eof = true
        return false
      end
      if pos > 1 then
        buf = buf:sub(pos)
        pos = 1
      end
      buf = buf .. chunk
    end
    return true
  end

  function R.readByte()
    if not ensure(1) then return nil end
    local b = buf:byte(pos)
    pos = pos + 1
    return b
  end

  function R.readString(n)
    if not ensure(n) then return nil end
    local s = buf:sub(pos, pos + n - 1)
    pos = pos + n
    return s
  end

  return R
end

-- --------------------------------------------------------------- bit reader
-- AUKit / Nayuki style: bitBuffer holds the remaining bits (MSB-first); after
-- consuming n bits, floor(bitBuffer / 2^remaining) % 2^n yields the next n bits.
local function makeBitReader(R)
  local obj = {}
  local bitBuffer, bitBufferLen = 0, 0

  function obj.alignToByte()
    bitBufferLen = bitBufferLen - bitBufferLen % 8
  end

  function obj.readByte()
    return obj.readUint(8)
  end

  function obj.readUint(n)
    if n == 0 then return 0 end
    while bitBufferLen < n do
      local temp = R.readByte()
      if temp == nil then return nil end
      bitBuffer = (bitBuffer * 256 + temp) % 0x100000000000
      bitBufferLen = bitBufferLen + 8
    end
    bitBufferLen = bitBufferLen - n
    local result = math.floor(bitBuffer / 2 ^ bitBufferLen) % 2 ^ n
    return result
  end

  function obj.readSignedInt(n)
    local v = obj.readUint(n)
    if v == nil then return nil end
    if v >= 2 ^ (n - 1) then v = v - 2 ^ n end
    return v
  end

  function obj.readRiceSignedInt(param)
    local val = 0
    while obj.readUint(1) == 0 do val = val + 1 end
    val = val * 2 ^ param + obj.readUint(param)
    if bit32.btest(val, 1) then
      return -math.floor(val / 2) - 1
    else
      return math.floor(val / 2)
    end
  end

  return obj
end

-- ------------------------------------------------------------- frame decoder
local function decodeResiduals(inp, warmup, blockSize, result)
  local method = inp.readUint(2)
  if method >= 2 then error("reserved residual coding method " .. tostring(method)) end
  local paramBits = method == 0 and 4 or 5
  local escapeParam = method == 0 and 0xF or 0x1F

  local partitionOrder = inp.readUint(4)
  local numPartitions = 2 ^ partitionOrder
  if blockSize % numPartitions ~= 0 then
    error("block size not divisible by number of Rice partitions")
  end
  local partitionSize = math.floor(blockSize / numPartitions)

  for i = 0, numPartitions - 1 do
    local start = i * partitionSize + (i == 0 and warmup or 0)
    local endd = (i + 1) * partitionSize
    local param = inp.readUint(paramBits)
    if param < escapeParam then
      for j = start, endd - 1 do
        result[j + 1] = inp.readRiceSignedInt(param)
      end
    else
      local numBits = inp.readUint(5)
      for j = start, endd - 1 do
        result[j + 1] = inp.readSignedInt(numBits)
      end
    end
  end
end

local function restoreLinearPrediction(result, coefs, shift, blockSize)
  for i = #coefs, blockSize - 1 do
    local sum = 0
    for j = 0, #coefs - 1 do
      sum = sum + result[i - j] * coefs[j + 1]
    end
    result[i + 1] = result[i + 1] + math.floor(sum / 2 ^ shift)
  end
end

local function decodeFixedPredictionSubframe(inp, predOrder, sampleDepth, blockSize, result)
  for i = 1, predOrder do result[i] = inp.readSignedInt(sampleDepth) end
  decodeResiduals(inp, predOrder, blockSize, result)
  restoreLinearPrediction(result, FIXED_PREDICTION_COEFFICIENTS[predOrder + 1], 0, blockSize)
end

local function decodeLinearPredictiveCodingSubframe(inp, lpcOrder, sampleDepth, blockSize, result)
  for i = 1, lpcOrder do result[i] = inp.readSignedInt(sampleDepth) end
  local precision = inp.readUint(4) + 1
  local shift = inp.readSignedInt(5)
  local coefs = {}
  for i = 1, lpcOrder do coefs[i] = inp.readSignedInt(precision) end
  decodeResiduals(inp, lpcOrder, blockSize, result)
  restoreLinearPrediction(result, coefs, shift, blockSize)
end

local function decodeSubframe(inp, sampleDepth, blockSize, result)
  inp.readUint(1)
  local stype = inp.readUint(6)
  local shift = inp.readUint(1)
  if shift == 1 then
    while inp.readUint(1) == 0 do shift = shift + 1 end
  end
  sampleDepth = sampleDepth - shift

  if stype == 0 then -- constant
    local c = inp.readSignedInt(sampleDepth)
    for i = 1, blockSize do result[i] = c end
  elseif stype == 1 then -- verbatim
    for i = 1, blockSize do result[i] = inp.readSignedInt(sampleDepth) end
  elseif stype >= 8 and stype <= 12 then
    decodeFixedPredictionSubframe(inp, stype - 8, sampleDepth, blockSize, result)
  elseif stype >= 32 and stype <= 63 then
    decodeLinearPredictiveCodingSubframe(inp, stype - 31, sampleDepth, blockSize, result)
  else
    error("reserved subframe type " .. tostring(stype))
  end

  for i = 1, blockSize do result[i] = result[i] * 2 ^ shift end
end

local function decodeSubframes(inp, sampleDepth, chanAsgn, blockSize, result)
  local subframes = {}
  for i = 1, #result do subframes[i] = {} end
  if chanAsgn >= 0 and chanAsgn <= 7 then
    for ch = 1, #result do
      decodeSubframe(inp, sampleDepth, blockSize, subframes[ch])
    end
  elseif chanAsgn >= 8 and chanAsgn <= 10 then
    decodeSubframe(inp, sampleDepth + (chanAsgn == 9 and 1 or 0), blockSize, subframes[1])
    decodeSubframe(inp, sampleDepth + (chanAsgn == 9 and 0 or 1), blockSize, subframes[2])
    if chanAsgn == 8 then
      for i = 1, blockSize do subframes[2][i] = subframes[1][i] - subframes[2][i] end
    elseif chanAsgn == 9 then
      for i = 1, blockSize do subframes[1][i] = subframes[1][i] + subframes[2][i] end
    else -- 10: mid/side
      for i = 1, blockSize do
        local side = subframes[2][i]
        local right = subframes[1][i] - math.floor(side / 2)
        subframes[2][i] = right
        subframes[1][i] = right + side
      end
    end
  else
    error("reserved channel assignment")
  end
  for ch = 1, #result do
    for i = 1, blockSize do
      local s = subframes[ch][i]
      if s >= 2 ^ (sampleDepth - 1) then s = s - 2 ^ sampleDepth end
      result[ch][i] = s / 2 ^ (sampleDepth - 1)
    end
  end
end

-- Returns the decoded frame (table of channels of float samples) via callback,
-- or false at end of stream.
local function decodeFrame(inp, numChannels, sampleDepth, callback)
  local out = {}
  for i = 1, numChannels do out[i] = {} end

  local temp = inp.readByte()
  if temp == nil then return false end
  local sync = temp * 64 + inp.readUint(6)
  if sync ~= 0x3FFE then error("sync code expected") end

  inp.readUint(1)
  inp.readUint(1)
  local blockSizeCode = inp.readUint(4)
  local sampleRateCode = inp.readUint(4)
  local chanAsgn = inp.readUint(4)
  inp.readUint(3)
  inp.readUint(1)

  temp = inp.readUint(8)
  local t2 = -1
  for i = 7, 0, -1 do
    if not bit32.btest(temp, 2 ^ i) then break end
    t2 = t2 + 1
  end
  for _ = 1, t2 do inp.readUint(8) end

  local blockSize
  if blockSizeCode == 1 then
    blockSize = 192
  elseif blockSizeCode >= 2 and blockSizeCode <= 5 then
    blockSize = 576 * 2 ^ (blockSizeCode - 2)
  elseif blockSizeCode == 6 then
    blockSize = inp.readUint(8) + 1
  elseif blockSizeCode == 7 then
    blockSize = inp.readUint(16) + 1
  elseif blockSizeCode >= 8 and blockSizeCode <= 15 then
    blockSize = 256 * 2 ^ (blockSizeCode - 8)
  else
    error("reserved block size")
  end

  if sampleRateCode == 12 then
    inp.readUint(8)
  elseif sampleRateCode == 13 or sampleRateCode == 14 then
    inp.readUint(16)
  end

  inp.readUint(8) -- CRC-8 (ignored)

  decodeSubframes(inp, sampleDepth, chanAsgn, blockSize, out)
  inp.alignToByte()
  inp.readUint(16) -- CRC-16 (ignored)

  callback(out)
  return true
end

-- ------------------------------------------------------------------ metadata
-- Parses the "fLaC" magic and metadata blocks, returning stream info.
local function parseMetadata(R)
  local magic = R.readString(4)
  if magic ~= "fLaC" then error("not a FLAC stream (bad magic)") end

  local info = {}
  local last = false
  while not last do
    local header = R.readByte()
    if header == nil then error("unexpected EOF in metadata") end
    last = bit32.btest(header, 0x80)
    local btype = bit32.band(header, 0x7F)
    local b1, b2, b3 = R.readByte(), R.readByte(), R.readByte()
    local length = b1 * 65536 + b2 * 256 + b3

    if btype == 0 then -- STREAMINFO
      local d = R.readString(length)
      if #d < 34 then error("short STREAMINFO") end
      local function u(i) return d:byte(i) end
      info.sampleRate = u(11) * 4096 + u(12) * 16 + math.floor(u(13) / 16)
      info.channels = bit32.band(bit32.rshift(u(13), 1), 7) + 1
      info.bitsPerSample = bit32.band(u(13), 1) * 16 + math.floor(u(14) / 16) + 1
      info.totalSamples = (u(14) % 16) * 2 ^ 32 + u(15) * 2 ^ 24 + u(16) * 2 ^ 16 + u(17) * 256 + u(18)
    else
      R.readString(length) -- skip
    end
  end

  if not info.sampleRate then error("STREAMINFO metadata block absent") end
  if info.bitsPerSample % 8 ~= 0 then error("sample depth not supported: " .. tostring(info.bitsPerSample)) end
  return info
end

-- --------------------------------------------------------------------- API
-- `getChunk()` must return the next chunk of the FLAC stream as a string, or
-- nil/"" at end of stream.
function M.newStream(getChunk)
  local R = makeByteReader(getChunk)
  local info = parseMetadata(R)
  local inp = makeBitReader(R)

  local decoder = {
    sampleRate = info.sampleRate,
    channels = info.channels,
    bitsPerSample = info.bitsPerSample,
    totalSamples = info.totalSamples,
  }

  -- Returns a table of channels (each an array of floats in [-1, 1]) or nil.
  function decoder.nextFrame()
    local frame
    local ok = decodeFrame(inp, decoder.channels, decoder.bitsPerSample, function(out)
      frame = out
    end)
    if not ok then return nil end
    return frame
  end

  return decoder
end

-- Decode a complete FLAC string, returning { sampleRate, data = {ch1, ch2, ...} }.
function M.decode(data)
  local pos = 1
  local dec = M.newStream(function()
    if pos > #data then return nil end
    local chunk = data:sub(pos, pos + 65535)
    pos = pos + #chunk
    return chunk
  end)
  local out = {}
  for i = 1, dec.channels do out[i] = {} end
  local frame
  while true do
    frame = dec.nextFrame()
    if not frame then break end
    for c = 1, dec.channels do
      local o, f, n = out[c], frame[c], #out[c]
      for i = 1, #f do o[n + i] = f[i] end
    end
  end
  return {
    sampleRate = dec.sampleRate,
    channels = dec.channels,
    bitsPerSample = dec.bitsPerSample,
    data = out,
  }
end

return M
