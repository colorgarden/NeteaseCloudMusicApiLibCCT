-- 广播电台 - 我的收藏

local createOption = require("ncm.options")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    contentType = "BROADCAST",
    limit = js.or_(query.limit, "99999"),
    timeReverseOrder = "true",
    startDate = "4762584922000",
  }
  return request("/api/content/channel/collect/list", data, createOption(query))
end
