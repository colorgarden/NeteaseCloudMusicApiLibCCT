-- 发送验证码

local createOption = require("ncm.options")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    ctcode = js.or_(query.ctcode, "86"),
    secrete = "music_middleuser_pclogin",
    cellphone = query.phone,
  }
  return request("/api/sms/captcha/sent", data, createOption(query, "weapi"))
end
