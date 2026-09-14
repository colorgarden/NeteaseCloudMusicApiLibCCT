-- DIFM电台 - 分类

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    sources = js.or_(query.sources, "[0]"),
  }
  return request("/api/dj/difm/all/style/channel/v2", data, createOption(query))
end
