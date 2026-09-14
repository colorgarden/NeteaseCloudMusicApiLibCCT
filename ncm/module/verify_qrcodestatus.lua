local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    qrCode = query.qr,
  }
  local res = request(
    "/api/frontrisk/verify/qrcodestatus",
    data,
    createOption(query, "weapi")
  )
  return res
end
