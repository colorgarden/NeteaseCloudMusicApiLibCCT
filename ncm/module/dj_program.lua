-- 电台节目列表
local index = require("ncm.util.index")
local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    radioId = query.rid,
    limit = js.or_(query.limit, 30),
    offset = js.or_(query.offset, 0),
    asc = index.toBoolean(query.asc),
  }
  query.crypto = js.or_(query.crypto, "weapi")
  return request("/api/dj/program/byradio", data, createOption(query, "weapi"))
end
