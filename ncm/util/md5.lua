-- Pure-Lua MD5 implementation for CC:Tweaked (Lua 5.2, uses bit32).
local M = {}

local floor, sin = math.floor, math.sin
local char, byte, rep, format = string.char, string.byte, string.rep, string.format

local band, bor, bxor, bnot = bit32.band, bit32.bor, bit32.bxor, bit32.bnot
local rshift, lrotate = bit32.rshift, bit32.lrotate

-- Per-round additive constants: floor(abs(sin(i)) * 2^32), i = 1..64.
local K = {}
for i = 1, 64 do
  K[i] = floor(math.abs(sin(i)) * 4294967296)
end

-- Per-step left-rotation amounts.
local S = {
  7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
  5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20,
  4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
  6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21,
}

-- Serialize a 32-bit word as 4 little-endian bytes.
local function le32(n)
  return char(band(n, 0xff), band(rshift(n, 8), 0xff),
              band(rshift(n, 16), 0xff), band(rshift(n, 24), 0xff))
end

-- Raw 16-byte binary MD5 digest of the byte string s.
function M.sum(s)
  local len = #s
  local bitLen = len * 8

  -- MD5 padding: 0x80, then zeros so the length is 56 (mod 64),
  -- then the 64-bit little-endian bit length.
  local padLen = (56 - (len + 1) % 64) % 64
  local msg = s .. "\128" .. rep("\0", padLen)
       .. le32(bitLen % 4294967296)
       .. le32(floor(bitLen / 4294967296))

  local a0, b0, c0, d0 = 0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476

  for chunk = 1, #msg, 64 do
    -- Load the 16 little-endian 32-bit words of this block.
    local w = {}
    for j = 0, 15 do
      local i = chunk + j * 4
      local b1, b2, b3, b4 = byte(msg, i, i + 3)
      w[j] = b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
    end

    local A, B, C, D = a0, b0, c0, d0

    for i = 0, 63 do
      local F, g
      if i < 16 then
        F = bor(band(B, C), band(bnot(B), D))
        g = i
      elseif i < 32 then
        F = bor(band(D, B), band(bnot(D), C))
        g = (5 * i + 1) % 16
      elseif i < 48 then
        F = bxor(B, bxor(C, D))
        g = (3 * i + 5) % 16
      else
        F = bxor(C, bor(B, bnot(D)))
        g = (7 * i) % 16
      end

      F = (F + A + K[i + 1] + w[g]) % 4294967296
      A = D
      D = C
      C = B
      B = (B + lrotate(F, S[i + 1])) % 4294967296
    end

    a0 = (a0 + A) % 4294967296
    b0 = (b0 + B) % 4294967296
    c0 = (c0 + C) % 4294967296
    d0 = (d0 + D) % 4294967296
  end

  return le32(a0) .. le32(b0) .. le32(c0) .. le32(d0)
end

-- 32-character lowercase hexadecimal MD5 digest of s.
function M.sumhexa(s)
  return (M.sum(s):gsub(".", function(c)
    return format("%02x", byte(c))
  end))
end

return M
