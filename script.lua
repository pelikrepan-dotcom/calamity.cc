local g = getinfo or debug.getinfo
local h = {}
local x, y
setthreadidentity(2)
for i, v in getgc(true) do
    if typeof(v) == "table" then
        local a = rawget(v, "Detected")
        local b = rawget(v, "Kill")
        if typeof(a) == "function" and not x then
            x = a
            local o; o = hookfunction(x, function(c, f, n) return true end)
            table.insert(h, x)
        end
        if rawget(v, "Variables") and rawget(v, "Process") and typeof(b) == "function" and not y then
            y = b
            local o; o = hookfunction(y, function(f) end)
            table.insert(h, y)
        end
    end
end
local o; o = hookfunction(getrenv().debug.info, newcclosure(function(...)
    local a, f = ...
    if x and a == x then return coroutine.yield(coroutine.running()) end
    return o(...)
end))
setthreadidentity(7)

library = loadstring(game:HttpGet("https://raw.githubusercontent.com/pelikrepan-dotcom/calamity.cc/refs/heads/main/true%20library.lua"))()

local players = game:GetService("Players")
local uis = game:GetService("UserInputService")
local runservice = game:GetService("RunService")
local workspace = game:GetService("Workspace")
local camera = workspace.CurrentCamera
local localplayer = players.LocalPlayer
local mouse = localplayer:GetMouse()
local flags = library.flags

local cfg = {
    silent = {
        enabled = false,
        hitpart = "Closest Part",
        prediction_enabled = false,
        prediction = { x = 0.133, y = 0.133, z = 0.133 },
        fov = {
            enabled = false,
            visible = false,
            mode = "3D",
            color = Color3.fromRGB(0, 17, 255),
            size = { x = 10, y = 10, z = 10 },
        },
        distance_enabled = false,
        max_distance = 300,
    },
    camlock = {
        enabled = false,
        active = false,
        hitpart = "Closest Part",
        smooth = { x = 40, y = 40, z = 40 },
        prediction_enabled = false,
        prediction = { x = 0.133, y = 0.133, z = 0.133 },
        fov = {
            enabled = false,
            visible = false,
            mode = "3D",
            color = Color3.fromRGB(0, 17, 255),
            size = { x = 10, y = 10, z = 10 },
        },
        distance_enabled = false,
        max_distance = 300,
    },
    spread = {
        enabled = false,
        amount = 1,
        specific_enabled = false,
        weapons = {},
    },
    rapidfire = {
        enabled = false,
        delay = 0.01,
        specific_enabled = false,
        weapons = {},
    },
    hitbox = {
        enabled = false,
        size = 5,
    },
    targetline = {
        enabled = false,
        thickness = 2.2,
        transparency = 0.8,
        vulnerable = Color3.fromRGB(100, 149, 237),
        invulnerable = Color3.fromRGB(150, 150, 150),
    },
    esp = {
        enabled = false,
        color = Color3.fromRGB(255, 255, 255),
        target_color = Color3.fromRGB(255, 0, 0),
        display_name = false,
        name_above = false,
    },
    headless = {
        enabled = false,
        remove_face = false,
    },
    settings = {
        visible_check = true,
        knock_check = true,
        self_knock_check = true,
        knife_check = true,
    },
    walkspeed = {
        enabled = false,
        active = false,
        amount = 35,
    },
    jumppower = {
        enabled = false,
        active = false,
        amount = 100,
    },
}

local currenttarget = nil
local silentaimactive = false
local esplabels = {}
local isfiring = false
local lastrapidfire = 0
local lasttriggerclick = 0
local lasttargetscan = 0
local lastvisibletarget = nil
local scanrate = 1 / 20

local rayparams = RaycastParams.new()
rayparams.FilterType = Enum.RaycastFilterType.Exclude
rayparams.IgnoreWater = true

local fovparts = {
    silentaim = Instance.new("Part"),
    camlock = Instance.new("Part"),
}

for name, part in pairs(fovparts) do
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.CastShadow = false
    part.Transparency = 1
    part.BrickColor = BrickColor.new("Grey")
    part.Material = Enum.Material.Neon
    part.Name = "calamity_fov_" .. name
    part.Parent = workspace
end

local fov2dboxes = { silentaim = {}, camlock = {} }
for key in pairs(fov2dboxes) do
    for i = 1, 4 do
        local line = Drawing.new("Line")
        line.Thickness = 1.5
        line.Color = Color3.fromRGB(150, 150, 150)
        line.Visible = false
        line.ZIndex = 5
        fov2dboxes[key][i] = line
    end
end

local targetline = Drawing.new("Line")
targetline.Visible = false
targetline.ZIndex = 999

local function getplayerpriority(player)
    local pb = library and library.player_buttons
    if pb and pb[player.Name] and pb[player.Name].priority then
        return pb[player.Name].priority.Text
    end
    return "Neutral"
end

local function playerknocked(player)
    if not cfg.settings.knock_check then return false end
    if not player.Character then return false end
    local be = player.Character:FindFirstChild("BodyEffects")
    if not be then return false end
    local ko = be:FindFirstChild("K.O")
    if ko and ko.Value then return true end
    local kn = be:FindFirstChild("Knocked")
    if kn and kn.Value then return true end
    return false
end

local function selfknocked()
    if not cfg.settings.self_knock_check then return false end
    if not localplayer.Character then return false end
    local be = localplayer.Character:FindFirstChild("BodyEffects")
    if not be then return false end
    local ko = be:FindFirstChild("K.O")
    if ko and ko.Value then return true end
    local kn = be:FindFirstChild("Knocked")
    if kn and kn.Value then return true end
    return false
end

local function holdingknife()
    if not cfg.settings.knife_check then return false end
    local char = localplayer.Character
    if not char then return false end
    local tool = char:FindFirstChildOfClass("Tool")
    return tool and tool.Name == "[Knife]"
end

