-- 相似MV

local createOption = require("ncm.util.option")
return function(query, request)
  local data = {
    mvid = query.mvid,
  }
  return request("/api/discovery/simiMV", data, createOption(query, "weapi"))
end
