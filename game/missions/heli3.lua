-- Вертоліт 3: «Нічний пошук». Прожектор вертольота світить на темний ліс; знайшов малюка —
-- він світиться й махає; веди його світлом до вогнища.
local Dr = require("core.draw")
local Snd = require("core.sound")
local Fx = require("core.fx")
local Kit = require("missions.kit")
local HK = require("missions.heli_kit")
local lg = love.graphics
local C = Dr.C

local M = {
    id = "heli3", vehicle = "heli", rescued = "owl",
    intro = "heli3_intro",
    icon = function(x, y, s, t)
        Dr.rrect(x - 46 * s, y - 40 * s, 92 * s, 84 * s, 18 * s, Dr.hex(0x1D2B53))
        Dr.star(x - 26 * s, y - 22 * s, 4 * s, C.yellow)
        Dr.poly({ x + 28 * s, y - 40 * s, x + 4 * s, y + 44 * s, x + 46 * s, y + 44 * s }, Dr.hex(0xFFF3B0), 0.5, true)
        Dr.animal("owl", x + 22 * s, y + 20 * s, 0.4 * s, t, "happy")
    end,
}

local GROUND = 425
local CAMP = { x = 565, y = 430 }
local KINDS = { "owl", "hedgehog", "owl" }
local STARTS = { { 110, 420 }, { 250, 438 }, { 385, 424 } }
local TREES = { 40, 150, 205, 320, 340, 450, 495, 610 }

local function drawForest(t)
    -- темні ялинки на задньому плані й ґрунт
    Dr.color(Dr.hex(0x233B3A)); lg.rectangle("fill", 0, GROUND - 20, Dr.W, 100)
    for k, x in ipairs(TREES) do Dr.tree(x, GROUND - 14 + (k % 3) * 4, 1.2 + (k % 2) * 0.35, t, "pine") end
    Dr.color(Dr.hex(0x2E5240)); lg.rectangle("fill", 0, GROUND + 14, Dr.W, 80)
    for _, x in ipairs({ 70, 190, 290, 420, 520 }) do Dr.bush(x, GROUND + 26, 1.0) end
end

local function drawCamp(t)
    Dr.shadow(CAMP.x, CAMP.y + 6, 40, 9)
    for k = -1, 1, 2 do Dr.line(C.brown, 8, CAMP.x + k * 22, CAMP.y + 4, CAMP.x - k * 6, CAMP.y - 14) end
    Dr.flame(CAMP.x, CAMP.y - 2, 1.5, t)
    for k = -3, 3 do Dr.circle(CAMP.x + k * 11, CAMP.y + 8, 6, C.grey) end
end

