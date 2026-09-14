-- 签到进度

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")
return function(query, request)
  local data = {
    moduleId = js.or_(query.moduleId, "1207signin-1207signin"),
  }
  return request(
    "/api/act/modules/signin/v2/progress",
    data,
    createOption(query, "weapi")
  )
end
