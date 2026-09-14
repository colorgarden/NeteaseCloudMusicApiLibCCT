-- 电台banner

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  query.crypto = js.or_(query.crypto, "weapi")
  return request("/api/djradio/banner/get", {}, createOption(query, "weapi"))
end
