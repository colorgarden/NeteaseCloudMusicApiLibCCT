-- 一起听 更新播放列表

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")
local json = require("ncm.util.json")

-- Faithful to String.prototype.split: calling it on an absent value throws.
local function splitArg(value, field)
  if value == nil then
    error("attempt to index a nil value (field '" .. field .. "')")
  end
  return js.split(value, ",")
end

return function(query, request)
  local data = {
    roomId = query.roomId,
    playlistParam = json.encode({
      commandType = query.commandType,
      version = {
        {
          userId = query.userId,
          version = query.version,
        },
      },
      anchorSongId = "",
      anchorPosition = -1,
      randomList = splitArg(query.randomList, "randomList"),
      displayList = splitArg(query.displayList, "displayList"),
    }),
  }
  return request(
    "/api/listen/together/sync/list/command/report",
    data,
    createOption(query)
  )
end
