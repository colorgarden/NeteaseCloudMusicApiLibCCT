-- 推荐歌单

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    limit = js.or_(query.limit, 30),
    -- offset: query.offset || 0,
    total = true,
    n = 1000,
  }
  return request(
    "/api/personalized/playlist",
    data,
    createOption(query, "weapi")
  )
end
