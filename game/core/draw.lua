-- Гладка векторна графіка: заокруглені фігури, м'які тіні, градієнти, обвідка.
-- Усе малюється в логічних координатах 640x480 (main.lua масштабує під екран приставки).
local lg = love.graphics

local Dr = {}

Dr.W, Dr.H = 640, 480

-- ---------- Кольори ----------

function Dr.hex(h, a)
    return { math.floor(h / 65536) % 256 / 255, math.floor(h / 256) % 256 / 255, h % 256 / 255, a or 1 }
end
local hex = Dr.hex

-- світліший / темніший відтінок (k від -1 до 1)
function Dr.shade(c, k)
    if k >= 0 then
        return { c[1] + (1 - c[1]) * k, c[2] + (1 - c[2]) * k, c[3] + (1 - c[3]) * k, c[4] or 1 }
    end
    return { c[1] * (1 + k), c[2] * (1 + k), c[3] * (1 + k), c[4] or 1 }
end
local shade = Dr.shade

Dr.C = {
    sky1 = hex(0x8FD3FF), sky2 = hex(0xE6F7FF),
    grass = hex(0x7CCB5E), grassD = hex(0x5DAE47),
    road = hex(0x8A8F9C), roadD = hex(0x6E7380), line = hex(0xFFF4C2),
    water = hex(0x4FB3E8), waterD = hex(0x2E8CC9), foam = hex(0xEAF8FF),
    red = hex(0xE84A3C), redD = hex(0xB8352B), yellow = hex(0xFFD23F), orange = hex(0xFF9A3C),
    blue = hex(0x3D7BE0), blueD = hex(0x2A59AB), white = hex(0xFFFFFF), cream = hex(0xFFF8E7),
    dark = hex(0x2B2D42), grey = hex(0xB9C0CC), glass = hex(0xBFE9FF), green = hex(0x4CBF6B),
    pink = hex(0xFF8FB1), purple = hex(0x9B6BDF), brown = hex(0x9C6B45), wood = hex(0xC98B57),
    fire = hex(0xFF7A1A), fire2 = hex(0xFFD23F), smoke = hex(0x9AA3AE),
    panel = hex(0xFFF8E7), panelD = hex(0xE0B97A), gold = hex(0xFFC93C),
}
local C = Dr.C

function Dr.color(c, a)
    lg.setColor(c[1], c[2], c[3], (c[4] or 1) * (a or 1))
end
local color = Dr.color

-- ---------- Базові фігури ----------

-- обвідка: темніший відтінок заливки
local OUT = 3
Dr.outlineW = OUT

local function outline(c) return shade(c, -0.45) end
Dr.outlineOf = outline

function Dr.rrect(x, y, w, h, r, c, a, noLine)
    color(c, a)
    lg.rectangle("fill", x, y, w, h, r, r, 8)
    if not noLine then
        color(outline(c), a)
        lg.setLineWidth(OUT)
        lg.rectangle("line", x, y, w, h, r, r, 8)
    end
end

function Dr.circle(x, y, r, c, a, noLine)
    color(c, a)
    lg.circle("fill", x, y, r, 40)
    if not noLine then
        color(outline(c), a)
        lg.setLineWidth(OUT)
        lg.circle("line", x, y, r, 40)
    end
end

function Dr.ellipse(x, y, rx, ry, c, a, noLine)
    color(c, a)
    lg.ellipse("fill", x, y, rx, ry, 40)
    if not noLine then
        color(outline(c), a)
        lg.setLineWidth(OUT)
        lg.ellipse("line", x, y, rx, ry, 40)
    end
end

function Dr.poly(pts, c, a, noLine)
    color(c, a)
    local ok = love.math.isConvex(pts)
    if ok then lg.polygon("fill", pts)
    else
        for _, tri in ipairs(love.math.triangulate(pts)) do lg.polygon("fill", tri) end
    end
    if not noLine then
        color(outline(c), a)
        lg.setLineWidth(OUT)
        lg.setLineJoin("bevel")
        lg.polygon("line", pts)
    end