local function cansee(part)
    if not cfg.settings.visible_check then return true end
    if not part or not part.Parent then return false end
    local char = part.Parent
    local origin = camera.CFrame.Position
    local dir = (part.Position - origin).Unit * (part.Position - origin).Magnitude
    rayparams.FilterDescendantsInstances = { localplayer.Character, char, fovparts.silentaim, fovparts.camlock }
    local result = workspace:Raycast(origin, dir, rayparams)
    return result == nil or result.Instance:IsDescendantOf(char)
end

local function withindistance(part, enabled, maxdist)
    if not enabled then return true end
    if not part or not part.Parent then return false end
    local char = localplayer.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    return (hrp.Position - part.Position).Magnitude <= maxdist
end

local function getbodyparts(char)
    return {
        char:FindFirstChild("Head"), char:FindFirstChild("UpperTorso"), char:FindFirstChild("HumanoidRootPart"),
        char:FindFirstChild("LowerTorso"), char:FindFirstChild("LeftUpperArm"), char:FindFirstChild("RightUpperArm"),
        char:FindFirstChild("LeftLowerArm"), char:FindFirstChild("RightLowerArm"), char:FindFirstChild("LeftHand"),
        char:FindFirstChild("RightHand"), char:FindFirstChild("LeftUpperLeg"), char:FindFirstChild("RightUpperLeg"),
        char:FindFirstChild("LeftLowerLeg"), char:FindFirstChild("RightLowerLeg"), char:FindFirstChild("LeftFoot"),
        char:FindFirstChild("RightFoot"),
    }
end

local function closestbodypart(char)
    local closest, shortest = nil, math.huge
    local mpos = uis:GetMouseLocation()
    for _, part in pairs(getbodyparts(char)) do
        if part then
            local sp, on = camera:WorldToViewportPoint(part.Position)
            if on then
                local d = ((sp.X - mpos.X)^2 + (sp.Y - mpos.Y)^2)^0.5
                if d < shortest then shortest = d closest = part end
            end
        end
    end
    return closest
end

local function partinfov3d(hrp, fovcfg)
    if not fovcfg.enabled then return true end
    local fovsize = hrp.Size + Vector3.new(fovcfg.size.x, fovcfg.size.y, fovcfg.size.z)
    local mpos = uis:GetMouseLocation()
    local ray = camera:ViewportPointToRay(mpos.X, mpos.Y)
    local cf = hrp.CFrame
    local size = fovsize / 2
    local lo = cf:PointToObjectSpace(ray.Origin)
    local ld = cf:VectorToObjectSpace(ray.Direction * 1000)
    local tmin, tmax = -math.huge, math.huge
    for _, axis in ipairs({"X","Y","Z"}) do
        local oa, da, sa = lo[axis], ld[axis], size[axis]
        if math.abs(da) < 1e-8 then
            if oa < -sa or oa > sa then return false end
        else
            local t1, t2 = (-sa - oa)/da, (sa - oa)/da
            if t1 > t2 then t1, t2 = t2, t1 end
            tmin = math.max(tmin, t1)
            tmax = math.min(tmax, t2)
            if tmin > tmax then return false end
        end
    end
    return tmax > 0
end

local function getscreenbounds2d(hrp, fovcfg)
    local sx = (hrp.Size.X + fovcfg.size.x)/2
    local sy = (hrp.Size.Y + fovcfg.size.y)/2
    local sz = (hrp.Size.Z + fovcfg.size.z)/2
    local cf = hrp.CFrame
    local offsets = {
        Vector3.new(sx,sy,sz), Vector3.new(-sx,sy,sz), Vector3.new(sx,-sy,sz), Vector3.new(-sx,-sy,sz),
        Vector3.new(sx,sy,-sz), Vector3.new(-sx,sy,-sz), Vector3.new(sx,-sy,-sz), Vector3.new(-sx,-sy,-sz),
    }
    local minx, miny, maxx, maxy = math.huge, math.huge, -math.huge, -math.huge
    local valid = false
    for _, off in ipairs(offsets) do
        local s = camera:WorldToViewportPoint(cf:PointToWorldSpace(off))
        if s.Z > 0 then
            valid = true
            if s.X < minx then minx = s.X end if s.Y < miny then miny = s.Y end
            if s.X > maxx then maxx = s.X end if s.Y > maxy then maxy = s.Y end
        end
    end
    if not valid then return nil, nil end
    return Vector2.new(minx, miny), Vector2.new(maxx, maxy)
end

local function mouseinfov3d(fovpart)
    if not fovpart.Parent then return false end
    local mpos = uis:GetMouseLocation()
    local ray = camera:ViewportPointToRay(mpos.X, mpos.Y)
    local cf = fovpart.CFrame
    local size = fovpart.Size/2
    local lo = cf:PointToObjectSpace(ray.Origin)
    local ld = cf:VectorToObjectSpace(ray.Direction*1000)
    local tmin, tmax = -math.huge, math.huge
    for _, axis in ipairs({"X","Y","Z"}) do
        local oa, da, sa = lo[axis], ld[axis], size[axis]
        if math.abs(da) < 1e-8 then
            if oa < -sa or oa > sa then return false end
        else
            local t1, t2 = (-sa-oa)/da, (sa-oa)/da
            if t1 > t2 then t1, t2 = t2, t1 end
            tmin = math.max(tmin, t1)
            tmax = math.min(tmax, t2)
            if tmin > tmax then return false end
        end
    end
    return tmax > 0
end

local function mouseinfovconfig(fovcfg, hrp)
    if not fovcfg.enabled then return true end
    if not hrp or not hrp.Parent then return false end
    if fovcfg.mode == "2D" then
        local tl, br = getscreenbounds2d(hrp, fovcfg)
        if not tl then return false end
        local mpos = uis:GetMouseLocation()
        return mpos.X >= tl.X and mpos.X <= br.X and mpos.Y >= tl.Y and mpos.Y <= br.Y
    end
    return partinfov3d(hrp, fovcfg)
end

local function setbox2d(lines, tl, br, color)
    lines[1].From = tl lines[1].To = Vector2.new(br.X, tl.Y)
    lines[2].From = Vector2.new(tl.X, br.Y) lines[2].To = br
    lines[3].From = tl lines[3].To = Vector2.new(tl.X, br.Y)
    lines[4].From = Vector2.new(br.X, tl.Y) lines[4].To = br
    for _, l in ipairs(lines) do l.Color = color l.Visible = true end
