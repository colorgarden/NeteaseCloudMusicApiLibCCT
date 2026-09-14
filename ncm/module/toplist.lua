-- 所有榜单介绍

local createOption = require("ncm.util.option")

return function(query, request)
  return request("/api/toplist", {}, createOption(query))
end
