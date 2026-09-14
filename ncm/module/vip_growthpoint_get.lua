-- 领取会员成长值

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    taskIds = query.ids,
  }
  return request("/api/vipnewcenter/app/level/task/reward/get", data, createOption(query, "weapi"))
end
