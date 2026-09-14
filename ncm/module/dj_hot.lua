-- 热门电台

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    limit = js.or_(query.limit, 30),
    offset = js.or_(query.offset, 0),
  }
  query.crypto = js.or_(query.crypto, "weapi")
  return request("/api/djradio/hot/v1", data, createOption(query, "weapi"))
end
