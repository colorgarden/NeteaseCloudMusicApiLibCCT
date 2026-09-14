-- 云贝推歌

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    songId = query.id,
    reason = js.or_(query.reason, "好歌献给你"),
    scene = "",
    fromUserId = -1,
    yunbeiNum = js.or_(query.yunbeiNum, 10),
  }
  return request("/api/yunbei/rcmd/song/submit", data, createOption(query, "weapi"))
end
