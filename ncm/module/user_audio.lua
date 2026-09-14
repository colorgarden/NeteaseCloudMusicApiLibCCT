-- 用户创建的电台

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    userId = query.uid,
  }
  return request("/api/djradio/get/byuser", data, createOption(query, "weapi"))
end
