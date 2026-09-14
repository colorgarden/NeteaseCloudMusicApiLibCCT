-- 一起听 发送心跳

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    roomId = query.roomId,
    songId = query.songId,
    playStatus = query.playStatus,
    progress = query.progress,
  }
  return request("/api/listen/together/heartbeat", data, createOption(query))
end
