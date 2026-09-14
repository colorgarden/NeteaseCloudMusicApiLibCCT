-- 校验验证码

local createOption = require("ncm.options")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    ctcode = js.or_(query.ctcode, "86"),
    cellphone = query.phone,
    captcha = query.captcha,
  }
  return request("/api/sms/captcha/verify", data, createOption(query, "weapi"))
end
