-- Фінал «Велика буря»: над Сонячним гроза. Усі чотири машини по черзі:
--   човен забирає Каченя з затопленої вулиці, вертоліт знімає Котика з даху,
--   пожежна гасить дерево, у яке влучила блискавка, поліція збирає всіх на станцію.
-- Кожен етап: під'їхати/підлетіти до значка (вліво/вправо), утримувати A, поки не заповниться коло.
-- Потім буря стихає: веселка, феєрверки, свято.
local Dr = require("core.draw")
local Ve = require("core.vehicles")
local In = require("core.input")
local Snd = require("core.sound")
local Fx = require("core.fx")
local Kit = require("missions.kit")
local lg = love.graphics
local C = Dr.C

local M = {
    id = "finale", vehicle = "fire", rescued = "beaver",
    intro = "finale_intro",
    icon = function(x, y, s, t)
        Dr.cloud(x, y - 6 * s, 0.9 * s, 1)
        Dr.color(C.yellow)
        lg.polygon("fill", x - 4 * s, y + 6 * s, x + 10 * s, y + 6 * s, x + 2 * s, y + 20 * s, x + 14 * s, y + 20 * s,
            x - 8 * s, y + 46 * s, x - 2 * s, y + 26 * s, x - 12 * s, y + 26 * s)
    end,
}

local GROUND = 380
-- етапи: машина, де ціль, кого рятуємо, де стоїть машина по висоті
local STAGES = {
    { vehicle = "boat", tx = 470, who = "duck", y = GROUND + 30, say = "finale_boat" },
    { vehicle = "heli", tx = 200, who = "cat", y = 210, say = "finale_heli" },
    { vehicle = "fire", tx = 430, who = "squirrel", y = GROUND + 20, say = "finale_fire" },
    { vehicle = "police", tx = 560, who = "bunny", y = GROUND + 20, say = "finale_police" },
}

