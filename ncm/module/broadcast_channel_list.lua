-- 广播电台 - 全部电台

local createOption = require("ncm.options")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    categoryId = js.or_(query.categoryId, "0"),
    regionId = js.or_(query.regionId, "0"),
    limit = js.or_(query.limit, "20"),
    lastId = js.or_(query.lastId, "0"),
    score = js.or_(query.score, "-1"),
  }
  return request("/api/voice/broadcast/channel/list", data, createOption(query))
end
