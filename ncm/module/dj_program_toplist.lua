-- 电台节目榜

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    limit = js.or_(query.limit, 100),
    offset = js.or_(query.offset, 0),
  }
  query.crypto = js.or_(query.crypto, "weapi")
  return request("/api/program/toplist/v1", data, createOption(query, "weapi"))
end
