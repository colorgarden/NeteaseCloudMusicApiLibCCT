-- 视频分类列表

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    offset = js.or_(query.offset, 0),
    total = "true",
    limit = js.or_(query.limit, 99),
  }
  return request(
    "/api/cloudvideo/category/list",
    data,
    createOption(query, "weapi")
  )
end
