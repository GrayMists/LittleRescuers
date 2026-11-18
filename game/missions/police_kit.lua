-- Спільні шматки поліцейських місій: машинки зверху, лапки, будинки й дерева зверху,
-- хрестовина-підказка, торт, повзучий переїзд зі «скриньками» для police3.
local Dr = require("core.draw")
local Ve = require("core.vehicles")
local Kit = require("missions.kit")
local lg = love.graphics
local C = Dr.C

local PK = {}

-- ---------- Машинки зверху ----------
-- Дивляться праворуч (ang = 0). kind: "police" | "car" | "bus" | "ambulance".
-- o: { color, driver = "bunny"|..., siren = true, pass = "dog" (пасажир-голівка), cap = true }
local HEADS = {
    bunny = { C.white, 1 }, dog = { Dr.hex(0xC8925E), 2 }, duck = { C.yellow, 0 }, cat = { Dr.hex(0xFFB65C), 0 },
    bear = { Dr.hex(0x9C6B45), 0 }, fox = { Dr.hex(0xFF8A3D), 0 }, pig = { C.pink, 0 }, hedgehog = { Dr.hex(0xB28A62), 0 },
}

local function head(kind, x, y, r, cap)
    local h = HEADS[kind] or HEADS.cat
    if kind == "bunny" then
        for side = -1, 1, 2 do
            Dr.ellipse(x - r * 1.2, y + side * r * 0.55, r * 0.9, r * 0.32, h[1])
            Dr.ellipse(x - r * 1.2, y + side * r * 0.55, r * 0.55, r * 0.15, C.pink, 1, true)
        end
    elseif kind == "dog" then
        for side = -1, 1, 2 do Dr.ellipse(x - r * 0.2, y + side * r * 0.95, r * 0.45, r * 0.3, Dr.shade(h[1], -0.25)) end
    elseif kind == "fox" or kind == "cat" then
        for side = -1, 1, 2 do Dr.circle(x - r * 0.3, y + side * r * 0.8, r * 0.38, h[1]) end
    end
    Dr.circle(x, y, r, h[1])
    Dr.circle(x + r * 0.45, y - r * 0.38, r * 0.17, C.dark, 1, true)
    Dr.circle(x + r * 0.45, y + r * 0.38, r * 0.17, C.dark, 1, true)
    Dr.circle(x + r * 0.9, y, r * 0.2, kind == "duck" and C.orange or C.dark, 1, true)
    if cap then Dr.circle(x - r * 0.1, y, r * 0.6, C.blue, 1, true) Dr.circle(x + r * 0.1, y, r * 0.2, C.gold, 1, true) end
end
PK.head = head

local function wheels(hl, hw, r)
    for _, sx in ipairs({ -hl * 0.58, hl * 0.58 }) do
        for _, sy in ipairs({ -hw, hw }) do Dr.rrect(sx - r, sy - r * 0.45 + (sy > 0 and r * 0.3 or -r * 0.3), r * 2, r * 0.9, 3, C.dark) end
    end
end

local function lamps(hl, hw)
    Dr.circle(hl - 2, -hw * 0.6, 3.5, C.yellow, 1, true)
    Dr.circle(hl - 2, hw * 0.6, 3.5, C.yellow, 1, true)
    Dr.circle(-hl + 2, -hw * 0.6, 3, C.red, 1, true)
    Dr.circle(-hl + 2, hw * 0.6, 3, C.red, 1, true)
end

