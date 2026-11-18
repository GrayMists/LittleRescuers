-- Поліція 1: «Загублене цуценя». Вигляд зверху: їдемо дорогами за слідами лапок,
-- знаходимо цуценя за кущем і відвозимо додому до мами (будиночок із серденьком).
local Dr = require("core.draw")
local In = require("core.input")
local Snd = require("core.sound")
local Fx = require("core.fx")
local PK = require("missions.police_kit")
local lg = love.graphics
local C = Dr.C

local M = {
    id = "police1", vehicle = "police", rescued = "dog",
    intro = "police1_intro",
    icon = function(x, y, s, t)
        PK.bush(x + 14 * s, y + 14 * s, 20 * s)
        Dr.animal("dog", x - 4 * s, y - 6 * s, 0.75 * s, t, "sad")
        PK.paw(x - 34 * s, y + 34 * s, -0.6, 0.9 * s, C.gold, 1)
        PK.paw(x - 10 * s, y + 42 * s, -0.2, 0.9 * s, C.gold, 1)
    end,
}

-- сітка доріг
local GX = { 160, 480, 800, 1120, 1440 }
local GY = { 160, 400, 640, 880, 1120 }
local HW = 36
local WW, WH = 1600, 1280
local SPEED = 175

local ROUTE = { { 160, 1120 }, { 160, 880 }, { 800, 880 }, { 800, 640 }, { 1120, 640 }, { 1120, 400 }, { 1440, 400 }, { 1440, 238 } }
local BACK = { { 1440, 238 }, { 1440, 400 }, { 320, 400 } }
local PUP = { 1384, 240 }
local BUSH = { 1394, 232 }
local HOME = { 320, 400 }