end

local function hidebox2d(lines)
    for _, l in ipairs(lines) do l.Visible = false end
end

local function updatefovbox(fovpart, lines2d, fovcfg, isactive)
    if not fovcfg.enabled then
        fovpart.Transparency = 1 hidebox2d(lines2d) return
    end
    if isactive and currenttarget and currenttarget.Parent then
        local hrp = currenttarget.Parent:FindFirstChild("HumanoidRootPart")
        if hrp then
            if fovcfg.mode == "2D" then
                fovpart.Transparency = 1
                if fovcfg.visible then
                    local tl, br = getscreenbounds2d(hrp, fovcfg)
                    if tl and br then
                        local mpos = uis:GetMouseLocation()
                        local inside = mpos.X >= tl.X and mpos.X <= br.X and mpos.Y >= tl.Y and mpos.Y <= br.Y
                        setbox2d(lines2d, tl, br, inside and fovcfg.color or Color3.fromRGB(150,150,150))
                    else hidebox2d(lines2d) end
                else hidebox2d(lines2d) end
            else
                hidebox2d(lines2d)
                fovpart.Size = hrp.Size + Vector3.new(fovcfg.size.x, fovcfg.size.y, fovcfg.size.z)
                fovpart.CFrame = hrp.CFrame
                if fovcfg.visible then
                    fovpart.Transparency = 0.85
                    fovpart.BrickColor = mouseinfov3d(fovpart) and BrickColor.new(fovcfg.color) or BrickColor.new("Grey")
                else fovpart.Transparency = 1 end
            end
        else fovpart.Transparency = 1 hidebox2d(lines2d) end
    else fovpart.Transparency = 1 hidebox2d(lines2d) end
end

local function findtarget(fovcfg, dist_enabled, maxdist, knifecheck)
    if knifecheck and holdingknife() then return nil end
    local mpos = uis:GetMouseLocation()

    local enemies = {}
    for _, player in pairs(players:GetPlayers()) do
        if player ~= localplayer and player.Character then
            if getplayerpriority(player) == "Enemy" then
                table.insert(enemies, player)
            end
        end
    end

    local pool = #enemies > 0 and enemies or nil
    if not pool then
        pool = {}
        for _, player in pairs(players:GetPlayers()) do
            if player ~= localplayer and player.Character then
                table.insert(pool, player)
            end
        end
    end

    local best, bestdist = nil, math.huge
    for _, player in ipairs(pool) do
        if playerknocked(player) then continue end
        local char = player.Character
        if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        local sp, on = camera:WorldToViewportPoint(hrp.Position)
        if not on then continue end
        if fovcfg and not mouseinfovconfig(fovcfg, hrp) then continue end
        if not cansee(hrp) then continue end
        if not withindistance(hrp, dist_enabled, maxdist) then continue end
        local d = ((sp.X - mpos.X)^2 + (sp.Y - mpos.Y)^2)^0.5
        if d < bestdist then bestdist = d best = hrp end
    end

    if best then return closestbodypart(best.Parent) or best end
    return nil
end

local function predictedpos(part, pred_enabled, pred)
    if not pred_enabled then return part.Position end
    local vel = part.AssemblyLinearVelocity
    return part.Position + Vector3.new(vel.X * pred.x, vel.Y * pred.y, vel.Z * pred.z)
end

local function elasticout(t)
    local p = 0.3
    return math.pow(2, -10*t) * math.sin((t - p/4) * (2*math.pi)/p) + 1
end

local function sineinout(t)
    return -(math.cos(math.pi*t) - 1)/2
end

local function applycamlock()
    if not cfg.camlock.active then return end
    if selfknocked() then
        cfg.camlock.active = false currenttarget = nil lastvisibletarget = nil targetline.Visible = false return
    end
    if holdingknife() then return end

    local target = nil
    if currenttarget and currenttarget.Parent then
        local player = players:GetPlayerFromCharacter(currenttarget.Parent)
        if player and not playerknocked(player) then
            local tp
            if cfg.camlock.hitpart == "Closest Part" then
                local now = tick()
                if now - lasttargetscan >= scanrate then
                    lasttargetscan = now
                    tp = closestbodypart(currenttarget.Parent)
                    if tp then currenttarget = tp end
                else tp = currenttarget end
            else
                tp = currenttarget.Parent:FindFirstChild(cfg.camlock.hitpart)
            end
            if tp and cansee(tp) and withindistance(tp, cfg.camlock.distance_enabled, cfg.camlock.max_distance) then
                lastvisibletarget = tp
                target = tp
            end
        else
            cfg.camlock.active = false currenttarget = nil lastvisibletarget = nil targetline.Visible = false return
        end
    end

    if not target then
        if lastvisibletarget and lastvisibletarget.Parent then
            local player = players:GetPlayerFromCharacter(lastvisibletarget.Parent)
            if player and not playerknocked(player) and cansee(lastvisibletarget) then
                currenttarget = lastvisibletarget
            end
        end
        return
    end

    local targetpos = predictedpos(target, cfg.camlock.prediction_enabled, cfg.camlock.prediction)
    local camcf = camera.CFrame
    local targetcf = CFrame.new(camcf.Position, targetpos)
    local sm = cfg.camlock.smooth
    local bax, bay, baz = 1/sm.x, 1/sm.y, 1/sm.z
    local eax = elasticout(math.min(bax, 1))
    local eay = elasticout(math.min(bay, 1))
    local eaz = elasticout(math.min(baz, 1))
    local avgea = (eax+eay+eaz)/3
    local avgba = (bax+bay+baz)/3
    local smoothcf = camcf:Lerp(targetcf, avgea*avgba)
    camera.CFrame = smoothcf:Lerp(targetcf, sineinout(math.min(avgba,1))*avgba)
end