function PK.car(x, y, ang, s, t, o)
    o = o or {}
    s = s or 1
    local kind = o.kind or "car"
    local hl, hw = 32, 15
    if kind == "bus" then hl, hw = 56, 17 elseif kind == "ambulance" then hl, hw = 38, 16 end
    local ca, sa = math.abs(math.cos(ang)), math.abs(math.sin(ang))
    Dr.shadow(x + 3, y + 5, (hl * ca + hw * sa + 6) * s, (hl * sa + hw * ca + 6) * s, 0.25)
    lg.push()
    lg.translate(x, y)
    lg.rotate(ang)
    lg.scale(s, s)
    wheels(hl, hw, 7)
    local ph = math.floor(t * 6) % 2
    if kind == "police" then
        Dr.rrect(-hl, -hw, hl * 2, hw * 2, 9, C.white)
        Dr.rrect(-hl + 3, -hw + 3, 9, hw * 2 - 6, 4, C.blue, 1, true)
        Dr.rrect(hl - 18, -hw + 3, 9, hw * 2 - 6, 4, C.glass)
        Dr.rrect(-hl + 14, -hw + 3, 6, hw * 2 - 6, 3, C.glass, 0.9)
        lamps(hl, hw)
        head(o.driver or "bunny", 2, o.pass and 6 or 0, 8, o.cap ~= false)
        if o.pass then head(o.pass, 2, -7, 7) end
        local on = o.siren ~= false
        Dr.rrect(-14, -hw + 2, 7, hw - 2, 3, on and ph == 0 and C.red or Dr.shade(C.red, -0.45))
        Dr.rrect(-14, 0, 7, hw - 2, 3, on and ph == 1 and C.blue or Dr.shade(C.blue, -0.45))
        if on then
            Dr.color(ph == 0 and C.red or C.blue, 0.2)
            lg.circle("fill", -10, ph == 0 and -hw / 2 or hw / 2, 17, 20)
        end
    elseif kind == "bus" then
        Dr.rrect(-hl, -hw, hl * 2, hw * 2, 10, o.color or C.yellow)
        for k = 0, 4 do
            local wx = -hl + 10 + k * 20
            Dr.rrect(wx, -hw + 3, 15, 8, 3, C.glass)
            Dr.rrect(wx, hw - 11, 15, 8, 3, C.glass)
        end
        Dr.rrect(hl - 14, -hw + 3, 9, hw * 2 - 6, 3, C.glass)
        -- каченята-пасажири на даху (видно голівки)
        for k = 0, 3 do head("duck", -hl + 16 + k * 22, (k % 2 == 0) and -4 or 4, 6) end
        Dr.rrect(-hl + 4, -2, hl * 2 - 20, 4, 2, Dr.shade(o.color or C.yellow, -0.2), 1, true)
        lamps(hl, hw)
    elseif kind == "ambulance" then
        Dr.rrect(-hl, -hw, hl * 2, hw * 2, 9, C.white)
        Dr.rrect(hl - 18, -hw + 3, 10, hw * 2 - 6, 4, C.glass)
        Dr.rrect(-6, -9, 18, 18, 3, C.red, 1, true)
        Dr.rrect(-2, -9, 10, 18, 2, C.white, 1, true)
        Dr.rrect(-6, -3, 18, 6, 2, C.white, 1, true)
        Dr.rrect(-hl + 4, -hw + 1, 14, 6, 3, ph == 0 and C.red or Dr.shade(C.red, -0.4))
        Dr.rrect(-hl + 4, hw - 7, 14, 6, 3, ph == 1 and C.blue or Dr.shade(C.blue, -0.4))
        Dr.color(ph == 0 and C.red or C.blue, 0.22)
        lg.circle("fill", -hl + 10, ph == 0 and -hw + 4 or hw - 4, 14, 20)
        lamps(hl, hw)
        head(o.driver or "pig", hl - 24, 0, 7)
    else
        local col = o.color or C.red
        Dr.rrect(-hl, -hw, hl * 2, hw * 2, 9, col)
        Dr.rrect(hl - 22, -hw + 3, 11, hw * 2 - 6, 4, C.glass)
        Dr.rrect(-hl + 8, -hw + 3, 8, hw * 2 - 6, 3, C.glass, 0.9)
        Dr.rrect(-hl + 14, -hw + 5, hl * 2 - 38, hw * 2 - 10, 6, Dr.shade(col, 0.22), 1, true)
        lamps(hl, hw)
        head(o.driver or "cat", hl - 28, 0, 7)
    end
    lg.pop()
