-- 搜索建议

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")
return function(query, request)
  local data = {
    s = js.or_(query.keywords, ""),
  }
  local suggestType = tostring(query.type) == "mobile" and "keyword" or "web"
  return request(
    "/api/search/suggest/" .. suggestType,
    data,
    createOption(query, "weapi")
  )
end
