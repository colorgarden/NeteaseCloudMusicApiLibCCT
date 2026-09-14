-- 会员成长值

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {}
  return request("/api/vipnewcenter/app/level/growhpoint/basic", data, createOption(query, "weapi"))
end
