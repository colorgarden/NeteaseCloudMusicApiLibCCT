local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    userTaskId = query.userTaskId,
    depositCode = js.or_(query.depositCode, "0"),
  }
  return request("/api/usertool/task/point/receive", data, createOption(query, "weapi"))
end
