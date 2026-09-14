-- 推荐节目

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    cateId = query.type,
    limit = js.or_(query.limit, 10),
    offset = js.or_(query.offset, 0),
  }
  return request(
    "/api/program/recommend/v1",
    data,
    createOption(query, "weapi")
  )
end
