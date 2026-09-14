-- ncm/util/base64.lua
-- Standard RFC 4648 base64 (the same alphabet CryptoJS uses: A-Za-z0-9+/ with '=' padding).
-- Pure Lua; no external dependency.

local M = {}

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local DECODE = {}
for i = 1, #ALPHABET do
  DECODE[ALPHABET:sub(i, i)] = i - 1
end

function M.encode(data)
  data = data or ""
  local out = {}
  local n = #data
  local i = 1
  while i <= n do
    local b1 = data:byte(i) or 0
    local b2 = data:byte(i + 1) or 0
    local b3 = data:byte(i + 2) or 0
    local c1 = math.floor(b1 / 4)
    local c2 = (b1 % 4) * 16 + math.floor(b2 / 16)
    local c3 = (b2 % 16) * 4 + math.floor(b3 / 64)
    local c4 = b3 % 64
    out[#out + 1] = ALPHABET:sub(c1 + 1, c1 + 1)
    out[#out + 1] = ALPHABET:sub(c2 + 1, c2 + 1)
    out[#out + 1] = (i + 1 <= n) and ALPHABET:sub(c3 + 1, c3 + 1) or "="
    out[#out + 1] = (i + 2 <= n) and ALPHABET:sub(c4 + 1, c4 + 1) or "="
    i = i + 3
  end
  return table.concat(out)
end

function M.decode(data)
  data = (data or ""):gsub("%s", "")
  local out = {}
  local buf = 0
  local bits = 0
  for i = 1, #data do
    local c = data:sub(i, i)
    if c == "=" then break end
    local v = DECODE[c]
    if v then
      buf = buf * 64 + v
      bits = bits + 6
      while bits >= 8 do
        bits = bits - 8
        local byte = math.floor(buf / 2 ^ bits) % 256
        out[#out + 1] = string.char(byte)
        buf = buf % 2 ^ bits
      end
    end
  end
  return table.concat(out)
end

return M
