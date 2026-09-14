-- 歌单导入 - 元数据/文字/链接导入
local createOption = require("ncm.util.option")
local js = require("ncm.util.js")
local json = require("ncm.util.json")

-- JS `new Date().toLocaleString()` under the harness' frozen clock. The default
-- en-US locale renders M/D/YYYY, h:mm:ss AM/PM using local time.
local function toLocaleString()
  local t = os.date("*t", js.now() / 1000)
  local hour = t.hour % 12
  if hour == 0 then hour = 12 end
  local meridian = t.hour < 12 and "AM" or "PM"
  return string.format(
    "%d/%d/%d, %d:%02d:%02d %s",
    t.month, t.day, t.year, hour, t.min, t.sec, meridian
  )
end

-- JS encodeURI: leaves the URI reserved/unreserved characters untouched and
-- percent-encodes every other (UTF-8) byte.
local function encodeURI(s)
  s = js.tostr(s)
  return (s:gsub("[^A-Za-z0-9%-_%.!~*'()%;,/%?:@&=+%$#]", function(c)
    return string.format("%%%02X", c:byte())
  end))
end

return function(query, request)
  local data = {
    importStarPlaylist = js.or_(query.importStarPlaylist, false), -- 导入我喜欢的音乐
  }

  if not js.falsy(query["local"]) then
    -- 元数据导入
    local local_ = json.decode(query["local"])
    local multi = {}
    for _, e in ipairs(local_) do
      multi[#multi + 1] = '{"songName":' .. json.encode(e.name)
        .. ',"artistName":' .. json.encode(e.artist)
        .. ',"albumName":' .. json.encode(e.album) .. '}'
    end
    local multiSongs = "[" .. table.concat(multi, ",") .. "]"
    data = js.assign({}, data, {
      multiSongs = multiSongs,
    })
  else
    local playlistName = -- 歌单名称
      js.or_(query.playlistName, "导入音乐 " .. toLocaleString())
    local songs = ""
    if not js.falsy(query.text) then
      -- 文字导入
      songs = '[{"name":' .. json.encode(playlistName)
        .. ',"type":"","url":'
        .. json.encode(encodeURI("rpc://playlist/import?text=" .. js.tostr(query.text)))
        .. "}]"
    end

    if not js.falsy(query.link) then
      -- 链接导入
      local link = json.decode(query.link)
      local out = {}
      for _, e in ipairs(link) do
        out[#out + 1] = '{"name":' .. json.encode(playlistName)
          .. ',"type":"","url":' .. json.encode(encodeURI(e)) .. "}"
      end
      songs = "[" .. table.concat(out, ",") .. "]"
    end
    data = js.assign({}, data, {
      playlistName = playlistName,
      createBusinessCode = nil,
      extParam = nil,
      taskIdForLog = "",
      songs = songs,
    })
  end
  return request(
    "/api/playlist/import/name/task/create",
    data,
    createOption(query)
  )
end
