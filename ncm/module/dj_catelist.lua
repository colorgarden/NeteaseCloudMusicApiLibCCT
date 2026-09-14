-- 电台分类列表

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  query.crypto = js.or_(query.crypto, "weapi")
  return request("/api/djradio/category/get", {}, createOption(query, "weapi"))
end
