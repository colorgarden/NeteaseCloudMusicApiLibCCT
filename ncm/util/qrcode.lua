-- ncm/util/qrcode.lua
-- Pure-Lua replacement for the npm `qrcode` package used by the Node original.
--
-- Scope: byte-mode QR encoder (error-correction level M, automatic version
-- 1..40) followed by a minimal PNG encoder.  `toDataURL(text)` returns
-- "data:image/png;base64,<...>".
--
-- Compatibility: Lua 5.2 / CC:Tweaked (uses the standard `bit32` library).
-- No external Lua or non-Lua dependency is required.
--
-- NOTE: byte-for-byte parity with npm qrcode's PNG is explicitly NOT a goal --
-- the encoders and renderers differ (different mask heuristics/output size).
-- What is guaranteed is a *valid* PNG data URL that encodes exactly the same
-- input text.
--
-- The QR construction follows the well-known ISO/IEC 18004 algorithm (the same
-- one used by Project Nayuki's reference implementation): data codewords are
-- protected with Reed-Solomon over GF(256), interleaved, placed into the module
-- matrix around the function patterns, and finished by choosing the mask with
-- the lowest penalty score.

local base64 = require("ncm.util.base64")

local M = {}

-- ============================================================================
-- QR Code tables (all error-correction levels)
-- ============================================================================

local MODE_BYTE = 4

-- EC level -> 2-bit format indicator (ISO/IEC 18004): L=01 M=00 Q=11 H=10
local EC_LEVELS = { L = { bits = 1 }, M = { bits = 0 }, Q = { bits = 3 }, H = { bits = 2 } }
local DEFAULT_ECL = "M"

-- Error-correction codewords PER BLOCK, [level][version 1..40].
local ECC_CODEWORDS = {
  L = {
    7, 10, 15, 20, 26, 18, 20, 24, 30, 18,
    20, 24, 26, 30, 22, 24, 28, 30, 28, 28,
    28, 28, 30, 30, 26, 28, 30, 30, 30, 30,
    30, 30, 30, 30, 30, 30, 30, 30, 30, 30,
  },
  M = {
    10, 16, 26, 18, 24, 16, 18, 22, 22, 26,
    30, 22, 22, 24, 24, 28, 28, 26, 26, 26,
    26, 28, 28, 28, 28, 28, 28, 28, 28, 28,
    28, 28, 28, 28, 28, 28, 28, 28, 28, 28,
  },
  Q = {
    13, 22, 18, 26, 18, 24, 18, 22, 20, 24,
    28, 26, 24, 20, 30, 24, 28, 28, 26, 30,
    28, 30, 30, 30, 30, 28, 30, 30, 30, 30,
    30, 30, 30, 30, 30, 30, 30, 30, 30, 30,
  },
  H = {
    17, 28, 22, 16, 22, 28, 26, 26, 24, 28,
    24, 28, 22, 24, 24, 30, 28, 28, 26, 28,
    30, 24, 30, 30, 30, 30, 30, 30, 30, 30,
    30, 30, 30, 30, 30, 30, 30, 30, 30, 30,
  },
}

-- Number of blocks, [level][version 1..40].
local NUM_BLOCKS = {
  L = {
    1, 1, 1, 1, 1, 2, 2, 2, 2, 4,
    4, 4, 4, 4, 6, 6, 6, 6, 7, 8,
    8, 9, 9, 10, 12, 12, 12, 13, 14, 15,
    16, 17, 18, 19, 19, 20, 21, 22, 24, 25,
  },
  M = {
    1, 1, 1, 2, 2, 4, 4, 4, 5, 5,
    5, 8, 9, 9, 10, 10, 11, 13, 14, 16,
    17, 17, 18, 20, 21, 23, 25, 26, 28, 29,
    31, 33, 35, 37, 38, 40, 43, 45, 47, 49,
  },
  Q = {
    1, 1, 2, 2, 4, 4, 6, 6, 8, 8,
    8, 10, 12, 16, 12, 17, 16, 18, 21, 20,
    23, 23, 25, 27, 29, 34, 34, 35, 38, 40,
    43, 45, 48, 51, 53, 56, 59, 62, 65, 68,
  },
  H = {
    1, 1, 2, 4, 4, 4, 5, 6, 8, 8,
    11, 11, 16, 16, 18, 16, 19, 21, 25, 25,
    25, 34, 30, 32, 35, 37, 40, 42, 45, 48,
    51, 54, 57, 60, 63, 66, 70, 74, 77, 81,
  },
}

-- Accepts "L"/"M"/"Q"/"H" (string) or an options table with
-- ecl / errorCorrectionLevel / level.
local function normalizeEcl(ecl)
  if type(ecl) == "table" then
    ecl = ecl.ecl or ecl.errorCorrectionLevel or ecl.level
  end
  if type(ecl) ~= "string" then return DEFAULT_ECL end
  ecl = ecl:upper()
  if not EC_LEVELS[ecl] then return DEFAULT_ECL end
  return ecl
end

-- Penalty weights N1..N4 from the specification.
local PENALTY_N1, PENALTY_N2, PENALTY_N3, PENALTY_N4 = 3, 3, 40, 10

-- ============================================================================
-- GF(256) arithmetic and Reed-Solomon
-- ============================================================================

-- Multiply two elements of GF(256) modulo x^8 + x^4 + x^3 + x^2 + 1 (0x11D).
local function gfMul(x, y)
  local z = 0
  for i = 7, 0, -1 do
    z = bit32.bxor(bit32.lshift(z, 1), bit32.rshift(z, 7) * 0x11D)
    z = bit32.bxor(z, bit32.band(bit32.rshift(y, i), 1) * x)
  end
  return z
end

-- Coefficients of the Reed-Solomon generator polynomial of the given degree.
local function rsDivisor(degree)
  local result = {}
  for i = 1, degree do result[i] = 0 end
  result[degree] = 1
  local root = 1
  for _ = 1, degree do
    for j = 1, degree do
      result[j] = gfMul(result[j], root)
      if j < degree then result[j] = bit32.bxor(result[j], result[j + 1]) end
    end
    root = gfMul(root, 2)
  end
  return result
end

-- Reed-Solomon remainder (the ECC codewords) of `data` for the given divisor.
local function rsRemainder(data, divisor)
  local n = #divisor
  local result = {}
  for i = 1, n do result[i] = 0 end
  for _, b in ipairs(data) do
    local factor = bit32.bxor(b, result[1])
    for i = 1, n - 1 do result[i] = result[i + 1] end
    result[n] = 0
    for i = 1, n do result[i] = bit32.bxor(result[i], gfMul(divisor[i], factor)) end
  end
  return result
end

-- ============================================================================
-- Version geometry
-- ============================================================================

-- Number of usable data modules (bits) for a version, before ECC.
local function numRawDataModules(ver)
  local result = (16 * ver + 128) * ver + 64
  if ver >= 2 then
    local numAlign = math.floor(ver / 7) + 2
    result = result - ((25 * numAlign - 10) * numAlign - 55)
    if ver >= 7 then result = result - 36 end
  end
  return result
end

-- Number of data codewords for a version at the given ECC level.
local function numDataCodewords(ver, ecl)
  local raw = math.floor(numRawDataModules(ver) / 8)
  return raw - ECC_CODEWORDS[ecl][ver] * NUM_BLOCKS[ecl][ver]
end

-- Character-count indicator width for byte mode.
local function charCountBits(ver)
  if ver <= 9 then return 8 end
  return 16
end

-- Centre coordinates of the alignment patterns for a version (empty for v1).
local function alignmentPatternPositions(ver)
  if ver == 1 then return {} end
  local numAlign = math.floor(ver / 7) + 2
  local step
  if ver == 32 then
    step = 26
  else
    step = math.floor((ver * 4 + numAlign * 2 + 1) / (numAlign * 2 - 2)) * 2
  end
  local result = {}
  for i = 1, numAlign do result[i] = 0 end
  result[1] = 6
  local pos = ver * 4 + 10
  for i = numAlign, 2, -1 do
    result[i] = pos
    pos = pos - step
  end
  return result
end

-- ============================================================================
-- Module matrix
-- ============================================================================

local function getBit(x, i)
  return bit32.band(bit32.rshift(x, i), 1) ~= 0
end

local function newQr(ver, eclBits)
  local size = ver * 4 + 17
  local modules, isFunction = {}, {}
  for y = 0, size - 1 do
    local mr, fr = {}, {}
    for x = 0, size - 1 do
      mr[x] = false
      fr[x] = false
    end
    modules[y] = mr
    isFunction[y] = fr
  end
  return { version = ver, size = size, modules = modules, isFunction = isFunction, eclBits = eclBits or 0 }
end

local function setFunc(qr, x, y, dark)
  qr.modules[y][x] = dark
  qr.isFunction[y][x] = true
end

local function drawFinderPattern(qr, x, y)
  local size = qr.size
  for dy = -4, 4 do
    for dx = -4, 4 do
      local xx, yy = x + dx, y + dy
      if xx >= 0 and xx < size and yy >= 0 and yy < size then
        local dist = math.max(math.abs(dx), math.abs(dy))
        setFunc(qr, xx, yy, dist ~= 2 and dist ~= 4)
      end
    end
  end
end

local function drawAlignmentPattern(qr, x, y)
  for dy = -2, 2 do
    for dx = -2, 2 do
      setFunc(qr, x + dx, y + dy, math.max(math.abs(dx), math.abs(dy)) ~= 1)
    end
  end
end

local function drawFormatBits(qr, mask)
  local data = (qr.eclBits or 0) * 8 + mask
  local rem = data
  for _ = 1, 10 do
    rem = bit32.bxor(bit32.lshift(rem, 1), bit32.rshift(rem, 9) * 0x537)
  end
  local bits = bit32.bxor(bit32.lshift(data, 10) + rem, 0x5412)
  local size = qr.size

  for i = 0, 5 do setFunc(qr, 8, i, getBit(bits, i)) end
  setFunc(qr, 8, 7, getBit(bits, 6))
  setFunc(qr, 8, 8, getBit(bits, 7))
  setFunc(qr, 7, 8, getBit(bits, 8))
  for i = 9, 14 do setFunc(qr, 14 - i, 8, getBit(bits, i)) end

  for i = 0, 7 do setFunc(qr, size - 1 - i, 8, getBit(bits, i)) end
  for i = 8, 14 do setFunc(qr, 8, size - 15 + i, getBit(bits, i)) end
  setFunc(qr, 8, size - 8, true) -- always-dark module
end

local function drawVersion(qr)
  local ver = qr.version
  if ver < 7 then return end
  local rem = ver
  for _ = 1, 12 do
    rem = bit32.bxor(bit32.lshift(rem, 1), bit32.rshift(rem, 11) * 0x1F25)
  end
  local bits = ver * 4096 + rem
  local size = qr.size
  for i = 0, 17 do
    local dark = getBit(bits, i)
    local a = size - 11 + (i % 3)
    local b = math.floor(i / 3)
    setFunc(qr, a, b, dark)
    setFunc(qr, b, a, dark)
  end
end

local function drawFunctionPatterns(qr)
  local size = qr.size
  for i = 0, size - 1 do
    setFunc(qr, 6, i, i % 2 == 0)
    setFunc(qr, i, 6, i % 2 == 0)
  end
  drawFinderPattern(qr, 3, 3)
  drawFinderPattern(qr, size - 4, 3)
  drawFinderPattern(qr, 3, size - 4)

  local pos = alignmentPatternPositions(qr.version)
  local n = #pos
  for i = 1, n do
    for j = 1, n do
      local skip = (i == 1 and j == 1) or (i == 1 and j == n) or (i == n and j == 1)
      if not skip then drawAlignmentPattern(qr, pos[i], pos[j]) end
    end
  end

  drawFormatBits(qr, 0) -- placeholder; rewritten once the mask is chosen
  drawVersion(qr)
end

local function drawCodewords(qr, data)
  local size = qr.size
  local i = 0
  local right = size - 1
  while right >= 1 do
    if right == 6 then right = 5 end
    for vert = 0, size - 1 do
      for j = 0, 1 do
        local x = right - j
        local upward = bit32.band(right + 1, 2) == 0
        local y = upward and (size - 1 - vert) or vert
        if not qr.isFunction[y][x] and i < #data * 8 then
          local byte = data[math.floor(i / 8) + 1]
          qr.modules[y][x] = getBit(byte, 7 - (i % 8))
          i = i + 1
        end
      end
    end
    right = right - 2
  end
end

local function applyMask(qr, mask)
  local size = qr.size
  for y = 0, size - 1 do
    for x = 0, size - 1 do
      if not qr.isFunction[y][x] then
        local invert
        if mask == 0 then
          invert = (x + y) % 2 == 0
        elseif mask == 1 then
          invert = y % 2 == 0
        elseif mask == 2 then
          invert = x % 3 == 0
        elseif mask == 3 then
          invert = (x + y) % 3 == 0
        elseif mask == 4 then
          invert = (math.floor(x / 3) + math.floor(y / 2)) % 2 == 0
        elseif mask == 5 then
          invert = ((x * y) % 2 + (x * y) % 3) == 0
        elseif mask == 6 then
          invert = ((x * y) % 2 + (x * y) % 3) % 2 == 0
        else
          invert = ((x + y) % 2 + (x * y) % 3) % 2 == 0
        end
        if invert then qr.modules[y][x] = not qr.modules[y][x] end
      end
    end
  end
end

-- ============================================================================
-- Mask penalty scoring
-- ============================================================================

local function penaltyAddHistory(runHistory, runLength, size)
  if runHistory[1] == 0 then runLength = runLength + size end
  for i = 7, 2, -1 do runHistory[i] = runHistory[i - 1] end
  runHistory[1] = runLength
end

local function penaltyCountPatterns(runHistory)
  local n = runHistory[2]
  local core = n > 0
    and runHistory[3] == n
    and runHistory[4] == n * 3
    and runHistory[5] == n
    and runHistory[6] == n
  if not core then return 0 end
  local found = 0
  if runHistory[1] >= n * 4 and runHistory[7] >= n then found = found + 1 end
  if runHistory[7] >= n * 4 and runHistory[1] >= n then found = found + 1 end
  return found
end

local function penaltyTerminateAndCount(runHistory, runColor, runLength, size)
  if runColor then
    penaltyAddHistory(runHistory, runLength, size)
    runLength = 0
  end
  runLength = runLength + size
  penaltyAddHistory(runHistory, runLength, size)
  return penaltyCountPatterns(runHistory)
end

local function penaltyScore(qr)
  local size = qr.size
  local modules = qr.modules
  local result = 0

  -- Rules 1 & 3 over rows.
  for y = 0, size - 1 do
    local runColor = false
    local runLength = 0
    local history = { 0, 0, 0, 0, 0, 0, 0 }
    for x = 0, size - 1 do
      if modules[y][x] == runColor then
        runLength = runLength + 1
        if runLength == 5 then
          result = result + PENALTY_N1
        elseif runLength > 5 then
          result = result + 1
        end
      else
        penaltyAddHistory(history, runLength, size)
        if not runColor then result = result + penaltyCountPatterns(history) * PENALTY_N3 end
        runColor = modules[y][x]
        runLength = 1
      end
    end
    result = result + penaltyTerminateAndCount(history, runColor, runLength, size) * PENALTY_N3
  end

  -- Rules 1 & 3 over columns.
  for x = 0, size - 1 do
    local runColor = false
    local runLength = 0
    local history = { 0, 0, 0, 0, 0, 0, 0 }
    for y = 0, size - 1 do
      if modules[y][x] == runColor then
        runLength = runLength + 1
        if runLength == 5 then
          result = result + PENALTY_N1
        elseif runLength > 5 then
          result = result + 1
        end
      else
        penaltyAddHistory(history, runLength, size)
        if not runColor then result = result + penaltyCountPatterns(history) * PENALTY_N3 end
        runColor = modules[y][x]
        runLength = 1
      end
    end
    result = result + penaltyTerminateAndCount(history, runColor, runLength, size) * PENALTY_N3
  end

  -- Rule 2: 2x2 blocks of a single colour.
  for y = 0, size - 2 do
    for x = 0, size - 2 do
      local c = modules[y][x]
      if c == modules[y][x + 1] and c == modules[y + 1][x] and c == modules[y + 1][x + 1] then
        result = result + PENALTY_N2
      end
    end
  end

  -- Rule 4: balance of dark and light modules.
  local dark = 0
  for y = 0, size - 1 do
    for x = 0, size - 1 do
      if modules[y][x] then dark = dark + 1 end
    end
  end
  local total = size * size
  local k = math.floor((math.abs(dark * 20 - total * 10) + total - 1) / total) - 1
  result = result + k * PENALTY_N4

  return result
end

-- ============================================================================
-- Data encoding
-- ============================================================================

local function encodeDataCodewords(text, ver, ecl)
  local capacityBits = numDataCodewords(ver, ecl) * 8
  local bits = {}
  local function append(value, length)
    for i = length - 1, 0, -1 do
      bits[#bits + 1] = bit32.band(bit32.rshift(value, i), 1)
    end
  end

  append(MODE_BYTE, 4)
  append(#text, charCountBits(ver))
  for i = 1, #text do append(text:byte(i), 8) end

  local terminator = math.min(4, capacityBits - #bits)
  for _ = 1, terminator do bits[#bits + 1] = 0 end
  while #bits % 8 ~= 0 do bits[#bits + 1] = 0 end

  local pad = 0xEC
  while #bits < capacityBits do
    append(pad, 8)
    pad = pad == 0xEC and 0x11 or 0xEC
  end

  local data = {}
  for i = 1, #bits, 8 do
    local byte = 0
    for j = 0, 7 do byte = byte * 2 + bits[i + j] end
    data[#data + 1] = byte
  end
  return data
end

-- Split into blocks, append Reed-Solomon ECC, then interleave.
local function addEccAndInterleave(data, ver, ecl)
  local numBlocks = NUM_BLOCKS[ecl][ver]
  local blockEccLen = ECC_CODEWORDS[ecl][ver]
  local rawCodewords = math.floor(numRawDataModules(ver) / 8)
  local numShortBlocks = numBlocks - (rawCodewords % numBlocks)
  local shortBlockDataLen = math.floor(rawCodewords / numBlocks) - blockEccLen

  local divisor = rsDivisor(blockEccLen)
  local blocks = {}
  local k = 0
  for i = 1, numBlocks do
    local datLen = shortBlockDataLen + (i > numShortBlocks and 1 or 0)
    local dat = {}
    for t = 1, datLen do dat[t] = data[k + t] end
    k = k + datLen
    blocks[i] = { data = dat, ecc = rsRemainder(dat, divisor) }
  end

  local result = {}
  local maxDataLen = 0
  for i = 1, numBlocks do
    if #blocks[i].data > maxDataLen then maxDataLen = #blocks[i].data end
  end
  for col = 1, maxDataLen do
    for i = 1, numBlocks do
      if col <= #blocks[i].data then result[#result + 1] = blocks[i].data[col] end
    end
  end
  for col = 1, blockEccLen do
    for i = 1, numBlocks do result[#result + 1] = blocks[i].ecc[col] end
  end
  return result
end

-- ============================================================================
-- Top-level QR construction
-- ============================================================================

local function encodeMatrix(text, ecl)
  text = text or ""
  ecl = normalizeEcl(ecl)
  local ver
  for v = 1, 40 do
    local need = 4 + charCountBits(v) + 8 * #text
    if need <= numDataCodewords(v, ecl) * 8 then
      ver = v
      break
    end
  end
  if not ver then error("qrcode: input too long (" .. #text .. " bytes)", 3) end

  local codewords = addEccAndInterleave(encodeDataCodewords(text, ver, ecl), ver, ecl)
  local qr = newQr(ver, EC_LEVELS[ecl].bits)
  drawFunctionPatterns(qr)
  drawCodewords(qr, codewords)

  local bestMask, bestPenalty
  for mask = 0, 7 do
    applyMask(qr, mask)
    drawFormatBits(qr, mask)
    local penalty = penaltyScore(qr)
    if bestPenalty == nil or penalty < bestPenalty then
      bestMask = mask
      bestPenalty = penalty
    end
    applyMask(qr, mask) -- undo (XOR is self-inverse)
  end

  applyMask(qr, bestMask)
  drawFormatBits(qr, bestMask)
  return qr
end

-- ============================================================================
-- Minimal PNG encoder (8-bit greyscale, zlib "stored" deflate blocks)
-- ============================================================================

local CRC_TABLE = {}
for n = 0, 255 do
  local c = n
  for _ = 1, 8 do
    if bit32.band(c, 1) == 1 then
      c = bit32.bxor(0xEDB88320, bit32.rshift(c, 1))
    else
      c = bit32.rshift(c, 1)
    end
  end
  CRC_TABLE[n] = c
end

local function crc32(s)
  local c = 0xFFFFFFFF
  for i = 1, #s do
    local idx = bit32.band(bit32.bxor(c, s:byte(i)), 0xFF)
    c = bit32.bxor(CRC_TABLE[idx], bit32.rshift(c, 8))
  end
  return bit32.bxor(c, 0xFFFFFFFF)
end

local function adler32(s)
  local a, b = 1, 0
  for i = 1, #s do
    a = (a + s:byte(i)) % 65521
    b = (b + a) % 65521
  end
  return b * 65536 + a
end

local function u32be(n)
  return string.char(
    math.floor(n / 16777216) % 256,
    math.floor(n / 65536) % 256,
    math.floor(n / 256) % 256,
    n % 256
  )
end

-- Wrap raw bytes in a zlib stream made of uncompressed (stored) deflate blocks.
local function zlibStore(data)
  local out = { string.char(0x78, 0x01) } -- CMF/FLG for a 32K window, no dict
  local n = #data
  local pos = 1
  if n == 0 then
    out[#out + 1] = string.char(0x01, 0x00, 0x00, 0xFF, 0xFF)
  end
  while pos <= n do
    local len = math.min(65535, n - pos + 1)
    local final = (pos + len - 1 == n) and 1 or 0
    local nlen = 65535 - len
    out[#out + 1] = string.char(
      final,
      len % 256, math.floor(len / 256),
      nlen % 256, math.floor(nlen / 256)
    )
    out[#out + 1] = data:sub(pos, pos + len - 1)
    pos = pos + len
  end
  local ad = adler32(data)
  out[#out + 1] = u32be(ad)
  return table.concat(out)
end

local function pngChunk(kind, data)
  return u32be(#data) .. kind .. data .. u32be(crc32(kind .. data))
end

local function encodePNG(qr, scale, border)
  local size = qr.size
  local modules = qr.modules
  local dim = (size + border * 2) * scale

  -- Raw scanlines: one filter byte (0 = None) then one byte per pixel.
  local rows = {}
  for py = 0, dim - 1 do
    local my = math.floor(py / scale) - border
    local pixels = {}
    for px = 0, dim - 1 do
      local mx = math.floor(px / scale) - border
      local dark = false
      if mx >= 0 and my >= 0 and mx < size and my < size then
        dark = modules[my][mx]
      end
      pixels[#pixels + 1] = dark and "\0" or "\255"
    end
    rows[#rows + 1] = "\0" .. table.concat(pixels)
  end

  local ihdr = u32be(dim) .. u32be(dim)
    .. string.char(8, 0, 0, 0, 0) -- bit depth 8, greyscale, deflate, adaptive filter, no interlace

  return "\137PNG\r\n\26\n"
    .. pngChunk("IHDR", ihdr)
    .. pngChunk("IDAT", zlibStore(table.concat(rows)))
    .. pngChunk("IEND", "")
end

-- ============================================================================
-- Public API
-- ============================================================================

-- Encode `text` and return a standard PNG data URL.
-- opts = "L"/"M"/"Q"/"H" or { ecl = ..., errorCorrectionLevel = ..., level = ... }.
function M.toDataURL(text, opts)
  local qr = encodeMatrix(text, opts)
  local png = encodePNG(qr, 4, 4) -- scale 4 px/module, 4-module quiet zone
  return "data:image/png;base64," .. base64.encode(png)
end

-- Raw module matrix: { version = v, size = n, modules[y+1][x+1] = boolean(dark) }.
-- opts = "L"/"M"/"Q"/"H" or an options table (see toDataURL).
function M.encode(text, opts)
  return encodeMatrix(text, opts)
end

-- Pad the matrix with a quiet zone (border modules of light).
local function padMatrix(qr, border)
  local size = qr.size
  local n = size + border * 2
  local m = {}
  for y = 0, n - 1 do
    local row = {}
    for x = 0, n - 1 do
      local sx, sy = x - border, y - border
      row[x + 1] = (sx >= 0 and sy >= 0 and sx < size and sy < size)
        and qr.modules[sy][sx] or false
    end
    m[y + 1] = row
  end
  return m, n
end

local ASCII_STYLES = {
  text = { dark = "\226\150\136\226\150\136", light = "  " }, -- "██" (2 cells)
  compact = { dark = "\226\150\136", light = " " },           -- "█"  (1 cell)
  ascii = { dark = "#", light = " " },                        -- pure ASCII
}

-- UTF-8 encode a 3-byte code point (used for the Braille block U+2800..U+28FF).
local function u3(cp)
  return string.char(
    0xE0 + math.floor(cp / 4096),
    0x80 + math.floor(cp / 64) % 64,
    0x80 + cp % 64
  )
end

-- Render `text` as an array of terminal lines.
--
-- opts:
--   style   = "text" (default, "██"/"  ", 2 cells/module)
--           | "compact" ("█"/" ", 1 cell/module)
--           | "ascii"   ("#"/" ", 1 cell/module, pure ASCII)
--           | "half"    ("█"/"▀"/"▄"/" ", two module rows per line)
--           | "braille" (2x4 modules per Unicode Braille char, densest)
--   border  = quiet-zone width in modules (default 2)
--   invert  = swap dark/light (default false)
function M.toLines(text, opts)
  opts = opts or {}
  local qr = encodeMatrix(text, opts)
  local border = opts.border == nil and 2 or opts.border
  local style = opts.style or "text"
  local invert = opts.invert and true or false
  local modules, n = padMatrix(qr, border)

  local function darkAt(x, y)
    local d = modules[y + 1][x + 1]
    if invert then d = not d end
    return d
  end

  local lines = {}
  if style == "braille" then
    -- Unicode Braille packs a 2x4 block of modules into one character
    -- (U+2800 + dot bits). Highest terminal density; needs a font that has the
    -- Braille Patterns block (e.g. a suitable CC resource pack).
    local nw = n + (n % 2)                    -- pad width to even
    local nh = n + ((4 - (n % 4)) % 4)        -- pad height to a multiple of 4
    local function dark(x, y)
      if x >= n or y >= n then return false end
      return darkAt(x, y)
    end
    for cy = 0, math.floor(nh / 4) - 1 do
      local out = {}
      for cx = 0, math.floor(nw / 2) - 1 do
        local bx, by = cx * 2, cy * 4
        local bits = 0
        if dark(bx, by) then bits = bits + 0x01 end
        if dark(bx, by + 1) then bits = bits + 0x02 end
        if dark(bx, by + 2) then bits = bits + 0x04 end
        if dark(bx + 1, by) then bits = bits + 0x08 end
        if dark(bx + 1, by + 1) then bits = bits + 0x10 end
        if dark(bx + 1, by + 2) then bits = bits + 0x20 end
        if dark(bx, by + 3) then bits = bits + 0x40 end
        if dark(bx + 1, by + 3) then bits = bits + 0x80 end
        out[#out + 1] = u3(0x2800 + bits)
      end
      lines[#lines + 1] = table.concat(out)
    end
  elseif style == "half" then
    local UPPER, LOWER, FULL, EMPTY = "\226\150\128", "\226\150\132", "\226\150\136", " "
    local y = 0
    while y < n do
      local out = {}
      for x = 0, n - 1 do
        local top = darkAt(x, y)
        local bot = (y + 1 < n) and darkAt(x, y + 1) or false
        if top and bot then out[#out + 1] = FULL
        elseif top then out[#out + 1] = UPPER
        elseif bot then out[#out + 1] = LOWER
        else out[#out + 1] = EMPTY end
      end
      lines[#lines + 1] = table.concat(out)
      y = y + 2
    end
  else
    local st = ASCII_STYLES[style] or ASCII_STYLES.text
    for y = 0, n - 1 do
      local out = {}
      for x = 0, n - 1 do
        out[#out + 1] = darkAt(x, y) and st.dark or st.light
      end
      lines[#lines + 1] = table.concat(out)
    end
  end
  return lines
end

-- Print the QR to stdout (and therefore to a CC:Tweaked terminal).
function M.printASCII(text, opts)
  for _, line in ipairs(M.toLines(text, opts)) do
    print(line)
  end
end

-- Draw the QR using terminal background colours (one cell per module). This is
-- the most reliable rendering on CC:Tweaked (no glyph/font dependency).
function M.draw(text, opts)
  opts = opts or {}
  local termApi = rawget(_G, "term")
  local coloursApi = rawget(_G, "colours")
  if not termApi or not coloursApi then
    return M.printASCII(text, opts)
  end

  local qr = encodeMatrix(text, opts)
  local border = opts.border == nil and 2 or opts.border
  local invert = opts.invert and true or false
  local scale = opts.scale == 2 and 2 or 1
  local modules, n = padMatrix(qr, border)

  local oldBg = termApi.getBackgroundColour and termApi.getBackgroundColour()
  local oldFg = termApi.getTextColour and termApi.getTextColour()
  local darkCol = coloursApi.black
  local lightCol = coloursApi.white

  for y = 0, n - 1 do
    local prev
    for x = 0, n - 1 do
      local d = modules[y + 1][x + 1]
      if invert then d = not d end
      local c = d and darkCol or lightCol
      if c ~= prev then
        termApi.setBackgroundColor(c)
        prev = c
      end
      for _ = 1, scale do termApi.write(" ") end
    end
    if oldBg ~= nil then termApi.setBackgroundColor(oldBg) end
    termApi.write("\n")
  end
  if oldBg ~= nil then termApi.setBackgroundColor(oldBg) end
  if oldFg ~= nil then termApi.setTextColour(oldFg) end
end

return M

