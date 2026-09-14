-- 注册账号
local createOption = require("ncm.util.option")
local js = require("ncm.util.js")
local md5 = require("ncm.util.md5")

return function(query, request)
  local data = {
    captcha = query.captcha,
    phone = query.phone,
    password = md5.sumhexa(js.md5in(query.password)),
    nickname = query.nickname,
    countrycode = js.or_(query.countrycode, "86"),
    force = "false",
  }
  return request("/api/w/register/cellphone", data, createOption(query))
end
