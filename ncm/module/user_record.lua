-- 听歌排行

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    uid = query.uid,
    type = js.or_(query.type, 0), -- 1: 最近一周, 0: 所有时间
  }
  return request("/api/v1/play/record", data, createOption(query, "weapi"))
end
