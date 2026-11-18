-- Вертоліт 1: «Козенята на горі». Висіти над козеням, тримати A — трос із кошиком спускається;
-- козеня застрибує — летіти на майданчик H і висадити.
local Dr = require("core.draw")
local In = require("core.input")
local Snd = require("core.sound")
local Fx = require("core.fx")
local Kit = require("missions.kit")
local HK = require("missions.heli_kit")
local lg = love.graphics
local C = Dr.C

local M = {
    id = "heli1", vehicle = "heli", rescued = "goat",
    intro = "heli1_intro",
    icon = function(x, y, s, t)
        Dr.poly({ x - 44 * s, y + 36 * s, x - 6 * s, y - 30 * s, x + 18 * s, y + 6 * s, x + 30 * s, y - 10 * s, x + 50 * s, y + 36 * s }, Dr.hex(0x8C9AB8))
        Dr.poly({ x - 6 * s, y - 30 * s, x - 15 * s, y - 14 * s, x + 3 * s, y - 14 * s }, C.white)
        Dr.animal("goat", x + 6 * s, y + 8 * s + math.sin(t * 5) * 2, 0.42 * s, t, "sad")
    end,
}

local GROUND = 432
local PAD = { x = 95, y = GROUND }
local LEDGES = { { x = 470, y = 190 }, { x = 285, y = 262 }, { x = 575, y = 330 } }
local ROPE_MAX = 240

local function drawPillar(l)
    local w = 92
    Dr.shadow(l.x, GROUND + 4, w * 0.6, 8)
    Dr.poly({ l.x - w / 2, l.y, l.x + w / 2, l.y, l.x + w / 2 + 12, GROUND, l.x - w / 2 - 12, GROUND }, Dr.hex(0x9B8E86))
    Dr.rrect(l.x - w / 2 - 4, l.y - 8, w + 8, 20, 10, C.grassD)
    Dr.rrect(l.x - w / 2 + 8, l.y - 12, w - 16, 12, 6, C.green, 1, true)
end

