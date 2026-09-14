local createOption = require("ncm.util.option")

return function(query, request)
  local data = {}
  return request(
    "/api/playlist/video/recent",
    data,
    createOption(query, "weapi")
  )
end
