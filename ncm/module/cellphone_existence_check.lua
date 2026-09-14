-- 检测手机号码是否已注册

local createOption = require("ncm.options")

return function(query, request)
  local data = {
    cellphone = query.phone,
    countrycode = query.countrycode,
  }
  return request("/api/cellphone/existence/check", data, createOption(query))
end
