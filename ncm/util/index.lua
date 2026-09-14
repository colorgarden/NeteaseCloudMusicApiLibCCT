-- ncm/util/index.lua
-- Port of NeteaseCloudMusicApi@4.32.0 util/index.js (cookie + misc helpers),
-- plus a JS-compatible encodeURIComponent needed when building cookies.

local M = {}

local chinaIPPrefixes = {
  "116.25", "116.76", "116.77", "116.78", "116.79", "116.80", "116.81",
  "116.82", "116.83", "116.84", "116.85", "116.86", "116.87", "116.88",
  "116.89", "116.90", "116.91", "116.92", "116.93", "116.94",
}

function M.toBoolean(val)
  if type(val) == "boolean" then return val end
  if val == "" then return val end
  return val == "true" or val == "1" or val == 1
end

-- JS String.prototype.split(';') equivalent with no limit.
local function split(str, sep)
  local out = {}
  local from = 1
  while true do
    local s, e = str:find(sep, from, true)
    if not s then
      out[#out + 1] = str:sub(from)
      break
    end
    out[#out + 1] = str:sub(from, s - 1)
    from = e + 1
  end
  return out
end
M.split = split

function M.trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Faithful to the original: an item is only kept when split('=') yields exactly 2 parts.
function M.cookieToJson(cookie)
  if not cookie then return {} end
  local obj = {}
  for _, item in ipairs(split(cookie, ";")) do
    local arr = split(item, "=")
    if #arr == 2 then
      obj[M.trim(arr[1])] = M.trim(arr[2])
    end
  end
  return obj
end

function M.encodeURIComponent(s)
  s = tostring(s)
  return (s:gsub("[^A-Za-z0-9%-_%.!~*'()]", function(c)
    return string.format("%%%02X", c:byte())
  end))
end

function M.cookieObjToString(cookie)
  local parts = {}
  for k, v in pairs(cookie) do
    parts[#parts + 1] = M.encodeURIComponent(k) .. "=" .. M.encodeURIComponent(v)
  end
  return table.concat(parts, "; ")
end

function M.getRandom(num)
  local randomValue = math.random()
  local floorValue = math.floor(randomValue * 9 + 1)
  local powValue = 10 ^ (num - 1)
  return math.floor((randomValue + floorValue) * powValue)
end

local function getRandomInt(min, max)
  return math.floor(math.random() * (max - min + 1)) + min
end

local function generateIPSegment()
  return getRandomInt(1, 255)
end

function M.generateRandomChineseIP()
  local prefix = chinaIPPrefixes[math.floor(math.random() * #chinaIPPrefixes) + 1]
  return prefix .. "." .. generateIPSegment() .. "." .. generateIPSegment()
end

function M.generateDeviceId()
  local hexChars = "0123456789ABCDEF"
  local chars = {}
  for i = 1, 52 do
    local idx = math.random(1, #hexChars)
    chars[i] = hexChars:sub(idx, idx)
  end
  return table.concat(chars)
end

local function getCookieValue(cookieStr, name)
  if not cookieStr then return "" end
  local cookies = "; " .. cookieStr
  local needle = "; " .. name .. "="
  local pos = cookies:find(needle, 1, true)
  if not pos then return "" end
  local rest = cookies:sub(pos + #needle)
  local semi = rest:find(";", 1, true)
  if semi then rest = rest:sub(1, semi - 1) end
  return rest
end

function M.generateChainId(cookie)
  local version = "v1"
  local randomNum = math.floor(math.random() * 1e6)
  local deviceId = getCookieValue(cookie, "sDeviceId")
  if deviceId == "" then deviceId = "unknown-" .. randomNum end
  local platform = "web"
  local action = "login"
  local timestamp = os.time() * 1000
  return version .. "_" .. deviceId .. "_" .. platform .. "_" .. action .. "_" .. timestamp
end

return M