function M.new()
    local o = { t = 0, h = HK.new(300, 120), rope = 0, carrying = nil, home = 0, doneT = nil, idle = 0, a = false,
        goats = {} }
    for k, l in ipairs(LEDGES) do o.goats[k] = { x = l.x, y = l.y - 22, state = "ledge", ph = k, k = k } end
    o.back = {
        HK.ridge(4, 330, 190, Dr.hex(0xB9C6E0), Dr.hex(0xD9E2F2), 150),
        HK.ridge(9, 390, 160, Dr.hex(0x8EA0C4), Dr.hex(0xB4C3E0), 250),
        HK.ridge(15, 440, 110, Dr.hex(0x6FA78A), Dr.hex(0x8CC4A0)),
    }

    local function basket() return HK.basketPos(o.h, o.rope) end

    function o.update(dt)
        o.t = o.t + dt
        local h = o.h
        local dx, dy = HK.update(h, dt, { x0 = 40, x1 = 600, y0 = 90, y1 = 395, speed = 190 })
        o.a = In.down("a") and not o.doneT
        o.idle = (dx == 0 and dy == 0 and not o.a) and o.idle + dt or 0
        -- трос: A — униз, інакше (або з козеням) — вгору
        if o.a and not o.carrying then o.rope = math.min(ROPE_MAX, o.rope + 150 * dt)
        else o.rope = math.max(0, o.rope - (o.carrying and 190 or 170) * dt) end
        local bx, by = basket()
        for _, g in ipairs(o.goats) do
            if g.state == "ledge" then
                if not o.carrying and o.rope > 10 and math.abs(bx - g.x) < 30 and math.abs(by - 12 - g.y) < 28 then
                    g.state, o.carrying = "carried", g
                    Snd.play("pop"); Fx.burst("spark", g.x, g.y, 8, 120, 0.6, 8)
                end
            elseif g.state == "carried" then
                g.x, g.y = bx, by - 18 - math.abs(math.sin(o.t * 6)) * 3
                if o.rope < 25 and math.abs(h.x - PAD.x) < 55 and h.y > 300 then
                    g.state, o.carrying = "drop", nil
                    g.tx = 175 + o.home * 40
                    o.home = o.home + 1
                    Snd.play("ding")
                end
            elseif g.state == "drop" then
                -- сходить на землю й біжить до друзів
                g.y = math.min(GROUND - 24, g.y + 160 * dt)
                if g.y >= GROUND - 24 then
                    g.x = g.x + (g.tx - g.x) * math.min(1, dt * 3)
                    if math.abs(g.x - g.tx) < 4 then g.state = "home"; Fx.burst("spark", g.x, g.y, 6, 100, 0.6, 7) end
                end
            end
        end
        if not o.doneT and o.home == 3 and not o.carrying then
            local all = true
            for _, g in ipairs(o.goats) do if g.state ~= "home" then all = false end end
            if all then
                o.doneT = o.t
                Snd.play("cheer"); Snd.voice("heli1_done")
                Fx.burst("confetti", 320, 200, 50, 260, 2.5, 12)
            end
        end
        return o.doneT ~= nil and o.t - o.doneT > 3
    end

    function o.draw()
        local t, h = o.t, o.h
        Kit.sky("town", t)
        Kit.clouds(t, 0)
        for _, r in ipairs(o.back) do HK.drawRidge(r) end
        Dr.color(C.grass); lg.rectangle("fill", 0, GROUND, Dr.W, 60)
        Dr.color(C.grassD); lg.rectangle("fill", 0, GROUND, Dr.W, 5)
        for _, l in ipairs(LEDGES) do drawPillar(l) end
        -- майданчик H
        Dr.ellipse(PAD.x, PAD.y + 6, 52, 13, C.grey)
        Dr.ellipse(PAD.x, PAD.y + 2, 48, 11, C.road)
        Dr.color(C.white); lg.setLineWidth(3); lg.ellipse("line", PAD.x, PAD.y + 2, 40, 9)
        Dr.line(C.white, 4, PAD.x - 10, PAD.y - 3, PAD.x - 10, PAD.y + 7)
        Dr.line(C.white, 4, PAD.x + 10, PAD.y - 3, PAD.x + 10, PAD.y + 7)
        Dr.line(C.white, 4, PAD.x - 10, PAD.y + 2, PAD.x + 10, PAD.y + 2)
        for _, g in ipairs(o.goats) do
            local mood = (g.state == "ledge") and "sad" or "happy"
            local jump = (g.state == "home") and math.abs(math.sin(t * 4 + g.ph)) * 6 or 0
            if g.state == "ledge" then
                Dr.shadow(g.x, g.y + 24, 20, 5)
                -- меч-меч: козеня переминається
                Dr.animal("goat", g.x, g.y + math.sin(t * 3 + g.ph) * 1.5, 0.7, t, mood)
            elseif g.state ~= "carried" then
                Dr.animal("goat", g.x, g.y - jump, 0.7, t, mood)
            end
        end
        Fx.draw()
        -- трос і кошик
        if o.rope > 2 or o.carrying then
            HK.drawRope(h, o.rope, "basket", nil, t)
        else
            HK.drawRope(h, 22, "basket", nil, t)
        end
        for _, g in ipairs(o.goats) do
            if g.state == "carried" then Dr.animal("goat", g.x, g.y - 6, 0.55, t, "happy") end
        end
        if o.carrying then
            local bx, by = basket()
            Dr.rrect(bx - 20, by - 18, 40, 18, 8, C.wood)
        end
        HK.draw(h, t, 0.55)
        if o.doneT then
            Kit.thanks("goat", 330, 380, t)
        elseif o.idle > 2 then
            local tx, ty
            if o.carrying then tx, ty = PAD.x, PAD.y - 70
            else
                for _, g in ipairs(o.goats) do if g.state == "ledge" then tx, ty = g.x, g.y - 60; break end end
            end
            if tx then
                Dr.arrow(tx, ty, 0, 1.2, C.yellow, t)
                if not o.carrying then Dr.buttonA(tx + 34, ty - 8, 1, t) end
            end
        end
        -- табло: козенята вдома
        Dr.rrect(14, 12, 150, 44, 16, C.panel)
        for i = 1, 3 do
            local x = 40 + (i - 1) * 44
            if i <= o.home then Dr.animal("goat", x, 36, 0.3, t, "happy") else Dr.circle(x, 34, 12, C.grey, 0.6) end
        end
    end

    function o.stars() return o.t < 150 and 3 or 2 end

    function o.bot()
        local h = o.h
        if o.carrying then
            In.release("a")
            -- їхати до майданчика
            HK.botMove(h, PAD.x, 340, 14)
            return
        end
        for _, g in ipairs(o.goats) do
            if g.state == "ledge" then
                local bx = HK.basketPos(h, o.rope)
                local want = g.y - 12 - h.y - 4
                if math.abs(bx - g.x) > 14 then
                    In.release("a")
                    HK.botMove(h, g.x, math.max(100, g.y - 140), 14)
                else
                    HK.botMove(h, g.x, h.y, 10)
                    if o.rope < want then In.press("a") elseif In.down("a") then In.release("a") end
                end
                return
            end
        end
        HK.botRelease()
    end

    function o.leave() HK.stop() end

    return o
end

return M
