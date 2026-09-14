-- 收藏与取消收藏视频

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  query.t = js.ternary(tonumber(query.t) == 1, "sub", "unsub")
  local data = {
    id = query.id,
  }
  return request(
    "/api/cloudvideo/video/" .. js.tostr(query.t),
    data,
    createOption(query, "weapi")
  )
end
