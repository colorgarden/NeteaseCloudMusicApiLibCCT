-- 听歌识曲 (audio fingerprint match)
-- Port of NeteaseCloudMusicApi@4.32.0 module/audio_match.js.
--
-- The Node original bypasses the shared `request` helper and calls axios
-- directly, so this port performs the GET through `ncm.util.httpx` (cc_big_http
-- Range chunks), which is mandatory on CC:Tweaked because NetEase responses can
-- exceed the 16 MiB (`http_max_download`) built-in single-response cap.
--
-- JS:
--   axios({ method: 'get', url: `https://interface.music.163.com/api/music/audio/match
--     ?sessionId=0123456789abcdef&algorithmCode=shazam_v2&duration=${query.duration}
--     &rawdata=${encodeURIComponent(query.audioFP)}&times=1&decrypt=1`, data: null })
--   return { status: 200, body: { code: 200, data: res.data.data } }

local index = require("ncm.util.index")
local json = require("ncm.util.json")
local js = require("ncm.util.js")
local httpx = require("ncm.util.httpx")

local MATCH_URL = "https://interface.music.163.com/api/music/audio/match"
  .. "?sessionId=0123456789abcdef"
  .. "&algorithmCode=shazam_v2"
  .. "&duration="

return function(query, request)
  -- Template literal: `...duration=${query.duration}&rawdata=${encodeURIComponent(query.audioFP)}...`
  local url = MATCH_URL
    .. js.tostr(query.duration)
    .. "&rawdata=" .. index.encodeURIComponent(query.audioFP)
    .. "&times=1&decrypt=1"

  local response, err = httpx.get(url)
  if not response then
    return { status = 500, body = { code = 500, msg = err or "request failed" } }
  end

  local raw = response.readAll()
  response.close()

  -- `res.data` is the parsed JSON body; the original reads `.data` off it.
  local ok, parsed = pcall(json.decode, raw)
  if not ok or type(parsed) ~= "table" then
    return { status = 500, body = { code = 500, msg = "invalid JSON response" } }
  end

  return {
    status = 200,
    body = {
      code = 200,
      data = parsed.data,
    },
  }
end
