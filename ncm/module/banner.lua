-- 首页轮播图
local createOption = require("ncm.options")
local js = require("ncm.util.js")

return function(query, request)
  local types = {
    ["0"] = "pc",
    ["1"] = "android",
    ["2"] = "iphone",
    ["3"] = "ipad",
  }
  local clientType = js.or_(types[js.tostr(js.or_(query.type, 0))], "pc")
  return request("/api/v2/banner/get", { clientType = clientType }, createOption(query))
end