function M.new()
    local o = { t = 0, k = 1, x = 90, prog = 0, flash = 0, storm = 1, saved = {}, endT = nil, idle = 0, said = false }
    local rain = {}
    for n = 1, 90 do rain[n] = { x = love.math.random(0, 700), y = love.math.random(0, 480), v = 500 + love.math.random() * 300 } end

    local function stage() return STAGES[o.k] end

    function o.update(dt)
        o.t = o.t + dt
        if not o.said then o.said = true; Snd.voice(STAGES[1].say) end
        for _, r in ipairs(rain) do
            r.y = r.y + r.v * dt * o.storm
            r.x = r.x - 120 * dt * o.storm
            if r.y > 480 then r.y, r.x = -10, love.math.random(0, 760) end
        end
        if o.storm > 0.5 and love.math.random() < dt * 0.25 then o.flash = 0.25; Snd.play("bump") end
        o.flash = math.max(0, o.flash - dt)
        if o.endT then
            o.storm = math.max(0, o.storm - dt * 0.6)
            if math.floor(o.t * 3) % 2 == 0 and love.math.random() < 0.3 then
                Fx.burst("confetti", love.math.random(100, 540), love.math.random(80, 220), 20, 220, 2, 10)
            end
            return o.t - o.endT > 6
        end
        local st = stage()
        local dx = In.axis()
        o.x = math.max(60, math.min(600, o.x + dx * 230 * dt))
        local near = math.abs(o.x - st.tx) < 40
        o.idle = (dx == 0 and not In.down("a")) and o.idle + dt or 0
        Snd.loop(st.vehicle == "heli" and "rotor" or "engine", true, 0.4)
        if near and In.down("a") then
            o.prog = math.min(1, o.prog + dt * 0.7)
            if math.floor(o.t * 12) % 3 == 0 then
                Fx.add(st.vehicle == "fire" and "drop" or "spark", st.tx, st.y - 120, love.math.random(-60, 60), -80, 0.6, 6)
            end
            if o.prog >= 1 then
                table.insert(o.saved, st.who)
                Snd.play("cheer")
                Fx.burst("spark", st.tx, st.y - 100, 14, 200, 0.8, 10)
                Snd.loop("rotor", false); Snd.loop("engine", false)
                o.k, o.prog = o.k + 1, 0
                if o.k > #STAGES then
                    o.endT = o.t
                    Snd.voice("finale_done")
                else
                    o.x = 90
                    Snd.voice(STAGES[o.k].say)
                end
            end
        else
            o.prog = math.max(0, o.prog - dt * 0.2)
        end
        return false
    end

    local function drawTown(t)
        -- небо: гроза -> веселка
        Dr.vgrad(0, 0, Dr.W, Dr.H, Dr.hex(0x46506E), Dr.hex(0x8A93A8))
        if o.storm < 1 then
            local a = 1 - o.storm
            Dr.vgrad(0, 0, Dr.W, Dr.H, { C.sky1[1], C.sky1[2], C.sky1[3], a }, { C.sky2[1], C.sky2[2], C.sky2[3], a })
            Dr.circle(560, 70, 34, C.yellow, a, true)
            -- веселка
            local cols = { C.red, C.orange, C.yellow, C.green, C.blue, C.purple }
            lg.setLineWidth(12)
            for k, c in ipairs(cols) do
                Dr.color(c, (1 - o.storm) * 0.85)
                lg.arc("line", "open", 320, 420, 300 - k * 12, math.pi, 2 * math.pi, 48)
            end
        end
        for k = 0, 3 do Dr.cloud(80 + k * 170 + math.sin(t * 0.5 + k) * 20, 60 + (k % 2) * 30, 1.2, 0.95, Dr.shade(Dr.hex(0x9AA3B8), 0.6 * (1 - o.storm))) end
        Kit.hills(0, 250, Dr.hex(0x6FAF5A))
        -- будиночки й дерево
        Dr.house(150, GROUND, 110, 90, C.red)
        Dr.house(320, GROUND, 90, 70, C.blue)
        Dr.tree(430, GROUND, 1.1, t)
        if o.k <= 3 and not o.endT then Dr.flame(430, GROUND - 100, 1.3, t, o.k == 3 and 1 - o.prog or 1) end
        -- станція праворуч
        Dr.rrect(520, GROUND - 120, 110, 120, 14, Dr.hex(0xF2E6D8))
        Dr.rrect(512, GROUND - 132, 126, 24, 10, C.redD)
        Dr.star(575, GROUND - 120, 12, C.gold)
        -- дорога й вода на вулиці (поки не забрали Каченя)
        Dr.color(C.road); lg.rectangle("fill", 0, GROUND, Dr.W, 100)
        if o.k <= 1 and not o.endT then
            Dr.color(C.water, 0.85)
            lg.rectangle("fill", 0, GROUND + 6, Dr.W, 90)
            for k = 0, 12 do lg.setColor(1, 1, 1, 0.5); lg.ellipse("fill", (k * 60 + t * 40) % 680 - 20, GROUND + 20 + (k % 3) * 22, 14, 3, 12) end
        end
    end

    -- кого ще треба врятувати: стоять/сидять на своїх місцях
    local function drawWaiting(t)
        local spots = { duck = { 470, GROUND + 10 }, cat = { 205, GROUND - 150 }, squirrel = { 430, GROUND - 170 }, bunny = { 560, GROUND - 10 } }
        for k, st in ipairs(STAGES) do
            if k >= o.k and not o.endT then
                local p = spots[st.who]
                Dr.animal(st.who, p[1], p[2] - math.abs(math.sin(t * 4 + k)) * 6, 0.6, t, "sad")
            end
        end
    end

    function o.draw()
        local t = o.t
        drawTown(t)
        drawWaiting(t)
        if o.endT then
            -- усі разом біля станції
            for k, v in ipairs({ "fire", "police", "boat" }) do
                Ve.draw(v, 110 + (k - 1) * 170, GROUND + 60, 0.55, t, { siren = true })
            end
            Ve.draw("heli", 520, 200 + math.sin(t) * 10, 0.5, t, { siren = true, alt = 150, shadowK = 0.3 })
            for k, who in ipairs({ "duck", "cat", "squirrel", "bunny", "hedgehog", "pig", "goat" }) do
                if Dr.ANIMALS[who] then Kit.thanks(who, 70 + k * 72, GROUND - 40, t + k) end
            end
            Kit.drawChief(320, 110, 0.6, t, true)
        else
            local st = stage()
            local alt = st.vehicle == "heli" and (GROUND - st.y) or 0
            Ve.draw(st.vehicle, o.x, st.y, 0.6, t, { siren = true, alt = alt, shadowK = 0.6, speed = 8, ladder = st.vehicle == "fire" and o.prog or 0 })
            if st.vehicle == "heli" and o.prog > 0 then
                Dr.line(C.dark, 3, o.x, st.y - 20, o.x, st.y - 20 + o.prog * 90)
                Dr.rrect(o.x - 14, st.y - 20 + o.prog * 90, 28, 14, 5, C.orange)
            end
            -- ціль: стрілка й коло прогресу
            local tx, ty = st.tx, st.y - (st.vehicle == "heli" and -80 or 150)
            Dr.arrow(tx, ty - 40, 0, 1, C.yellow, t)
            if o.prog > 0 then
                lg.setLineWidth(8)
                Dr.color(C.white, 0.6); lg.circle("line", tx, ty + 10, 26, 32)
                Dr.color(C.green); lg.arc("line", "open", tx, ty + 10, 26, -math.pi / 2, -math.pi / 2 + o.prog * math.pi * 2, 32)
            end
            if o.idle > 2 then
                if math.abs(o.x - st.tx) < 40 then Dr.buttonA(o.x, st.y - 160, 1, t)
                else Dr.arrow(o.x + (st.tx > o.x and 70 or -70), st.y - 60, st.tx > o.x and 3 or 1, 1, C.yellow, t) end
            end
        end
        -- дощ і блискавка
        lg.setLineWidth(2)
        lg.setColor(0.85, 0.9, 1, 0.6 * o.storm)
        for _, r in ipairs(rain) do lg.line(r.x, r.y, r.x - 6, r.y + 16) end
        if o.flash > 0 then lg.setColor(1, 1, 1, o.flash * 2); lg.rectangle("fill", 0, 0, Dr.W, Dr.H) end
        Fx.draw()
        -- скільки врятовано
        Dr.rrect(14, 12, 54 * #STAGES + 16, 56, 18, C.panel)
        for k, st in ipairs(STAGES) do
            local x = 46 + (k - 1) * 54
            if k < o.k or o.endT then Dr.animal(st.who, x, 40, 0.42, t, "happy")
            else Dr.circle(x, 40, 16, C.grey, 0.6) end
        end
    end

    function o.stars() return 3 end

    function o.bot()
        if o.endT then In.release("a"); In.release("left"); In.release("right"); return end
        local st = stage()
        In.release("left"); In.release("right")
        if math.abs(o.x - st.tx) > 20 then In.press(st.tx > o.x and "right" or "left"); In.release("a")
        else In.press("a") end
    end

    function o.leave() Snd.loop("rotor", false); Snd.loop("engine", false) end

    return o
end

return M
