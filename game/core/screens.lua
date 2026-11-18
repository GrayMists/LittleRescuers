-- Екрани гри: screens/<назва>.lua повертає таблицю з полями
--   enter(args)  при переході на екран
--   leave()      при виході
--   update(dt)   щокадрово
--   draw()       малювання (логічні 640x480)
--   press(name)  натиснута кнопка: "up" "down" "left" "right" "a" "x" "y" "back"
-- Перехід: Sc.go("назва", args) — з м'яким затемненням.
local Sc = {}

local cache = {}
local cur, curName = nil, nil
local fade = { t = 0, dir = 0, nextName = nil, nextArgs = nil }

local function get(name)
    if not cache[name] then cache[name] = require("screens." .. name) end
    return cache[name]
end

local function switch(name, args)
    if cur and cur.leave then cur.leave() end
    cur, curName = get(name), name
    if cur.enter then cur.enter(args or {}) end
end

function Sc.go(name, args, instant)
    if instant or not cur then switch(name, args); return end
    fade.dir, fade.nextName, fade.nextArgs = 1, name, args
end

function Sc.name() return curName end
function Sc.busy() return fade.dir ~= 0 end

function Sc.update(dt)
    if fade.dir == 1 then
        fade.t = math.min(1, fade.t + dt * 4)
        if fade.t >= 1 then switch(fade.nextName, fade.nextArgs); fade.dir = -1 end
    elseif fade.dir == -1 then
        fade.t = math.max(0, fade.t - dt * 4)
        if fade.t <= 0 then fade.dir = 0 end
    end
    if cur and cur.update then cur.update(dt) end
end

function Sc.draw()
    if cur and cur.draw then cur.draw() end
    if fade.t > 0 then
        love.graphics.setColor(0.08, 0.1, 0.2, fade.t)
        love.graphics.rectangle("fill", -2000, -2000, 5000, 5000)
    end
end

function Sc.press(name)
    if fade.dir ~= 0 then return end
    if cur and cur.press then cur.press(name) end
end

return Sc
