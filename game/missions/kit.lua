-- Спільні шматки місій: дорога-переїзд, табло, хмари й пагорби, «рація» з капітаном.
local Dr = require("core.draw")
local Ve = require("core.vehicles")
local In = require("core.input")
local Snd = require("core.sound")
local Fx = require("core.fx")
local lg = love.graphics
local C = Dr.C

local Kit = {}

-- ---------- Тло ----------

-- theme: "town" | "forest" | "beach" | "mountain" | "night"
function Kit.sky(theme, t)
    if theme == "night" then
        Dr.vgrad(0, 0, Dr.W, Dr.H, Dr.hex(0x1D2B53), Dr.hex(0x5B4B8A))
        for k = 1, 30 do
            local x, y = (k * 97) % Dr.W, (k * 53) % 220
            lg.setColor(1, 1, 0.8, 0.5 + 0.5 * math.sin(t * 2 + k))
            lg.circle("fill", x, y, 1.5, 6)
        end
        Dr.circle(540, 70, 28, Dr.hex(0xFFF3B0), 1, true)
        return
    end
    Dr.vgrad(0, 0, Dr.W, Dr.H, C.sky1, C.sky2)
    Dr.circle(560, 70, 34, C.yellow, 1, true)
    lg.setColor(1, 0.95, 0.6, 0.25)
    lg.circle("fill", 560, 70, 48 + math.sin(t * 2) * 3, 32)
end

-- хмари, що повільно пливуть (cam — зсув камери, для паралаксу)
function Kit.clouds(t, cam)
    for k = 0, 4 do
        local x = ((k * 180 - (cam or 0) * 0.1 - t * 8) % (Dr.W + 200)) - 100
        Dr.cloud(x, 50 + (k % 3) * 34, 0.8 + (k % 2) * 0.3, 0.9)
    end
end

-- пагорби на задньому плані
function Kit.hills(cam, y, col)
    col = col or Dr.hex(0xA6DE8A)
    Dr.color(col)
    local off = (cam or 0) * 0.3
    for k = -1, 6 do
        local x = k * 160 - off % 160
        lg.circle("fill", x, y + 40, 110, 40)
    end
    lg.rectangle("fill", 0, y + 40, Dr.W, Dr.H)
end

-- ---------- Переїзд дорогою ----------
-- Машина їде праворуч сама; вгору/вниз — змінити смугу. Зірочки — збирати,
-- конуси/калюжі — об'їжджати (наїхав — машина підстрибне й пригальмує, нічого страшного).
-- opt: { vehicle = "fire", length = 3000, theme = "town", stars = 8, bumps = 4, goal = function(x, y) малює ціль }

local LANES = { 330, 400 }

function Kit.newDrive(opt)
    local d = {
        vehicle = opt.vehicle, length = opt.length or 3000, theme = opt.theme or "town",
        x = 0, lane = 1, ly = LANES[1], speed = 0, items = {}, got = 0, total = 0,
        bumped = 0, wob = 0, done = false, goal = opt.goal, deco = {}, t = 0,
    }
    local rnd = love.math.newRandomGenerator(opt.seed or 3)
    local nStars, nBumps = opt.stars or 8, opt.bumps or 4
    for k = 1, nStars do
        table.insert(d.items, { kind = "star", x = 500 + (k - 0.5) * (d.length - 900) / nStars, lane = rnd:random(1, 2) })
    end
    for k = 1, nBumps do
        local x = 700 + (k - 0.5) * (d.length - 1100) / nBumps + 90
        table.insert(d.items, { kind = opt.obstacle or "cone", x = x, lane = rnd:random(1, 2) })
    end
    d.total = nStars
    for k = 0, math.floor(d.length / 140) + 6 do
        local r = rnd:random()
        local kind = (d.theme == "forest" or d.theme == "mountain") and ((r < 0.6) and "pine" or "tree")
            or ((r < 0.45) and "house" or (r < 0.8) and "tree" or "bush")
        table.insert(d.deco, { kind = kind, x = k * 140 + rnd:random(-30, 30), roof = ({ C.red, C.blue, C.purple, C.orange, C.green })[rnd:random(1, 5)] })
    end
    return d
end

-- повертає true, коли доїхали
function Kit.updateDrive(d, dt)
    d.t = d.t + dt
    if d.done then return true end
    local target = 320
    if In.down("right") then target = 430 elseif In.down("left") then target = 220 end
    d.speed = d.speed + (target - d.speed) * math.min(1, dt * 2)
    if d.wob > 0 then d.wob = math.max(0, d.wob - dt); d.speed = d.speed * (1 - dt * 2) end
    d.x = d.x + d.speed * dt
    local _, dy = In.axis()
    if dy ~= 0 then d.lane = (dy < 0) and 1 or 2 end
    d.ly = d.ly + (LANES[d.lane] - d.ly) * math.min(1, dt * 9)
    local carX = d.x + 160
    for _, it in ipairs(d.items) do
        if not it.taken and math.abs(it.x - carX) < 50 and math.abs(LANES[it.lane] - d.ly) < 30 then
            it.taken = true
            if it.kind == "star" then
                d.got = d.got + 1
                Snd.play("ding")
                Fx.burst("spark", 160, d.ly - 60, 6, 120, 0.6, 8)
            else
                d.bumped = d.bumped + 1
                d.wob = 0.6
                Snd.play("bump")
            end
        end
    end
    if d.x >= d.length - 160 then d.done = true; return true end
    return false
