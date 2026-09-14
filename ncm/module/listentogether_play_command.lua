-- 一起听 发送播放状态

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")
local json = require("ncm.util.json")

return function(query, request)
  local data = {
    roomId = query.roomId,
    commandInfo = json.encode({
      commandType = query.commandType,
      progress = js.or_(query.progress, 0),
      playStatus = query.playStatus,
      formerSongId = query.formerSongId,
      targetSongId = query.targetSongId,
      clientSeq = query.clientSeq,
    }),
  }
  return request(
    "/api/listen/together/play/command/report",
    data,
    createOption(query)
  )
end
