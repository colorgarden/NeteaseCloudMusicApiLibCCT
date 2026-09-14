-- 歌曲详情

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

-- query.ids.split(/\s*,\s*/): split on a comma together with the whitespace
-- surrounding it (but not whitespace at the very start/end). Kept strict: a
-- missing/non-string query.ids raises, exactly like the JS `.split` call.
local function split_ids(s)
  local out = {}
  local from = 1
  while true do
    local a, b = s:find(",", from, true)
    if not a then
      out[#out + 1] = s:sub(from)
      break
    end
    out[#out + 1] = (s:sub(from, a - 1):gsub("%s+$", ""))
    local next_pos = b + 1
    while next_pos <= #s and s:sub(next_pos, next_pos):match("%s") do
      next_pos = next_pos + 1
    end
    from = next_pos
  end
  return out
end

return function(query, request)
  -- 歌曲数量不要超过1000
  query.ids = split_ids(query.ids)
  local parts = {}
  for _, id in ipairs(query.ids) do
    parts[#parts + 1] = '{"id":' .. js.tostr(id) .. "}"
  end
  local data = {
    c = "[" .. table.concat(parts, ",") .. "]",
  }
  return request("/api/v3/song/detail", data, createOption(query, "weapi"))
end
