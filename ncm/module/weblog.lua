-- 操作记录

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  return request("/api/feedback/weblog", js.or_(query.data, {}), createOption(query, "weapi"))
end