end

-- ---------- Лапка (слід) ----------
function PK.paw(x, y, ang, s, c, a)
    lg.push()
    lg.translate(x, y)
    lg.rotate(ang)
    lg.scale(s, s)
    Dr.color(c, a)
    lg.ellipse("fill", 0, 3, 9, 7.5, 16)
    for k = -1.5, 1.5 do lg.circle("fill", 10 - math.abs(k) * 2.2, k * 6.5, 3.6, 10) end
    lg.pop()
end

-- ---------- Місто зверху ----------
function PK.house(x, y, w, h, roof)
    Dr.shadow(x + w / 2 + 4, y + h / 2 + 6, w * 0.6, h * 0.55, 0.22)
    Dr.rrect(x, y, w, h, 8, roof)
    Dr.rrect(x + 3, y + 3, w - 6, h / 2 - 3, 6, Dr.shade(roof, 0.25), 1, true)
    Dr.line(Dr.shade(roof, -0.35), 3, x + 6, y + h / 2, x + w - 6, y + h / 2)
    Dr.rrect(x + w * 0.68, y + 7, 11, 11, 2, C.grey)
end

function PK.tree(x, y, r)
    Dr.shadow(x + 5, y + 6, r * 1.05, r * 0.85, 0.22)
    Dr.circle(x, y, r, C.green)
    Dr.circle(x - r * 0.28, y - r * 0.3, r * 0.55, Dr.shade(C.green, 0.25), 1, true)
    Dr.circle(x + r * 0.35, y + r * 0.25, r * 0.28, Dr.shade(C.green, -0.15), 1, true)
end

function PK.bush(x, y, r)
    Dr.shadow(x + 4, y + 5, r * 1.3, r * 0.9, 0.2)
    Dr.circle(x - r * 0.55, y + r * 0.1, r * 0.7, C.grassD)
    Dr.circle(x + r * 0.55, y + r * 0.1, r * 0.7, C.grassD)
    Dr.circle(x, y - r * 0.2, r * 0.85, C.green)
    Dr.circle(x - r * 0.25, y - r * 0.45, r * 0.3, Dr.shade(C.green, 0.3), 1, true)
end

-- ---------- Стрілочка-вказівник (будь-який кут) ----------
function PK.pointer(x, y, ang, s, c, t)
    local bob = math.sin((t or 0) * 7) * 4
    lg.push()
    lg.translate(x, y)
    lg.rotate(ang)
    lg.translate(bob, 0)
    lg.scale(s, s)
    Dr.poly({ -14, -9, 2, -9, 2, -17, 22, 0, 2, 17, 2, 9, -14, 9 }, c or C.yellow)
    lg.pop()
end

-- маленька хрестовина, один напрямок підсвічено (dir: "left"|"right"|"up"|"down")
function PK.dpad(x, y, s, dir, t)
    s = s or 1
    local pulse = 0.5 + 0.5 * math.sin((t or 0) * 8)
    Dr.circle(x, y, 40 * s, C.dark, 0.35, true)
    Dr.rrect(x - 14 * s, y - 34 * s, 28 * s, 68 * s, 8 * s, C.grey)
    Dr.rrect(x - 34 * s, y - 14 * s, 68 * s, 28 * s, 8 * s, C.grey)
    Dr.circle(x, y, 9 * s, Dr.shade(C.grey, -0.2), 1, true)
    local v = { left = { -1, 0 }, right = { 1, 0 }, up = { 0, -1 }, down = { 0, 1 } }
    local d = v[dir]
    if d then
        local cx, cy = x + d[1] * 24 * s, y + d[2] * 24 * s
        Dr.circle(cx, cy, 12 * s, C.yellow, 0.6 + 0.4 * pulse, true)
        PK.pointer(cx, cy, math.atan2(d[2], d[1]), 0.5 * s, C.red, t)
    end
end