end

function Dr.line(c, w, ...)
    color(c)
    lg.setLineWidth(w)
    lg.line(...)
end

-- м'яка тінь під предметом
function Dr.shadow(x, y, rx, ry, a)
    for k = 3, 1, -1 do
        lg.setColor(0.1, 0.12, 0.2, (a or 0.22) / 3)
        lg.ellipse("fill", x, y, rx * (0.7 + k * 0.15), ry * (0.7 + k * 0.15), 32)
    end
end

-- вертикальний градієнт
local gradMesh = nil
function Dr.vgrad(x, y, w, h, c1, c2)
    if not gradMesh then
        gradMesh = lg.newMesh({
            { 0, 0, 0, 0, 1, 1, 1, 1 }, { 1, 0, 0, 0, 1, 1, 1, 1 },
            { 1, 1, 0, 0, 1, 1, 1, 1 }, { 0, 1, 0, 0, 1, 1, 1, 1 },
        }, "fan", "dynamic")
    end
    gradMesh:setVertexAttribute(1, 3, c1[1], c1[2], c1[3], c1[4] or 1)
    gradMesh:setVertexAttribute(2, 3, c1[1], c1[2], c1[3], c1[4] or 1)
    gradMesh:setVertexAttribute(3, 3, c2[1], c2[2], c2[3], c2[4] or 1)
    gradMesh:setVertexAttribute(4, 3, c2[1], c2[2], c2[3], c2[4] or 1)
    lg.setColor(1, 1, 1, 1)
    lg.draw(gradMesh, x, y, 0, w, h)
end

-- відблиск на круглих речах
function Dr.shine(x, y, r, a)
    lg.setColor(1, 1, 1, a or 0.55)
    lg.ellipse("fill", x - r * 0.35, y - r * 0.4, r * 0.32, r * 0.2, 20)
end

-- ---------- Значки ----------

function Dr.star(x, y, r, c, a, rot)
    local pts = {}
    for k = 0, 9 do
        local ang = (rot or 0) - math.pi / 2 + k * math.pi / 5
        local rr = (k % 2 == 0) and r or r * 0.48
        table.insert(pts, x + math.cos(ang) * rr)
        table.insert(pts, y + math.sin(ang) * rr)
    end
    Dr.poly(pts, c or C.gold, a)
end

function Dr.heart(x, y, s, c, a)
    c = c or C.red
    color(c, a)
    lg.circle("fill", x - s * 0.5, y - s * 0.2, s * 0.55, 24)
    lg.circle("fill", x + s * 0.5, y - s * 0.2, s * 0.55, 24)
    lg.polygon("fill", x - s * 1.02, y, x + s * 1.02, y, x, y + s * 1.1)
end

-- кнопка «A» (червоне коло з літерою — літеру діти впізнають на приставці)
function Dr.buttonA(x, y, s, t)
    s = s or 1
    local bob = t and math.sin(t * 5) * 3 or 0
    Dr.shadow(x, y + 16 * s, 14 * s, 5 * s)
    Dr.circle(x, y + bob, 15 * s, C.red)
    Dr.shine(x, y + bob, 15 * s)
    lg.setColor(1, 1, 1, 1)
    local f = Dr.font(22 * s)
    lg.setFont(f)
    lg.print("A", x - f:getWidth("A") / 2, y + bob - f:getHeight() / 2)
end

-- стрілочка, що показує напрямок (dir: 0 вниз, 1 вліво, 2 вгору, 3 вправо)
function Dr.arrow(x, y, dir, s, c, t)
    s = s or 1
    local bob = t and math.sin(t * 6) * 4 or 0
    lg.push()
    lg.translate(x, y)
    lg.rotate(({ [0] = 0, math.pi / 2, math.pi, -math.pi / 2 })[dir])
    lg.translate(0, bob)
    Dr.poly({ -10 * s, -14 * s, 10 * s, -14 * s, 10 * s, 0, 18 * s, 0, 0, 18 * s, -18 * s, 0, -10 * s, 0 }, c or C.yellow)
    lg.pop()
