local createOption = require("ncm.util.option")

return function(query, request)
  return request(
    "/api/artist/head/info/get",
    {
      id = query.id,
    },
    createOption(query)
  )
end
