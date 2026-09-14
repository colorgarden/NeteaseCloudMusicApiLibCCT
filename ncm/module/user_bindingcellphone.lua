local createOption = require("ncm.util.option")
local js = require("ncm.util.js")
local md5 = require("ncm.util.md5")

return function(query, request)
  local password = ""
  if not js.falsy(query.password) then
    password = md5.sumhexa(js.md5in(query.password))
  end
  local data = {
    phone = query.phone,
    countrycode = js.or_(query.countrycode, "86"),
    captcha = query.captcha,
    password = password,
  }
  return request(
    "/api/user/bindingCellphone",
    data,
    createOption(query, "weapi")
  )
end
