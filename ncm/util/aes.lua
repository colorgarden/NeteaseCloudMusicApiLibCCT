-- ncm/util/aes.lua
-- AES-128 in ECB/CBC mode with PKCS#7 padding.
--
-- Built on the AES *block* primitives from aeslua-cc (AngusAU293/aeslua-cc).
-- We deliberately do NOT use aeslua's high-level aeslua.encrypt/aeslua.decrypt:
--   * its padding is a custom random scheme, not PKCS#7 (NetEase needs PKCS#7);
--   * its CBC ignores the supplied IV (a bug in ciphermode.encryptString).
-- Instead we drive aes.encrypt/aes.decrypt block-by-block and implement the
-- modes + PKCS#7 ourselves. This matches CryptoJS.pad.Pkcs7 / mode.CBC|ECB.
--
-- Outputs/inputs are Lua byte strings.

local M = {}

-- aeslua-cc's modules assign into a global `aeslua` table, so ensure it exists
-- even if the user did not load the `aeslua` entry file first.
_G.aeslua = _G.aeslua or {}
local aes = require("aeslua.aes")

local function toBytes(s)
  local t = {}
  for i = 1, #s do t[i] = s:byte(i) end
  return t
end

local function fromBytes(t)
  return string.char(table.unpack(t, 1, #t))
end

-- PKCS#7: always pad, adding a full block when the input is block-aligned.
local function pkcs7pad(s)
  local pad = 16 - (#s % 16)
  if pad == 0 then pad = 16 end
  return s .. string.rep(string.char(pad), pad)
end

local function pkcs7unpad(s)
  local n = #s
  if n == 0 then return s end
  local pad = s:byte(n)
  if pad < 1 or pad > 16 or pad > n then return s end
  for i = n - pad + 1, n do
    if s:byte(i) ~= pad then return s end
  end
  return s:sub(1, n - pad)
end

local function xorInto(dst, a, b)
  for i = 1, 16 do dst[i] = bit32.bxor(a[i], b[i]) end
  return dst
end

local function encBlock(sched, block)
  local out = {}
  aes.encrypt(sched, block, 1, out, 1)
  return out
end

local function decBlock(sched, block)
  local out = {}
  aes.decrypt(sched, block, 1, out, 1)
  return out
end

local function runECB(key, data, decrypt)
  local sched = decrypt and aes.expandDecryptionKey(toBytes(key))
    or aes.expandEncryptionKey(toBytes(key))
  local out = {}
  local n = #data / 16
  for i = 0, n - 1 do
    local block = {}
    for j = 1, 16 do block[j] = data:byte(i * 16 + j) end
    local r = decrypt and decBlock(sched, block) or encBlock(sched, block)
    for j = 1, 16 do out[i * 16 + j] = r[j] end
  end
  return fromBytes(out)
end

local function runCBC(key, data, iv, decrypt)
  local sched = decrypt and aes.expandDecryptionKey(toBytes(key))
    or aes.expandEncryptionKey(toBytes(key))
  local out = {}
  local n = #data / 16
  local prev = {}
  for j = 1, 16 do prev[j] = iv:byte(j) end
  for i = 0, n - 1 do
    local block = {}
    for j = 1, 16 do block[j] = data:byte(i * 16 + j) end
    local r
    if decrypt then
      local cipher = block
      r = xorInto({}, decBlock(sched, block), prev)
      prev = cipher
    else
      r = encBlock(sched, xorInto({}, block, prev))
      prev = r
    end
    for j = 1, 16 do out[i * 16 + j] = r[j] end
  end
  return fromBytes(out)
end

-- Encrypt/decrypt with PKCS#7. `mode` is "ecb" or "cbc".
function M.encrypt(text, mode, key, iv)
  text = text or ""
  if mode == "ecb" then
    return runECB(key, pkcs7pad(text), false)
  elseif mode == "cbc" then
    return runCBC(key, pkcs7pad(text), iv, false)
  end
  error("ncm.util.aes: unknown mode '" .. tostring(mode) .. "'")
end

function M.decrypt(data, mode, key, iv)
  if mode == "ecb" then
    return pkcs7unpad(runECB(key, data, true))
  elseif mode == "cbc" then
    return pkcs7unpad(runCBC(key, data, iv, true))
  end
  error("ncm.util.aes: unknown mode '" .. tostring(mode) .. "'")
end

M.encryptECB = function(text, key) return M.encrypt(text, "ecb", key) end
M.decryptECB = function(data, key) return M.decrypt(data, "ecb", key) end
M.encryptCBC = function(text, key, iv) return M.encrypt(text, "cbc", key, iv) end
M.decryptCBC = function(data, key, iv) return M.decrypt(data, "cbc", key, iv) end

return M
