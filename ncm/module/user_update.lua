-- 编辑用户信息

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    -- avatarImgId = "0",
    birthday = query.birthday,
    city = query.city,
    gender = query.gender,
    nickname = query.nickname,
    province = query.province,
    signature = query.signature,
  }
  return request("/api/user/profile/update", data, createOption(query))
end
