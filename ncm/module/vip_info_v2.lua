-- 获取 VIP 信息

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  return request("/api/music-vip-membership/client/vip/info", {
    userId = js.or_(query.uid, ""),
  }, createOption(query, "weapi"))
end
