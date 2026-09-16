-- 相关歌单 (related playlists scraped from the playlist HTML page)
-- Port of NeteaseCloudMusicApi@4.32.0 module/related_playlist.js.
--
-- The Node original calls axios directly and scrapes the HTML with a global
-- regex, so this port performs the GET through `ncm.util.httpx` (cc_big_http
-- Range chunks) and uses a faithful Lua pattern translation of that regex.
-- httpx is mandatory on CC:Tweaked because NetEase pages can exceed the 16 MiB
-- (`http_max_download`) built-in single-response cap.
--
-- JS pattern (global):
--   /<div class="cver u-cover u-cover-3">[\s\S]*?<img src="([^"]+)">[\s\S]*?
--    <a class="sname f-fs1 s-fc0" href="([^"]+)"[^>]*>([^<]+?)<\/a>[\s\S]*?
--    <a class="nm nm f-thide s-fc3" href="([^"]+)"[^>]*>([^<]+?)<\/a>/g

local js = require("ncm.util.js")
local httpx = require("ncm.util.httpx")

-- `.-` for lazy [\s\S]*?, `[^<]-` for lazy [^<]+?, literal `-` escaped as `%-`.
local PATTERN = '<div class="cver u%-cover u%-cover%-3">'
  .. '.-<img src="([^"]+)">'
  .. '.-<a class="sname f%-fs1 s%-fc0" href="([^"]+)"[^>]*>([^<]-)</a>'
  .. '.-<a class="nm nm f%-thide s%-fc3" href="([^"]+)"[^>]*>([^<]-)</a>'

-- Prefix/suffix lengths taken from the JS string literals (String.length):
--   '?param=50y50'  = 12
--   '/playlist?id=' = 13
--   '/user/home?id=' = 14
local COVER_SUFFIX_LEN = #"?param=50y50"
local PLAYLIST_PREFIX_LEN = #"/playlist?id="
local USER_PREFIX_LEN = #"/user/home?id="

local function parsePlaylists(text)
  local playlists = js.array({})
  local init = 1
  while true do
    -- Emulates RegExp.exec + lastIndex: resume after the previous match end.
    local s, e, cover, href, name, userHref, nickname = text:find(PATTERN, init)
    if not s then break end
    init = e + 1

    playlists[#playlists + 1] = {
      creator = {
        userId = userHref:sub(USER_PREFIX_LEN + 1),   -- slice('/user/home?id='.length)
        nickname = nickname,
      },
      coverImgUrl = cover:sub(1, #cover - COVER_SUFFIX_LEN), -- slice(0, -'?param=50y50'.length)
      name = name,
      id = href:sub(PLAYLIST_PREFIX_LEN + 1),         -- slice('/playlist?id='.length)
    }
  end
  return playlists
end

return function(query, request)
  local response, err = httpx.get("https://music.163.com/playlist?id=" .. js.tostr(query.id))
  if not response then
    return { status = 500, body = { code = 500, msg = err or "request failed" } }
  end

  local raw = response.readAll()
  response.close()

  local ok, playlists = pcall(parsePlaylists, raw or "")
  if not ok then
    return { status = 500, body = { code = 500, msg = tostring(playlists) } }
  end

  return {
    status = 200,
    body = { code = 200, playlists = playlists },
  }
end
