-- discover_boss_fight_v2.lua  (read-only)
-- Start it BEFORE the boss dies, with the farm script running normally, and leave it
-- running through the boss result screen and into the next stage. Do NOT stop it early:
-- it saves to the clipboard + discover_boss_fight_v2_output.txt every 20 seconds, so you
-- can paste at any time, but a longer recording is better. It never fires a remote or moves you.

local DURATION = 420

local WS = game:GetService("Workspace")
local Players = game:GetService("Players")
local lp = Players.LocalPlayer

local lines = {}
local function out(s) s = tostring(s); if #lines < 700 then lines[#lines + 1] = s end print(s) end
local t0 = os.clock()
local function ts() return string.format("[%5.1fs] ", os.clock() - t0) end
local function full(i) local ok, r = pcall(function() return i:GetFullName() end) return ok and r or tostring(i) end
local function r5(n) return math.floor(n / 5 + 0.5) * 5 end
local function save()
    local text = table.concat(lines, "\n")
    if writefile then pcall(writefile, "discover_boss_fight_v2_output.txt", text) end
    if setclipboard then pcall(setclipboard, text) end
end

local function attrs(i)
    local t = {}
    for k, v in pairs(i:GetAttributes()) do t[#t + 1] = k .. "=" .. tostring(v) end
    table.sort(t)
    return table.concat(t, ",")
end
local function playerPos()
    local c = lp.Character
    local h = c and c:FindFirstChild("HumanoidRootPart")
    return h and h.Position
end
local function anyPart(m)
    return m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("Root") or m:FindFirstChild("RootPart")
        or (m:IsA("Model") and m.PrimaryPart) or m:FindFirstChildWhichIsA("BasePart", true)
end

out("=== discover_boss_fight_v2  PlaceId=" .. game.PlaceId .. "  duration=" .. DURATION .. "s")

-- [A] folders / run roots that exist (logged on change)
local lastMode = ""
local function modeCheck()
    local t = {}
    for _, c in ipairs(WS:GetChildren()) do
        local n = c.Name
        if n == "NPCs" or n == "Boss_Rush" or n == "Raid_NPCs" or n == "BossRush_NPCs" or n == "Challenge_NPCs"
            or string.match(n, "^Generated_") or string.match(n, "^HollowRealm") then
            t[#t + 1] = n
        end
    end
    table.sort(t)
    local s = table.concat(t, ", ")
    if s ~= lastMode then lastMode = s out(ts() .. "ROOTS: " .. s) end
end

-- [B] boss models in the Hollow Realm NPC folder + streaming counts
local knownBoss = {}
local lastSummary = ""
local function bossScan()
    local hr
    for _, c in ipairs(WS:GetChildren()) do if string.match(c.Name, "^HollowRealm") then hr = c break end end
    if not hr then return end
    local npcs = hr:FindFirstChild("NPCs")
    if not npcs then return end
    local pp = playerPos()
    local total, withPart, near = 0, 0, 0
    local seen = {}
    for _, m in ipairs(npcs:GetChildren()) do
        total += 1
        local p = anyPart(m)
        if p then
            withPart += 1
            if pp and (p.Position - pp).Magnitude < 150 then near += 1 end
        end
        local isBoss = m:GetAttribute("IsBoss") == true
        local lname = string.lower(m.Name)
        if isBoss or string.find(lname, "coyote", 1, true) or string.find(lname, "vacio", 1, true) then
            seen[m] = true
            local hum = m:FindFirstChildOfClass("Humanoid")
            local pos = p and string.format("%d,%d,%d", r5(p.Position.X), r5(p.Position.Y), r5(p.Position.Z)) or "noPart"
            local d = (p and pp) and r5((p.Position - pp).Magnitude) or "?"
            local nparts = 0
            for _, dsc in ipairs(m:GetDescendants()) do if dsc:IsA("BasePart") then nparts += 1 end end
            local st = string.format("parent=%s hum=%s parts=%d dist=%s pos=%s attrs=[%s]",
                full(m.Parent), hum and (math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth)) or "none", nparts, tostring(d), pos, attrs(m))
            if knownBoss[m] ~= st then
                out(ts() .. (knownBoss[m] and "BOSS CHG  " or "BOSS NEW  ") .. m.Name .. "  " .. st)
                knownBoss[m] = st
            end
        end
    end
    for m, _ in pairs(knownBoss) do
        if not seen[m] then knownBoss[m] = nil out(ts() .. "BOSS GONE " .. tostring(m.Name)) end
    end
    local sum = string.format("NPC folder %s: models=%d withParts=%d within150=%d", hr.Name, total, withPart, near)
    if sum ~= lastSummary then lastSummary = sum out(ts() .. sum) end
end

-- [C] result / continue / selection UI: log appearances and disappearances of matching visible objects
local KEYS = { "result", "reward", "complete", "clear", "victory", "defeat", "continue", "leave", "replay",
    "return", "next", "stage", "boost", "boon", "blessing", "select", "expire", "choose", "proceed", "portal" }
local function keyed(name)
    local l = string.lower(name)
    for _, k in ipairs(KEYS) do if string.find(l, k, 1, true) then return true end end
    return false
end
local function visibleChain(g, root)
    local o = g
    while o and o ~= root do
        if o:IsA("GuiObject") and not o.Visible then return false end
        o = o.Parent
    end
    return true
end
local uiKnown = {}
local function uiScan()
    local pg = lp:FindFirstChild("PlayerGui")
    if not pg then return end
    local seen = {}
    for _, sg in ipairs(pg:GetChildren()) do
        if sg:IsA("ScreenGui") and sg.Enabled then
            for _, d in ipairs(sg:GetDescendants()) do
                if d:IsA("GuiObject") and keyed(d.Name) and d.AbsoluteSize.X > 0 and visibleChain(d, sg) then
                    seen[d] = true
                    if not uiKnown[d] then
                        local txt = ""
                        if d:IsA("TextButton") or d:IsA("TextLabel") then txt = "  text=\"" .. tostring(d.Text):sub(1, 40) .. "\"" end
                        local kids = {}
                        for _, c in ipairs(d:GetChildren()) do
                            if (c:IsA("TextButton") or c:IsA("TextLabel")) and c.Text ~= "" and #kids < 5 then
                                kids[#kids + 1] = c.Name .. "=\"" .. tostring(c.Text):sub(1, 25) .. "\""
                            end
                        end
                        uiKnown[d] = true
                        out(ts() .. "UI SHOW  " .. sg.Name .. " > " .. d:GetFullName():gsub("^.-PlayerGui%.", ""):sub(1, 110) .. "<" .. d.ClassName .. ">" .. txt
                            .. (#kids > 0 and ("  kids{" .. table.concat(kids, "; ") .. "}") or ""))
                    end
                end
            end
        end
    end
    for d, _ in pairs(uiKnown) do
        if not seen[d] then
            uiKnown[d] = nil
            local nm = "?"
            pcall(function() nm = d:GetFullName():gsub("^.-PlayerGui%.", ""):sub(1, 110) end)
            out(ts() .. "UI HIDE  " .. nm)
        end
    end
end

-- [D] player + death state
local lastPlayer
local function playerCheck()
    local pp = playerPos()
    local c = lp.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    local s = (pp and string.format("%d,%d,%d", r5(pp.X), r5(pp.Y), r5(pp.Z)) or "noHRP") .. (h and h.Health <= 0 and " DEAD" or "")
    if s ~= lastPlayer then lastPlayer = s out(ts() .. "PLAYER @ " .. s) end
end

local nextSave, tick2 = 20, 0
while os.clock() - t0 < DURATION do
    pcall(modeCheck)
    pcall(bossScan)
    pcall(playerCheck)
    tick2 += 1
    if tick2 % 2 == 0 then pcall(uiScan) end
    if os.clock() - t0 >= nextSave then nextSave += 20 save() end
    task.wait(1)
end
out("=== done (" .. #lines .. " lines) ===")
save()
