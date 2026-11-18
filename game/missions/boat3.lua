-- Човен 3: «Маяк згас». Вечірнє море: човен пливе сам, вгору/вниз — пропливай крізь світні кільця буйків.
-- Біля острова: збери три лампочки в пляшках, підпливи до причалу і натисни A — Черепаха-доглядачка
-- вкручує їх, і маяк знову світить, промінь ходить над морем.
local Dr = require("core.draw")
local In = require("core.input")
local Snd = require("core.sound")
local Fx = require("core.fx")
local Kit = require("missions.kit")
local Bk = require("missions.boat_kit")
local lg = love.graphics
local C = Dr.C
local hex = Dr.hex

local LIGHT = hex(0xFFE27A)

local function lighthouse(x, y, s, t, lit, dim)
    -- вежа зі смужками
    local h, wb, wt = 170 * s, 30 * s, 20 * s
    local col = dim and hex(0xC9C4D8) or C.white
    Dr.poly({ x - wb, y, x + wb, y, x + wt, y - h, x - wt, y - h }, col)
    for k = 0, 1 do
        local y1, y2 = y - h * (0.2 + k * 0.38), y - h * (0.38 + k * 0.38)
        local w1 = wb + (wt - wb) * (0.2 + k * 0.38)
        local w2 = wb + (wt - wb) * (0.38 + k * 0.38)
        Dr.poly({ x - w1, y1, x + w1, y1, x + w2, y2, x - w2, y2 }, dim and hex(0x9C5A6A) or C.red, 1, true)
    end
    Dr.rrect(x - 8 * s, y - 34 * s, 16 * s, 34 * s, 6 * s, C.brown)
    -- галерея й ліхтарня
    Dr.rrect(x - 30 * s, y - h - 6 * s, 60 * s, 9 * s, 3 * s, C.dark)
    Dr.rrect(x - 18 * s, y - h - 38 * s, 36 * s, 32 * s, 6 * s, lit and LIGHT or hex(0x4A4F6B))
    if lit then
        for k = 3, 1, -1 do
            lg.setColor(1, 0.92, 0.5, 0.12 + 0.05 * math.sin(t * 4))
            lg.circle("fill", x, y - h - 22 * s, (20 + k * 16) * s, 32)
        end
    end
    Dr.poly({ x - 24 * s, y - h - 38 * s, x + 24 * s, y - h - 38 * s, x, y - h - 62 * s }, dim and hex(0x9C5A6A) or C.red)
    return x, y - h - 22 * s
end

-- пляшка з лампочкою
local function bottle(x, y, s, t, rot)
    lg.push(); lg.translate(x, y); lg.rotate(rot or 0); lg.scale(s, s)
    lg.setColor(1, 0.9, 0.5, 0.25 + 0.1 * math.sin(t * 5))
    lg.circle("fill", 0, 0, 30, 24)
    Dr.ellipse(0, 0, 26, 15, hex(0x7FD6B0), 0.75)
    Dr.rrect(22, -6, 14, 12, 4, hex(0x7FD6B0), 0.75)
    Dr.rrect(34, -5, 8, 10, 3, C.wood)
    Dr.circle(-3, -1, 9, LIGHT, 1)
    Dr.rrect(5, -4, 8, 8, 2, C.grey, 1, true)
    lg.setColor(1, 1, 1, 0.5)
    lg.ellipse("fill", -8, -8, 10, 3, 12)
    lg.pop()
end

local function bulb(x, y, s, t)
    lg.setColor(1, 0.92, 0.5, 0.3 + 0.1 * math.sin(t * 6 + x))
    lg.circle("fill", x, y, 16 * s, 20)
    Dr.circle(x, y, 8 * s, LIGHT)
    Dr.rrect(x - 4 * s, y + 6 * s, 8 * s, 6 * s, 2 * s, C.grey, 1, true)
end

local M = {
    id = "boat3", vehicle = "boat", rescued = "turtle",
    intro = "boat3_intro",
    icon = function(x, y, s, t)
        Dr.ellipse(x, y + 30 * s, 40 * s, 12 * s, hex(0x34457E))
        Dr.ellipse(x, y + 26 * s, 30 * s, 8 * s, hex(0x8C7A5B))
        lighthouse(x, y + 24 * s, 0.32 * s, t, false, true)
        Dr.star(x + 26 * s, y - 34 * s, 5 * s, LIGHT, 0.5 + 0.5 * math.sin(t * 3))
        Dr.star(x - 28 * s, y - 20 * s, 4 * s, LIGHT, 0.5 + 0.5 * math.sin(t * 2 + 1))
    end,
}

