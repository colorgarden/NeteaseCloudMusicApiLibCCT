-- 用户是否互相关注

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    friendid = query.uid,
  }
  return request("/api/user/mutualfollow/get", data, createOption(query))
end
