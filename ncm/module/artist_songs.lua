local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    id = query.id,
    private_cloud = "true",
    work_type = 1,
    order = js.or_(query.order, "hot"), --hot,time
    offset = js.or_(query.offset, 0),
    limit = js.or_(query.limit, 100),
  }
  return request("/api/v1/artist/songs", data, createOption(query))
end
