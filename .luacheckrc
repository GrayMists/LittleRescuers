-- luacheck game   (встановити: luarocks install luacheck)
std = "luajit"
globals = { "love" }          -- LÖVE і його колбеки love.load, love.update тощо
max_line_length = false
unused_args = false
files["game/conf.lua"] = { globals = { "love" } }
