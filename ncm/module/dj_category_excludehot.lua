-- 电台非热门类型

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  query.crypto = js.or_(query.crypto, "weapi")
  return request(
    "/api/djradio/category/excludehot",
    {},
    createOption(query, "weapi")
  )
end
