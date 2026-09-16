-- ncm/util/request.lua
-- Port of NeteaseCloudMusicApi@4.32.0 util/request.js onto CC:Tweaked's `http` API.
--
-- The Node original is axios + async/await. Here everything is synchronous and
-- returns the same `{ status, body, cookie }` answer table. Instead of rejecting
-- on a non-200 status (which Lua callers cannot `await`), we always return the
-- answer and let callers inspect `.status` / `.body.code`.
--
-- Usage:
--   local request = require("ncm.util.request")
--   local res = request("/api/search/get", { s = "hello" }, { crypto = "" })

local crypto = require("ncm.util.crypto")
local cfg = require("ncm.util.config")
local json = require("ncm.util.json")
local index = require("ncm.util.index")
local js = require("ncm.util.js")

local APP = cfg.APP_CONF
local M = {}

-- ---------------------------------------------------------------- randomness
local function randomHex(nbytes)
  local out = {}
  for i = 1, nbytes do
    out[i] = string.format("%02x", math.random(0, 255))
  end
  return table.concat(out)
end

local function randomString(len, chars)
  chars = chars or "abcdefghijklmnopqrstuvwxyz"
  local out = {}
  for i = 1, len do
    local idx = math.random(1, #chars)
    out[i] = chars:sub(idx, idx)
  end
  return table.concat(out)
end

-- ------------------------------------------------------------------ constants
-- Computed once, like the Node module-level WNMCID.
local WNMCID = randomString(6) .. "." .. tostring(os.time() * 1000) .. ".01.0"

local osMap = {
  pc = { os = "pc", appver = "3.1.17.204416", osver = "Microsoft-Windows-10-Professional-build-19045-64bit", channel = "netease" },
  linux = { os = "linux", appver = "1.2.1.0428", osver = "Deepin 20.9", channel = "netease" },
  android = { os = "android", appver = "8.20.20.231215173437", osver = "14", channel = "xiaomi" },
  iphone = { os = "iPhone OS", appver = "9.0.90", osver = "16.2", channel = "distribution" },
}

local userAgentMap = {
  weapi = { pc = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36 Edg/124.0.0.0" },
  linuxapi = { linux = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.90 Safari/537.36" },
  api = {
    pc = "Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Safari/537.36 Chrome/91.0.4472.164 NeteaseMusicDesktop/3.0.18.203152",
    android = "NeteaseMusic/9.1.65.240927161425(9001065);Dalvik/2.1.0 (Linux; U; Android 14; 23013RK75C Build/UKQ1.230804.001)",
    iphone = "NeteaseMusic 9.0.90/5038 (iPhone; iOS 16.2; zh_CN)",
  },
}

local function chooseUserAgent(cryptoName, uaType)
  local m = userAgentMap[cryptoName]
  if m then return m[uaType or "pc"] or "" end
  return ""
end

local SPECIAL_STATUS_CODES = {
  [201] = true, [302] = true, [400] = true, [502] = true,
  [800] = true, [801] = true, [802] = true, [803] = true,
}

-- ------------------------------------------------------------- cookie helpers
-- The default anonymous MUSIC_A token. The original reads it from a temp file
-- written by register_anonimous(); here callers may set it explicitly.
M.anonymousToken = ""

function M.setAnonymousToken(t) M.anonymousToken = t or "" end

-- Cookie jar kept in memory (and optionally persisted by the caller).
M.cookieJar = {}

function M.setCookieJar(jar) M.cookieJar = jar or {} end

local function processCookieObject(cookie, uri)
  cookie = cookie or {}
  local _ntes_nuid = cookie._ntes_nuid or randomHex(32)
  local profile = osMap[cookie.os] or osMap.pc

  local processed = {}
  for k, v in pairs(cookie) do processed[k] = v end
  processed.__remember_me = "true"
  processed.ntes_kaola_ad = "1"
  processed._ntes_nuid = _ntes_nuid
  processed._ntes_nnid = cookie._ntes_nnid or (_ntes_nuid .. "," .. tostring(os.time() * 1000))
  processed.WNMCID = cookie.WNMCID or WNMCID
  processed.WEVNSM = cookie.WEVNSM or "1.0.0"
  processed.osver = cookie.osver or profile.osver
  processed.deviceId = cookie.deviceId or M.deviceId
  processed.os = cookie.os or profile.os
  processed.channel = cookie.channel or profile.channel
  processed.appver = cookie.appver or profile.appver

  if not uri:find("login", 1, true) then
    processed.NMTID = randomHex(16)
  end

  if not processed.MUSIC_U then
    processed.MUSIC_A = processed.MUSIC_A or M.anonymousToken
  end
  return processed
end

local function createHeaderCookie(header)
  local parts = {}
  for k, v in pairs(header) do
    parts[#parts + 1] = index.encodeURIComponent(k) .. "=" .. index.encodeURIComponent(v)
  end
  return table.concat(parts, "; ")
end

-- Split a combined Set-Cookie header. CC:Tweaked joins repeated headers with
-- ", ", but Expires dates also contain commas, so only split when the next
-- segment looks like `name=`.
local function splitSetCookie(header)
  local out = {}
  local start = 1
  local i = 1
  while i <= #header do
    if header:sub(i, i) == "," then
      local rest = header:sub(i + 1):gsub("^%s+", "")
      if rest:match("^[%w!#$%%&'*+.^_`|~%-]+=") then
        out[#out + 1] = header:sub(start, i - 1)
        start = i + 1
      end
    end
    i = i + 1
  end
  out[#out + 1] = header:sub(start)
  return out
end
M.splitSetCookie = splitSetCookie

-- Parse "a=1; Path=/; b=2" style cookies into a jar.
function M.mergeSetCookie(jar, setCookieList)
  for _, raw in ipairs(setCookieList) do
    local first = raw:match("^%s*([^;]+)")
    if first then
      local k, v = first:match("^%s*([^=]+)=(.*)$")
      if k then
        k = index.trim(k)
        v = index.trim(v)
        if k ~= "" then jar[k] = v end
      end
    end
  end
  return jar
end

-- --------------------------------------------------------------- form encoding
-- Faithful to `new URLSearchParams(data).toString()` (application/x-www-form-
-- urlencoded): only [A-Za-z0-9*._-] stay literal, space becomes '+', everything
-- else is percent-encoded. This differs from encodeURIComponent, which leaves
-- !~*'() unescaped and encodes space as %20.
local function formEncodeByte(b, c)
  if c == " " then return "+" end
  if (b >= 48 and b <= 57) or (b >= 65 and b <= 90) or (b >= 97 and b <= 122)
    or c == "*" or c == "-" or c == "." or c == "_" then
    return c
  end
  return string.format("%%%02X", b)
end

local function urlencode(data)
  local parts = {}
  for k, v in pairs(data) do
    local outk, outv = {}, {}
    for i = 1, #k do
      local b = k:byte(i)
      outk[i] = formEncodeByte(b, string.char(b))
    end
    local sv = js.tostr(v)
    for i = 1, #sv do
      local b = sv:byte(i)
      outv[i] = formEncodeByte(b, string.char(b))
    end
    parts[#parts + 1] = table.concat(outk) .. "=" .. table.concat(outv)
  end
  return table.concat(parts, "&")
end

-- -------------------------------------------------------------------- request
local function toHexUpper(s)
  return (s:gsub(".", function(c) return string.format("%02X", c:byte()) end))
end

function M.setDeviceId(id) M.deviceId = id end

function M.request(uri, data, options)
  data = data or {}
  options = options or {}

  local headers = {}
  if options.headers then
    for k, v in pairs(options.headers) do headers[k] = v end
  end

  local ip = options.realIP or options.ip or ""
  if ip ~= "" then
    headers["X-Real-IP"] = ip
    headers["X-Forwarded-For"] = ip
  end

  local cookie = options.cookie or {}
  if type(cookie) == "string" then
    cookie = index.cookieToJson(cookie)
  end
  cookie = processCookieObject(cookie, uri)
  headers["Cookie"] = index.cookieObjToString(cookie)

  local csrfToken = cookie.__csrf or ""

  local cryptoName = options.crypto
  if cryptoName == nil or cryptoName == "" then
    cryptoName = APP.encrypt and "eapi" or "api"
  end

  local answer = { status = 500, body = {}, cookie = {} }

  local eR = options.e_r
  if eR == nil then eR = data.e_r end
  if eR == nil then eR = APP.encryptResponse end
  data.e_r = index.toBoolean(eR)

  local url, encryptData
  local header -- eapi header object, reused for Cookie + data.header

  -- Upstream is `options.domain || DOMAIN`. option.js defaults domain to `''`,
  -- and an empty string is TRUTHY in Lua (only nil/false are falsy), so a plain
  -- `options.domain or APP.domain` would keep the empty string and build a
  -- scheme-less URL such as "/weapi/login/qrcode/unikey". CraftOS then rejects
  -- it with "Must specify http or https". Always fall back through js.or_.
  local webDomain = js.or_(options.domain, APP.domain)
  local apiDomain = js.or_(options.domain, APP.apiDomain)

  if cryptoName == "weapi" then
    headers["Referer"] = webDomain
    headers["User-Agent"] = options.ua ~= "" and options.ua or chooseUserAgent("weapi")
    data.csrf_token = csrfToken
    encryptData = crypto.weapi(data)
    url = webDomain .. "/weapi/" .. uri:sub(6)

  elseif cryptoName == "linuxapi" then
    headers["User-Agent"] = options.ua ~= "" and options.ua or chooseUserAgent("linuxapi", "linux")
    encryptData = crypto.linuxapi({
      method = "POST",
      url = webDomain .. uri,
      params = data,
    })
    url = webDomain .. "/api/linux/forward"

  elseif cryptoName == "eapi" or cryptoName == "api" then
    header = {
      osver = cookie.osver,
      deviceId = cookie.deviceId,
      os = cookie.os,
      appver = cookie.appver,
      versioncode = cookie.versioncode or "140",
      mobilename = cookie.mobilename or "",
      buildver = cookie.buildver or tostring(os.time()):sub(1, 10),
      resolution = cookie.resolution or "1920x1080",
      __csrf = csrfToken,
      channel = cookie.channel,
      requestId = tostring(os.time() * 1000) .. "_" .. string.format("%04d", math.random(0, 999)),
    }
    if options.checkToken then
      header["X-antiCheatToken"] = APP.checkToken
    end
    if cookie.MUSIC_U then header.MUSIC_U = cookie.MUSIC_U end
    if cookie.MUSIC_A then header.MUSIC_A = cookie.MUSIC_A end

    headers["Cookie"] = createHeaderCookie(header)
    headers["User-Agent"] = options.ua ~= "" and options.ua or chooseUserAgent("api", "iphone")

    if cryptoName == "eapi" then
      data.header = header
      encryptData = crypto.eapi(uri, data)
      url = apiDomain .. "/eapi/" .. uri:sub(6)
      -- Optional: ask the server to gzip the (encrypted) response. Off by
      -- default, matching the original (which leaves this commented out).
      if options.aeapi then
        headers["x-aeapi"] = "true"
      end
    else
      url = apiDomain .. uri
      encryptData = data
    end
  else
    answer.status = 502
    answer.body = { code = 502, msg = "Unknown crypto: " .. tostring(cryptoName) }
    error(answer, 2)
  end

  local body = urlencode(encryptData)
  local useER = (cryptoName == "eapi" or cryptoName == "weapi") and data.e_r

  local httpApi = rawget(_G, "http")
  if not httpApi then
    answer.status = 502
    answer.body = { code = 502, msg = "http API unavailable (need an advanced computer with HTTP enabled)" }
    error(answer, 2)
  end

  -- Retry transient transport failures: NetEase's edge occasionally refuses or
  -- drops a connection, and one bad packet should not abort an API call. Only
  -- the "no response at all" case is retried - an HTTP error status is a real
  -- answer and is handled below.
  local attempts = 3
  local response, err, failResponse
  for attempt = 1, attempts do
    response, err, failResponse = httpApi.post({ url = url, body = body, headers = headers, binary = true })
    if response then break end
    if attempt < attempts and type(sleep) == "function" then
      sleep(attempt) -- 1s, then 2s
    end
  end
  if not response then
    answer.status = 502
    answer.body = {
      code = 502,
      msg = (err or "request failed") .. " (after " .. attempts .. " attempts)",
    }
    error(answer, 2)
  end

  -- The response must be a CC handle. When it is not (some servers/edge cases
  -- make http.post return a response-shaped object, or the call failed with a
  -- status), a bare readAll() would only say "attempt to call method 'readAll'".
  -- Report the status and the server's own message instead.
  if type(response) ~= "table" and type(response) ~= "userdata" then
    local detail = "type=" .. type(response)
    if failResponse ~= nil then detail = detail .. ", failing response present" end
    answer.status = 502
    answer.body = { code = 502, msg = "http.post returned a non-response (" .. detail .. "): " .. tostring(err) }
    error(answer, 2)
  end
  if type(response.readAll) ~= "function" then
    local code = "?"
    if type(response.getResponseCode) == "function" then
      local okCode, c = pcall(response.getResponseCode)
      if okCode and c ~= nil then code = tostring(c) end
    end
    local text = ""
    if type(response.read) == "function" then
      local okBody, chunk = pcall(response.read)
      if okBody and type(chunk) == "string" then text = chunk:sub(1, 200) end
    end
    answer.status = 502
    answer.body = { code = 502, msg = "http.post response has no readAll (status " .. code .. ")" .. (text ~= "" and (": " .. text) or "") }
    error(answer, 2)
  end
  local raw = response.readAll()
  local code = response.getResponseCode()
  local respHeaders = response.getResponseHeaders() or {}
  response.close()

  local setCookie = nil
  for k, v in pairs(respHeaders) do
    if type(k) == "string" and k:lower() == "set-cookie" then
      setCookie = v
      break
    end
  end
  if setCookie then
    local cookies = splitSetCookie(setCookie)
    for i = 1, #cookies do
      -- Mirror the original: x.replace(/\s*Domain=[^(;|$)]+;*/, '')
      cookies[i] = (cookies[i]:gsub("%s*Domain=[^;]*;*", ""))
    end
    answer.cookie = cookies
    M.mergeSetCookie(M.cookieJar, answer.cookie)
  end

  local decoded
  if useER then
    decoded = crypto.eapiResDecrypt(toHexUpper(raw), options.aeapi)
  else
    local ok, parsed = pcall(json.decode, raw)
    if ok and type(parsed) == "table" then
      decoded = parsed
    else
      decoded = raw
    end
  end
  answer.body = decoded

  -- Faithful to the Node status logic:
  --   if (body.code) body.code = Number(body.code)
  --   status = Number(body.code || res.status)
  --   if (SPECIAL.has(body.code)) status = 200
  --   status = (100 < status < 600) ? status : 400
  local rawCode
  if type(answer.body) == "table" then rawCode = answer.body.code end
  if rawCode ~= nil and not js.falsy(rawCode) then
    local n = tonumber(rawCode)
    if n then
      answer.body.code = n
      rawCode = n
    end
  end

  local status
  if js.falsy(rawCode) then
    status = code
  else
    status = tonumber(rawCode) or code
  end
  if SPECIAL_STATUS_CODES[rawCode] then status = 200 end
  if not (status > 100 and status < 600) then status = 400 end
  answer.status = status

  if status == 200 then return answer end
  -- The Node original rejects non-200 responses; emulate by raising the answer.
  error(answer, 2)
end

return M
