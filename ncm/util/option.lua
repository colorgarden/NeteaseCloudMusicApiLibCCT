-- ncm/util/option.lua
-- Port of NeteaseCloudMusicApi@4.32.0 util/option.js
--
--   const createOption = (query, crypto = '') => ({
--     crypto: query.crypto || crypto || '',
--     cookie: query.cookie,
--     ua: query.ua || '',
--     proxy: query.proxy,
--     realIP: query.realIP,
--     e_r: query.e_r || undefined,
--     domain: query.domain || '',
--     checkToken: query.checkToken || false,
--   })
--
-- JS `||` treats "", 0 and false as absent; Lua `or` does NOT (only nil/false),
-- so every default goes through js.or_ to keep the two implementations identical.

local js = require("ncm.util.js")

local function createOption(query, crypto)
  query = query or {}
  return {
    crypto = js.or_(query.crypto, js.or_(crypto, "")),
    cookie = query.cookie,
    ua = js.or_(query.ua, ""),
    proxy = query.proxy,
    realIP = query.realIP,
    e_r = js.or_(query.e_r, nil),
    domain = js.or_(query.domain, ""),
    checkToken = js.or_(query.checkToken, false),
  }
end

return createOption
