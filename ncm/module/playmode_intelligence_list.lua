-- 智能播放

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    songId = query.id,
    type = "fromPlayOne",
    playlistId = query.pid,
    startMusicId = js.or_(query.sid, query.id),
    count = js.or_(query.count, 1),
  }
  return request("/api/playmode/intelligence/list", data, createOption(query))
end
