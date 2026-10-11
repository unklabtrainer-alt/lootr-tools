-- discover.lua  (read-only)
-- Scans the game for dungeon / raid / boss-rush definitions and prints them.
-- It never calls InvokeServer / FireServer. It only reads instance names and
-- (pcall-wrapped) require()s ModuleScripts whose names look relevant.
-- Output: console + "discover_output.txt" (if writefile exists) + clipboard (if setclipboard exists).

local RS        = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local KEYWORDS = { "dungeon", "raid", "boss", "rush", "portal", "lobby", "difficult", "mode", "map", "queue", "expedition" }
local SERVICES = { "DungeonQueueService", "DungeonRunService", "RaidRunService", "BossRushRunService", "RaidShopService" }

local lines = {}
local function out(s)
    s = tostring(s)
    lines[#lines + 1] = s
    print(s)
end

local function matches(name)
    local l = string.lower(name)
    for _, k in ipairs(KEYWORDS) do
        if string.find(l, k, 1, true) then return true end
    end
    return false
end

local function fullName(inst)
    local ok, r = pcall(function() return inst:GetFullName() end)
    return ok and r or tostring(inst)
end

local function childList(inst, cap)
    local names, n = {}, 0
    for _, c in ipairs(inst:GetChildren()) do
        n += 1
        if n <= cap then names[#names + 1] = c.Name .. "<" .. c.ClassName .. ">" end
    end
    local s = table.concat(names, ", ")
    if n > cap then s = s .. (", ... +" .. (n - cap) .. " more") end
    return s, n
end

-- Dump a table: keys + value types, recursing a limited depth.
local function dumpTable(t, depth, maxDepth, indent, seen)
    seen = seen or {}
    if seen[t] then out(indent .. "<cycle>") return end
    seen[t] = true
    local count = 0
    for k, v in pairs(t) do
        count += 1
        if count > 60 then out(indent .. "... (truncated)") break end
        local vt = typeof(v)
        if vt == "table" and depth < maxDepth then
            out(indent .. tostring(k) .. " = {")
            dumpTable(v, depth + 1, maxDepth, indent .. "  ", seen)
            out(indent .. "}")
        elseif vt == "string" or vt == "number" or vt == "boolean" then
            out(indent .. tostring(k) .. " = " .. tostring(v))
        else
            out(indent .. tostring(k) .. " : " .. vt)
        end
    end
end

out("=== discover.lua  PlaceId=" .. tostring(game.PlaceId) .. "  JobId=" .. tostring(game.JobId))

-- 1) Remotes under the services the script already talks to
out("\n--- [1] Known services under ReplicatedStorage ---")
for _, svcName in ipairs(SERVICES) do
    local svc = RS:FindFirstChild(svcName, true)
    if svc then
        out(svcName .. " -> " .. fullName(svc))
        for _, folder in ipairs(svc:GetChildren()) do
            local s = childList(folder, 40)
            out("  " .. folder.Name .. "<" .. folder.ClassName .. ">: " .. s)
        end
    else
        out(svcName .. " -> NOT FOUND")
    end
end

-- 2) Every instance in ReplicatedStorage whose name looks relevant
out("\n--- [2] ReplicatedStorage instances with relevant names ---")
local modules = {}
for _, d in ipairs(RS:GetDescendants()) do
    if matches(d.Name) then
        local s, n = childList(d, 25)
        out(fullName(d) .. "  <" .. d.ClassName .. ">  children=" .. n .. (n > 0 and ("  [" .. s .. "]") or ""))
        if d:IsA("ModuleScript") then modules[#modules + 1] = d end
    end
end

-- 3) Workspace containers the script references (Dungeon_Container, *_NPCs, lobby portals)
out("\n--- [3] Workspace instances with relevant names (depth-limited) ---")
local function walk(inst, depth)
    if depth > 4 then return end
    for _, c in ipairs(inst:GetChildren()) do
        if matches(c.Name) and not c:IsA("BasePart") then
            local s, n = childList(c, 25)
            out(fullName(c) .. "  <" .. c.ClassName .. ">  children=" .. n .. (n > 0 and ("  [" .. s .. "]") or ""))
        end
        if #c:GetChildren() > 0 and not c:IsA("Terrain") and not c:IsA("Camera") then
            walk(c, depth + 1)
        end
    end
end
pcall(walk, Workspace, 0)

-- 4) Require relevant ModuleScripts and dump their shape
out("\n--- [4] Relevant ModuleScript contents (require, 3 levels) ---")
if #modules == 0 then
    out("(no relevant ModuleScripts found in ReplicatedStorage)")
end
for _, m in ipairs(modules) do
    out("\n# " .. fullName(m))
    local ok, res = pcall(require, m)
    if not ok then
        out("  require failed: " .. tostring(res))
    elseif type(res) == "table" then
        dumpTable(res, 1, 3, "  ")
    else
        out("  returns " .. typeof(res) .. ": " .. tostring(res))
    end
end

out("\n=== done (" .. #lines .. " lines) ===")

local text = table.concat(lines, "\n")
if writefile then pcall(writefile, "discover_output.txt", text) out("saved to discover_output.txt in your executor workspace") end
if setclipboard then pcall(setclipboard, text) out("copied to clipboard") end
