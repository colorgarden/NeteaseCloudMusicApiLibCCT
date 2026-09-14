-- 私人FM

local createOption = require("ncm.util.option")

return function(query, request)
  return request("/api/v1/radio/get", {}, createOption(query, "weapi"))
end