local function updatetargetline()
    if not cfg.targetline.enabled then targetline.Visible = false return end
    if not currenttarget or not currenttarget.Parent or (not silentaimactive and not cfg.camlock.active) then
        targetline.Visible = false return
    end
    local hrp = currenttarget.Parent:FindFirstChild("HumanoidRootPart")
    if not hrp then targetline.Visible = false return end
    local sp, on = camera:WorldToViewportPoint(hrp.Position)
    if on and sp.Z > 0 then
        local mpos = uis:GetMouseLocation()
        targetline.From = Vector2.new(mpos.X, mpos.Y)
        targetline.To = Vector2.new(sp.X, sp.Y)
        targetline.Thickness = cfg.targetline.thickness
        targetline.Transparency = cfg.targetline.transparency
        targetline.Color = cansee(currenttarget) and cfg.targetline.vulnerable or cfg.targetline.invulnerable
        targetline.Visible = true
    else targetline.Visible = false end
end

local function getrapidgun()
    local char = localplayer.Character
    if not char then return nil end
    for _, tool in next, char:GetChildren() do
        if tool:IsA("Tool") and tool:FindFirstChild("Ammo") then return tool end
    end
    return nil
end

local function patchtool(tool)
    pcall(function()
        for _, conn in pairs(getconnections(tool.Activated)) do
            local info = debug.getinfo(conn.Function)
            for i = 1, info.nups do
                local val = debug.getupvalue(conn.Function, i)
                if type(val) == "number" then debug.setupvalue(conn.Function, i, 0) end
            end
        end
    end)
end

local function rapidfire()
    if not cfg.rapidfire.enabled then isfiring = false return end
    if not isfiring then return end
    if tick() - lastrapidfire < cfg.rapidfire.delay then return end
    local gun = getrapidgun()
    if not gun then return end
    if cfg.rapidfire.specific_enabled then
        local valid = false
        for _, wname in pairs(cfg.rapidfire.weapons) do
            local clean = wname:gsub("%[",""):gsub("%]","")
            if gun.Name == wname or gun.Name:find(clean) then valid = true break end
        end
        if not valid then isfiring = false return end
    end
    gun:Activate()
    lastrapidfire = tick()
end

local function refreshesp()
    if not cfg.esp.enabled then
        for uid, esp in pairs(esplabels) do esp.nametag:Remove() esplabels[uid] = nil end
        return
    end
    for uid, esp in pairs(esplabels) do
        local player = esp.player
        if not player or not player.Parent then
            esp.nametag:Remove() esplabels[uid] = nil continue
        end
        local char = player.Character
        if char and char.Parent and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Head") then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then esp.nametag.Visible = false continue end
            local head, hrp = char.Head, char.HumanoidRootPart
            local worldpos = cfg.esp.name_above and (head.Position + Vector3.new(0,1.5,0)) or (hrp.Position - Vector3.new(0,2.8,0))
            local esppos, on = camera:WorldToViewportPoint(worldpos)
            if on and esppos.Z > 0 then
                local np = Vector2.new(esppos.X, esppos.Y)
                local cur = esp.nametag.Position
                if math.abs(np.X-cur.X) > 0.5 or math.abs(np.Y-cur.Y) > 0.5 then esp.nametag.Position = np end
                esp.nametag.Text = cfg.esp.display_name and player.DisplayName or player.Name
                esp.nametag.Color = (currenttarget and currenttarget.Parent == char) and cfg.esp.target_color or cfg.esp.color
                esp.nametag.Visible = true
            else esp.nametag.Visible = false end
        else esp.nametag.Visible = false end
    end
end

local function addesp(player)
    if player == localplayer then return end
    if not cfg.esp.enabled then return end
    local esp = { player = player, nametag = Drawing.new("Text") }
    esp.nametag.Size = 14
    esp.nametag.Center = true
    esp.nametag.Outline = true
    esp.nametag.OutlineColor = Color3.fromRGB(0,0,0)
    esp.nametag.Color = cfg.esp.color
    esp.nametag.Font = Drawing.Fonts.Plex
    esp.nametag.Visible = false
    esp.nametag.ZIndex = 1000
    esplabels[player.UserId] = esp
end

local function removeesp(player)
    local esp = esplabels[player.UserId]
    if esp then esp.nametag:Remove() esplabels[player.UserId] = nil end
end

local function applyheadless(char)
    if not cfg.headless.enabled then return end
    if not char then return end
    local head = char:FindFirstChild("Head")
    if head then
        head.Transparency = 1 head.CanCollide = false
        local face = head:FindFirstChild("face")
        if face then face.Transparency = 1 end
    end
    if cfg.headless.remove_face then
        for _, acc in ipairs(char:GetChildren()) do
            if acc:IsA("Accessory") and acc.AccessoryType == Enum.AccessoryType.Face then
                local handle = acc:FindFirstChild("Handle")
                if handle then handle.Transparency = 1 handle.CanCollide = false end
            end
        end
    end
    char.ChildAdded:Connect(function(child)
        if not cfg.headless.enabled then return end
        if child:IsA("Accessory") and child.AccessoryType == Enum.AccessoryType.Face and cfg.headless.remove_face then
            local handle = child:FindFirstChild("Handle") or child:WaitForChild("Handle", 5)
            if handle then handle.Transparency = 1 handle.CanCollide = false end
        end
    end)
end

for _, player in pairs(players:GetPlayers()) do
    if player ~= localplayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        addesp(player)
    end
    player.CharacterAdded:Connect(function(char)
        removeesp(player) char:WaitForChild("HumanoidRootPart") task.wait(0.1) addesp(player)
    end)
    player.CharacterRemoving:Connect(function() removeesp(player) end)
end

players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(char)
        removeesp(player) char:WaitForChild("HumanoidRootPart") task.wait(0.1) addesp(player)
    end)
    player.CharacterRemoving:Connect(function() removeesp(player) end)
end)
players.PlayerRemoving:Connect(function(player) removeesp(player) end)

if localplayer.Character then
    applyheadless(localplayer.Character)
    local char = localplayer.Character
    char.ChildAdded:Connect(function(tool)
        if tool:IsA("Tool") and cfg.rapidfire.enabled then patchtool(tool) end
    end)
end

