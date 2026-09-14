-- 歌手相关视频

local createOption = require("ncm.options")
local js = require("ncm.util.js")
local json = require("ncm.util.json")

return function(query, request)
  local data = {
    artistId = query.id,
    -- JSON.stringify writes keys in insertion order; json.encode iterates via
    -- pairs() (order unspecified), so emit the object string in the original
    -- `{ size, cursor }` order.
    page = '{"size":'
      .. json.encode(js.or_(query.size, 10))
      .. ',"cursor":'
      .. json.encode(js.or_(query.cursor, 0))
      .. "}",
    tab = 0,
    order = js.or_(query.order, 0),
  }
  return request("/api/mlog/artist/video", data, createOption(query, "weapi"))
end
