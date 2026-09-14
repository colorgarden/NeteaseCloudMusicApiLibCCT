local base64 = require("ncm.util.base64")
local createOption = require("ncm.util.option")
local index = require("ncm.util.index")
local js = require("ncm.util.js")
local md5 = require("ncm.util.md5")

local bxor = bit32.bxor

local ID_XOR_KEY_1 = "3go8&$8*3*3h0k(2)2"

-- function getRandomFromList(list) {
--   return list[Math.floor(Math.random() * list.length)]
-- }

-- Encode a JS-style string (code units 0..255) the way CryptoJS.enc.Utf8.parse
-- would: each char becomes its UTF-8 byte sequence.
local function utf8_parse(s)
  local out = {}
  for i = 1, #s do
    local c = s:byte(i)
    if c < 0x80 then
      out[#out + 1] = string.char(c)
    elseif c < 0x800 then
      out[#out + 1] = string.char(0xC0 + math.floor(c / 64), 0x80 + (c % 64))
    else
      out[#out + 1] = string.char(
        0xE0 + math.floor(c / 4096),
        0x80 + math.floor(c / 64) % 64,
        0x80 + c % 64
      )
    end
  end
  return table.concat(out)
end

local function cloudmusic_dll_encode_id(some_id)
  local xored = {}
  for i = 1, #some_id do
    local charCode =
      bxor(some_id:byte(i), ID_XOR_KEY_1:byte(((i - 1) % #ID_XOR_KEY_1) + 1))
    xored[i] = string.char(charCode)
  end
  local xoredString = table.concat(xored)
  local wordArray = utf8_parse(xoredString)
  local digest = md5.sum(wordArray)
  return base64.encode(digest)
end

return function(query, request)
  local deviceId = index.generateDeviceId()
  -- print("[register_anonimous] deviceId: " .. deviceId)
  local encodedId = base64.encode(
    utf8_parse(deviceId .. " " .. cloudmusic_dll_encode_id(deviceId))
  )
  local data = {
    username = encodedId,
  }
  local result = request(
    "/api/register/anonimous",
    data,
    createOption(query, "weapi")
  )
  if result.body.code == 200 then
    result = {
      status = 200,
      body = js.assign({}, result.body, { cookie = js.join(result.cookie, ";") }),
      cookie = result.cookie,
    }
  end
  return result
end
