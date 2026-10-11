-- discover_boss_fight.lua  (read-only)
-- Run it right when the Boss Rush / Coyote fight starts (before stage 2 begins),
-- keep playing normally (let the farm script run as usual). It records for DURATION seconds (300 = 5 min, enough for Coyote and Vacio).
-- It never fires a remote and never moves you.
-- Output: console + discover_boss_fight_output.txt + clipboard.

local DURATION = 300

local WS = game:GetService("Workspace")
local Players = game:GetService("Players")
local lp = Players.LocalPlayer

local lines = {}
local function out(s) s = tostring(s); if #lines < 600 then lines[#lines + 1] = s; print(s) end end
local t0 = os.clock()
local function ts() return string.format("[%5.1fs] ", os.clock() - t0) end
local function full(i) local ok, r = pcall(function() return i:GetFullName() end) return ok and r or tostring(i) end
local function r5(n) return math.floor(n / 5 + 0.5) * 5 end

local function attrs(i)
    local t = {}
    for k, v in pairs(i:GetAttributes()) do t[#t + 1] = k .. "=" .. tostring(v) end
    table.sort(t)
    return table.concat(t, ",")
end
local function partOf(m)
    return m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("Root") or m:FindFirstChild("RootPart")
        or (m:IsA("Model") and m.PrimaryPart) or m:FindFirstChildWhichIsA("BasePart", true)
end
local function playerPos()
    local c = lp.Character
    local h = c and c:FindFirstChild("HumanoidRootPart")
    return h and h.Position
end

out("=== discover_boss_fight  PlaceId=" .. game.PlaceId .. "  duration=" .. DURATION .. "s")

-- mode folders present right now
local MODE = { "BossRush_NPCs", "Raid_NPCs", "Challenge_NPCs", "NPCs", "Dungeon_Container", "HollowRealmRun", "Boss_Rush" }
local function modeLine()
    local t = {}
    for _, n in ipairs(MODE) do if WS:FindFirstChild(n, true) then t[#t + 1] = n end end
    for _, c in ipairs(WS:GetChildren()) do if string.match(c.Name, "^Generated_") then t[#t + 1] = c.Name end end
    return table.concat(t, ", ")
end
local lastMode = ""
local function checkMode()
    local m = modeLine()
    if m ~= lastMode then lastMode = m out(ts() .. "FOLDERS PRESENT: " .. m) end
end

-- events: anything named like the boss appearing or disappearing (catches fast stage swaps)
local watch = { "coyote", "vacio", "boss" }
local function interesting(name)
    local l = string.lower(name)
    for _, w in ipairs(watch) do if string.find(l, w, 1, true) then return true end end
    return false
end
local conns = {}
conns[#conns + 1] = WS.DescendantAdded:Connect(function(d)
    if (d:IsA("Model") or d:IsA("Humanoid")) and interesting(d.Name) then
        out(ts() .. "ADDED   " .. d.ClassName .. "  " .. full(d))
    end
end)
conns[#conns + 1] = WS.DescendantRemoving:Connect(function(d)
    if (d:IsA("Model") or d:IsA("Humanoid")) and interesting(d.Name) then
        out(ts() .. "REMOVED " .. d.ClassName .. "  " .. full(d))
    end
end)

-- snapshot diff of every non-player model that has a Humanoid, plus anything boss-named
local known = {}
local function stateOf(m)
    local hum = m:FindFirstChildOfClass("Humanoid")
    local p = partOf(m)
    local pp = playerPos()
    local d = (p and pp) and r5((p.Position - pp).Magnitude) or "?"
    local hp = hum and (math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth)) or "noHum"
    local pos = p and string.format("%d,%d,%d", r5(p.Position.X), r5(p.Position.Y), r5(p.Position.Z)) or "noPart"
    return string.format("parent=%s hp=%s dist=%s pos=%s attrs=[%s]", full(m.Parent), hp, tostring(d), pos, attrs(m))
end

local function snapshot()
    local seen = {}
    for _, d in ipairs(WS:GetDescendants()) do
        local m
        if d:IsA("Humanoid") then
            m = d.Parent
        elseif d:IsA("Model") and interesting(d.Name) then
            m = d
        end
        if m and m:IsA("Model") and not Players:GetPlayerFromCharacter(m) and not seen[m] then
            seen[m] = true
            local ok, st = pcall(stateOf, m)
            if ok then
                local old = known[m]
                if not old then
                    known[m] = st
                    out(ts() .. "NEW  " .. m.Name .. "  " .. st)
                elseif old ~= st then
                    known[m] = st
                    out(ts() .. "CHG  " .. m.Name .. "  " .. st)
                end
            end
        end
    end
    for m, _ in pairs(known) do
        if not seen[m] then
            known[m] = nil
            out(ts() .. "GONE " .. tostring(m.Name))
        end
    end
end

local lastPos
while os.clock() - t0 < DURATION do
    pcall(checkMode)
    pcall(snapshot)
    local pp = playerPos()
    if pp then
        local s = string.format("%d,%d,%d", r5(pp.X), r5(pp.Y), r5(pp.Z))
        if s ~= lastPos then lastPos = s out(ts() .. "PLAYER @ " .. s) end
    end
    task.wait(2)
end
for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end

out("=== done (" .. #lines .. " lines) ===")
local text = table.concat(lines, "\n")
if writefile then pcall(writefile, "discover_boss_fight_output.txt", text) print("saved to discover_boss_fight_output.txt") end
if setclipboard then pcall(setclipboard, text) print("copied to clipboard") end