localplayer.CharacterAdded:Connect(function(char)
    applyheadless(char)
    char.ChildAdded:Connect(function(tool)
        if tool:IsA("Tool") and cfg.rapidfire.enabled then patchtool(tool) end
    end)
end)

local grm = getrawmetatable(game)
local oldindex = grm.__index
setreadonly(grm, false)

grm.__index = newcclosure(function(self, key)
    if not checkcaller() and self == mouse and cfg.silent.enabled then
        if key == "Hit" then
            if not silentaimactive then return oldindex(self, key) end
            if not currenttarget or not currenttarget.Parent then return oldindex(self, key) end
            local player = players:GetPlayerFromCharacter(currenttarget.Parent)
            if not player then return oldindex(self, key) end
            if playerknocked(player) then return oldindex(self, key) end
            if not cansee(currenttarget) then return oldindex(self, key) end
            if not withindistance(currenttarget, cfg.silent.distance_enabled, cfg.silent.max_distance) then return oldindex(self, key) end
            if not mouseinfovconfig(cfg.silent.fov, currenttarget.Parent:FindFirstChild("HumanoidRootPart")) then return oldindex(self, key) end
            local predpos = predictedpos(currenttarget, cfg.silent.prediction_enabled, cfg.silent.prediction)
            return CFrame.new(predpos)
        end
    end
    return oldindex(self, key)
end)

local oldrandom
oldrandom = hookfunction(math.random, newcclosure(function(...)
    local args = {...}
    if checkcaller() then return oldrandom(...) end
    if (#args == 0) or (args[1] == -0.05 and args[2] == 0.05) or (args[1] == -0.1) or (args[1] == -0.05) then
        if cfg.spread.enabled then
            if cfg.spread.specific_enabled then
                local tool = localplayer.Character and localplayer.Character:FindFirstChildOfClass("Tool")
                if tool then
                    local found = false
                    for _, wname in pairs(cfg.spread.weapons) do
                        if tool.Name == wname then found = true break end
                    end
                    if found then return oldrandom(...) * (cfg.spread.amount / 100) end
                end
            else
                return oldrandom(...) * (cfg.spread.amount / 100)
            end
        end
    end
    return oldrandom(...)
end))

game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)

local window = library:window({
    name = "Calamity.Wtf",
    size = UDim2.fromOffset(500, 600),
})

local combatTab   = window:tab({ name = "combat" })
local movementTab = window:tab({ name = "movement" })
local visualTab   = window:tab({ name = "visual" })
local settingsTab = window:tab({ name = "settings" })
local configTab   = window:tab({ name = "config" })

local weaponList = {
    "[Double-Barrel SG]", "[TacticalShotgun]", "[Revolver]", "[Shotgun]",
    "[DrumShotgun]", "[AK-47]", "[AR]", "[AUG]", "[P90]", "[Silencer]",
    "[Drum Gun]", "[Silencer AR]", "[Glock]",
}

