local crypto = require("ncm.util.crypto")

return function(query, request)
  local hexString = query.hexString:gsub("%s", "")
  local isReq = query.isReq ~= "false"

  if not hexString or hexString == "" then
    return {
      status = 400,
      body = {
        code = 400,
        message = "hex string is required",
      },
    }
  end

  local data
  if isReq then
    data = crypto.eapiReqDecrypt(hexString)
  else
    data = crypto.eapiResDecrypt(hexString) or crypto.eapiResDecrypt(hexString, true)
  end

  return {
    status = 200,
    body = {
      code = 200,
      data = data,
    },
  }
end