end

local fonts = {}
function Dr.font(size)
    size = math.floor(size + 0.5)
    -- Inter ExtraBold (SIL OFL 1.1) — з кирилицею, для цифр і назви гри
    if not fonts[size] then fonts[size] = lg.newFont("assets/fonts/Inter-ExtraBold.otf", size) end
    return fonts[size]
end

-- цифри (лічильники) — діти 5 років уже знають цифри
function Dr.number(n, x, y, size, c)
    local f = Dr.font(size or 28)
    lg.setFont(f)
    local s = tostring(n)
    local w = f:getWidth(s)
    color(outline(c or C.white))
    for dx = -2, 2, 2 do for dy = -2, 2, 2 do lg.print(s, x - w / 2 + dx, y + dy) end end
    color(c or C.white)
    lg.print(s, x - w / 2, y)
end

-- панель-табличка
function Dr.panel(x, y, w, h)
    Dr.shadow(x + w / 2, y + h + 4, w * 0.45, 8, 0.18)
    Dr.rrect(x, y, w, h, 18, C.panel)
    color(C.panelD, 0.35)
    lg.setLineWidth(2)
    lg.rectangle("line", x + 7, y + 7, w - 14, h - 14, 12, 12)
end

-- ---------- Природа ----------

function Dr.cloud(x, y, s, a, col)
    if col then color(col, a or 0.95) else lg.setColor(1, 1, 1, a or 0.95) end
    for _, p in ipairs({ { -30, 6, 22 }, { -8, -8, 28 }, { 22, -2, 24 }, { 40, 10, 16 }, { 5, 12, 22 } }) do
        lg.circle("fill", x + p[1] * s, y + p[2] * s, p[3] * s, 28)
    end
end

function Dr.tree(x, y, s, t, kind)
    s = s or 1
    Dr.shadow(x, y, 30 * s, 8 * s)
    Dr.rrect(x - 6 * s, y - 40 * s, 12 * s, 40 * s, 4 * s, C.brown)
    local sway = math.sin((t or 0) * 1.3 + x * 0.05) * 2 * s
    if kind == "pine" then
        for k = 0, 2 do
            local yy = y - 40 * s - k * 22 * s
            Dr.poly({ x - (38 - k * 8) * s + sway, yy, x + (38 - k * 8) * s + sway, yy, x + sway, yy - 42 * s }, C.grassD)
        end
    else
        Dr.circle(x + sway - 18 * s, y - 52 * s, 24 * s, C.green)
        Dr.circle(x + sway + 18 * s, y - 52 * s, 24 * s, C.green)
        Dr.circle(x + sway, y - 74 * s, 30 * s, C.green)
        lg.setColor(1, 1, 1, 0.18)
        lg.circle("fill", x + sway - 10 * s, y - 84 * s, 12 * s, 20)
    end
end

function Dr.bush(x, y, s)
    s = s or 1
    Dr.shadow(x, y, 26 * s, 6 * s)
    Dr.circle(x - 14 * s, y - 10 * s, 14 * s, C.grassD)
    Dr.circle(x + 14 * s, y - 10 * s, 14 * s, C.grassD)
    Dr.circle(x, y - 18 * s, 17 * s, C.green)
end

