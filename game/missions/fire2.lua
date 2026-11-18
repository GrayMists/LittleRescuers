-- Пожежна 2: «Кошеня на дереві». Доїхати до парку, потім підняти драбину (вгору),
-- під'їхати під гілку, взяти кошеня (A), опустити драбину (вниз) — кошеня стрибає до мами.
local Dr = require("core.draw")
local Ve = require("core.vehicles")
local In = require("core.input")
local Snd = require("core.sound")
local Fx = require("core.fx")
local Kit = require("missions.kit")
local lg = love.graphics
local C = Dr.C

local M = {
    id = "fire2", vehicle = "fire", rescued = "cat",
    intro = "fire2_intro",
    icon = function(x, y, s, t)
        Dr.rrect(x - 6 * s, y - 10 * s, 12 * s, 56 * s, 4 * s, C.brown)
        Dr.circle(x, y - 22 * s, 26 * s, C.green)
        Dr.circle(x - 18 * s, y - 8 * s, 18 * s, C.green)
        Dr.circle(x + 18 * s, y - 8 * s, 18 * s, C.green)
        Dr.animal("cat", x + 2 * s, y - 14 * s + math.sin(t * 4) * 2, 0.4 * s, t, "sad")
    end,
}

local GROUND = 430
local SC = 0.8
local LAD_MAX, LAD_EXT = 1.4, 150
local BRANCH = { { 345, 168 }, { 545, 150 } }   -- де сидить кошеня (центр мордочки)
local MOM = { 230, 440 }

-- кінчик драбини у світі
local function tip(tx, lad)
    local a = -lad * LAD_MAX
    local L = 110 + lad * LAD_EXT
    return tx + SC * (-60 + L * math.cos(a)), GROUND + SC * (-78 + L * math.sin(a))
end

local function drawTree(t)
    local x = 470
    Dr.shadow(x, GROUND - 40, 70, 12)
    Dr.poly({ x - 26, GROUND - 40, x + 26, GROUND - 40, x + 14, 120, x - 14, 120 }, C.brown)
    Dr.line(C.brown, 16, x - 5, 250, 330, 195)
    Dr.line(C.brown, 16, x + 5, 235, 560, 170)
    Dr.line(C.brown, 12, x, 170, 400, 120)
    local sway = math.sin(t * 1.3) * 3
    for _, c in ipairs({ { 400, 110, 60 }, { 540, 100, 66 }, { 470, 60, 70 }, { 330, 150, 44 }, { 590, 130, 44 }, { 470, 120, 56 } }) do
        Dr.circle(c[1] + sway, c[2], c[3], C.green)
    end
    lg.setColor(1, 1, 1, 0.16); lg.circle("fill", 440 + sway, 50, 26, 20)
end

