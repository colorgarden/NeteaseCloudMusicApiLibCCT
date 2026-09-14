-- 热门歌单分类

local createOption = require("ncm.util.option")

return function(query, request)
  return request("/api/playlist/hottags", {}, createOption(query, "weapi"))
end
