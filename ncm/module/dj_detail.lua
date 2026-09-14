-- 电台详情

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    id = query.rid,
  }
  query.crypto = js.or_(query.crypto, "weapi")
  return request("/api/djradio/v2/get", data, createOption(query, "weapi"))
end
