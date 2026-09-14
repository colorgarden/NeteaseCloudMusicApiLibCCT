-- 粉丝来源
local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    startTime = js.or_(query.startTime, js.now() - 7 * 24 * 3600 * 1000),
    endTime = js.or_(query.endTime, js.now()),
    type = js.or_(query.type, 0), --新增关注:0 新增取关:1
  }
  return request("/api/fanscenter/trend/list", data, createOption(query))
end
