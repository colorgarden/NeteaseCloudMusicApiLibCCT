-- MV 点赞转发评论数数据

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    threadid = "R_MV_5_" .. js.tostr(query.mvid),
    composeliked = true,
  }
  return request(
    "/api/comment/commentthread/info",
    data,
    createOption(query, "weapi")
  )
end
