-- 曲风偏好

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {}
  return request(
    "/api/tag/my/preference/get",
    data,
    createOption(query, "weapi")
  )
end
