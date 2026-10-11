-- discover_dungeon.lua  (read-only)
-- Run this INSIDE the Hollow Realm, a few seconds after the run starts and
-- while enemies are visible. It never fires a remote or moves you.
-- Output: console + discover_dungeon_output.txt (writefile) + clipboard (setclipboard).

local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")
local Players = game:GetService("Players")
local lp = Players.LocalPlayer

local lines = {}
local function out(s) s = tostring(s); lines[#lines + 1] = s; print(s) end
local function full(i) local ok, r = pcall(function() return i:GetFullName() end) return ok and r or tostring(i) end
local function kids(i, cap)
    local t, n = {}, 0
    for _, c in ipairs(i:GetChildren()) do
        n += 1
        if n <= cap then t[#t + 1] = c.Name .. "<" .. c.ClassName .. ">" end
    end
    local s = table.concat(t, ", ")
    if n > cap then s = s .. ", ... +" .. (n - cap) .. " more" end
    return s, n
end

out("=== discover_dungeon  PlaceId=" .. game.PlaceId .. "  JobId=" .. tostring(game.JobId))

-- [1] What the farm engine looks for first
out("\n--- [1] Workspace direct children ---")
for _, c in ipairs(WS:GetChildren()) do
    if not c:IsA("Terrain") and not c:IsA("Camera") and c ~= lp.Character and not Players:GetPlayerFromCharacter(c) then
        local s, n = kids(c, 12)
        out(c.Name .. "<" .. c.ClassName .. ">  children=" .. n .. (n > 0 and ("  [" .. s .. "]") or ""))
    end
end

out("\n--- [H] HollowRealmRun contents ---")
pcall(function()
    local hr = WS:FindFirstChild("HollowRealmRun")
    if not hr then out("HollowRealmRun NOT in Workspace (run this while inside the dungeon)") return end
    for _, c in ipairs(hr:GetChildren()) do
        local s, n = kids(c, 12)
        out("  " .. c.Name .. "<" .. c.ClassName .. ">  children=" .. n .. (n > 0 and ("  [" .. s .. "]") or ""))
    end
    local npcs = hr:FindFirstChild("NPCs")
    out("NPCs folder: " .. (npcs and ("present, children=" .. #npcs:GetChildren()) or "MISSING"))
    if npcs then
        for i, m in ipairs(npcs:GetChildren()) do
            if i > 25 then out("  ...") break end
            local hum = m:FindFirstChildOfClass("Humanoid")
            out("  NPC " .. m.Name .. "<" .. m.ClassName .. ">  Humanoid=" .. tostring(hum ~= nil)
                .. (hum and ("  hp=" .. hum.Health .. "/" .. hum.MaxHealth) or ""))
        end
    end
    -- any Humanoid anywhere under the run model, with the path
    local cnt = 0
    for _, h in ipairs(hr:GetDescendants()) do
        if h:IsA("Humanoid") then
            cnt += 1
            if cnt <= 25 then out("  Humanoid at " .. full(h.Parent)) end
        end
    end
    out("Humanoids under HollowRealmRun: " .. cnt)
end)

out("\n--- [2] Anything matching ^Generated_ (the script's dungeon root) ---")
local found = false
for _, c in ipairs(WS:GetDescendants()) do
    if string.match(c.Name, "^Generated_") then
        found = true
        local s, n = kids(c, 40)
        out(full(c) .. "  children=" .. n .. "  [" .. s .. "]")
    end
end
if not found then out("NONE FOUND  <-- the farm engine will think there is no dungeon") end

out("\n--- [3] Room models: names the script expects are Room_<number> ---")
local roomCount, otherRooms = 0, {}
for _, c in ipairs(WS:GetDescendants()) do
    if c:IsA("Model") or c:IsA("Folder") then
        if string.match(c.Name, "^Room_%d+$") then
            roomCount += 1
            if roomCount <= 6 then
                local s = kids(c, 20)
                out(full(c) .. "  [" .. s .. "]")
            end
        elseif string.find(string.lower(c.Name), "room", 1, true) and #otherRooms < 15 then
            otherRooms[#otherRooms + 1] = full(c)
        end
    end
end
out("Room_<n> models found: " .. roomCount)
if #otherRooms > 0 then out("Other room-like names:\n  " .. table.concat(otherRooms, "\n  ")) end

pcall(function()
-- [4] Enemies: every model with a Humanoid that is not a player
out("\n--- [4] NPC/enemy models (Humanoid, not a player), first 40 ---")
local n = 0
local parents = {}
for _, h in ipairs(WS:GetDescendants()) do
    if h:IsA("Humanoid") then
        local m = h.Parent
        if m and not Players:GetPlayerFromCharacter(m) then
            n += 1
            local pn = m.Parent and full(m.Parent) or "nil"
            parents[pn] = (parents[pn] or 0) + 1
            if n <= 40 then
                local root = m:FindFirstChild("HumanoidRootPart")
                local okp, pp = pcall(function() return m.PrimaryPart end)
                out(full(m) .. "<" .. m.ClassName .. ">  hp=" .. tostring(h.Health) .. "/" .. tostring(h.MaxHealth)
                    .. "  HRP=" .. tostring(root ~= nil) .. "  PrimaryPart=" .. (okp and tostring(pp ~= nil) or "n/a"))
            end
        end
    end
end
out("Total non-player Humanoid models: " .. n)
out("Grouped by parent folder:")
for p, cnt in pairs(parents) do out("  " .. p .. "  x" .. cnt) end

end)

-- [5] The NPC folders the script reads
out("\n--- [5] Folders the script reads for NPCs ---")
for _, name in ipairs({ "NPCs", "BossRush_NPCs", "Raid_NPCs", "Challenge_NPCs", "Dungeon_Container" }) do
    local f = WS:FindFirstChild(name, true)
    if f then
        local s, cnt = kids(f, 15)
        out(name .. " -> " .. full(f) .. "  children=" .. cnt .. "  [" .. s .. "]")
    else
        out(name .. " -> NOT FOUND")
    end
end

-- [6] The game's own data for this dungeon
out("\n--- [6] DungeonData entry for the Hollow Realm ---")
local function dump(t, depth, indent, seen)
    seen = seen or {}
    if seen[t] or depth > 3 then return end
    seen[t] = true
    local cnt = 0
    for k, v in pairs(t) do
        cnt += 1
        if cnt > 60 then out(indent .. "...") break end
        local vt = typeof(v)
        if vt == "table" then
            out(indent .. tostring(k) .. " = {")
            dump(v, depth + 1, indent .. "  ", seen)
            out(indent .. "}")
        elseif vt == "string" or vt == "number" or vt == "boolean" then
            out(indent .. tostring(k) .. " = " .. tostring(v))
        else
            out(indent .. tostring(k) .. " : " .. vt)
        end
    end
end
pcall(function()
    local gi = RS:FindFirstChild("GameInfo")
    local mod = gi and gi:FindFirstChild("DungeonData")
    local D = mod and require(mod)
    if D and D.Dungeons then
        for id, d in pairs(D.Dungeons) do
            local dn = type(d) == "table" and d.DisplayName or tostring(id)
            if string.find(string.lower(tostring(id) .. tostring(dn)), "hollow", 1, true) then
                out("id=" .. tostring(id) .. "  DisplayName=" .. tostring(dn))
                dump(d, 1, "  ")
            end
        end
    else
        out("DungeonData not found")
    end
end)

-- [7] Player + attributes that hint at the run mode
out("\n--- [7] Local player ---")
local ch = lp.Character
out("Character: " .. tostring(ch and full(ch)))
if ch then
    local hrp = ch:FindFirstChild("HumanoidRootPart")
    out("HRP position: " .. tostring(hrp and hrp.Position))
end
for k, v in pairs(WS:GetAttributes()) do out("Workspace attribute " .. k .. " = " .. tostring(v)) end

out("\n=== done (" .. #lines .. " lines) ===")
local text = table.concat(lines, "\n")
if writefile then pcall(writefile, "discover_dungeon_output.txt", text) out("saved to discover_dungeon_output.txt") end
if setclipboard then pcall(setclipboard, text) out("copied to clipboard") end