end

local function drawDeco(dd, sx, t)
    local y = 290
    if dd.kind == "house" then Dr.house(sx - 50, y, 100, 70, dd.roof)
    elseif dd.kind == "bush" then Dr.bush(sx, y, 1)
    else Dr.tree(sx, y, 0.9, t, dd.kind == "pine" and "pine" or nil) end
end

function Kit.drawDrive(d)
    local t, cam = d.t, d.x
    Kit.sky(d.theme, t)
    Kit.clouds(t, cam)
    Kit.hills(cam, 220, d.theme == "forest" and Dr.hex(0x8FCB74) or nil)
    for _, dd in ipairs(d.deco) do
        local sx = dd.x - cam * 0.85
        if sx > -120 and sx < Dr.W + 120 then drawDeco(dd, sx, t) end
    end
    -- дорога
    Dr.color(C.roadD); lg.rectangle("fill", 0, 296, Dr.W, 150)
    Dr.color(C.road); lg.rectangle("fill", 0, 302, Dr.W, 138)
    Dr.color(C.line)
    for k = -1, 12 do
        local x = k * 80 - cam % 80
        lg.rectangle("fill", x, 362, 44, 6, 3, 3)
    end
    Dr.color(C.grass); lg.rectangle("fill", 0, 440, Dr.W, 40)
    -- ціль у кінці
    if d.goal then d.goal(d.length - cam + 120, 300, t) end
    -- зірочки й перешкоди
    for _, it in ipairs(d.items) do
        local sx, sy = it.x - cam, LANES[it.lane]
        if not it.taken and sx > -40 and sx < Dr.W + 40 then
            if it.kind == "star" then
                Dr.star(sx, sy - 50 + math.sin(t * 4 + it.x) * 5, 16, C.gold, 1, math.sin(t * 2 + it.x) * 0.3)
            elseif it.kind == "puddle" then
                Dr.ellipse(sx, sy, 40, 10, C.water, 0.9)
            else
                Dr.shadow(sx, sy, 20, 5)
                Dr.poly({ sx - 16, sy, sx + 16, sy, sx + 4, sy - 40, sx - 4, sy - 40 }, C.orange)
                Dr.rrect(sx - 11, sy - 24, 22, 7, 3, C.white, 1, true)
            end
        end
    end
    local bob = d.wob > 0 and math.abs(math.sin(d.wob * 20)) * 10 or 0
    Ve.draw(d.vehicle, 160, d.ly - bob, 0.8, t, { siren = true, speed = d.speed / 15 })
    Kit.progress(d.x / (d.length - 160), d.vehicle)
    Kit.starCount(d.got, d.total)
end

-- ---------- Табло ----------

-- смужка «скільки ще їхати»: машинка рухається до прапорця
function Kit.progress(p, vehicle)
    p = math.max(0, math.min(1, p))
    Dr.rrect(170, 18, 300, 16, 8, C.white, 0.85)
    Dr.rrect(172, 20, 296 * p, 12, 6, C.green, 1, true)
    Dr.circle(470, 26, 12, C.red)
    Dr.star(470, 26, 7, C.white)
    Dr.circle(172 + 296 * p, 26, 13, Ve.TEAM[vehicle].color)
end

function Kit.starCount(got, total)
    Dr.rrect(14, 12, 110, 40, 16, C.panel)
    Dr.star(40, 32, 13, C.gold)
    Dr.number(got .. (total and ("/" .. total) or ""), 84, 18, 22, C.dark)
end

-- ---------- Капітан Бобер по рації ----------

function Kit.drawChief(x, y, s, t, talking)
    s = s or 1
    Dr.rrect(x - 60 * s, y - 60 * s, 120 * s, 120 * s, 26 * s, C.blue)
    Dr.rrect(x - 52 * s, y - 52 * s, 104 * s, 104 * s, 20 * s, C.glass, 1, true)
    local bob = talking and math.abs(math.sin(t * 12)) * 3 or 0
    Dr.animal("beaver", x, y + 10 * s - bob, 1.1 * s, t, "happy", "captain")
    -- антена рації
    Dr.line(C.dark, 4 * s, x + 46 * s, y - 60 * s, x + 56 * s, y - 92 * s)
    Dr.circle(x + 56 * s, y - 94 * s, 6 * s, C.red, 0.5 + 0.5 * math.sin(t * 8))
end

-- звірятко дякує (у кінці місії)
function Kit.thanks(kind, x, y, t)
    Dr.shadow(x, y + 34, 30, 8)
    Dr.animal(kind, x, y - math.abs(math.sin(t * 5)) * 12, 1.2, t, "happy")
    Dr.heart(x + 34, y - 48 - (t * 30) % 30, 9, C.red, 1 - ((t * 30) % 30) / 30)
end

return Kit
