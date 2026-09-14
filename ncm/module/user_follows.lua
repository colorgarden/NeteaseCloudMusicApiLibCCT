-- TA关注的人(关注)

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    offset = js.or_(query.offset, 0),
    limit = js.or_(query.limit, 30),
    order = true,
  }
  return request(
    "/api/user/getfollows/" .. js.tostr(query.uid),
    data,
    createOption(query, "weapi")
  )
end
