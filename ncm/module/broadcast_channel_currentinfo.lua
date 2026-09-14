-- 广播电台 - 电台信息

local createOption = require("ncm.options")

return function(query, request)
  local data = {
    channelId = query.id,
  }
  return request(
    "/api/voice/broadcast/channel/currentinfo",
    data,
    createOption(query)
  )
end
