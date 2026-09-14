local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    type = 3,
  }
  local result = request("/api/login/qrcode/unikey", data, createOption(query))
  return {
    status = 200,
    body = {
      data = result.body,
      code = 200,
    },
    cookie = result.cookie,
  }
end
