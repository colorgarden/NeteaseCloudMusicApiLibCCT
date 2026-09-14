-- 推荐新歌

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    type = "recommend",
    limit = js.or_(query.limit, 10),
    areaId = js.or_(query.areaId, 0),
  }
  return request(
    "/api/personalized/newsong",
    data,
    createOption(query, "weapi")
  )
end
