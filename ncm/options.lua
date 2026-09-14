-- ncm/options.lua
-- Compatibility alias. The single source of truth is ncm.util.option; this shim
-- exists because some ported modules require "ncm.options".
return require("ncm.util.option")
