-- 视频点赞转发评论数数据

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    threadid = "R_VI_62_" .. js.tostr(query.vid),
    composeliked = true,
  }
  return request(
    "/api/comment/commentthread/info",
    data,
    createOption(query, "weapi")
  )
end
