-- 批量请求接口

local createOption = require("ncm.options")
local js = require("ncm.util.js")

return function(query, request)
  local data = {}
  for _, i in ipairs(js.keys(query)) do
    if i:match("^/api/") then
      data[i] = query[i]
    end
  end
  return request("/api/batch", data, createOption(query))
end