local function onRoad(x, y)
    local m = HW - 8
    if x >= GX[1] - HW and x <= GX[#GX] + HW then
        for _, g in ipairs(GY) do if math.abs(y - g) <= m then return true end end
    end
    if y >= GY[1] - HW and y <= GY[#GY] + HW then
        for _, g in ipairs(GX) do if math.abs(x - g) <= m then return true end end
    end
    return false
end

local function nearest(list, v)
    local best = list[1]
    for _, g in ipairs(list) do if math.abs(g - v) < math.abs(best - v) then best = g end end
    return best
end

local function clamp(v, a, b) return math.max(a, math.min(b, v)) end

-- прикраси кварталів (дерева, будинки, ставок), детерміновано
local function buildDecor()
    local out = {}
    local rnd = love.math.newRandomGenerator(5)
    local roofs = { C.red, C.blue, C.purple, C.orange, C.pink, C.green }
    local function roof() return roofs[rnd:random(#roofs)] end
    for i = 1, 4 do
        for j = 1, 4 do
            local x0, y0 = GX[i] + HW + 14, GY[j] + HW + 14
            local style = rnd:random(1, 3)
            if i == 4 and j == 1 then
                for _, p in ipairs({ { 1190, 215, 24 }, { 1250, 330, 28 }, { 1330, 345, 22 }, { 1200, 320, 20 }, { 1300, 220, 22 } }) do
                    table.insert(out, { k = "tree", x = p[1], y = p[2], r = p[3] })
                end
            elseif i == 1 and j == 1 then
                table.insert(out, { k = "tree", x = 200, y = 230, r = 24 })
                table.insert(out, { k = "tree", x = 430, y = 235, r = 22 })
                table.insert(out, { k = "bush", x = 215, y = 330, r = 14 })
                table.insert(out, { k = "bush", x = 430, y = 335, r = 14 })
            elseif style == 1 then
                table.insert(out, { k = "house", x = x0 + 4, y = y0 + 12, w = 84, h = 62, c = roof() })
                table.insert(out, { k = "house", x = x0 + 128, y = y0 + 12, w = 84, h = 62, c = roof() })
                table.insert(out, { k = "tree", x = x0 + 40, y = y0 + 118, r = 20 })
                table.insert(out, { k = "tree", x = x0 + 170, y = y0 + 116, r = 22 })
                table.insert(out, { k = "bush", x = x0 + 108, y = y0 + 120, r = 12 })
            elseif style == 2 then
                table.insert(out, { k = "pond", x = x0 + 110, y = y0 + 74, rx = 62, ry = 34 })
                table.insert(out, { k = "tree", x = x0 + 24, y = y0 + 28, r = 22 })
                table.insert(out, { k = "tree", x = x0 + 200, y = y0 + 26, r = 20 })
                table.insert(out, { k = "tree", x = x0 + 30, y = y0 + 120, r = 20 })
                table.insert(out, { k = "tree", x = x0 + 196, y = y0 + 120, r = 22 })
            else
                table.insert(out, { k = "house", x = x0 + 60, y = y0 + 20, w = 110, h = 70, c = roof() })
                table.insert(out, { k = "bush", x = x0 + 20, y = y0 + 60, r = 13 })
                table.insert(out, { k = "bush", x = x0 + 205, y = y0 + 64, r = 13 })
                table.insert(out, { k = "tree", x = x0 + 40, y = y0 + 124, r = 20 })
                table.insert(out, { k = "tree", x = x0 + 180, y = y0 + 124, r = 18 })
            end
        end
    end
    return out
end

local function drawWorld(decor, t, cx, cy)
    Dr.color(C.grass); lg.rectangle("fill", 0, 0, WW, WH)
    -- квартали: трохи світліша трава
    for i = 1, 4 do
        for j = 1, 4 do
            Dr.color(C.grassD, 0.25)
            lg.rectangle("fill", GX[i] + HW + 10, GY[j] + HW + 10, GX[i + 1] - GX[i] - 2 * HW - 20, GY[j + 1] - GY[j] - 2 * HW - 20, 16, 16)
        end
    end
    -- дороги: тротуар, асфальт, розмітка
    local sw = Dr.hex(0xE9E0C8)
    for _, g in ipairs(GY) do
        Dr.color(sw); lg.rectangle("fill", GX[1] - HW - 7, g - HW - 7, GX[#GX] - GX[1] + 2 * HW + 14, 2 * HW + 14, 10, 10)
    end
    for _, g in ipairs(GX) do
        Dr.color(sw); lg.rectangle("fill", g - HW - 7, GY[1] - HW - 7, 2 * HW + 14, GY[#GY] - GY[1] + 2 * HW + 14, 10, 10)
    end
    for _, g in ipairs(GY) do
        Dr.color(C.road); lg.rectangle("fill", GX[1] - HW, g - HW, GX[#GX] - GX[1] + 2 * HW, 2 * HW)
    end
    for _, g in ipairs(GX) do
        Dr.color(C.road); lg.rectangle("fill", g - HW, GY[1] - HW, 2 * HW, GY[#GY] - GY[1] + 2 * HW)
    end
    Dr.color(C.line)
    for _, g in ipairs(GY) do
        for x = GX[1] + HW + 10, GX[#GX] - HW - 30, 56 do
            local near = false
            for _, gx in ipairs(GX) do if math.abs(x + 14 - gx) < HW + 16 then near = true end end
            if not near and x > cx - 40 and x < cx + 700 then lg.rectangle("fill", x, g - 3, 28, 6, 3, 3) end
        end
    end
    for _, g in ipairs(GX) do
        for y = GY[1] + HW + 10, GY[#GY] - HW - 30, 56 do
            local near = false
            for _, gy in ipairs(GY) do if math.abs(y + 14 - gy) < HW + 16 then near = true end end
            if not near and y > cy - 40 and y < cy + 520 then lg.rectangle("fill", g - 3, y, 6, 28, 3, 3) end
        end
    end
    for _, d in ipairs(decor) do
        if d.x > cx - 150 and d.x < cx + 800 and d.y > cy - 150 and d.y < cy + 620 then
            if d.k == "house" then PK.house(d.x, d.y, d.w, d.h, d.c)
            elseif d.k == "tree" then PK.tree(d.x, d.y, d.r)
            elseif d.k == "bush" then PK.bush(d.x, d.y, d.r)
            elseif d.k == "pond" then
                Dr.ellipse(d.x, d.y, d.rx, d.ry, C.water)
                Dr.ellipse(d.x - 16, d.y - 8, d.rx * 0.4, d.ry * 0.25, C.foam, 0.6, true)
            end
        end
    end
end

local function drawHome(t, hot)
    -- будиночок з серденьком, мама-собачка біля дверей
    PK.house(268, 214, 104, 76, C.pink)
    Dr.rrect(308, 280, 24, 14, 4, C.brown)
    Dr.circle(320, 394, 44 + math.sin(t * 5) * 3, C.yellow, hot and 0.35 or 0.18, true)
    Dr.circle(320, 394, 30, C.white, hot and 0.5 or 0.25, true)
    local by = math.sin(t * 4) * 6
    Dr.circle(320, 180 + by, 30, C.white, 0.9, true)
    Dr.heart(320, 184 + by, 20, C.red)
end

function M.new()
    local o = { t = 0, phase = "search", x = ROUTE[1][1], y = ROUTE[1][2], ang = -math.pi / 2, v = 0, idle = 0,
        got = 0, total = 0, prints = {}, decor = buildDecor(), hinted = false, tt = 0, wp = 2 }
    -- сліди лапок уздовж маршруту
    local dist, side = 80, 1
    local acc = 0
    for k = 1, #ROUTE - 1 do
        local a, b = ROUTE[k], ROUTE[k + 1]
        local len = math.abs(b[1] - a[1]) + math.abs(b[2] - a[2])
        local ux, uy = (b[1] - a[1]) / len, (b[2] - a[2]) / len
        local d = dist - acc
        while d < len - 20 do
            local px, py = a[1] + ux * d - uy * 9 * side, a[2] + uy * d + ux * 9 * side
            table.insert(o.prints, { x = px, y = py, ang = math.atan2(uy, ux), taken = false })
            side = -side
            d = d + dist
        end
        acc = len - (d - dist)
    end
    o.total = #o.prints

    local function move(dx, dy, dt)
        local sp = SPEED * dt
        local moved = false
        if dx ~= 0 then
            local g = nearest(GY, o.y)
            if math.abs(g - o.y) < 46 then o.y = o.y + clamp(g - o.y, -sp, sp) end
            if onRoad(o.x + dx * sp, o.y) then o.x = o.x + dx * sp; moved = true end
        end
        if not moved and dy ~= 0 then
            local g = nearest(GX, o.x)
            if math.abs(g - o.x) < 46 then o.x = o.x + clamp(g - o.x, -sp, sp) end
            if onRoad(o.x, o.y + dy * sp) then o.y = o.y + dy * sp; moved = true end
        end
        return moved
    end

    function o.update(dt)
        o.t = o.t + dt
        local dx, dy = In.axis()
        local driving = (o.phase == "search" or o.phase == "home")
        local moving = false
        if driving and (dx ~= 0 or dy ~= 0) then
            local ox, oy = o.x, o.y
            moving = move(dx, dy, dt)
            if moving then
                local mx, my = o.x - ox, o.y - oy
                if math.abs(mx) + math.abs(my) > 0.01 then
                    local want = math.atan2(my, mx)
                    local diff = (want - o.ang + math.pi) % (math.pi * 2) - math.pi
                    o.ang = o.ang + diff * math.min(1, dt * 12)
                end
            end
        end
        o.v = moving and SPEED or 0
        Snd.loop("engine", moving, 0.25)
        o.idle = (driving and not moving) and o.idle + dt or 0
        if o.idle > 5 and not o.hinted then o.hinted = true; Snd.voice("police1_hint") end
        if moving then o.hinted = false end

        if o.phase == "search" then
            for _, p in ipairs(o.prints) do
                if not p.taken and (p.x - o.x) ^ 2 + (p.y - o.y) ^ 2 < 48 ^ 2 then
                    p.taken = true
                    o.got = o.got + 1
                    Snd.play("ding")
                    Fx.burst("spark", p.x, p.y, 6, 110, 0.6, 7)
                end
            end
            local near = (PUP[1] - o.x) ^ 2 + (PUP[2] - o.y) ^ 2
            if near < 90 ^ 2 then
                o.phase, o.tt = "found", 0
                Snd.play("pop")
                Snd.voice("police1_found")
            end
        elseif o.phase == "found" then
            o.tt = o.tt + dt
            if o.tt > 1.4 then o.phase, o.tt, o.wp, o.idle = "home", 0, 2, 0 end
        elseif o.phase == "home" then
            if (HOME[1] - o.x) ^ 2 + (HOME[2] - o.y) ^ 2 < 55 ^ 2 then
                o.phase, o.tt = "arrive", 0
                Snd.loop("engine", false)
            end
        elseif o.phase == "arrive" then
            local was = o.tt
            o.tt = o.tt + dt
            if was < 1.1 and o.tt >= 1.1 then
                Snd.play("cheer")
                Snd.voice("police1_done")
                Fx.burst("confetti", 320, 320, 50, 260, 2.5, 12)
                for k = 1, 4 do Fx.add("spark", 300 + k * 10, 330, (k - 2.5) * 30, -70, 1.2, 9) end
            end
            return o.tt > 4.2
        end
        return false
    end

    -- цуценя: де воно зараз (світові координати) і висота стрибка
    local function puppyPos()
        if o.phase == "search" then return PUP[1], PUP[2], 0, 0
        elseif o.phase == "found" then
            local k = math.min(1, o.tt / 0.9)
            return PUP[1] + (o.x - PUP[1]) * k, PUP[2] + (o.y - PUP[2]) * k, math.sin(k * math.pi) * 40, k
        elseif o.phase == "arrive" then
            local k = math.min(1, o.tt / 1.0)
            return o.x + (320 - o.x) * k, o.y + (350 - o.y) * k, math.sin(k * math.pi) * 40, k
        end
        return 320, 350, 0, 1
    end

    function o.draw()
        local t = o.t
        local cx = clamp(o.x - 320, 0, WW - 640)
        local cy = clamp(o.y - 240, 0, WH - 480)
        lg.push()
        lg.translate(-cx, -cy)
        drawWorld(o.decor, t, cx, cy)
        drawHome(t, o.phase == "home" or o.phase == "arrive")
        -- сліди
        local nextP
        for _, p in ipairs(o.prints) do
            if not p.taken then
                nextP = nextP or p
                if p.x > cx - 40 and p.x < cx + 680 and p.y > cy - 40 and p.y < cy + 520 then
                    local pulse = 0.5 + 0.5 * math.sin(t * 4 + p.x * 0.05)
                    Dr.circle(p.x, p.y, 20 + pulse * 6, C.yellow, 0.25 + 0.15 * pulse, true)
                    PK.paw(p.x, p.y, p.ang, 1.15, C.gold, 1)
                    PK.paw(p.x, p.y, p.ang, 0.7, C.white, 0.5)
                end
            end
        end
        -- цуценя за кущем
        local px, py, pz, k = puppyPos()
        if o.phase == "search" then
            local shake = ((o.x - PUP[1]) ^ 2 + (o.y - PUP[2]) ^ 2 < 260 ^ 2) and math.sin(t * 30) * 1.5 or 0
            Dr.animal("dog", PUP[1] + 4, PUP[2] - 12, 0.5, t, "sad")
            PK.bush(BUSH[1] + shake, BUSH[2], 20)
        end
        -- машина
        PK.car(o.x, o.y, o.ang, 1, t, { kind = "police", siren = true,
            pass = (o.phase == "home") and "dog" or (o.phase == "found" and k > 0.9) and "dog" or nil })
        if o.phase == "found" and k < 0.9 or o.phase == "arrive" then
            Dr.shadow(px, py + 14, 14, 5)
            Dr.animal("dog", px, py - pz - 8, 0.5, t, "happy")
        end
        if o.phase == "arrive" then
            Dr.animal("dog", 322, 336, 0.62, t, "happy")
            if o.tt > 1.1 then
                for h = 0, 2 do Dr.heart(300 + h * 22, 296 - ((o.tt * 40 + h * 14) % 40), 9, C.red, 1 - ((o.tt * 40 + h * 14) % 40) / 40) end
            end
        elseif o.phase ~= "search" then
            Dr.animal("dog", 322, 336, 0.62, t, "happy")
        end
        Fx.draw()
        lg.pop()

        -- підказка-стрілка до наступного сліду / до дому
        local tx, ty
        if o.phase == "search" and o.idle > 2 and nextP then tx, ty = nextP.x, nextP.y
        elseif o.phase == "home" then tx, ty = HOME[1], HOME[2] end
        if tx then
            local a = math.atan2(ty - o.y, tx - o.x)
            local sx, sy = o.x - cx, o.y - cy
            PK.pointer(sx + math.cos(a) * 62, sy + math.sin(a) * 62, a, 0.9, C.yellow, t)
        end
        -- табло
        Dr.rrect(14, 12, 122, 40, 16, C.panel)
        if o.phase == "search" or o.phase == "found" then
            PK.paw(38, 30, 0, 1.1, C.brown, 1)
            Dr.number(o.got .. "/" .. o.total, 92, 18, 22, C.dark)
        else
            Dr.heart(40, 22, 14, C.red)
            Dr.circle(100, 32, 14, C.green, 1, true)
            Dr.star(100, 32, 8, C.white)
        end
    end

    function o.stars()
        return (o.got >= o.total * 0.6) and 3 or 2
    end

    function o.bot()
        for _, n in ipairs({ "left", "right", "up", "down" }) do In.release(n) end
        if o.phase ~= "search" and o.phase ~= "home" then return end
        local list = (o.phase == "search") and ROUTE or BACK
        local w = list[o.wp]
        if not w then return end
        local ex, ey = w[1] - o.x, w[2] - o.y
        if math.abs(ex) < 8 and math.abs(ey) < 8 then o.wp = o.wp + 1; return end
        if math.abs(ex) > 6 then In.press(ex > 0 and "right" or "left") else In.press(ey > 0 and "down" or "up") end
    end

    function o.leave() Snd.loop("engine", false) end

    return o
end

return M
