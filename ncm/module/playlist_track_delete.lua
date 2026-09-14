-- 收藏单曲到歌单 从歌单删除歌曲

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")
local json = require("ncm.util.json")

return function(query, request)
  query.ids = js.or_(query.ids, "")
  -- JSON.stringify preserves JS insertion order, so build the array text manually
  -- (Lua json.encode iterates with pairs(), which would reorder type/id).
  local parts = {}
  js.forEach(js.split(query.ids, ","), function(item)
    parts[#parts + 1] = '{"type":3,"id":' .. json.encode(item) .. "}"
  end)
  local data = {
    id = query.id,
    tracks = "[" .. table.concat(parts, ",") .. "]",
  }

  return request(
    "/api/playlist/track/delete",
    data,
    createOption(query, "weapi")
  )
end
