-- 初始化名字

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    nickname = query.nickname,
  }
  return request("/api/activate/initProfile", data, createOption(query))
end
