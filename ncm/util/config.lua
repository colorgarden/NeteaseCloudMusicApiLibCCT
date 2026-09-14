-- ncm/util/config.lua
-- Constants ported from NeteaseCloudMusicApi@4.32.0 util/config.json + util/crypto.js.
-- The RSA modulus is the NetEase weapi public key (1024-bit, e = 65537).

local M = {}

M.resourceTypeMap = {
  ["0"] = "R_SO_4_",
  ["1"] = "R_MV_5_",
  ["2"] = "A_PL_0_",
  ["3"] = "R_AL_3_",
  ["4"] = "A_DJ_1_",
  ["5"] = "R_VI_62_",
  ["6"] = "A_EV_2_",
  ["7"] = "A_DR_14_",
}

M.APP_CONF = {
  apiDomain = "https://interface.music.163.com",
  domain = "https://music.163.com",
  encrypt = true,
  encryptResponse = false,
  clientSign = "18:C0:4D:B9:8F:FE@@@453832335F384641365F424635335F303030315F303031425F343434415F343643365F333638332@@@@@@6ff673ef74955b38bce2fa8562d95c976ed4758b1227c4e9ee345987cee17bc9",
  checkToken = "9ca17ae2e6ffcda170e2e6ee8af14fbabdb988f225b3868eb2c15a879b9a83d274a790ac8ff54a97b889d5d42af0feaec3b92af58cff99c470a7eafd88f75e839a9ea7c14e909da883e83fb692a3abdb6b92adee9e",
}

-- from util/crypto.js
M.crypto = {
  iv = "0102030405060708",
  presetKey = "0CoJUm6Qyw8W8jud",
  linuxapiKey = "rFgB&h#%2?^eDg:Q",
  base62 = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789",
  eapiKey = "e82ckenh8dichen8",
  eapiSeparator = "-36cd479b6b5-",
}

-- RSA public key material (extracted from the PEM in util/crypto.js).
M.rsa = {
  modulusHex = "e0b509f6259df8642dbc35662901477df22677ec152b5ff68ace615bb7b725152b3ab17a876aea8a5aa76d2e417629ec4ee341f56135fccf695280104e0312ecbda92557c93870114af6c9d05c4f7f0c3685b7a46bee255932575cce10b424d813cfe4875d3e82047b97ddef52741d546b8e289dc6935b3ece0462db0a22b8e7",
  exponent = 65537,
}

return M