local BX = 190
local Y_MIN, Y_MAX = 318, 408
local CAM2 = 4000
local BUOYS = { { 800, 360 }, { 1360, 332 }, { 1920, 396 }, { 2480, 346 }, { 3040, 400 }, { 3600, 352 } }
local BOTTLES = { { 90, 335 }, { 235, 402 }, { 300, 330 } }
local DOCK_X, DOCK_Y = 480, 345
local LH_X, LH_Y = 560, 300

local function mix(a, b, p)
    return { a[1] + (b[1] - a[1]) * p, a[2] + (b[2] - a[2]) * p, a[3] + (b[3] - a[3]) * p, 1 }
end
local NEAR1, NEAR2, FAR1, FAR2 = hex(0x3E5A99), hex(0x263A6E), hex(0x2B4580), hex(0x111D40)

function M.new()
    local o = {
        t = 0, phase = "sail", cam = 0, speed = 0, px = BX, py = 360, vx = 0, vy = 0, idle = 0,
        passed = 0, buoys = {}, bottles = {}, carried = 0, giveT = 0, lit = false, litT = 0, doneT = nil, throw = false,
    }
    for k, b in ipairs(BUOYS) do o.buoys[k] = { x = b[1], y = b[2], state = "wait", flash = 0 } end
    for k, b in ipairs(BOTTLES) do o.bottles[k] = { x = b[1], y = b[2], taken = false, ph = k * 1.7 } end

    local function bs() return 0.74 + (o.py - Y_MIN) / (Y_MAX - Y_MIN) * 0.16 end
    local function nearDock()
        return o.phase == "bay" and o.carried == 3 and o.px > 270 and math.abs(o.py - DOCK_Y) < 50
    end

    function o.press(name)
        if name == "a" then o.throw = true end
    end

    function o.update(dt)
        o.t = o.t + dt
        local t = o.t
        local dx, dy = In.axis()
        if o.phase == "sail" or o.phase == "bay" then
            o.idle = (dx == 0 and dy == 0) and o.idle + dt or 0
            Snd.loop("engine", true, 0.2)
        end
        o.vy = o.vy + (dy * 130 - o.vy) * math.min(1, dt * 6)
        if o.phase == "sail" or o.phase == "bay" then o.py = math.max(Y_MIN, math.min(Y_MAX, o.py + o.vy * dt)) end
        if o.phase == "sail" then
            local target = 150
            if In.down("right") then target = 215 elseif In.down("left") then target = 95 end
            local toStop = CAM2 - o.cam
            if toStop < 320 then target = math.min(target, math.max(25, toStop * 0.8)) end
            o.speed = o.speed + (target - o.speed) * math.min(1, dt * 2.5)
            o.cam = math.min(CAM2, o.cam + o.speed * dt)
            local wx = o.cam + BX
            for _, b in ipairs(o.buoys) do
                if b.state == "wait" then
                    if math.abs(b.x - wx) < 28 and math.abs(b.y - o.py) < 32 then
                        b.state = "ok"; b.flash = 1
                        o.passed = o.passed + 1
                        Snd.play("ding")
                        Fx.burst("spark", b.x - o.cam, b.y - 40, 12, 170, 0.8, 9)
                    elseif wx - b.x > 40 then b.state = "miss" end
                end
                b.flash = math.max(0, b.flash - dt)
            end
            if o.cam >= CAM2 - 0.5 then
                o.phase = "bay"; o.speed = 0
                Snd.voice("boat3_bottles")
            end
        elseif o.phase == "bay" then
            o.vx = o.vx + (dx * 160 - o.vx) * math.min(1, dt * 4)
            o.px = math.max(60, math.min(310, o.px + o.vx * dt))
            for _, b in ipairs(o.bottles) do
                if not b.taken and math.abs(b.x - o.px) < 62 and math.abs(b.y - o.py) < 34 then
                    b.taken = true
                    o.carried = o.carried + 1
                    Snd.play("pop"); Snd.play("splash")
                    Fx.burst("spark", b.x, b.y - 20, 10, 150, 0.7, 8)
                    if o.carried == 3 then Snd.voice("boat3_give") end
                end
            end
            if nearDock() and (o.throw or In.down("a")) then
                o.phase = "give"; o.giveT = 0
                Snd.loop("engine", false)
                Snd.play("whoosh")
            end
        elseif o.phase == "give" then
            o.vx = 0
            o.giveT = o.giveT + dt
            for k = 1, 3 do
                local arrive = 0.5 * (k - 1) + 0.9
                if o.giveT >= arrive and o.giveT - dt < arrive then Snd.play("pop") end
            end
            if o.giveT > 2.0 and not o.lit then
                o.lit = true; o.litT = t
                Snd.play("cheer")
                Snd.voice("boat3_done")
                Fx.burst("confetti", LH_X, 120, 50, 260, 2.6, 11)
            end
            if o.lit and t - o.litT > 4.5 then return true end
        end
        o.throw = false
        return false
    end

    local function sky(t)
        Dr.vgrad(0, 0, Dr.W, 290, hex(0x141C44), hex(0x7A5294))
        Dr.vgrad(0, 200, Dr.W, 90, hex(0x7A5294, 0), hex(0xF0907A, 0.85))
        for k = 1, 40 do
            local x, y = (k * 97 + 13) % Dr.W, (k * 53) % 190
            lg.setColor(1, 1, 0.85, 0.35 + 0.45 * (0.5 + 0.5 * math.sin(t * 2 + k)))
            lg.circle("fill", x, y, 1.2 + (k % 3) * 0.5, 6)
        end
        Dr.circle(250, 92, 26, hex(0xFFF3B0), 1, true)
        lg.setColor(1, 0.95, 0.7, 0.15)
        lg.circle("fill", 250, 92, 44, 32)
    end

    local function farHills(cam)
        Dr.color(hex(0x3A3366))
        for k = -1, 6 do
            local x = k * 170 - (cam * 0.15) % 170
            lg.ellipse("fill", x, 282, 120, 30, 32)
        end
    end

    local function island(sx, t)
        -- скеля з травою, маяк, причал
        Dr.poly({ sx - 40, 340, sx - 10, 300, sx + 40, 280, sx + 160, 270, sx + 260, 282, sx + 300, 340 }, hex(0x6E6A8A))
        Dr.poly({ sx - 10, 300, sx + 40, 280, sx + 160, 270, sx + 260, 282, sx + 250, 292, sx + 150, 284, sx + 40, 294 }, hex(0x4E8A5E), 1, true)
        local lx, ly = lighthouse(sx + LH_X - 420, LH_Y - 18, 1, t, o.lit, not o.lit)
        o.lampX, o.lampY = lx, ly
        Dr.house(sx + 190, 282, 50, 34, hex(0x9C5A6A), o.lit and C.cream or hex(0xB8B2C8))
    end

    local function beam(t)
        if not o.lit then return end
        local lx, ly = o.lampX, o.lampY
        local a = (t - o.litT) * 1.5
        local c = math.cos(a)
        local len = 760 * math.abs(c)
        local dir = c >= 0 and 1 or -1
        local half = 26 + 30 * (1 - math.abs(c))
        lg.setColor(1, 0.93, 0.55, 0.28)
        lg.polygon("fill", lx, ly - 6, lx + dir * len, ly - half - 30, lx + dir * len, ly + half + 30, lx, ly + 6)
        lg.setColor(1, 0.97, 0.75, 0.25)
        lg.polygon("fill", lx, ly - 3, lx + dir * len, ly - half * 0.4, lx + dir * len, ly + half * 0.4, lx, ly + 3)
        -- спалах, коли промінь дивиться на нас
        local f = 1 - math.min(1, math.abs(c) * 3)
        if f > 0 then
            lg.setColor(1, 0.95, 0.7, 0.5 * f)
            lg.circle("fill", lx, ly, 40 + 30 * f, 32)
        end
    end

    local function layerFor(py, cam)
        local p = math.max(0, math.min(1, (py - Y_MIN) / (Y_MAX - Y_MIN)))
        return { y0 = py - 3, amp = 0.9 + p * 0.5, par = 1, ph = py * 0.021 + 0.4, cam = cam,
            c1 = mix(NEAR1, FAR1, p), c2 = mix(NEAR2, FAR2, p), bottom = py + 170, foam = 0.6 }
    end

    local function ring(b, sx, y, t, half)
        local cy, rx, ry = y - 40, 20, 54
        local k = 0.75 + 0.25 * math.sin(t * 5 + b.x)
        local col = b.state == "ok" and C.gold or (b.state == "miss" and hex(0x8A8FB0) or hex(0x7FF0FF))
        local a = b.state == "miss" and 0.35 or 1
        local a1, a2 = math.pi, math.pi * 2
        if half == "front" then a1, a2 = 0, math.pi end
        if b.state == "wait" then
            lg.setColor(col[1], col[2], col[3], 0.25 * k)
            lg.setLineWidth(14)
            lg.arc("line", "open", sx, cy, rx, a1, a2, 24)
        end
        lg.push(); lg.translate(sx, cy); lg.scale(1, ry / rx)
        lg.setColor(col[1], col[2], col[3], a * k)
        lg.setLineWidth(6 * rx / ry + 1)
        lg.arc("line", "open", 0, 0, rx, a1, a2, 24)
        lg.pop()
        if half == "back" then
            -- буйок унизу кільця
            Dr.rrect(sx - 9, y - 18, 18, 22, 6, C.red)
            Dr.rrect(sx - 9, y - 11, 18, 6, 2, C.white, 1, true)
            Dr.circle(sx, y - 22, 6, b.state == "miss" and hex(0x8A8FB0) or LIGHT)
        end
        if b.flash > 0 then
            lg.setColor(1, 0.95, 0.6, b.flash * 0.6)
            lg.circle("fill", sx, cy, 60 * (1.5 - b.flash), 32)
        end
    end

    function o.draw()
        local t = o.t
        local cam = o.cam
        sky(t)
        farHills(cam)
        -- далекий згаслий маяк на обрії
        if cam < CAM2 - 700 then
            local fx = 560 - cam * 0.03
            Dr.ellipse(fx, 284, 40, 8, hex(0x3A3366), 1, true)
            lighthouse(fx, 284, 0.28, t, false, true)
        end
        Bk.layer({ y0 = 278, amp = 0.4, par = 0.4, ph = 0.2, cam = cam, c1 = hex(0x58508E), c2 = hex(0x34457E), bottom = 380, foam = 0.4 }, t)
        Bk.layer({ y0 = 300, amp = 0.6, par = 0.7, ph = 1.0, cam = cam, c1 = hex(0x4A5A99), c2 = hex(0x2B3A72), bottom = 420, foam = 0.5 }, t)
        Bk.reflect(250, 290, 340, t, { 1, 0.95, 0.7 }, 44, 0.5)
        -- острів (під'їжджає наприкінці)
        local isx = 420 + (CAM2 - cam)
        if isx < Dr.W + 60 then island(isx, t) end
        beam(t)
        if isx < Dr.W + 60 then
            Bk.pier(isx + DOCK_X - 420, DOCK_Y, 100, t, true)
            local tx = isx + DOCK_X - 420 - 50
            local hop = o.lit and math.abs(math.sin(t * 6)) * 10 or 0
            Dr.animal("turtle", tx, DOCK_Y - 40 - hop, 0.85, t, o.lit and "happy" or "sad")
        end
        -- буйки й човен за глибиною
        local ents = { { y = o.py, me = true } }
        for _, b in ipairs(o.buoys) do
            local sx = b.x - cam
            if sx > -60 and sx < Dr.W + 60 then ents[#ents + 1] = { y = b.y, b = b, sx = sx } end
        end
        table.sort(ents, function(a, b) return a.y < b.y end)
        local sc = bs()
        local meSX = o.px
        local meL = layerFor(o.py, cam)
        local meY = o.py + Bk.height(meL, meSX, t)
        for _, e in ipairs(ents) do
            local L = layerFor(e.y, cam)
            if e.me then
                local sp = o.phase == "sail" and o.speed or o.vx
                Bk.wake(meSX, meY, sc, 1, sp, t)
                Bk.boat(meSX, meY, sc, t, math.atan(Bk.slope(meL, meSX, t) * 1.3), 1, sp)
                -- лампочки на борту
                local shown = o.carried
                if o.phase == "give" then shown = 0 end
                for k = 1, shown do bulb(meSX + (-74 + (k - 1) * 18) * sc, meY - 48 * sc, 0.7, t) end
            else
                local y = e.y + Bk.height(L, e.sx, t)
                e.wy = y
                lg.setColor(1, 0.92, 0.5, 0.25)
                lg.circle("fill", e.sx, y - 22, 18, 20)
                ring(e.b, e.sx, y, t, "back")
            end
            Bk.layer(L, t)
            if not e.me then Bk.reflect(e.sx, e.wy + 6, e.wy + 46, t, LIGHT, 14, 0.35) end
        end
        -- світні цятки-доріжка між буйками
        for k = 1, #o.buoys - 1 do
            local a, b = o.buoys[k], o.buoys[k + 1]
            if b.state == "wait" then
                for i = 1, 7 do
                    local p = i / 8
                    local wx = a.x + (b.x - a.x) * p
                    local sx = wx - cam
                    if sx > BX + 40 and sx < Dr.W + 10 then
                        local y = a.y + (b.y - a.y) * (0.5 - 0.5 * math.cos(p * math.pi))
                        lg.setColor(0.5, 0.95, 1, 0.35 + 0.3 * math.sin(t * 4 - i))
                        lg.circle("fill", sx, y + 2, 3.5, 10)
                    end
                end
            end
        end
        for _, e in ipairs(ents) do
            if not e.me then ring(e.b, e.sx, e.wy, t, "front") end
        end
        -- пляшки з лампочками
        if o.phase ~= "sail" then
            for _, b in ipairs(o.bottles) do
                if not b.taken then
                    local L = layerFor(b.y, cam)
                    local y = b.y + Bk.height(L, b.x, t)
                    bottle(b.x, y - 6, 0.9, t, math.sin(t * 2 + b.ph) * 0.25)
                    Bk.reflect(b.x, y + 10, y + 40, t, LIGHT, 12, 0.3)
                end
            end
        end
        -- лампочки летять до маяка
        if o.phase == "give" and o.lampX then
            for k = 1, 3 do
                local p = math.max(0, math.min(1, (o.giveT - 0.5 * (k - 1)) / 0.9))
                if p < 1 then
                    local x0, y0 = meSX + (-74 + (k - 1) * 18) * sc, meY - 48 * sc
                    local x = x0 + (o.lampX - x0) * p
                    local y = y0 + (o.lampY - y0) * p - math.sin(p * math.pi) * 90
                    bulb(x, y, 0.8, t)
                end
            end
        end
        Bk.layer({ y0 = 450, amp = 1.6, par = 1.3, ph = 2.2, cam = cam, c1 = hex(0x2A3F78), c2 = hex(0x0E1838), a = 0.95, foam = 0.5 }, t)
        if o.lit then
            lg.setColor(1, 0.85, 0.5, 0.08)
            lg.rectangle("fill", 0, 0, Dr.W, Dr.H)
        end
        Fx.draw()
        -- табло
        if o.phase == "sail" then
            Dr.rrect(14, 12, 150, 44, 16, C.panel)
            for i = 1, #o.buoys do
                local st = o.buoys[i].state
                local x = 34 + (i - 1) * 22
                lg.setLineWidth(4)
                Dr.color(st == "ok" and C.gold or hex(0xD6D0C4))
                lg.ellipse("line", x, 34, 6, 11, 16)
            end
            Kit.progress(cam / CAM2, "boat")
        else
            Dr.rrect(14, 12, 130, 44, 16, C.panel)
            for i = 1, 3 do
                if i <= o.carried or o.lit then bulb(40 + (i - 1) * 38, 32, 0.8, t)
                else Dr.circle(40 + (i - 1) * 38, 32, 8, hex(0xD6D0C4), 1, true) end
            end
        end
        -- підказки
        if o.phase == "sail" and o.idle > 2 then
            for _, b in ipairs(o.buoys) do
                if b.state == "wait" then
                    if math.abs(b.y - o.py) > 20 then
                        local up = b.y < o.py
                        Dr.arrow(meSX + 20, meY - 130, up and 2 or 0, 1.1, C.yellow, t)
                    end
                    break
                end
            end
        elseif o.phase == "bay" then
            if nearDock() then
                Dr.buttonA(meSX, meY - 110 * sc - 20, 1.1, t)
            elseif o.idle > 2 then
                local tx, ty = DOCK_X - 60, DOCK_Y - 110
                for _, b in ipairs(o.bottles) do if not b.taken then tx, ty = b.x, b.y - 70; break end end
                Dr.arrow(tx, ty, 0, 1.1, C.yellow, t)
            end
        end
    end

    function o.stars()
        if o.passed >= 4 then return 3 elseif o.passed >= 2 then return 2 end
        return 1
    end

    -- бот: тримає курс на наступний буйок, потім збирає пляшки й пливе до причалу
    function o.bot()
        local function steer(nm, other, on)
            if on then In.press(nm); In.release(other) else In.release(nm) end
        end
        local tx, ty
        if o.phase == "sail" then
            In.press("right")
            ty = o.py
            for _, b in ipairs(o.buoys) do if b.state == "wait" then ty = b.y; break end end
        elseif o.phase == "bay" then
            In.release("right")
            tx, ty = 300, DOCK_Y
            for _, b in ipairs(o.bottles) do if not b.taken then tx, ty = b.x, b.y; break end end
            if nearDock() then In.press("a"); In.release("a") end
        else
            for _, k in ipairs({ "up", "down", "left", "right" }) do In.release(k) end
            return
        end
        steer("up", "down", ty < o.py - 5)
        if ty >= o.py - 5 then steer("down", "up", ty > o.py + 5) end
        if tx then
            steer("left", "right", tx < o.px - 8)
            if tx >= o.px - 8 then steer("right", "left", tx > o.px + 8) end
        end
    end

    function o.leave() Snd.loop("engine", false) end

    return o
end

return M
