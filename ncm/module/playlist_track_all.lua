-- 通过传过来的歌单id拿到所有歌曲数据
-- 支持传递参数limit来限制获取歌曲的数据数量 例如: /playlist/track/all?id=7044354223&limit=10

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    id = query.id,
    n = 100000,
    s = js.or_(query.s, 8),
  }
  --不放在data里面避免请求带上无用的数据
  local limit = js.or_(tonumber(query.limit), 1000)
  local offset = js.or_(tonumber(query.offset), 0)

  local res = request("/api/v6/playlist/detail", data, createOption(query))
  -- Mirrors the original `.then` callback: `res.body.playlist.trackIds` raises
  -- when the stub response has no playlist (the JS side errors the same way).
  local trackIds = res.body.playlist.trackIds
  local ids = {}
  local sliced = js.slice(trackIds, offset, offset + limit)
  for _, item in ipairs(sliced) do
    ids[#ids + 1] = '{"id":' .. js.tostr(item.id) .. "}"
  end
  local idsData = {
    c = "[" .. table.concat(ids, ",") .. "]",
  }

  return request("/api/v3/song/detail", idsData, createOption(query))
end
