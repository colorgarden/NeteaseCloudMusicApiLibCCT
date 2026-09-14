-- ncm/util/crypto.lua
-- Port of NeteaseCloudMusicApi@4.32.0 util/crypto.js
--
-- Schemes:
--   weapi    : AES-128-CBC(json, presetKey, iv) -> base64, then AES-128-CBC(that, secretKey, iv) -> base64;
--              encSecKey = RSA_nopad(reverse(secretKey))
--   eapi     : AES-128-ECB("<url>-36cd479b6b5-<json>-36cd479b6b5-<md5>", eapiKey) -> UPPER hex
--   linuxapi : AES-128-ECB(json, linuxapiKey) -> UPPER hex

local cfg = require("ncm.util.config")
local json = require("ncm.util.json")
local md5 = require("ncm.util.md5")
local rsa = require("ncm.util.rsa")
local aes = require("ncm.util.aes")
local b64 = require("ncm.util.base64")
local gzip = require("ncm.util.gzip")

local C = cfg.crypto
local M = {}

local function toHexUpper(s)
  return (s:gsub(".", function(c) return string.format("%02X", c:byte()) end))
end

local function fromHex(s)
  return (s:gsub("%x%x", function(h) return string.char(tonumber(h, 16)) end))
end
M.fromHex = fromHex
M.toHexUpper = toHexUpper

-- aesEncrypt(text, mode, key, iv, format): format 'base64' (default) or 'hex' (uppercase).
function M.aesEncrypt(text, mode, key, iv, format)
  local out = aes.encrypt(text, mode, key, iv)
  if format == "hex" then
    return toHexUpper(out)
  end
  return b64.encode(out)
end

-- aesDecrypt(ciphertext, key, iv, format='base64'). Faithful to util/crypto.js:
-- the mode is hardcoded to ECB/PKCS7 there (the `iv` argument is unused).
function M.aesDecrypt(ciphertext, key, iv, format)
  format = format or "base64"
  local raw = (format == "hex") and fromHex(ciphertext) or b64.decode(ciphertext)
  return aes.decryptECB(raw, key)
end

local function randomSecretKey()
  local chars = {}
  for i = 1, 16 do
    local idx = math.floor(math.random() * 62) + 1
    chars[i] = C.base62:sub(idx, idx)
  end
  return table.concat(chars)
end

local function reverseString(s)
  return s:reverse()
end

-- secretKey may be supplied for deterministic testing; otherwise random base62.
function M.weapi(object, secretKey)
  local text = json.encode(object)
  secretKey = secretKey or randomSecretKey()
  local inner = M.aesEncrypt(text, "cbc", C.presetKey, C.iv, "base64")
  local params = M.aesEncrypt(inner, "cbc", secretKey, C.iv, "base64")
  local encSecKey = rsa.encryptNoPadding(reverseString(secretKey))
  return { params = params, encSecKey = encSecKey }
end

function M.linuxapi(object)
  local text = json.encode(object)
  return { eparams = M.aesEncrypt(text, "ecb", C.linuxapiKey, nil, "hex") }
end

function M.eapi(url, object)
  local text = type(object) == "table" and json.encode(object) or object
  local message = "nobody" .. url .. "use" .. text .. "md5forencrypt"
  local digest = md5.sumhexa(message)
  local data = url .. C.eapiSeparator .. text .. C.eapiSeparator .. digest
  return { params = M.aesEncrypt(data, "ecb", C.eapiKey, nil, "hex") }
end

-- Decrypt an eapi response body (hex). Returns the decoded Lua value, or nil.
function M.eapiResDecrypt(encryptedParams, aeapi)
  local ok, plain = pcall(function()
    return aes.decryptECB(fromHex(encryptedParams), C.eapiKey)
  end)
  if not ok then return nil end

  if aeapi then
    -- Mirrors the Node original: when x-aeapi is used the decrypted bytes are
    -- a gzip stream (zlib.gunzipSync in util/crypto.js).
    local okGz, decompressed = pcall(gzip.gunzip, plain)
    if not okGz or decompressed == nil then return nil end
    plain = decompressed
  end

  local ok2, decoded = pcall(json.decode, plain)
  if ok2 then return decoded end
  return nil
end

-- Split an eapi payload "<url><sep><json><sep><md5>" into its three parts.
-- Uses plain-text search because the separator contains '-' which is a Lua
-- pattern magic character.
local function splitEapiPayload(plain)
  local sep = C.eapiSeparator
  local a, b = plain:find(sep, 1, true)
  if not a then return nil end
  local c, d = plain:find(sep, b + 1, true)
  if not c then return nil end
  return plain:sub(1, a - 1), plain:sub(b + 1, c - 1), plain:sub(d + 1)
end
M.splitEapiPayload = splitEapiPayload

-- Decrypt an eapi hex ciphertext to its UTF-8 string.
function M.decrypt(cipherHex)
  return aes.decryptECB(fromHex(cipherHex), C.eapiKey)
end

-- Split an encrypted eapi request payload back into { url, data }.
function M.eapiReqDecrypt(encryptedParams)
  local plain = aes.decryptECB(fromHex(encryptedParams), C.eapiKey)
  local url, text = splitEapiPayload(plain)
  if url then
    local ok, decoded = pcall(json.decode, text)
    if ok then return { url = url, data = decoded } end
  end
  return nil
end

return M