-- будиночок збоку: w x h, колір даху
function Dr.house(x, y, w, h, roof, wall)
    wall = wall or C.cream
    Dr.shadow(x + w / 2, y + 2, w * 0.55, 10)
    Dr.rrect(x, y - h, w, h, 8, wall)
    Dr.poly({ x - 14, y - h + 4, x + w + 14, y - h + 4, x + w / 2, y - h - h * 0.6 }, roof)
    local dw, dh = math.min(28, w * 0.3), math.min(46, h * 0.62)
    Dr.rrect(x + w / 2 - dw / 2, y - dh, dw, dh, dw * 0.35, C.brown)
    lg.setColor(1, 1, 1, 0.5)
    lg.circle("fill", x + w / 2 + dw * 0.25, y - dh * 0.48, dw * 0.1, 12)
end

-- вікно будинку (для пожеж, котиків тощо)
function Dr.window(x, y, w, h, lit)
    Dr.rrect(x, y, w, h, 6, lit and C.yellow or C.glass)
    Dr.line(outline(C.glass), 3, x + w / 2, y + 2, x + w / 2, y + h - 2)
    Dr.line(outline(C.glass), 3, x + 2, y + h / 2, x + w - 2, y + h / 2)
end

-- вогник-крапля; size 0..1 (згасає, коли гасимо)
local function drop(x, y, w, h, t, ph, c, a)
    local pts = {}
    for k = 0, 23 do
        local ang = k / 24 * math.pi * 2
        local wob = 1 + math.sin(t * 9 + ph + k) * 0.05
        local px = math.sin(ang) * math.sin(ang / 2) * w * wob
        local py = -math.cos(ang) * h
        -- кінчик хитається
        px = px + math.sin(t * 7 + ph) * w * 0.35 * (1 + py / h) * 0.5
        table.insert(pts, x + px); table.insert(pts, y + py - h)
    end
    color(c, a)
    for _, tri in ipairs(love.math.triangulate(pts)) do lg.polygon("fill", tri) end
end
function Dr.flame(x, y, s, t, size)
    size = size or 1
    if size <= 0.02 then return end
    local k = s * size
    local f = 1 + math.sin(t * 13 + x) * 0.08
    drop(x, y, 20 * k, 26 * k * f, t, x, C.red, 0.95)
    drop(x, y + 2 * k, 14 * k, 19 * k * f, t, x + 1, C.fire, 1)
    drop(x, y + 3 * k, 8 * k, 11 * k * f, t, x + 2, C.fire2, 1)
end

