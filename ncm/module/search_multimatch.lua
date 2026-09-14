-- 多类型搜索

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")
return function(query, request)
  local data = {
    type = js.or_(query.type, 1),
    s = js.or_(query.keywords, ""),
  }
  return request(
    "/api/search/suggest/multimatch",
    data,
    createOption(query, "weapi")
  )
end