function M.new()
    local o = { t = 0, h = HK.new(150, 110), idle = 0, animals = {}, arrived = 0, doneT = nil, spotX = 0 }
    for k, s in ipairs(STARTS) do
        o.animals[k] = { kind = KINDS[k], x = s[1], y = s[2], seen = 0, found = false, arrived = false, face = 1, slot = k }
    end

    local function spot(h) return h.x + h.vx * 0.3, GROUND + 6 end

    function o.update(dt)
        o.t = o.t + dt
        local h = o.h
        local dx, dy = HK.update(h, dt, { x0 = 40, x1 = 610, y0 = 70, y1 = 250, speed = 180 })
        o.idle = (dx == 0 and dy == 0) and o.idle + dt or 0
        local sx = spot(h)
        o.spotX = sx
        for _, a in ipairs(o.animals) do
            if not a.found then
                if math.abs(a.x - sx) < 55 then a.seen = a.seen + dt else a.seen = math.max(0, a.seen - dt * 0.5) end
                if a.seen > 0.9 then
                    a.found = true
                    Snd.play("ding"); Fx.burst("spark", a.x, a.y - 30, 10, 140, 0.8, 9)
                    if not o.said then o.said = true; Snd.voice("heli3_found") end
                end
            elseif not a.arrived then
                -- іде за світлом, якщо воно поруч (кожен трохи збоку, щоб не злипались)
                local d = sx + (a.slot - 2) * 42 - a.x
                if math.abs(sx - a.x) < 230 and math.abs(d) > 10 then
                    local dir = d > 0 and 1 or -1
                    a.x = a.x + dir * 90 * dt
                    a.face = dir
                    a.hop = (a.hop or 0) + dt
                end
                if a.x > CAMP.x - 135 then
                    a.arrived = true
                    o.arrived = o.arrived + 1
                    Snd.play("pop")
                end
            else
                a.x = a.x + (CAMP.x - 130 + a.slot * 34 - 34 - a.x) * math.min(1, dt * 3)
            end
        end
        if not o.doneT and o.arrived == 3 then
            o.doneT = o.t
            Snd.play("cheer"); Snd.voice("heli3_done")
            Fx.burst("confetti", 320, 200, 50, 260, 2.5, 12)
        end
        return o.doneT ~= nil and o.t - o.doneT > 3
    end

    local function beam(h)
        local sx = spot(h)
        return { h.x, h.y + 4, sx - 62, GROUND + 14, sx + 62, GROUND + 14 }, sx
    end

    local function drawAnimal(a, t, lit)
        local hop = a.found and not a.arrived and math.abs(math.sin((a.hop or 0) * 9)) * 6 or 0
        local wave = (a.found and a.arrived) and math.abs(math.sin(t * 6 + a.slot)) * 5 or 0
        if a.found then
            lg.setColor(1, 0.95, 0.6, 0.4 + 0.15 * math.sin(t * 5)); lg.circle("fill", a.x, a.y - 14, 46, 28)
        end
        Dr.shadow(a.x, a.y + 24, 22, 5)
        Dr.animal(a.kind, a.x, a.y - 6 - hop - wave, 0.7, t, a.found and "happy" or "sad")
        if a.found and not a.arrived then
            -- махає лапкою
            Dr.circle(a.x + 24, a.y - 26 + math.sin(t * 12) * 6, 6, Dr.ANIMALS[a.kind].body)
        end
    end

    function o.draw()
        local t, h = o.t, o.h
        Kit.sky("night", t)
        Kit.clouds(t, 0)
        Dr.color(Dr.hex(0x2B3A67)); lg.circle("fill", 150, 340, 190, 40); lg.circle("fill", 480, 360, 210, 40)
        drawForest(t)
        drawCamp(t)
        for _, a in ipairs(o.animals) do if not a.found then drawAnimal(a, t) end end
        -- нічна темрява з «вирізаним» конусом світла
        local poly, sx = beam(h)
        lg.stencil(function()
            lg.polygon("fill", poly)
            lg.ellipse("fill", sx, GROUND + 14, 62, 18)
        end, "replace", 1)
        lg.setStencilTest("equal", 0)
        lg.setColor(0.03, 0.05, 0.16, 0.62)
        lg.rectangle("fill", 0, 0, Dr.W, Dr.H)
        lg.setStencilTest()
        -- сяйво прожектора
        lg.setColor(1, 0.96, 0.7, 0.22)
        lg.polygon("fill", poly)
        lg.ellipse("fill", sx, GROUND + 14, 62, 18)
        lg.setColor(1, 0.96, 0.7, 0.18)
        lg.ellipse("fill", sx, GROUND + 14, 40, 11)
        -- тварини, що в світлі: малюємо ще раз, щоб були яскравими
        for _, a in ipairs(o.animals) do
            if a.found then drawAnimal(a, t)
            elseif math.abs(a.x - sx) < 62 then
                lg.stencil(function() lg.polygon("fill", poly); lg.ellipse("fill", sx, GROUND + 14, 62, 18) end, "replace", 1)
                lg.setStencilTest("greater", 0)
                drawAnimal(a, t)
                lg.setStencilTest()
                -- кільце «знаходимо»
                lg.setColor(1, 1, 0.7, 0.9); lg.setLineWidth(4)
                lg.arc("line", "open", a.x, a.y - 60, 14, -math.pi / 2, -math.pi / 2 + math.pi * 2 * math.min(1, a.seen / 0.9), 24)
            end
        end
        -- вогнище світиться завжди
        lg.setColor(1, 0.7, 0.3, 0.25); lg.circle("fill", CAMP.x, CAMP.y - 12, 70 + math.sin(t * 8) * 3, 30)
        drawCamp(t)
        Fx.draw()
        HK.draw(h, t, 0.55)
        -- ліхтар вертольота
        Dr.circle(h.x, h.y + 4, 5, C.yellow, 1, true)
        if o.doneT then
            lg.setColor(1, 1, 1, 0.9)
            Dr.star(330, 130, 20 + math.sin(t * 4) * 3, C.gold)
        elseif o.idle > 2 then
            local tx, ty
            for _, a in ipairs(o.animals) do if not a.found then tx, ty = a.x, a.y - 80; break end end
            if not tx then
                for _, a in ipairs(o.animals) do if not a.arrived then tx, ty = a.x, a.y - 80; break end end
            end
            if tx then Dr.arrow(tx, ty, 0, 1.2, C.yellow, t) end
        end
        -- табло
        Dr.rrect(14, 12, 150, 44, 16, C.panel)
        for i = 1, 3 do
            local a = o.animals[i]
            local x = 40 + (i - 1) * 44
            if a.arrived then Dr.animal(a.kind, x, 38, 0.3, t, "happy") else Dr.circle(x, 34, 12, a.found and C.yellow or C.grey, 0.6) end
        end
    end

    function o.stars() return o.t < 160 and 3 or 2 end

    function o.bot()
        local h = o.h
        local sx = o.spotX
        for _, a in ipairs(o.animals) do
            if not a.found then
                HK.botMove(h, a.x - h.vx * 0.3, 150, 8)
                return
            end
        end
        for _, a in ipairs(o.animals) do
            if not a.arrived then
                HK.botMove(h, math.min(CAMP.x, a.x + 50 - (a.slot - 2) * 42) - h.vx * 0.3, 150, 8)
                return
            end
        end
        HK.botRelease()
        if sx then return end
    end

    function o.leave() HK.stop() end

    return o
end

return M
