local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    nickname = query.nickname,
  }
  return request("/api/nickname/duplicated", data, createOption(query, "weapi"))
end
