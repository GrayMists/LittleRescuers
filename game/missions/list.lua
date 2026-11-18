-- Усі місії по машинах. Нова місія: файл missions/<id>.lua (див. fire1.lua) і id у списку нижче.
-- Наступна місія машини відкривається, коли пройдено попередню; фінал — коли пройдено всі.
local Ve = require("core.vehicles")

local L = {}

L.VEHICLES = {
    { id = "fire",   missions = { "fire1", "fire2", "fire3" } },
    { id = "police", missions = { "police1", "police2", "police3" } },
    { id = "heli",   missions = { "heli1", "heli2", "heli3" } },
    { id = "boat",   missions = { "boat1", "boat2", "boat3" } },
}
L.FINALE = "finale"

local cache = {}
-- модуль місії або nil, якщо файлу ще немає
function L.get(id)
    if cache[id] == nil then
        cache[id] = love.filesystem.getInfo("missions/" .. id .. ".lua") and require("missions." .. id) or false
    end
    return cache[id] or nil
end

-- місії, які вже існують, для машини v
function L.of(v)
    local out = {}
    for _, id in ipairs(v.missions) do if L.get(id) then table.insert(out, id) end end
    return out
end

function L.unlocked(id, stars)
    for _, v in ipairs(L.VEHICLES) do
        local list = L.of(v)
        for k, mid in ipairs(list) do
            if mid == id then return k == 1 or stars(list[k - 1]) > 0 end
        end
    end
    if id == L.FINALE then
        for _, v in ipairs(L.VEHICLES) do
            for _, mid in ipairs(L.of(v)) do if stars(mid) == 0 then return false end end
        end
        return L.get(L.FINALE) ~= nil
    end
    return false
end

L.TEAM = Ve.TEAM
return L