do
    local silentSection = combatTab:section({ name = "silent aim" })

    silentSection:toggle({
        name = "enabled",
        flag = "silent_enabled",
        default = false,
        callback = function(v) cfg.silent.enabled = v end,
    })

    silentSection:dropdown({
        name = "hit part",
        flag = "silent_hitpart",
        items = { "Closest Part", "Head", "UpperTorso", "LowerTorso", "HumanoidRootPart" },
        default = "Closest Part",
        multi = false,
        callback = function(v) cfg.silent.hitpart = v end,
    })

    silentSection:toggle({
        name = "enabled prediction",
        flag = "silent_pred_enabled",
        default = false,
        callback = function(v) cfg.silent.prediction_enabled = v end,
    })

    silentSection:textbox({
        flag = "silent_pred_x",
        default = "0.133",
        placeholder = "prediction x",
        callback = function(v) local n = tonumber(v) if n then cfg.silent.prediction.x = n end end,
    })

    silentSection:textbox({
        flag = "silent_pred_y",
        default = "0.133",
        placeholder = "prediction y",
        callback = function(v) local n = tonumber(v) if n then cfg.silent.prediction.y = n end end,
    })

    silentSection:textbox({
        flag = "silent_pred_z",
        default = "0.133",
        placeholder = "prediction z",
        callback = function(v) local n = tonumber(v) if n then cfg.silent.prediction.z = n end end,
    })

    silentSection:toggle({
        name = "distance check",
        flag = "silent_dist_enabled",
        default = false,
        callback = function(v) cfg.silent.distance_enabled = v end,
    })

    silentSection:slider({
        name = "max distance",
        flag = "silent_dist_max",
        min = 10,
        max = 1000,
        default = 300,
        interval = 10,
        suffix = "m",
        callback = function(v) cfg.silent.max_distance = v end,
    })

    local silentFovSection = combatTab:section({ name = "silent aim fov", side = "right" })

    silentFovSection:toggle({
        name = "enabled",
        flag = "silent_fov_enabled",
        default = false,
        callback = function(v) cfg.silent.fov.enabled = v end,
    })

    silentFovSection:toggle({
        name = "visible",
        flag = "silent_fov_visible",
        default = false,
        callback = function(v) cfg.silent.fov.visible = v end,
    })

    silentFovSection:dropdown({
        name = "mode",
        flag = "silent_fov_mode",
        items = { "3D", "2D" },
        default = "3D",
        multi = false,
        callback = function(v) cfg.silent.fov.mode = v end,
    })

    silentFovSection:colorpicker({
        flag = "silent_fov_color",
        color = Color3.fromRGB(0, 17, 255),
        callback = function(v) cfg.silent.fov.color = v end,
    })

    silentFovSection:textbox({
        flag = "silent_fov_x",
        default = "10",
        placeholder = "size x",
        callback = function(v) local n = tonumber(v) if n then cfg.silent.fov.size.x = n end end,
    })

    silentFovSection:textbox({
        flag = "silent_fov_y",
        default = "10",
        placeholder = "size y",
        callback = function(v) local n = tonumber(v) if n then cfg.silent.fov.size.y = n end end,
    })

    silentFovSection:textbox({
        flag = "silent_fov_z",
        default = "10",
        placeholder = "size z",
        callback = function(v) local n = tonumber(v) if n then cfg.silent.fov.size.z = n end end,
    })

    local camSection = combatTab:section({ name = "camera lock" })

    camSection:toggle({
        name = "enabled",
        flag = "cam_enabled",
        default = false,
        callback = function(v) cfg.camlock.enabled = v end,
    })

    camSection:keybind({
        name = "toggle camera lock",
        flag = "cam_keybind",
        default = Enum.KeyCode.Q,
        display = "camera lock",
        callback = function(active)
            if not cfg.camlock.enabled then return end
            cfg.camlock.active = not cfg.camlock.active
            if cfg.camlock.active then
                local target = findtarget(cfg.camlock.fov, cfg.camlock.distance_enabled, cfg.camlock.max_distance, true)
                if target then
                    currenttarget = target lastvisibletarget = target
                    local player = players:GetPlayerFromCharacter(target.Parent)
                    if player then
                        library:notification({ text = "Locking To (" .. player.Name .. ") " .. player.DisplayName })
                    end
                else
                    cfg.camlock.active = false
                end
            else
                if not silentaimactive then
                    currenttarget = nil lastvisibletarget = nil targetline.Visible = false
                end
                library:notification({ text = "Camera Lock Off" })
            end
        end,
    })

    camSection:dropdown({
        name = "hit part",
        flag = "cam_hitpart",
        items = { "Closest Part", "Head", "UpperTorso", "LowerTorso", "HumanoidRootPart" },
        default = "Closest Part",
        multi = false,
        callback = function(v) cfg.camlock.hitpart = v end,
    })

    camSection:textbox({
        flag = "cam_smooth_x",
        default = "40",
        placeholder = "smooth x",
        callback = function(v) local n = tonumber(v) if n then cfg.camlock.smooth.x = n end end,
    })

    camSection:textbox({
        flag = "cam_smooth_y",
        default = "40",
        placeholder = "smooth y",
        callback = function(v) local n = tonumber(v) if n then cfg.camlock.smooth.y = n end end,
    })

    camSection:textbox({
        flag = "cam_smooth_z",
        default = "40",
        placeholder = "smooth z",
        callback = function(v) local n = tonumber(v) if n then cfg.camlock.smooth.z = n end end,
    })

    camSection:toggle({
        name = "enabled prediction",
        flag = "cam_pred_enabled",
        default = false,
        callback = function(v) cfg.camlock.prediction_enabled = v end,
    })

    camSection:textbox({
        flag = "cam_pred_x",
        default = "0.133",
        placeholder = "prediction x",
        callback = function(v) local n = tonumber(v) if n then cfg.camlock.prediction.x = n end end,
    })

    camSection:textbox({
        flag = "cam_pred_y",
        default = "0.133",
        placeholder = "prediction y",
        callback = function(v) local n = tonumber(v) if n then cfg.camlock.prediction.y = n end end,
    })

    camSection:textbox({
        flag = "cam_pred_z",
        default = "0.133",
        placeholder = "prediction z",
        callback = function(v) local n = tonumber(v) if n then cfg.camlock.prediction.z = n end end,
    })

    camSection:toggle({
        name = "distance check",
        flag = "cam_dist_enabled",
        default = false,
        callback = function(v) cfg.camlock.distance_enabled = v end,
    })

    camSection:slider({
        name = "max distance",
        flag = "cam_dist_max",
        min = 10,
        max = 1000,
        default = 300,
        interval = 10,
        suffix = "m",
        callback = function(v) cfg.camlock.max_distance = v end,
    })

    local camFovSection = combatTab:section({ name = "camera lock fov", side = "right" })

    camFovSection:toggle({
        name = "enabled",
        flag = "cam_fov_enabled",
        default = false,
        callback = function(v) cfg.camlock.fov.enabled = v end,
    })

    camFovSection:toggle({
        name = "visible",
        flag = "cam_fov_visible",
        default = false,
        callback = function(v) cfg.camlock.fov.visible = v end,
    })

    camFovSection:dropdown({
        name = "mode",
        flag = "cam_fov_mode",
        items = { "3D", "2D" },
        default = "3D",
        multi = false,
        callback = function(v) cfg.camlock.fov.mode = v end,
    })

    camFovSection:colorpicker({
        flag = "cam_fov_color",
        color = Color3.fromRGB(0, 17, 255),
        callback = function(v) cfg.camlock.fov.color = v end,
    })

    camFovSection:textbox({
        flag = "cam_fov_x",
        default = "10",
        placeholder = "size x",
        callback = function(v) local n = tonumber(v) if n then cfg.camlock.fov.size.x = n end end,
    })

    camFovSection:textbox({
        flag = "cam_fov_y",
        default = "10",
        placeholder = "size y",
        callback = function(v) local n = tonumber(v) if n then cfg.camlock.fov.size.y = n end end,
    })

    camFovSection:textbox({
        flag = "cam_fov_z",
        default = "10",
        placeholder = "size z",
        callback = function(v) local n = tonumber(v) if n then cfg.camlock.fov.size.z = n end end,
    })

    local spreadSection = combatTab:section({ name = "spread modification" })

    spreadSection:toggle({
        name = "enabled",
        flag = "spread_enabled",
        default = false,
        callback = function(v) cfg.spread.enabled = v end,
    })

    spreadSection:textbox({
        flag = "spread_amount",
        default = "1",
        placeholder = "amount (1-100)",
        callback = function(v) local n = tonumber(v) if n then cfg.spread.amount = math.clamp(n, 1, 100) end end,
    })

    spreadSection:toggle({
        name = "specific weapon",
        flag = "spread_specific",
        default = false,
        callback = function(v) cfg.spread.specific_enabled = v end,
    })

    spreadSection:dropdown({
        name = "weapon list",
        flag = "spread_weapons",
        items = weaponList,
        multi = true,
        callback = function(v) cfg.spread.weapons = type(v) == "table" and v or {v} end,
    })

    local rapidSection = combatTab:section({ name = "rapid fire", side = "right" })

    rapidSection:toggle({
        name = "enabled",
        flag = "rapid_enabled",
        default = false,
        callback = function(v) cfg.rapidfire.enabled = v end,
    })

    rapidSection:textbox({
        flag = "rapid_delay",
        default = "0.01",
        placeholder = "delay",
        callback = function(v) local n = tonumber(v) if n then cfg.rapidfire.delay = n end end,
    })

    rapidSection:toggle({
        name = "specific weapon",
        flag = "rapid_specific",
        default = false,
        callback = function(v) cfg.rapidfire.specific_enabled = v end,
    })

    rapidSection:dropdown({
        name = "weapon list",
        flag = "rapid_weapons",
        items = weaponList,
        multi = true,
        callback = function(v) cfg.rapidfire.weapons = type(v) == "table" and v or {v} end,
    })

    local hitboxSection = combatTab:section({ name = "hitbox expander", side = "right" })

    hitboxSection:toggle({
        name = "enabled",
        flag = "hitbox_enabled",
        default = false,
        callback = function(v)
            cfg.hitbox.enabled = v
            if not v then
                for _, player in pairs(players:GetPlayers()) do
                    if player ~= localplayer and player.Character then
                        local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            hrp.Size = Vector3.new(2, 2, 1)
                            hrp.Transparency = 1
                        end
                    end
                end
            end
        end,
    })

    hitboxSection:slider({
        name = "size",
        flag = "hitbox_size",
        min = 1,
        max = 20,
        default = 5,
        interval = 0.5,
        callback = function(v) cfg.hitbox.size = v end,
    })
