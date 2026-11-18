-- Машини рятувальників (вигляд збоку, дивляться праворуч; flip = -1 — ліворуч).
-- Ve.draw(kind, x, y, s, t, opt): x, y — точка на землі/воді під серединою машини.
-- opt: { siren = true, flip = -1, rotor = true, driver = true, ladder = 0..1 }
local Dr = require("core.draw")
local lg = love.graphics
local C = Dr.C

local Ve = {}

-- Команда: хто кермує якою машиною
Ve.TEAM = {
    fire = { animal = "dog", hat = "fire", color = C.red },
    police = { animal = "bunny", hat = "police", color = C.blue },
    heli = { animal = "fox", hat = "pilot", color = C.yellow },
    boat = { animal = "bear", hat = "sailor", color = C.orange },
}

local function wheel(x, y, r, t, speed)
    Dr.circle(x, y, r, C.dark)
    Dr.circle(x, y, r * 0.5, C.grey)
    local a = (t or 0) * (speed or 0)
    lg.setColor(1, 1, 1, 0.6)
    lg.setLineWidth(2)
    lg.line(x + math.cos(a) * r * 0.45, y + math.sin(a) * r * 0.45, x - math.cos(a) * r * 0.45, y - math.sin(a) * r * 0.45)
end

-- мигалка: два кольори по черзі
local function siren(x, y, t, c1, c2, on)
    local ph = on and (math.floor(t * 6) % 2) or -1
    Dr.rrect(x - 14, y - 8, 14, 9, 4, ph == 0 and c1 or Dr.shade(c1, -0.3))
    Dr.rrect(x, y - 8, 14, 9, 4, ph == 1 and c2 or Dr.shade(c2, -0.3))
    if on then
        local c = ph == 0 and c1 or c2
        Dr.color(c, 0.25)
        lg.circle("fill", x + (ph == 0 and -7 or 7), y - 4, 22, 24)
    end
end

local function driver(kind, x, y, s, t)
    local tm = Ve.TEAM[kind]
    Dr.animal(tm.animal, x, y, 0.55 * s, t, "happy", tm.hat)
end

local draw = {}

function draw.fire(t, o)
    Dr.shadow(0, 2, 95, 10)
    -- драбина на даху
    local lad = o.ladder or 0
    lg.push()
    lg.translate(-60, -78)
    lg.rotate(-lad * 0.9)
    Dr.rrect(0, -6, 110 + lad * 60, 12, 5, C.grey)
    for k = 0, 6 + math.floor(lad * 4) do Dr.line(Dr.outlineOf(C.grey), 2, 10 + k * 15, -5, 10 + k * 15, 5) end
    lg.pop()
    Dr.rrect(-90, -72, 120, 54, 12, C.red)                -- кузов
    Dr.rrect(26, -84, 60, 66, 16, C.red)                  -- кабіна
    Dr.rrect(40, -76, 38, 26, 9, C.glass)                 -- вікно
    lg.setColor(1, 1, 1, 0.5); lg.rectangle("fill", 46, -72, 8, 18, 3, 3)
    driver("fire", 58, -62, 1, t)
    Dr.rrect(40, -76, 38, 26, 9, C.glass, 0.25)
    Dr.rrect(-84, -50, 104, 8, 4, C.white, 1, true)       -- біла смуга
    for k = 0, 2 do Dr.rrect(-80 + k * 34, -66, 26, 14, 5, C.redD) end   -- дверцята шаф
    Dr.rrect(80, -40, 12, 14, 4, C.yellow)               -- фара
    siren(56, -84, t, C.red, C.yellow, o.siren)
    -- шланг збоку
    Dr.circle(-30, -30, 9, C.yellow)
    wheel(-60, -14, 15, t, o.speed)
    wheel(52, -14, 15, t, o.speed)
end

function draw.police(t, o)
    Dr.shadow(0, 2, 80, 9)
    Dr.poly({ -76, -16, -76, -46, -40, -50, -18, -78, 34, -78, 54, -50, 80, -44, 80, -16 }, C.white)
    Dr.rrect(-76, -40, 156, 14, 4, C.blue, 1, true)
    Dr.poly({ -12, -50, -2, -72, 22, -72, 22, -50 }, C.glass)
    Dr.poly({ 28, -50, 28, -72, 32, -72, 46, -50 }, C.glass)
    driver("police", 10, -58, 1, t)
    Dr.poly({ -12, -50, -2, -72, 22, -72, 22, -50 }, C.glass, 0.25)
    Dr.star(-44, -33, 8, C.gold)
    Dr.rrect(70, -40, 12, 10, 4, C.yellow)
    siren(8, -78, t, C.blue, C.red, o.siren)
    wheel(-46, -14, 15, t, o.speed)
    wheel(48, -14, 15, t, o.speed)
end

function draw.boat(t, o)
    local rock = math.sin(t * 2.2) * 0.04
    lg.rotate(rock)
    Dr.poly({ -92, -34, 96, -34, 70, 6, -76, 6 }, C.orange)
    Dr.rrect(-80, -30, 160, 9, 4, C.white, 1, true)
    Dr.rrect(-30, -84, 64, 52, 12, C.white)
    Dr.rrect(-20, -76, 44, 22, 8, C.glass)
    driver("boat", 2, -62, 1, t)
    Dr.rrect(-20, -76, 44, 22, 8, C.glass, 0.25)
    -- рятувальний круг
    Dr.circle(-58, -48, 13, C.red)
    Dr.circle(-58, -48, 6, C.water, 1, false)
    siren(2, -84, t, C.orange, C.yellow, o.siren)
    -- піна біля носа
    lg.setColor(1, 1, 1, 0.8)
    for k = 0, 3 do lg.circle("fill", 80 - k * 8 + math.sin(t * 6 + k) * 3, 4, 6 - k, 12) end
end

function draw.heli(t, o)
    local hover = math.sin(t * 3) * 3
    lg.translate(0, hover)
    Dr.shadow(0, 2 - hover + (o.alt or 0), 70 * (o.shadowK or 1), 8 * (o.shadowK or 1), 0.15)
    -- хвіст
    Dr.poly({ -30, -70, -120, -78, -120, -64, -30, -50 }, C.yellow)
    Dr.circle(-118, -72, 14, C.red, 0.4 + 0.6 * math.abs(math.sin(t * 30)))
    Dr.rrect(-50, -110, 110, 66, 32, C.yellow)
    Dr.rrect(14, -102, 40, 36, 16, C.glass)
    driver("heli", 34, -84, 1, t)
    Dr.rrect(14, -102, 40, 36, 16, C.glass, 0.25)
    Dr.rrect(-40, -70, 60, 10, 5, C.red, 1, true)
    -- полози
    Dr.line(C.dark, 4, -30, -44, -36, -26)
    Dr.line(C.dark, 4, 30, -44, 36, -26)
    Dr.rrect(-56, -30, 112, 7, 4, C.dark)
    -- гвинт
    Dr.rrect(-6, -122, 12, 14, 4, C.grey)
    local w = 110 * math.abs(math.cos(t * 25))
    Dr.rrect(-w, -126, w * 2, 6, 3, C.dark, 0.85, true)
    siren(4, -110, t, C.red, C.white, o.siren)
end

function Ve.draw(kind, x, y, s, t, opt)
    opt = opt or {}
    lg.push()
    lg.translate(x, y)
    lg.scale((s or 1) * (opt.flip or 1), s or 1)
    draw[kind](t or 0, opt)
    lg.pop()
end

return Ve