-- ---------- Звірята (м'які круглі мордочки) ----------
-- kind: cat, dog, bunny, bear, duck, fox, beaver, raccoon, hedgehog, owl

local ANIMALS = {
    cat = { body = hex(0xFFB65C), ear = "tri", inner = hex(0xFFD9A8) },
    dog = { body = hex(0xC8925E), ear = "flop", inner = hex(0xE8C49B) },
    bunny = { body = hex(0xF3F0F7), ear = "long", inner = hex(0xFFC7D9) },
    bear = { body = hex(0x9C6B45), ear = "round", inner = hex(0xD7A97E) },
    duck = { body = hex(0xFFE066), ear = "none", inner = hex(0xFFE066), beak = true },
    fox = { body = hex(0xFF8A3D), ear = "tri", inner = hex(0xFFF0E0) },
    beaver = { body = hex(0xA8703F), ear = "round", inner = hex(0xE0B48A), teeth = true },
    raccoon = { body = hex(0xA3A8B5), ear = "tri", inner = hex(0xE6E8EE), mask = true },
    hedgehog = { body = hex(0xB28A62), ear = "round", inner = hex(0xF2D7B5), spikes = true },
    owl = { body = hex(0xA77B5B), ear = "tuft", inner = hex(0xF4E2C8), beak = true },
    pig = { body = hex(0xFFA9C4), ear = "round", inner = hex(0xFF7FA6), snout = true },
    goat = { body = hex(0xF7F4EE), ear = "round", inner = hex(0xFFD9D9), horns = true },
    squirrel = { body = hex(0xE8803A), ear = "tri", inner = hex(0xFFE3C2), tail = true },
    frog = { body = hex(0x6CCB5F), ear = "none", inner = hex(0xE4F5B8), eyesTop = true },
    turtle = { body = hex(0x9BD36B), ear = "none", inner = hex(0xE4F5B8), shell = hex(0x3F9A5B) },
}
Dr.ANIMALS = ANIMALS

-- hat: "fire" | "police" | "captain" | "pilot" | "sailor" | nil
function Dr.animal(kind, x, y, s, t, mood, hat)
    local a = ANIMALS[kind] or ANIMALS.cat
    s = s or 1
    t = t or 0
    local blink = (math.floor(t * 10 + x) % 37 == 0)
    local b = a.body
    if a.spikes then
        for k = -3, 3 do
            local ang = -math.pi / 2 + k * 0.38
            Dr.poly({ x + math.cos(ang - 0.2) * 24 * s, y + math.sin(ang - 0.2) * 24 * s,
                x + math.cos(ang) * 40 * s, y + math.sin(ang) * 40 * s,
                x + math.cos(ang + 0.2) * 24 * s, y + math.sin(ang + 0.2) * 24 * s }, shade(b, -0.25))
        end
    end
    -- вушка
    if a.ear == "tri" or a.ear == "tuft" then
        local h = a.ear == "tuft" and 16 or 22
        for side = -1, 1, 2 do
            Dr.poly({ x + side * 10 * s, y - 20 * s, x + side * 28 * s, y - 14 * s, x + side * 22 * s, y - (20 + h) * s }, b)
        end
    elseif a.ear == "round" then
        for side = -1, 1, 2 do
            Dr.circle(x + side * 19 * s, y - 20 * s, 9 * s, b)
            Dr.circle(x + side * 19 * s, y - 20 * s, 4.5 * s, a.inner, 1, true)
        end
    elseif a.ear == "long" then
        for side = -1, 1, 2 do
            Dr.ellipse(x + side * 10 * s, y - 38 * s, 7 * s, 20 * s, b)
            Dr.ellipse(x + side * 10 * s, y - 37 * s, 3.5 * s, 14 * s, a.inner, 1, true)
        end
    end
    if a.tail then Dr.ellipse(x + 30 * s, y - 14 * s, 14 * s, 26 * s, shade(b, -0.1)); Dr.ellipse(x + 31 * s, y - 24 * s, 7 * s, 14 * s, a.inner, 1, true) end
    if a.horns then
        for side = -1, 1, 2 do
            Dr.poly({ x + side * 6 * s, y - 22 * s, x + side * 15 * s, y - 22 * s, x + side * 14 * s, y - 38 * s }, C.panelD)
        end
    end
    if a.shell then   -- панцир позаду голови
        for side = -1, 1, 2 do Dr.ellipse(x + side * 26 * s, y + 30 * s, 10 * s, 7 * s, b) end
        Dr.ellipse(x, y + 12 * s, 40 * s, 28 * s, a.shell)
        Dr.ellipse(x, y + 6 * s, 30 * s, 18 * s, shade(a.shell, 0.25))
        for k = -1, 1 do Dr.line(shade(a.shell, -0.3), 2 * s, x + k * 22 * s, y + 30 * s, x + k * 14 * s, y + 38 * s) end
    end
    -- голова
    Dr.circle(x, y, 27 * s, b)
    if a.eyesTop then   -- вирячені очі зверху
        for side = -1, 1, 2 do Dr.circle(x + side * 14 * s, y - 23 * s, 11 * s, b) end
    end
    if a.ear == "flop" then
        for side = -1, 1, 2 do Dr.ellipse(x + side * 25 * s, y - 4 * s, 8 * s, 16 * s, shade(b, -0.2)) end
    end
    Dr.ellipse(x, y + 9 * s, 16 * s, 12 * s, a.inner, 1, true)
    if a.mask then Dr.ellipse(x, y - 4 * s, 22 * s, 8 * s, shade(b, -0.5), 1, true) end
    -- очі
    for side = -1, 1, 2 do
        local ex, ey = x + side * (a.eyesTop and 14 or 10) * s, y + (a.eyesTop and -23 or -4) * s
        if blink or mood == "sleep" then
            Dr.line(C.dark, 2.5 * s, ex - 4 * s, ey, ex + 4 * s, ey)
        else
            Dr.circle(ex, ey, 5 * s, C.dark, 1, true)
            lg.setColor(1, 1, 1, 1)
            lg.circle("fill", ex + 1.5 * s, ey - 1.5 * s, 1.8 * s, 10)
        end
    end
    -- щічки
    color(C.pink, 0.45)
    lg.circle("fill", x - 17 * s, y + 6 * s, 4.5 * s, 14)
    lg.circle("fill", x + 17 * s, y + 6 * s, 4.5 * s, 14)
    -- ротик
    if a.beak then
        Dr.poly({ x - 7 * s, y + 4 * s, x + 7 * s, y + 4 * s, x, y + 13 * s }, C.orange)
    else
        Dr.circle(x, y + 4 * s, 3.2 * s, C.dark, 1, true)
        lg.setLineWidth(2 * s)
        color(C.dark)
        if mood == "sad" then
            lg.arc("line", "open", x, y + 16 * s, 6 * s, -math.pi * 0.8, -math.pi * 0.2, 12)
        else
            lg.arc("line", "open", x, y + 7 * s, 6 * s, math.pi * 0.15, math.pi * 0.85, 12)
        end
        if a.teeth then Dr.rrect(x - 3 * s, y + 11 * s, 6 * s, 5 * s, 1, C.white, 1) end
    end
    if a.snout then
        Dr.ellipse(x, y + 7 * s, 12 * s, 9 * s, shade(b, -0.12))
        Dr.circle(x - 4 * s, y + 7 * s, 2 * s, C.dark, 1, true)
        Dr.circle(x + 4 * s, y + 7 * s, 2 * s, C.dark, 1, true)
    end
    if hat then Dr.hat(hat, x, y - 22 * s, s) end
end

-- шоломи й кашкети рятувальників
function Dr.hat(kind, x, y, s)
    if kind == "fire" then
        Dr.ellipse(x, y + 4 * s, 30 * s, 7 * s, C.redD)
        Dr.poly({ x - 22 * s, y + 3 * s, x - 18 * s, y - 14 * s, x, y - 20 * s, x + 18 * s, y - 14 * s, x + 22 * s, y + 3 * s }, C.red)
        Dr.circle(x, y - 6 * s, 6 * s, C.yellow)
    elseif kind == "police" then
        Dr.rrect(x - 22 * s, y - 14 * s, 44 * s, 16 * s, 6 * s, C.blueD)
        Dr.ellipse(x, y + 3 * s, 26 * s, 5 * s, C.dark)
        Dr.star(x, y - 6 * s, 6 * s, C.gold)
    elseif kind == "pilot" then
        Dr.ellipse(x, y - 2 * s, 24 * s, 14 * s, C.orange)
        Dr.rrect(x - 18 * s, y - 6 * s, 14 * s, 9 * s, 4 * s, C.glass)
        Dr.rrect(x + 4 * s, y - 6 * s, 14 * s, 9 * s, 4 * s, C.glass)
    elseif kind == "sailor" then
        Dr.ellipse(x, y, 24 * s, 9 * s, C.white)
        Dr.rrect(x - 18 * s, y - 2 * s, 36 * s, 6 * s, 3 * s, C.blue, 1, true)
    elseif kind == "captain" then
        Dr.rrect(x - 22 * s, y - 14 * s, 44 * s, 16 * s, 6 * s, C.white)
        Dr.ellipse(x, y + 3 * s, 26 * s, 5 * s, C.dark)
        Dr.circle(x, y - 6 * s, 5 * s, C.gold)
    end
end

return Dr
