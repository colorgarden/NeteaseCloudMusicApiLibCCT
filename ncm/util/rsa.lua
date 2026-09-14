-- ncm/util/rsa.lua
-- Pure-Lua textbook (raw / no-padding) RSA public-key encryptor for CC:Tweaked.
--
-- Mirrors NeteaseCloudMusicApi's `forge ...publicKey.encrypt(str, 'NONE')`:
-- the message bytes are interpreted directly as a big-endian integer and raised
-- to the public exponent modulo n. There is deliberately NO PKCS#1 padding.
--
-- Self-contained: base-2^16 little-endian limb bignums with Montgomery
-- multiplication + square-and-multiply modular exponentiation. Lua 5.2
-- compatible (no `//`, no `goto`, no `bit32`, no external deps).

local M = {}

-- 1024-bit RSA public modulus (hex, 256 chars) and public exponent.
M.MODULUS_HEX =
  "e0b509f6259df8642dbc35662901477df22677ec152b5ff68ace615bb7b725152b3ab17a876aea8a5aa76d2e417629ec4ee341f56135fccf695280104e0312ecbda92557c93870114af6c9d05c4f7f0c3685b7a46bee255932575cce10b424d813cfe4875d3e82047b97ddef52741d546b8e289dc6935b3ece0462db0a22b8e7"
M.EXPONENT = 65537

local BASE = 65536

-- Drop most-significant zero limbs so `#a` is the true limb count.
local function trim(a)
  local n = #a
  while n > 0 and a[n] == 0 do
    a[n] = nil
    n = n - 1
  end
  return a
end

-- Parse a hex string (big-endian text) into base-2^16 little-endian limbs.
local function fromHex(hex)
  local limbs = {}
  local i = #hex
  while i > 0 do
    local j = i - 3
    if j < 1 then j = 1 end
    limbs[#limbs + 1] = tonumber(hex:sub(j, i), 16)
    i = j - 1
  end
  return trim(limbs)
end

-- Render exactly `limbCount` limbs as lowercase big-endian hex.
local function toHexFixed(a, limbCount)
  local parts = {}
  for i = limbCount, 1, -1 do
    parts[#parts + 1] = string.format("%04x", a[i] or 0)
  end
  return table.concat(parts)
end

-- -1, 0, 1 for a < b, a == b, a > b.
local function cmp(a, b)
  local na, nb = #a, #b
  if na ~= nb then
    return na < nb and -1 or 1
  end
  for i = na, 1, -1 do
    if a[i] ~= b[i] then
      return a[i] < b[i] and -1 or 1
    end
  end
  return 0
end

-- a - b, assuming a >= b.
local function sub(a, b)
  local r = {}
  local borrow = 0
  for i = 1, #a do
    local x = a[i] - (b[i] or 0) - borrow
    if x < 0 then
      x = x + BASE
      borrow = 1
    else
      borrow = 0
    end
    r[i] = x
  end
  return trim(r)
end

-- (2a) mod n for 0 <= a < n, using a single conditional subtraction.
local function dblmod(a, n)
  local r = {}
  local carry = 0
  for i = 1, #a do
    local x = a[i] * 2 + carry
    if x >= BASE then
      x = x - BASE
      carry = 1
    else
      carry = 0
    end
    r[i] = x
  end
  if carry > 0 then
    r[#r + 1] = carry
  end
  if cmp(r, n) >= 0 then
    r = sub(r, n)
  end
  return r
end

-- Interpret a raw byte string as a big-endian integer -> little-endian limbs.
local function bytesToLimbs(s)
  if #s % 2 == 1 then
    s = "\0" .. s
  end
  local limbs = {}
  for i = #s, 1, -2 do
    limbs[#limbs + 1] = s:byte(i - 1) * 256 + s:byte(i)
  end
  return trim(limbs)
end

-- Precompute Montgomery constants for modulus n (n must be odd, k limbs).
local function montgomeryParams(n)
  local k = #n
  -- inv = n^-1 mod 2^16 via Newton iteration (doubles correct bits per step).
  local inv = 1
  local n0 = n[1]
  for _ = 1, 6 do
    inv = (inv * (2 - n0 * inv)) % BASE
  end
  local nprime = (BASE - inv) % BASE

  -- R = BASE^k; Rm = R mod n and R2 = R^2 mod n by repeated doubling.
  local Rm = { 1 }
  for _ = 1, 16 * k do
    Rm = dblmod(Rm, n)
  end
  local R2 = Rm
  for _ = 1, 16 * k do
    R2 = dblmod(R2, n)
  end

  return k, nprime, Rm, R2
end

-- Montgomery multiplication: returns a*b*R^-1 mod n for 0 <= a,b < n.
local function montMul(a, b, n, k, nprime)
  local t = {}
  for i = 1, 2 * k + 2 do
    t[i] = 0
  end

  -- t = a * b (schoolbook).
  for i = 0, k - 1 do
    local ai = a[i + 1]
    if ai and ai ~= 0 then
      local carry = 0
      for j = 0, k - 1 do
        local idx = i + j + 1
        local sum = t[idx] + ai * (b[j + 1] or 0) + carry
        t[idx] = sum % BASE
        carry = math.floor(sum / BASE)
      end
      local idx = i + k + 1
      while carry > 0 do
        local sum = t[idx] + carry
        t[idx] = sum % BASE
        carry = math.floor(sum / BASE)
        idx = idx + 1
      end
    end
  end

  -- Montgomery reduction: fold low k limbs to zero.
  for i = 0, k - 1 do
    local ti = i + 1
    local u = (t[ti] * nprime) % BASE
    if u ~= 0 then
      local carry = 0
      for j = 0, k - 1 do
        local idx = ti + j
        local sum = t[idx] + u * n[j + 1] + carry
        t[idx] = sum % BASE
        carry = math.floor(sum / BASE)
      end
      local idx = ti + k
      while carry > 0 do
        local sum = t[idx] + carry
        t[idx] = sum % BASE
        carry = math.floor(sum / BASE)
        idx = idx + 1
      end
    end
  end

  local r = {}
  for i = 1, k + 2 do
    r[i] = t[k + i]
  end
  trim(r)
  if cmp(r, n) >= 0 then
    r = sub(r, n)
  end
  return r
end

local N = fromHex(M.MODULUS_HEX)
local K, NPRIME, R_MOD_N, R2_MOD_N = montgomeryParams(N)

-- Encrypt raw `message` bytes: big-endian integer ^ EXPONENT mod n, returned as
-- a 256-char lowercase hex string (128 bytes, left zero-padded).
function M.encryptNoPadding(message)
  local base = bytesToLimbs(message)

  -- Convert base into Montgomery form (base * R mod n) via R^2.
  local am = montMul(R2_MOD_N, base, N, K, NPRIME)
  -- 1 in Montgomery form is R mod n.
  local result = R_MOD_N

  -- Square-and-multiply over the exponent bits, MSB -> LSB.
  local bits = {}
  local x = M.EXPONENT
  while x > 0 do
    bits[#bits + 1] = x % 2
    x = math.floor(x / 2)
  end
  for i = #bits, 1, -1 do
    result = montMul(result, result, N, K, NPRIME)
    if bits[i] == 1 then
      result = montMul(result, am, N, K, NPRIME)
    end
  end

  -- Convert out of Montgomery form and render fixed-width.
  local out = montMul(result, { 1 }, N, K, NPRIME)
  return toHexFixed(out, K)
end

return M