end

do
    local wsSection = movementTab:section({ name = "walkspeed" })

    wsSection:toggle({
        name = "enabled",
        flag = "ws_enabled",
        default = false,
        callback = function(v)
            cfg.walkspeed.enabled = v
            if not v then
                cfg.walkspeed.active = false
                local hum = localplayer.Character and localplayer.Character:FindFirstChildOfClass("Humanoid")
                if hum then hum.WalkSpeed = 16 end
            end
        end,
    })

    wsSection:keybind({
        name = "toggle walkspeed",
        flag = "ws_keybind",
        default = Enum.KeyCode.V,
        display = "walkspeed",
        callback = function(active)
            if not cfg.walkspeed.enabled then return end
            cfg.walkspeed.active = not cfg.walkspeed.active
            local hum = localplayer.Character and localplayer.Character:FindFirstChildOfClass("Humanoid")
            if cfg.walkspeed.active then
                if hum then hum.WalkSpeed = cfg.walkspeed.amount end
                library:notification({ text = "Walkspeed On" })
            else
                if hum then hum.WalkSpeed = 16 end
                library:notification({ text = "Walkspeed Off" })
            end
        end,
    })

    wsSection:textbox({
        flag = "ws_amount",
        default = "35",
        placeholder = "speed amount",
        callback = function(v)
            local n = tonumber(v)
            if n then
                cfg.walkspeed.amount = n * 16
                if cfg.walkspeed.active then
                    local hum = localplayer.Character and localplayer.Character:FindFirstChildOfClass("Humanoid")
                    if hum then hum.WalkSpeed = cfg.walkspeed.amount end
                end
            end
        end,
    })

    local jpSection = movementTab:section({ name = "jump power", side = "right" })

    jpSection:toggle({
        name = "enabled",
        flag = "jp_enabled",
        default = false,
        callback = function(v)
            cfg.jumppower.enabled = v
            if not v then
                cfg.jumppower.active = false
                local hum = localplayer.Character and localplayer.Character:FindFirstChildOfClass("Humanoid")
                if hum then hum.JumpPower = 50 end
            end
        end,
    })

    jpSection:keybind({
        name = "toggle jump power",
        flag = "jp_keybind",
        default = Enum.KeyCode.J,
        display = "jump power",
        callback = function(active)
            if not cfg.jumppower.enabled then return end
            cfg.jumppower.active = not cfg.jumppower.active
            local hum = localplayer.Character and localplayer.Character:FindFirstChildOfClass("Humanoid")
            if cfg.jumppower.active then
                if hum then hum.JumpPower = cfg.jumppower.amount end
                library:notification({ text = "Jump Power On" })
            else
                if hum then hum.JumpPower = 50 end
                library:notification({ text = "Jump Power Off" })
            end
        end,
    })

    jpSection:textbox({
        flag = "jp_amount",
        default = "100",
        placeholder = "jump power",
        callback = function(v)
            local n = tonumber(v)
            if n then
                cfg.jumppower.amount = n
                if cfg.jumppower.active then
                    local hum = localplayer.Character and localplayer.Character:FindFirstChildOfClass("Humanoid")
                    if hum then hum.JumpPower = n end
                end
            end
        end,
    })
end

do
    local tlineSection = visualTab:section({ name = "target line" })

    tlineSection:toggle({
        name = "enabled",
        flag = "tline_enabled",
        default = false,
        callback = function(v) cfg.targetline.enabled = v end,
    })

    tlineSection:textbox({
        flag = "tline_thickness",
        default = "2.2",
        placeholder = "thickness",
        callback = function(v) local n = tonumber(v) if n then cfg.targetline.thickness = n targetline.Thickness = n end end,
    })

    tlineSection:textbox({
        flag = "tline_transparency",
        default = "0.8",
        placeholder = "transparency",
        callback = function(v) local n = tonumber(v) if n then cfg.targetline.transparency = n targetline.Transparency = n end end,
    })

    tlineSection:colorpicker({
        flag = "tline_vulnerable",
        color = Color3.fromRGB(100, 149, 237),
        callback = function(v) cfg.targetline.vulnerable = v end,
    })

    tlineSection:colorpicker({
        flag = "tline_invulnerable",
        color = Color3.fromRGB(150, 150, 150),
        callback = function(v) cfg.targetline.invulnerable = v end,
    })

    local espSection = visualTab:section({ name = "esp", side = "right" })

    espSection:toggle({
        name = "enabled",
        flag = "esp_enabled",
        default = false,
        callback = function(v) cfg.esp.enabled = v end,
    })

    espSection:colorpicker({
        flag = "esp_color",
        color = Color3.fromRGB(255, 255, 255),
        callback = function(v)
            cfg.esp.color = v
            for _, esp in pairs(esplabels) do esp.nametag.Color = v end
        end,
    })

    espSection:colorpicker({
        flag = "esp_target_color",
        color = Color3.fromRGB(255, 0, 0),
        callback = function(v) cfg.esp.target_color = v end,
    })

    espSection:toggle({
        name = "use display name",
        flag = "esp_displayname",
        default = false,
        callback = function(v) cfg.esp.display_name = v end,
    })

    espSection:toggle({
        name = "name above",
        flag = "esp_nameabove",
        default = false,
        callback = function(v) cfg.esp.name_above = v end,
    })

    local headlessSection = visualTab:section({ name = "headless" })

    headlessSection:toggle({
        name = "enabled",
        flag = "headless_enabled",
        default = false,
        callback = function(v)
            cfg.headless.enabled = v
            if v and localplayer.Character then applyheadless(localplayer.Character) end
        end,
    })

    headlessSection:toggle({
        name = "remove face accessories",
        flag = "headless_face",
        default = false,
        callback = function(v) cfg.headless.remove_face = v end,
    })
