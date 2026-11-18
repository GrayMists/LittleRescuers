-- Озвучка (assets/voice/<id>.ogg; якщо файлу немає — тиша) і звуки, згенеровані кодом.
local Snd = {}

local DIR = "assets/voice/"
local known, cache = {}, {}
local current, queue = nil, {}

local function exists(path)
    if known[path] == nil then known[path] = love.filesystem.getInfo(path) ~= nil end
    return known[path]
end

function Snd.hasVoice(id) return exists(DIR .. id .. ".ogg") end

local function playNow(id)
    local path = DIR .. id .. ".ogg"
    if not exists(path) then return false end
    if current then current:stop() end
    local src = cache[path]
    if not src then
        src = love.audio.newSource(path, "static")
        cache[path] = src
    end
    src:setVolume(1)
    src:play()
    current = src
    return true
end

-- одна фраза (перебиває попередню)
function Snd.voice(id)
    queue = {}
    playNow(id)
end

-- кілька фраз поспіль
function Snd.voiceList(ids)
    queue = {}
    for k = 2, #ids do table.insert(queue, ids[k]) end
    if not playNow(ids[1]) and #queue > 0 then Snd.update() end
end

function Snd.speaking() return current ~= nil and current:isPlaying() end

function Snd.update()
    if (not current or not current:isPlaying()) and #queue > 0 then
        local id = table.remove(queue, 1)
        if not playNow(id) then Snd.update() end
    end
end

-- ---------- Синтезовані звуки ----------

local RATE = 22050
local function make(dur, fn)
    local n = math.floor(dur * RATE)
    local sd = love.sound.newSoundData(n, RATE, 16, 1)
    for i = 0, n - 1 do
        local t = i / RATE
        local v = fn(t, t / dur)
        sd:setSample(i, math.max(-1, math.min(1, v)))
    end
    return love.audio.newSource(sd, "static")
end

local function env(p, a, r) -- атака й затухання
    if p < a then return p / a end
    return math.max(0, 1 - (p - a) / (r or (1 - a)))
end

local sq = function(x) return (x % 1 < 0.5) and 1 or -1 end
local noise = function() return love.math.random() * 2 - 1 end

Snd.sfx = {}

function Snd.init()
    local s = Snd.sfx
    s.ding = make(0.35, function(t, p) return math.sin(t * 2 * math.pi * 1320) * env(p, 0.02) * 0.4 end)
    s.pop = make(0.12, function(t, p) return math.sin(t * 2 * math.pi * (600 + p * 600)) * env(p, 0.05) * 0.5 end)
    s.bump = make(0.18, function(t, p) return math.sin(t * 2 * math.pi * (140 - p * 60)) * env(p, 0.03) * 0.6 end)
    s.whoosh = make(0.4, function(_, p) return noise() * math.sin(p * math.pi) * 0.25 end)
    s.splash = make(0.45, function(_, p) return noise() * env(p, 0.02) * 0.35 end)
    s.horn = make(0.3, function(t, p) return (sq(t * 330) + sq(t * 415)) * 0.12 * env(p, 0.05, 0.4) end)
    s.cheer = make(0.9, function(t, p)
        local notes = { 523, 659, 784, 1046 }
        local f = notes[math.min(4, math.floor(p * 4) + 1)]
        return math.sin(t * 2 * math.pi * f) * 0.3 * env((p * 4) % 1, 0.05)
    end)
    -- безперервні (у циклі)
    s.siren = make(1.2, function(t, p)
        local f = (p < 0.5) and 740 or 587
        return math.sin(t * 2 * math.pi * f) * 0.12
    end)
    s.siren:setLooping(true)
    s.spray = make(1.0, function() return noise() * 0.12 end)
    s.spray:setLooping(true)
    s.rotor = make(0.5, function(t) return noise() * 0.2 * (0.5 + 0.5 * math.sin(t * 2 * math.pi * 16)) end)
    s.rotor:setLooping(true)
    s.engine = make(0.5, function(t) return sq(t * 55) * 0.05 + math.sin(t * 2 * math.pi * 110) * 0.05 end)
    s.engine:setLooping(true)
end

function Snd.play(name)
    local s = Snd.sfx[name]
    if not s then return end
    s:stop()
    s:play()
end

-- безперервний звук: увімкнути / вимкнути
function Snd.loop(name, on, vol)
    local s = Snd.sfx[name]
    if not s then return end
    s:setVolume(vol or 1)
    if on and not s:isPlaying() then s:play()
    elseif not on and s:isPlaying() then s:stop() end
end

function Snd.stopLoops()
    for _, n in ipairs({ "siren", "spray", "rotor", "engine" }) do Snd.loop(n, false) end
end

return Snd
