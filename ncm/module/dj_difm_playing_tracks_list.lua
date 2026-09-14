-- DIFM电台 - 播放列表

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    limit = js.or_(query.limit, 5),
    source = js.or_(query.source, 0),
    channelId = query.channelId,
  }
  return request("/api/dj/difm/playing/tracks/list", data, createOption(query))
end