end

do
    local settSection = settingsTab:section({ name = "checks" })

    settSection:toggle({
        name = "visible check",
        flag = "check_visible",
        default = true,
        callback = function(v) cfg.settings.visible_check = v end,
    })

    settSection:toggle({
        name = "knock check",
        flag = "check_knock",
        default = true,
        callback = function(v) cfg.settings.knock_check = v end,
    })

    settSection:toggle({
        name = "self knock check",
        flag = "check_selfknock",
        default = true,
        callback = function(v) cfg.settings.self_knock_check = v end,
    })

    settSection:toggle({
        name = "knife check",
        flag = "check_knife",
        default = true,
        callback = function(v) cfg.settings.knife_check = v end,
    })
end

do
    local cfgSection = configTab:section({ name = "configuration" })
    local dir = "Calamity.Wtf/cfg/"

    cfgSection:textbox({ flag = "config_name_input", placeholder = "config name" })

    cfgSection:button({
        name = "save",
        callback = function()
            local name = flags["config_name_input"]
            if not name or name == "" then
                library:notification({ text = "enter a config name" })
                return
            end
            if not isfolder("Calamity.Wtf") then makefolder("Calamity.Wtf") end
            if not isfolder("Calamity.Wtf/cfg") then makefolder("Calamity.Wtf/cfg") end
            writefile(dir .. name .. ".cfg", library:get_config())
            library:notification({ text = "saved: " .. name })
            library:config_list_update()
        end,
    })

    library.config_holder = cfgSection:dropdown({ name = "configs", items = {}, flag = "config_name_list" })

    cfgSection:button({
        name = "load",
        callback = function()
            local name = flags["config_name_list"]
            if not name or name == "" then
                library:notification({ text = "select a config first" })
                return
            end
            library:load_config(readfile(dir .. name .. ".cfg"))
            library:notification({ text = "loaded: " .. name })
        end,
    })

    cfgSection:button({
        name = "delete",
        callback = function()
            local name = flags["config_name_list"]
            if not name or name == "" then
                library:notification({ text = "select a config first" })
                return
            end
            library:panel({
                name = "delete " .. name .. "?",
                options = { "Yes", "No" },
                callback = function(opt)
                    if opt == "Yes" then
                        delfile(dir .. name .. ".cfg")
                        library:notification({ text = "deleted: " .. name })
                        library:config_list_update()
                    end
                end,
            })
        end,
    })

    pcall(function()
        if not isfolder("Calamity.Wtf") then makefolder("Calamity.Wtf") end
        if not isfolder("Calamity.Wtf/cfg") then makefolder("Calamity.Wtf/cfg") end
    end)

    library.directory = "Calamity.Wtf"
    library:config_list_update()
end

combatTab.open_tab()
library:update_theme("accent", Color3.fromHex("#ADD8E6"))

local menuVisible = true
local rshiftPressed = false

uis.InputBegan:Connect(function(input, processed)
    if input.KeyCode == Enum.KeyCode.RightShift then
        if not rshiftPressed then
            rshiftPressed = true
            menuVisible = not menuVisible
            window.set_menu_visibility(menuVisible)
        end
        return
    end

    if processed then return end

    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if cfg.rapidfire.enabled then
            local gun = getrapidgun()
            if gun then isfiring = true end
        end
    end
end)

uis.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.RightShift then rshiftPressed = false return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then isfiring = false end
end)

runservice.RenderStepped:Connect(function()
    local now = tick()

    if now - lasttargetscan >= scanrate then
        lasttargetscan = now
        local target = findtarget(cfg.silent.fov, cfg.silent.distance_enabled, cfg.silent.max_distance, false)
        currenttarget = target
        silentaimactive = cfg.silent.enabled and currenttarget ~= nil
    end

    if selfknocked() then
        currenttarget = nil silentaimactive = false cfg.camlock.active = false
        lastvisibletarget = nil targetline.Visible = false
    end

    rapidfire()

    if cfg.walkspeed.enabled and cfg.walkspeed.active then
        local hum = localplayer.Character and localplayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = cfg.walkspeed.amount end
    end

    if cfg.jumppower.enabled and cfg.jumppower.active then
        local hum = localplayer.Character and localplayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            if hum.JumpPower ~= cfg.jumppower.amount then hum.JumpPower = cfg.jumppower.amount end
        end
    end

    if cfg.hitbox.enabled then
        for _, player in pairs(players:GetPlayers()) do
            if player ~= localplayer and player.Character then
                local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.Size = Vector3.new(cfg.hitbox.size, cfg.hitbox.size, cfg.hitbox.size)
                    hrp.Transparency = 1
                end
            end
        end
    end

    updatefovbox(fovparts.silentaim, fov2dboxes.silentaim, cfg.silent.fov, silentaimactive)
    updatefovbox(fovparts.camlock, fov2dboxes.camlock, cfg.camlock.fov, cfg.camlock.active)
    updatetargetline()
    refreshesp()

    if cfg.camlock.enabled then applycamlock() end
end)
