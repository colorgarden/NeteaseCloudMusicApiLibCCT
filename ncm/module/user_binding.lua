local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {}
  return request(
    "/api/v1/user/bindings/" .. js.tostr(query.uid),
    data,
    createOption(query, "weapi")
  )
end