-- ---------- Торт ----------
function PK.cake(x, y, s, t)
    Dr.shadow(x, y + 4 * s, 40 * s, 8 * s)
    Dr.ellipse(x, y, 44 * s, 10 * s, C.white)
    Dr.rrect(x - 36 * s, y - 28 * s, 72 * s, 28 * s, 8 * s, C.pink)
    Dr.rrect(x - 36 * s, y - 28 * s, 72 * s, 10 * s, 6 * s, C.cream)
    Dr.rrect(x - 26 * s, y - 52 * s, 52 * s, 26 * s, 8 * s, Dr.shade(C.pink, 0.2))
    Dr.rrect(x - 26 * s, y - 52 * s, 52 * s, 9 * s, 6 * s, C.cream)
    for k = -1, 1 do Dr.circle(x + k * 16 * s, y - 56 * s, 5 * s, C.red) end
    Dr.rrect(x - 2 * s, y - 76 * s, 5 * s, 20 * s, 2, C.blue, 1, true)
    Dr.flame(x + 0.5 * s, y - 76 * s, 0.35 * s, t or 0, 1)
end

-- ---------- Переїзд зі скриньками (для police3) ----------
-- Копія Kit.drawDrive, але перешкоди — скриньки, а «зірочки» — крихти торта.
local LANES = { 330, 400 }

local function deco(dd, sx, t)
    local y = 290
    if dd.kind == "house" then Dr.house(sx - 50, y, 100, 70, dd.roof)
    elseif dd.kind == "bush" then Dr.bush(sx, y, 1)
    else Dr.tree(sx, y, 0.9, t, dd.kind == "pine" and "pine" or nil) end
end

function PK.drawChase(d, ahead)
    local t, cam = d.t, d.x
    Kit.sky(d.theme, t)
    Kit.clouds(t, cam)
    Kit.hills(cam, 220)
    for _, dd in ipairs(d.deco) do
        local sx = dd.x - cam * 0.85
        if sx > -120 and sx < Dr.W + 120 then deco(dd, sx, t) end
    end
    Dr.color(C.roadD); lg.rectangle("fill", 0, 296, Dr.W, 150)
    Dr.color(C.road); lg.rectangle("fill", 0, 302, Dr.W, 138)
    Dr.color(C.line)
    for k = -1, 12 do lg.rectangle("fill", k * 80 - cam % 80, 362, 44, 6, 3, 3) end
    Dr.color(C.grass); lg.rectangle("fill", 0, 440, Dr.W, 40)
    if d.goal then d.goal(d.length - cam + 120, 300, t) end
    for _, it in ipairs(d.items) do
        local sx, sy = it.x - cam, LANES[it.lane]
        if not it.taken and sx > -40 and sx < Dr.W + 40 then
            if it.kind == "star" then
                local by = sy - 50 + math.sin(t * 4 + it.x) * 5
                Dr.star(sx, by, 16, C.gold, 1, math.sin(t * 2 + it.x) * 0.3)
                Dr.circle(sx + 12, by + 12, 3, C.pink, 1, true)
                Dr.circle(sx - 13, by + 10, 2.5, C.brown, 1, true)
            else
                Dr.shadow(sx, sy + 2, 26, 6)
                Dr.rrect(sx - 24, sy - 40, 48, 42, 5, C.wood)
                Dr.line(Dr.outlineOf(C.wood), 3, sx - 20, sy - 36, sx + 20, sy - 2)
                Dr.line(Dr.outlineOf(C.wood), 3, sx + 20, sy - 36, sx - 20, sy - 2)
                Dr.rrect(sx - 24, sy - 26, 48, 8, 2, Dr.shade(C.wood, 0.25), 1, true)
            end
        end
    end
    if ahead then ahead(t, cam) end
    local bob = d.wob > 0 and math.abs(math.sin(d.wob * 20)) * 10 or 0
    Ve.draw(d.vehicle, 160, d.ly - bob, 0.8, t, { siren = true, speed = d.speed / 15 })
    Kit.progress(d.x / (d.length - 160), d.vehicle)
    Kit.starCount(d.got, d.total)
end

return PK
