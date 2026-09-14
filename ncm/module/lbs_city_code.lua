-- 多级行政区划数据获取接口

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    bizCode = js.or_(query.bizCode, ""),
  }
  return request("/api/lbs/city/code", data, createOption(query))
end
