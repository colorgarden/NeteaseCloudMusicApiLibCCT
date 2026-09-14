-- 全部歌单分类

local createOption = require("ncm.util.option")

return function(query, request)
  return request("/api/playlist/catalogue", {}, createOption(query, "eapi"))
end
