-- Поліція 3: «Хто забрав торт?». Наздоганяємо Єнотика (збираємо крихти, об'їжджаємо скриньки),
-- а в парку він вибачається й ділиться тортом з усіма — свято з конфеті.
local Dr = require("core.draw")
local In = require("core.input")
local Snd = require("core.sound")
local Fx = require("core.fx")
local Kit = require("missions.kit")
local PK = require("missions.police_kit")
local lg = love.graphics
local C = Dr.C

local M = {
    id = "police3", vehicle = "police", rescued = "raccoon",
    intro = "police3_intro",
    icon = function(x, y, s, t)
        PK.cake(x, y + 36 * s, 0.7 * s, t)
        Dr.animal("raccoon", x + 26 * s, y - 14 * s + math.sin(t * 6) * 2, 0.62 * s, t, "happy")
        Dr.star(x - 34 * s, y + 4 * s, 9 * s, C.gold)
    end,
}

local GUESTS = {
    { kind = "hedgehog", x = 190 }, { kind = "duck", x = 280 }, { kind = "dog", x = 370 }, { kind = "bear", x = 450 },
}
local CAKE = { 530, 470 }
local GY = 400

-- ворота парку в кінці дороги
local function goal(x, y, t)
    Dr.tree(x + 150, y - 4, 1.5, t)
    Dr.tree(x + 270, y - 4, 1.2, t)
    for k = 0, 7 do
        local px = x + 20 + k * 22
        Dr.rrect(px, y - 60, 12, 66, 4, C.cream)
        Dr.poly({ px, y - 60, px + 12, y - 60, px + 6, y - 72 }, C.cream)
    end
    Dr.rrect(x + 4, y - 40, 190, 7, 3, C.wood)
    Dr.rrect(x - 8, y - 96, 14, 100, 5, C.brown)
    Dr.rrect(x + 196, y - 96, 14, 100, 5, C.brown)
    Dr.rrect(x - 8, y - 104, 218, 16, 8, C.green)
    for k = 0, 4 do Dr.circle(x + 10 + k * 44, y - 104, 7, k % 2 == 0 and C.pink or C.yellow, 1, true) end
end

local function slice(x, y, s)
    Dr.rrect(x - 15 * s, y - 9 * s, 30 * s, 18 * s, 5 * s, C.pink)
    Dr.rrect(x - 15 * s, y - 9 * s, 30 * s, 7 * s, 4 * s, C.cream)
    Dr.circle(x + 4 * s, y - 12 * s, 5 * s, C.red)
end

function M.new()
    local o = { t = 0, phase = "chase", idle = 0, hintVoiced = false, botC = 0, fade = 0 }
    o.drive = Kit.newDrive({
        vehicle = "police", length = 3400, theme = "town", stars = 10, bumps = 5, seed = 21, obstacle = "box",
        goal = goal,
    })
    -- сцена в парку
    local sc = { step = "corner", st = 0, fed = 0, fly = nil, balloons = {}, partyT = 0 }
    o.sc = sc
    for _, g in ipairs(GUESTS) do g.t0 = nil; g.fed = false; g.pop = 0 end

    local crumbT = 0

    function o.press(name)
        if name ~= "a" or o.phase ~= "park" then return end
        o.idle = 0
        if sc.step == "corner" then
            sc.step, sc.st = "sorry", 0
            Snd.voice("police3_sorry")
            Snd.play("pop")
        elseif sc.step == "share" and not sc.fly then
            sc.fly = { k = sc.fed + 1, t = 0 }
            Snd.play("whoosh")
        end
    end

    function o.update(dt)
        o.t = o.t + dt
        if o.phase == "chase" then
            Snd.loop("siren", true, 0.45)
            -- Єнотик кидає крихти
            crumbT = crumbT + dt
            if crumbT > 0.35 then
                crumbT = 0
                Fx.add("spark", 520, 360, -120, -30, 0.7, 6)
            end
            if Kit.updateDrive(o.drive, dt) then
                o.phase, o.fade = "park", 1
                Snd.loop("siren", false)
                Snd.play("pop")
            end
            return false
        end
        o.fade = math.max(0, o.fade - dt * 2)
        sc.st = sc.st + dt
        o.idle = o.idle + dt
        if o.idle > 5 and not o.hintVoiced and sc.step ~= "party" then o.hintVoiced = true; Snd.voice("police3_hint") end
        for _, g in ipairs(GUESTS) do g.pop = math.max(0, g.pop - dt) end
        if sc.step == "sorry" then
            if sc.st > 0.4 then for k, g in ipairs(GUESTS) do if not g.t0 and k > 1 then g.t0 = o.t end end end
            if sc.st > 2.2 then sc.step, sc.st = "share", 0 end
        elseif sc.step == "share" then
            if sc.fly then
                sc.fly.t = sc.fly.t + dt
                if sc.fly.t >= 0.65 then
                    local g = GUESTS[sc.fly.k]
                    g.fed, g.pop = true, 1
                    sc.fed = sc.fed + 1
                    sc.fly = nil
                    Snd.play("ding")
                    Fx.burst("spark", g.x, GY - 40, 8, 120, 0.7, 8)
                    if sc.fed >= #GUESTS then sc.step, sc.st = "party", 0; Snd.play("cheer"); Snd.voice("police3_done") end
                end
            end
        elseif sc.step == "party" then
            sc.partyT = sc.partyT + dt
            if math.floor(sc.st * 2.5) ~= math.floor((sc.st - dt) * 2.5) then
                Fx.burst("confetti", 80 + love.math.random() * 480, 120, 22, 220, 2.5, 11)
                table.insert(sc.balloons, { x = 40 + love.math.random() * 560, y = 500, v = 50 + love.math.random() * 40,
                    c = ({ C.red, C.yellow, C.blue, C.pink, C.green, C.purple })[love.math.random(6)] })
            end
            for _, b in ipairs(sc.balloons) do b.y = b.y - b.v * dt end
            return sc.st > 5
        end
        return false
    end

    -- Єнотик попереду на дорозі
    local function ahead(t, cam)
        local d = o.drive
        local goalX = d.length - cam + 120
        local rx = math.min(540, goalX - 10)
        local ry = 392
        local step = math.sin(t * 14)
        Dr.shadow(rx, ry + 6, 30, 7)
        Dr.ellipse(rx - 10 + step * 8, ry - 2, 11, 6, C.dark)
        Dr.ellipse(rx + 12 - step * 8, ry - 2, 11, 6, C.dark)
        Dr.ellipse(rx - 34, ry - 28 + math.sin(t * 9) * 3, 20, 9, Dr.hex(0x8A8F9C))
        Dr.ellipse(rx - 38, ry - 28 + math.sin(t * 9) * 3, 5, 9, C.dark, 1, true)
        Dr.animal("raccoon", rx, ry - 38 - math.abs(math.sin(t * 7)) * 5, 0.85, t, "happy")
        PK.cake(rx + 26, ry - 8 - math.abs(math.sin(t * 7)) * 3, 0.36, t)
    end

    local function guestPos(k)
        local g = GUESTS[k]
        if k == 1 then return g.x end
        if not g.t0 then return -80 end
        local p = math.min(1, (o.t - g.t0) / 0.9)
        return -60 + (g.x + 60) * (1 - (1 - p) ^ 2)
    end

    local function drawPark(t)
        Kit.sky("town", t)
        Kit.clouds(t, 0)
        Kit.hills(0, 230)
        Dr.color(C.grass); lg.rectangle("fill", 0, 330, Dr.W, 150)
        Dr.ellipse(320, 440, 360, 36, Dr.hex(0xE9E0C8), 0.7, true)
        -- парк: дерева, паркан, лавка
        Dr.tree(600, 330, 1.6, t)
        Dr.tree(36, 330, 1.3, t)
        for k = 0, 6 do
            local px = 430 + k * 30
            Dr.rrect(px, 280, 14, 62, 4, C.cream)
            Dr.poly({ px, 280, px + 14, 280, px + 7, 268 }, C.cream)
        end
        Dr.rrect(424, 300, 200, 8, 3, C.wood)
        Dr.rrect(300, 318, 80, 14, 5, C.wood)
        Dr.rrect(304, 330, 8, 14, 2, C.brown); Dr.rrect(368, 330, 8, 14, 2, C.brown)
        -- Зоя
        Dr.shadow(90, GY + 36, 34, 8)
        Dr.animal("bunny", 90, GY - math.abs(math.sin(t * 3)) * 3, 1.15, t, "happy", "police")
        -- гості
        for k, g in ipairs(GUESTS) do
            local gx = guestPos(k)
            if gx > -70 then
                local sad = (k == 1 and sc.step == "corner")
                local hop = (g.pop > 0 and math.abs(math.sin(g.pop * 9)) * 18 or 0)
                if sc.step == "party" then hop = math.abs(math.sin(sc.st * 7 + k)) * 14 end
                Dr.shadow(gx, GY + 36, 28, 7)
                Dr.animal(g.kind, gx, GY - hop, 1.0, t, sad and "sad" or "happy")
                if g.fed then slice(gx + 6, GY + 38 - hop * 0.5, 0.8) end
                if g.pop > 0 then Dr.heart(gx + 30, GY - 40 - (1 - g.pop) * 30, 9, C.red, g.pop) end
            end
        end
        -- Єнотик з тортом
        local rx, ry = 530, GY - 32
        local sorry = sc.step ~= "corner"
        Dr.shadow(rx, ry + 46, 40, 9)
        Dr.animal("raccoon", rx, ry, 1.35, t, sorry and "happy" or "sad")
        PK.cake(CAKE[1], CAKE[2], 0.8, t)
        if sc.step == "sorry" then
            -- бульбашка «вибач»: серденько
            local bob = math.sin(t * 5) * 3
            Dr.ellipse(rx - 8, ry - 100 + bob, 38, 28, C.white)
            Dr.poly({ rx - 24, ry - 76 + bob, rx - 6, ry - 76 + bob, rx - 10, ry - 62 + bob }, C.white)
            Dr.heart(rx - 8, ry - 104 + bob, 15, C.red)
        end
        -- летить шматочок
        if sc.fly then
            local k = math.min(1, sc.fly.t / 0.65)
            local g = GUESTS[sc.fly.k]
            local x = CAKE[1] + (g.x - CAKE[1]) * k
            local y = CAKE[2] - 40 + (GY - 10 - CAKE[2] + 40) * k - math.sin(k * math.pi) * 90
            slice(x, y, 1.0)
        end
        -- кульки
        for _, b in ipairs(sc.balloons) do
            Dr.line(C.grey, 2, b.x, b.y + 22, b.x + math.sin(t * 2 + b.x) * 5, b.y + 70)
            Dr.ellipse(b.x, b.y, 17, 21, b.c)
            Dr.shine(b.x, b.y, 17)
        end
    end

    function o.draw()
        if o.phase == "chase" then
            PK.drawChase(o.drive, ahead)
            Fx.draw()
            return
        end
        local t = o.t
        drawPark(t)
        Fx.draw()
        if sc.step == "corner" and o.idle > 1.2 then
            Dr.arrow(520, 300, 0, 1.2, C.yellow, t)
            Dr.buttonA(520, 262, 1.1, t)
        elseif sc.step == "share" and not sc.fly and o.idle > 1.2 then
            Dr.buttonA(CAKE[1], CAKE[2] - 150, 1.1, t)
        end
        -- лічильник шматочків
        if sc.step == "share" or sc.step == "party" then
            Dr.rrect(14, 12, 140, 40, 16, C.panel)
            for k = 1, #GUESTS do
                if GUESTS[k].fed then slice(40 + (k - 1) * 30, 32, 0.8) else Dr.circle(40 + (k - 1) * 30, 32, 9, Dr.hex(0xD6D0C4), 1, true) end
            end
        end
        if o.fade > 0 then lg.setColor(1, 1, 1, o.fade); lg.rectangle("fill", 0, 0, Dr.W, Dr.H) end
    end

    function o.stars()
        local d = o.drive
        local s = 3
        if d.got < d.total / 2 then s = s - 1 end
        if d.bumped >= 3 then s = s - 1 end
        return math.max(1, s)
    end

    function o.bot()
        if o.phase == "chase" then
            In.press("right")
            local carX = o.drive.x + 160
            for _, it in ipairs(o.drive.items) do
                if not it.taken and it.x > carX and it.x < carX + 260 then
                    local want = (it.kind == "star") and it.lane or (3 - it.lane)
                    if want ~= o.drive.lane then In.press(want == 1 and "up" or "down"); In.release(want == 1 and "up" or "down") end
                    break
                end
            end
            return
        end
        In.release("right")
        o.botC = o.botC + 1
        if o.botC % 30 == 0 then In.press("a"); In.release("a") end
    end

    function o.leave() Snd.loop("siren", false) end

    return o
end

return M
