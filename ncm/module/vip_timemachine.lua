-- 黑胶时光机

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {}
  if js.and_(query.startTime, query.endTime) then
    data.startTime = query.startTime
    data.endTime = query.endTime
    data.type = 1
    data.limit = js.or_(query.limit, 60)
  end
  return request("/api/vipmusic/newrecord/weekflow", data, createOption(query, "weapi"))
end
