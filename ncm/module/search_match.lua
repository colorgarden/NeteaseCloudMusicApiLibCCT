-- 本地歌曲匹配音乐信息

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")
local json = require("ncm.util.json")

return function(query, request)
  -- JSON.stringify preserves JS insertion order, so build the string manually.
  local fields = {}
  fields[#fields + 1] = '"title":' .. json.encode(js.or_(query.title, ""))
  fields[#fields + 1] = '"album":' .. json.encode(js.or_(query.album, ""))
  fields[#fields + 1] = '"artist":' .. json.encode(js.or_(query.artist, ""))
  fields[#fields + 1] = '"duration":' .. json.encode(js.or_(query.duration, 0))
  if query.md5 ~= nil then
    fields[#fields + 1] = '"persistId":' .. json.encode(query.md5)
  end
  local songs = "[{" .. table.concat(fields, ",") .. "}]"
  local data = {
    songs = songs,
  }
  return request("/api/search/match/new", data, createOption(query))
end
