-- 领取云豆

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    userMissionId = query.id,
    period = query.period,
  }
  return request(
    "/api/nmusician/workbench/mission/reward/obtain/new",
    data,
    createOption(query, "weapi")
  )
end