function M.new()
    local o = { phase = "drive", t = 0, tx = 120, lad = 0, idle = 0, doneT = nil, state = "wait", hint = false }
    o.kit = { bx = BRANCH[1][1], by = BRANCH[1][2], branch = 1, hop = nil, hopped = false, near = 0, jump = nil, mood = "sad" }
    o.drive = Kit.newDrive({
        vehicle = "fire", length = 3000, theme = "forest", stars = 8, bumps = 4, seed = 22, obstacle = "puddle",
        goal = function(x, y, t)
            Dr.tree(x + 20, y + 100, 1.5, t); Dr.tree(x + 130, y + 100, 1.3, t, "pine")
            Dr.rrect(x - 60, y + 10, 10, 90, 4, C.wood); Dr.rrect(x - 60, y + 10, 90, 12, 5, C.wood)
        end,
    })

    function o.tipNow() return tip(o.tx, o.lad) end

    function o.update(dt)
        o.t = o.t + dt
        local k = o.kit
        if o.phase == "drive" then
            Snd.loop("siren", true, 0.5)
            if Kit.updateDrive(o.drive, dt) then
                o.phase = "rescue"
                Snd.loop("siren", false)
                Snd.voice("fire2_hint")
            end
            return false
        end
        local dx, dy = In.axis()
        local sp = o.lad > 0.3 and 90 or 170
        if o.state == "down" then dx = dx * 0.5 end
        o.tx = math.max(100, math.min(565, o.tx + dx * sp * dt))
        if dy < 0 then o.lad = math.min(1, o.lad + dt * 0.45)
        elseif dy > 0 then o.lad = math.max(0, o.lad - dt * 0.55) end
        o.idle = (dx == 0 and dy == 0) and o.idle + dt or 0
        local px, py = tip(o.tx, o.lad)
        -- кошеня стрибає на іншу гілку, коли драбина підбирається близько (один раз)
        if o.state == "wait" and not k.hopped and not k.hop and o.lad > 0.6 and math.abs(px - k.bx) < 70 then
            k.near = k.near + dt
            if k.near > 0.7 then
                k.hopped, k.hop = true, { t = 0, fx = k.bx, fy = k.by, tx = BRANCH[2][1], ty = BRANCH[2][2] }
                Snd.play("whoosh")
            end
        end
        if k.hop then
            k.hop.t = k.hop.t + dt / 0.9
            local p = math.min(1, k.hop.t)
            k.bx = k.hop.fx + (k.hop.tx - k.hop.fx) * p
            k.by = k.hop.fy + (k.hop.ty - k.hop.fy) * p - math.sin(p * math.pi) * 70
            if p >= 1 then k.hop = nil; k.branch = 2; Snd.play("pop") end
        end
        o.canGrab = o.state == "wait" and not k.hop and o.lad > 0.8 and math.abs(px - k.bx) < 45 and math.abs(py - (k.by + 22)) < 45
        if o.state == "carry" then
            k.bx, k.by = px, py - 20
            if o.lad < 0.12 then
                o.state = "jump"
                k.jump = { t = 0, fx = k.bx, fy = k.by }
                Snd.play("whoosh")
            end
        elseif o.state == "jump" then
            local j = k.jump
            j.t = j.t + dt / 0.9
            local p = math.min(1, j.t)
            local tx, ty = MOM[1] + 40, MOM[2] + 8
            k.bx = j.fx + (tx - j.fx) * p
            k.by = j.fy + (ty - j.fy) * p - math.sin(p * math.pi) * 90
            if p >= 1 then
                o.state = "done"; o.doneT = o.t; k.mood = "happy"
                Snd.play("cheer"); Snd.voice("fire2_done")
                Fx.burst("confetti", MOM[1] + 30, 360, 50, 260, 2.5, 12)
            end
        end
        return o.doneT ~= nil and o.t - o.doneT > 3
    end

    function o.press(name)
        if o.phase ~= "rescue" then return end
        if name == "a" and o.canGrab then
            o.state = "carry"; o.kit.mood = "happy"
            Snd.play("ding"); Snd.voice("fire2_grab")
            Fx.burst("spark", o.kit.bx, o.kit.by, 10, 140, 0.7, 8)
        end
    end

    function o.draw()
        if o.phase == "drive" then Kit.drawDrive(o.drive); Fx.draw(); return end
        local t, k = o.t, o.kit
        Kit.sky("forest", t)
        Kit.clouds(t, 0)
        Kit.hills(0, 230, Dr.hex(0x8FCB74))
        Dr.tree(60, 340, 1.1, t, "pine"); Dr.tree(160, 330, 0.9, t)
        Dr.color(C.grass); lg.rectangle("fill", 0, 360, Dr.W, 130)
        Dr.color(C.grassD); lg.rectangle("fill", 0, GROUND + 22, Dr.W, 40)
        -- дорожка
        Dr.color(C.wood); Dr.ellipse(320, GROUND + 38, 330, 16, C.wood, 0.55, true)
        drawTree(t)
        -- кошеня на гілці (до машини, щоб було видно)
        local px, py = tip(o.tx, o.lad)
        Ve.draw("fire", o.tx, GROUND, SC, t, { ladder = o.lad, ladderMax = LAD_MAX, ladderExt = LAD_EXT, driver = true })
        if o.state ~= "carry" and o.state ~= "jump" and o.state ~= "done" then
            Dr.shadow(k.bx, k.by + 28, 14, 4, 0.2)
        end
        Dr.animal("cat", k.bx, k.by + (o.state == "wait" and math.sin(t * 3) * 1.5 or 0), 0.62, t, k.mood)
        if o.canGrab then Dr.circle(k.bx, k.by, 36 + math.sin(t * 8) * 3, C.yellow, 0.25, true) end
        -- мама-кішка
        local mm = (o.state == "done") and "happy" or "sad"
        local hop = (o.state == "done") and math.abs(math.sin(t * 5)) * 6 or 0
        Dr.shadow(MOM[1], MOM[2] + 34, 34, 8)
        Dr.animal("cat", MOM[1], MOM[2] - hop, 0.95, t, mm)
        if o.state == "done" then Dr.heart(MOM[1] + 50, MOM[2] - 44 - (t * 30) % 30, 9, C.red, 1 - ((t * 30) % 30) / 30) end
        Fx.draw()
        -- підказки
        if o.idle > 2 and not o.doneT and o.state ~= "jump" then
            if o.state == "carry" then
                Dr.arrow(o.tx - 20, 330, 0, 1.3, C.yellow, t)
            elseif o.canGrab then
                Dr.buttonA(px + 40, py - 50, 1.1, t)
            elseif o.lad < 0.8 then
                Dr.arrow(o.tx - 20, 300, 2, 1.3, C.yellow, t)
            else
                local want = (k.bx - 15) > o.tx and 3 or 1
                Dr.arrow(o.tx - 20, 300, want, 1.3, C.yellow, t)
            end
        end
        -- табло: ступінь «драбина» не потрібен; невеличка іконка кошеняти
        Dr.rrect(14, 12, 70, 44, 16, C.panel)
        if o.doneT then Dr.circle(49, 34, 14, C.green); Dr.star(49, 34, 8, C.white)
        else Dr.animal("cat", 49, 38, 0.38, t, "sad") end
    end

    function o.stars()
        local d = o.drive
        local s = 3
        if d.got < d.total / 2 then s = s - 1 end
        if d.bumped >= 3 then s = s - 1 end
        return math.max(1, s)
    end

    function o.bot()
        if o.phase == "drive" then
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
        for _, kk in ipairs({ "left", "up", "down" }) do In.release(kk) end
        local k = o.kit
        local px = tip(o.tx, o.lad)
        if o.state == "wait" then
            if o.canGrab then In.press("a"); In.release("a"); return end
            if o.lad < 0.95 then In.press("up") end
            if k.hop then return end
            local d = px - k.bx
            if d > 12 then In.press("left") elseif d < -12 then In.press("right") end
        elseif o.state == "carry" then
            In.press("down")
        end
    end

    function o.leave() Snd.loop("siren", false) end

    return o
end

return M
