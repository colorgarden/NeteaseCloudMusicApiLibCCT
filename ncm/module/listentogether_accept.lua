local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    refer = "inbox_invite",
    roomId = query.roomId,
    inviterId = query.inviterId,
  }
  return request(
    "/api/listen/together/play/invitation/accept",
    data,
    createOption(query)
  )
end
