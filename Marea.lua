--[[
    ███╗   ███╗ █████╗ ██████╗ ███████╗ █████╗
    ████╗ ████║██╔══██╗██╔══██╗██╔════╝██╔══██╗
    ██╔████╔██║███████║██████╔╝█████╗  ███████║
    ██║╚██╔╝██║██╔══██║██╔══██╗██╔══╝  ██╔══██║
    ██║ ╚═╝ ██║██║  ██║██║  ██║███████╗██║  ██║
    ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝
             A D R I A T I C   A I M   S U I T E
--===========================================================================
--  MAREA  |  Aimbot + ESP + Player List
--  Menu  : RIGHT SHIFT        Aim : E (hold, remappable)
--  Execs : Solara / Delta / Wave / Xeno / Krnl / Synapse / Script-Ware
--  Raw   : raw.githubusercontent.com/<USER>/<REPO>/main/Marea.lua
--===========================================================================
]]

local META = {
    Name    = "Marea",
    Version = "1.0.0",
    Tagline = "Adriatic Aim Suite",
    Author  = "you",
}

getgenv = getgenv or function() return _G end
if getgenv().Marea and getgenv().Marea.Unload then pcall(getgenv().Marea.Unload) end

--============================= SERVICES ===================================
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Workspace        = game:GetService("Workspace")

local LP     = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse  = LP:GetMouse()

local RayFilter = Enum.RaycastFilterType.Blacklist
pcall(function() RayFilter = Enum.RaycastFilterType.Exclude end)

local DRAWING = (function()
    if not Drawing then return false end
    local ok, o = pcall(function() return Drawing.new("Square") end)
    if ok and o then pcall(function() o:Remove() end) end
    return ok
end)()

local Connections, Drawings = {}, {}
local function onConn(c) table.insert(Connections, c); return c end
local function mkDraw(...)
    local d = Drawing.new(...); table.insert(Drawings, d); return d
end

--=============================== IDENTITÉ =================================
local BRAND = {
    ACCENT  = Color3.fromRGB(0, 200, 190),   -- teal Adriatique
    ACCENT2 = Color3.fromRGB(232, 193, 112), -- or vénitien
    ENEMY   = Color3.fromRGB(255, 90, 90),
    ALLY    = Color3.fromRGB(0, 200, 190),
    BANNER  = Color3.fromRGB(120, 230, 225),
}

local function banner()
    print([[
   __  __    _    ____  _____    _
  |  \/  |  / \  |  _ \| ____|  / \
  | |\/| | / _ \ | |_) |  _|   / _ \
  | |  | |/ ___ \|  _ <| |___ / ___ \
  |_|  |_/_/   \_\_| \_\_____/_/   \_\
]])
    print(("  %s v%s  •  %s"):format(META.Name, META.Version, META.Tagline))
    local ok, exec = pcall(function() return identifyexecutor() end)
    print(("  executor: %s  •  %s"):format(ok and exec or "unknown", os.date("%Y-%m-%d %H:%M")))
end

--=============================== CONFIG ===================================
local Config = {
    Aimbot = {
        Enabled     = false,
        Key         = Enum.KeyCode.E,
        Mode        = "Hold",
        TeamCheck   = true,
        WallCheck   = true,
        FOV         = 140,
        ShowFOV     = true,
        Smoothness  = 0.30,
        Hitbox      = "Head",
        Prediction  = 0.12,
        LockTarget  = false,
    },
    ESP = {
        Enabled   = true,
        Box       = true,
        Name      = true,
        Health    = true,
        Distance  = true,
        Tracer    = false,
        Chams     = false,
        TeamCheck = false,
        MaxDist   = 1000,
        TextSize  = 13,
    },
    Misc = {
        Fullbright = false,
        Watermark  = true,
        MenuKey    = Enum.KeyCode.RightShift,
    },
}

--=============================== OUTILS ===================================
local function alive(plr)
    local char = plr.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root or hum.Health <= 0 then return nil end
    return char, hum, root
end

local function isEnemy(plr)
    if not Config.Aimbot.TeamCheck then return true end
    if plr.Team == nil or LP.Team == nil then return true end
    return plr.Team ~= LP.Team
end

local visParams = RaycastParams.new()
visParams.FilterType  = RayFilter
visParams.IgnoreWater = true

local function isVisible(part)
    if not part or not LP.Character then return true end
    visParams.FilterDescendantsInstances = { LP.Character, part.Parent }
    local origin = Camera.CFrame.Position
    return Workspace:Raycast(origin, part.Position - origin, visParams) == nil
end

local function keyMatches(input, key)
    if not key then return false end
    if input.KeyCode == key then return true end
    if input.UserInputType == key then return true end
    return false
end

--=============================== AIMBOT ===================================
local aimHold, aimToggle = false, false
local lockedTarget = nil

local function aimPart(plr)
    local char = plr.Character
    if not char then return nil end
    return char:FindFirstChild(Config.Aimbot.Hitbox)
        or char:FindFirstChild("Head")
        or char:FindFirstChild("HumanoidRootPart")
        or char:FindFirstChild("UpperTorso")
        or char:FindFirstChild("Torso")
end

local function closestTarget()
    local ref = Vector2.new(Mouse.X, Mouse.Y)
    local best, bestScore = nil, math.huge

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and isEnemy(plr) then
            local char = alive(plr)
            if char then
                local part = aimPart(plr)
                if part then
                    local sp, on = Camera:WorldToViewportPoint(part.Position)
                    if on then
                        local d = (Vector2.new(sp.X, sp.Y) - ref).Magnitude
                        if d <= Config.Aimbot.FOV and d < bestScore then
                            if not Config.Aimbot.WallCheck or isVisible(part) then
                                best, bestScore = plr, d
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

local function runAimbot(dt)
    local target = lockedTarget
    if target and not alive(target) then target = nil end

    if not target then
        target = closestTarget()
        lockedTarget = Config.Aimbot.LockTarget and target or nil
    end
    if not target then return end

    local part = aimPart(target)
    if not part then return end

    local aimPos = part.Position
    if Config.Aimbot.Prediction > 0 and part:IsA("BasePart") then
        aimPos = aimPos + part.AssemblyLinearVelocity * Config.Aimbot.Prediction
    end

    local camCF  = Camera.CFrame
    local goal   = CFrame.lookAt(camCF.Position, aimPos)
    local smooth = math.clamp(Config.Aimbot.Smoothness, 0.01, 1)
    local alpha  = 1 - (1 - smooth) ^ (dt * 60)
    Camera.CFrame = camCF:Lerp(goal, alpha)
end

--================================ ESP =====================================
local espObjects = {}
local espGui     = nil
local fovCircle  = DRAWING and mkDraw("Circle") or nil
if fovCircle then
    fovCircle.Thickness    = 1
    fovCircle.Filled       = false
    fovCircle.NumSides     = 64
    fovCircle.Transparency = 0.45
    fovCircle.Color        = BRAND.ACCENT
end

local function espColor(plr)
    if Config.ESP.TeamCheck and plr.Team and LP.Team and plr.Team == LP.Team then
        return BRAND.ALLY
    end
    return BRAND.ENEMY
end

local function project(char)
    local ok, cf, size = pcall(function() return char:GetBoundingBox() end)
    if not ok or not cf then return nil end

    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local any = false

    for _, sx in ipairs({ -0.5, 0.5 }) do
        for _, sy in ipairs({ -0.5, 0.5 }) do
            for _, sz in ipairs({ -0.5, 0.5 }) do
                local wp = cf * Vector3.new(size.X * sx, size.Y * sy, size.Z * sz)
                local sp, on = Camera:WorldToViewportPoint(wp)
                if on and sp.Z > 0 then
                    any = true
                    minX = math.min(minX, sp.X) maxX = math.max(maxX, sp.X)
                    minY = math.min(minY, sp.Y) maxY = math.max(maxY, sp.Y)
                end
            end
        end
    end
    if not any then return nil end
    return minX, minY, maxX, maxY
end

local function createESP(plr)
    if DRAWING then
        local o = {
            box    = mkDraw("Square"),
            name   = mkDraw("Text"),
            dist   = mkDraw("Text"),
            tracer = mkDraw("Line"),
            hbg    = mkDraw("Square"),
            hfill  = mkDraw("Square"),
        }
        o.box.Filled, o.box.Thickness = false, 1
        o.hbg.Filled, o.hfill.Filled  = true, true
        for _, t in ipairs({ o.name, o.dist }) do
            t.Center, t.Outline, t.OutlineColor = true, true, Color3.new(0, 0, 0)
        end
        return o
    end

    if not espGui then
        espGui = Instance.new("ScreenGui")
        espGui.Name = "MareaESP"
        espGui.ResetOnSpawn = false
        espGui.IgnoreGuiInset = true
        pcall(function() espGui.Parent = game:GetService("CoreGui") end)
        if not espGui.Parent then espGui.Parent = LP:WaitForChild("PlayerGui") end
    end
    local char = plr.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end

    local bb = Instance.new("BillboardGui")
    bb.Name = "MareaESP"
    bb.Size = UDim2.new(0, 60, 0, 90)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.Adornee = root
    bb.Parent = root

    local box = Instance.new("Frame")
    box.BackgroundTransparency = 1
    box.Size = UDim2.fromScale(1, 1)
    box.Parent = bb
    local st = Instance.new("UIStroke")
    st.Thickness = 1.5
    st.Parent = box

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 0, 14)
    label.Position = UDim2.new(0, 0, 0, -16)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextStrokeTransparency = 0
    label.Parent = bb

    return { bb = bb, box = box, stroke = st, label = label, fallback = true }
end

local function destroyESP(plr)
    local o = espObjects[plr]
    if not o then return end
    if o.fallback then
        pcall(function() o.bb:Destroy() end)
    else
        for _, d in pairs(o) do pcall(function() d:Remove() end) end
    end
    espObjects[plr] = nil
end

local function updateESP()
    if Config.ESP.Enabled then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP and not espObjects[plr] and alive(plr) then
                espObjects[plr] = createESP(plr)
            end
        end
    end
    local dead = {}
    for plr in pairs(espObjects) do
        if not Config.ESP.Enabled or not plr.Parent or not alive(plr) then
            table.insert(dead, plr)
        end
    end
    for _, plr in ipairs(dead) do destroyESP(plr) end

    local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local myPos  = myRoot and myRoot.Position or Camera.CFrame.Position
    local vp     = Camera.ViewportSize

    for plr, o in pairs(espObjects) do
        local char, hum, root = alive(plr)
        if char and root then
            local dist  = (root.Position - myPos).Magnitude
            local color = espColor(plr)

            if Config.ESP.Chams then
                local h = char:FindFirstChild("MareaHL")
                if not h then
                    h = Instance.new("Highlight")
                    h.Name = "MareaHL"
                    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    h.FillTransparency = 0.65
                    h.OutlineTransparency = 0
                    h.Parent = char
                end
                h.FillColor, h.OutlineColor = color, color
            else
                local h = char:FindFirstChild("MareaHL")
                if h then h:Destroy() end
            end

            if dist > Config.ESP.MaxDist then
                if o.fallback then o.bb.Enabled = false
                else for _, d in pairs(o) do d.Visible = false end end
            else
                if o.fallback then
                    o.bb.Enabled = true
                    o.stroke.Color = color
                    o.label.Text = Config.ESP.Name and plr.Name or ""
                    o.label.TextColor3 = color
                else
                    local minX, minY, maxX, maxY = project(char)
                    if minX then
                        local w, hgt = maxX - minX, maxY - minY
                        local cx = (minX + maxX) / 2

                        o.box.Visible = Config.ESP.Box
                        o.box.Position, o.box.Size, o.box.Color =
                            Vector2.new(minX, minY), Vector2.new(w, hgt), color

                        o.name.Visible = Config.ESP.Name
                        o.name.Text, o.name.Size, o.name.Color =
                            plr.Name, Config.ESP.TextSize, color
                        o.name.Position = Vector2.new(cx, minY - Config.ESP.TextSize - 4)

                        o.dist.Visible = Config.ESP.Distance
                        o.dist.Text  = string.format("%d m", math.floor(dist))
                        o.dist.Size  = Config.ESP.TextSize - 1
                        o.dist.Color = Color3.fromRGB(235, 235, 245)
                        o.dist.Position = Vector2.new(cx, maxY + 3)

                        o.tracer.Visible = Config.ESP.Tracer
                        o.tracer.From, o.tracer.To, o.tracer.Color =
                            Vector2.new(vp.X / 2, vp.Y), Vector2.new(cx, maxY), color
                        o.tracer.Thickness = 1

                        local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                        o.hbg.Visible, o.hfill.Visible = Config.ESP.Health, Config.ESP.Health
                        o.hbg.Position, o.hbg.Size, o.hbg.Color =
                            Vector2.new(minX - 6, minY), Vector2.new(3, hgt), Color3.fromRGB(25, 25, 30)
                        o.hfill.Position = Vector2.new(minX - 6, minY + hgt * (1 - pct))
                        o.hfill.Size     = Vector2.new(3, hgt * pct)
                        o.hfill.Color    = BRAND.ACCENT:Lerp(BRAND.ENEMY, 1 - pct)
                    else
                        for _, d in pairs(o) do d.Visible = false end
                    end
                end
            end
        end
    end
end

Players.PlayerRemoving:Connect(function(p) destroyESP(p) end)

--================================= UI =====================================
local T = {
    BG     = Color3.fromRGB(13, 15, 18),
    PANEL  = Color3.fromRGB(18, 21, 25),
    ELEM   = Color3.fromRGB(28, 32, 38),
    STROKE = Color3.fromRGB(42, 48, 56),
    ACCENT = BRAND.ACCENT,
    GOLD   = BRAND.ACCENT2,
    TEXT   = Color3.fromRGB(233, 238, 242),
    DIM    = Color3.fromRGB(138, 148, 158),
    GOOD   = Color3.fromRGB(60, 200, 120),
}

local function mk(class, props)
    local i = Instance.new(class)
    for k, v in pairs(props or {}) do i[k] = v end
    return i
end
local function corner(o, r) mk("UICorner", { CornerRadius = UDim.new(0, r or 6), Parent = o }) end
local function stroke(o, c, t)
    mk("UIStroke", { Color = c or T.STROKE, Thickness = t or 1, Parent = o })
end

local gui = mk("ScreenGui", {
    Name = "Marea", ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true,
})
pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end

local main = mk("Frame", {
    Name = "Main", Parent = gui,
    Size = UDim2.new(0, 520, 0, 360),
    Position = UDim2.new(0, 60, 0, 120),
    BackgroundColor3 = T.BG, BorderSizePixel = 0,
})
corner(main, 10) stroke(main, T.STROKE, 1)

local titlebar = mk("Frame", {
    Parent = main, Size = UDim2.new(1, 0, 0, 36),
    BackgroundColor3 = T.PANEL, BorderSizePixel = 0,
})
corner(titlebar, 10)
mk("Frame", {
    Parent = titlebar, Size = UDim2.new(1, 0, 0, 12),
    Position = UDim2.new(0, 0, 1, -12), BackgroundColor3 = T.PANEL, BorderSizePixel = 0,
})

-- Logo + signature
local logo = mk("TextLabel", {
    Parent = titlebar, BackgroundTransparency = 1,
    Position = UDim2.new(0, 16, 0, 0), Size = UDim2.new(0, 90, 1, 0),
    Font = Enum.Font.GothamBlack, TextSize = 16, TextColor3 = T.TEXT,
    Text = "MAREA", TextXAlignment = Enum.TextXAlignment.Left,
})
mk("Frame", {
    Parent = titlebar, Size = UDim2.new(0, 3, 0, 16),
    Position = UDim2.new(0, 10, 0.5, -8), BackgroundColor3 = T.ACCENT, BorderSizePixel = 0,
})
corner(titlebar:FindFirstChildOfClass("Frame") or logo, 2)

local pill = mk("TextLabel", {
    Parent = titlebar, BackgroundColor3 = T.ELEM,
    Position = UDim2.new(0, 92, 0.5, -8), Size = UDim2.new(0, 44, 0, 16),
    Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = T.ACCENT,
    Text = "v" .. META.Version, BorderSizePixel = 0,
})
corner(pill, 4)

mk("TextLabel", {
    Parent = titlebar, BackgroundTransparency = 1,
    Position = UDim2.new(0, 142, 0, 0), Size = UDim2.new(0, 220, 1, 0),
    Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = T.DIM,
    Text = META.Tagline, TextXAlignment = Enum.TextXAlignment.Left,
})

local minimize = mk("TextButton", {
    Parent = titlebar, Size = UDim2.new(0, 22, 0, 22),
    Position = UDim2.new(1, -30, 0.5, -11), BackgroundColor3 = T.ELEM,
    Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = T.TEXT,
    Text = "—", AutoButtonColor = false,
})
corner(minimize, 5)

local sidebar = mk("Frame", {
    Parent = main, Position = UDim2.new(0, 8, 0, 44),
    Size = UDim2.new(0, 118, 1, -52), BackgroundTransparency = 1,
})
local content = mk("Frame", {
    Parent = main, Position = UDim2.new(0, 134, 0, 44),
    Size = UDim2.new(1, -142, 1, -52), BackgroundTransparency = 1,
})

local tabs, pages = {}, {}
local order = { "Aimbot", "ESP", "Joueurs", "Divers" }
local currentTab

local function selectTab(name)
    currentTab = name
    for n, p in pairs(pages) do p.Visible = (n == name) end
    for n, b in pairs(tabs) do
        b.BackgroundColor3 = (n == name) and T.ACCENT or T.ELEM
        b.TextColor3 = (n == name) and Color3.fromRGB(10, 20, 22) or T.DIM
    end
end

for i, name in ipairs(order) do
    local b = mk("TextButton", {
        Parent = sidebar, Size = UDim2.new(1, 0, 0, 30),
        Position = UDim2.new(0, 0, 0, (i - 1) * 34),
        BackgroundColor3 = T.ELEM, Font = Enum.Font.GothamBold, TextSize = 12,
        TextColor3 = T.DIM, Text = name, AutoButtonColor = false,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    mk("UIPadding", { PaddingLeft = UDim.new(0, 10), Parent = b })
    corner(b, 6)
    b.MouseButton1Click:Connect(function() selectTab(name) end)
    tabs[name] = b

    local page = mk("ScrollingFrame", {
        Parent = content, Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = T.STROKE,
        CanvasSize = UDim2.new(0, 0, 0, 400), Visible = false,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    })
    mk("UIPadding", { PaddingRight = UDim.new(0, 8), Parent = page })
    mk("UIListLayout", { Parent = page, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
    pages[name] = page
end

-- Signature en bas de la sidebar
local sig = mk("Frame", {
    Parent = sidebar, Size = UDim2.new(1, 0, 0, 34),
    Position = UDim2.new(0, 0, 1, -34), BackgroundTransparency = 1,
})
mk("TextLabel", {
    Parent = sig, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14),
    Font = Enum.Font.GothamBlack, TextSize = 11, TextColor3 = T.GOLD,
    Text = "MAREA v" .. META.Version, TextXAlignment = Enum.TextXAlignment.Left,
})
mk("TextLabel", {
    Parent = sig, BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 14),
    Size = UDim2.new(1, 0, 0, 14), Font = Enum.Font.Gotham, TextSize = 10,
    TextColor3 = T.DIM, Text = META.Tagline, TextXAlignment = Enum.TextXAlignment.Left,
})

--============================= COMPOSANTS =================================
local function section(parent, text)
    local f = mk("Frame", { Parent = parent, Size = UDim2.new(1, -4, 0, 24), BackgroundTransparency = 1 })
    mk("TextLabel", {
        Parent = f, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
        Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = T.ACCENT,
        Text = string.upper(text), TextXAlignment = Enum.TextXAlignment.Left,
    })
    return f
end

local function toggle(parent, text, default, cb)
    local row = mk("Frame", { Parent = parent, Size = UDim2.new(1, -4, 0, 26), BackgroundTransparency = 1 })
    mk("TextLabel", {
        Parent = row, BackgroundTransparency = 1, Size = UDim2.new(1, -50, 1, 0),
        Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = T.TEXT,
        Text = text, TextXAlignment = Enum.TextXAlignment.Left,
    })
    local box = mk("TextButton", {
        Parent = row, Size = UDim2.new(0, 34, 0, 18), Position = UDim2.new(1, -36, 0.5, -9),
        BackgroundColor3 = T.ELEM, Text = "", AutoButtonColor = false,
    })
    corner(box, 9)
    local knob = mk("Frame", {
        Parent = box, Size = UDim2.new(0, 14, 0, 14),
        Position = UDim2.new(0, 2, 0.5, -7), BackgroundColor3 = T.DIM, BorderSizePixel = 0,
    })
    corner(knob, 7)

    local state = default
    local function render()
        box.BackgroundColor3 = state and T.ACCENT or T.ELEM
        knob.Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
        knob.BackgroundColor3 = state and Color3.fromRGB(10, 20, 22) or T.DIM
    end
    box.MouseButton1Click:Connect(function()
        state = not state; render(); cb(state)
    end)
    render()
    return { Set = function(v) state = v; render(); cb(v) end, Get = function() return state end }
end

local function slider(parent, text, min, max, default, cb)
    local row = mk("Frame", { Parent = parent, Size = UDim2.new(1, -4, 0, 38), BackgroundTransparency = 1 })
    mk("TextLabel", {
        Parent = row, BackgroundTransparency = 1, Size = UDim2.new(0.7, 0, 0, 16),
        Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = T.TEXT,
        Text = text, TextXAlignment = Enum.TextXAlignment.Left,
    })
    local value = mk("TextLabel", {
        Parent = row, BackgroundTransparency = 1, Size = UDim2.new(0.3, 0, 0, 16),
        Position = UDim2.new(0.7, 0, 0, 0), Font = Enum.Font.GothamBold, TextSize = 12,
        TextColor3 = T.ACCENT, Text = tostring(default), TextXAlignment = Enum.TextXAlignment.Right,
    })
    local bar = mk("TextButton", {
        Parent = row, Size = UDim2.new(1, 0, 0, 8), Position = UDim2.new(0, 0, 0, 24),
        BackgroundColor3 = T.ELEM, Text = "", AutoButtonColor = false,
    })
    corner(bar, 4)
    local fill = mk("Frame", { Parent = bar, Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = T.ACCENT, BorderSizePixel = 0 })
    corner(fill, 4)

    local dragging = false
    local val = default
    local function set(v, fire)
        val = math.clamp(v, min, max)
        fill.Size = UDim2.new((val - min) / (max - min), 0, 1, 0)
        value.Text = (val % 1 == 0) and tostring(math.floor(val)) or string.format("%.2f", val)
        if fire then cb(val) end
    end
    local function fromInput(input)
        local rel = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        set(min + (max - min) * rel, true)
    end
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; fromInput(i) end
    end)
    onConn(UserInputService.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then fromInput(i) end
    end))
    onConn(UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end))
    set(default, false)
    return { Set = function(v) set(v, false) end, Get = function() return val end }
end

local function keybind(parent, text, default, cb)
    local row = mk("Frame", { Parent = parent, Size = UDim2.new(1, -4, 0, 26), BackgroundTransparency = 1 })
    mk("TextLabel", {
        Parent = row, BackgroundTransparency = 1, Size = UDim2.new(1, -80, 1, 0),
        Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = T.TEXT,
        Text = text, TextXAlignment = Enum.TextXAlignment.Left,
    })
    local btn = mk("TextButton", {
        Parent = row, Size = UDim2.new(0, 70, 0, 22), Position = UDim2.new(1, -70, 0.5, -11),
        BackgroundColor3 = T.ELEM, Font = Enum.Font.GothamBold, TextSize = 11,
        TextColor3 = T.TEXT, Text = default and default.Name or "—", AutoButtonColor = false,
    })
    corner(btn, 5)
    local state, listening = default, false

    btn.MouseButton1Click:Connect(function()
        if listening then return end
        listening = true
        btn.Text = "..."
        btn.BackgroundColor3 = T.ACCENT
        local c
        c = UserInputService.InputBegan:Connect(function(input, gpe)
            if input.UserInputType == Enum.UserInputType.MouseMovement or gpe then return end
            local k = input.KeyCode
            if k == Enum.KeyCode.Unknown then k = input.UserInputType end
            state = k
            btn.Text = (k.Name or "?"):gsub("MouseButton", "M")
            btn.BackgroundColor3 = T.ELEM
            listening = false
            c:Disconnect()
            cb(k)
        end)
    end)
    return { Get = function() return state end }
end

local function dropdown(parent, text, options, default, cb)
    local row = mk("Frame", { Parent = parent, Size = UDim2.new(1, -4, 0, 26), BackgroundTransparency = 1 })
    mk("TextLabel", {
        Parent = row, BackgroundTransparency = 1, Size = UDim2.new(1, -90, 1, 0),
        Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = T.TEXT,
        Text = text, TextXAlignment = Enum.TextXAlignment.Left,
    })
    local btn = mk("TextButton", {
        Parent = row, Size = UDim2.new(0, 80, 0, 22), Position = UDim2.new(1, -80, 0.5, -11),
        BackgroundColor3 = T.ELEM, Font = Enum.Font.GothamBold, TextSize = 11,
        TextColor3 = T.TEXT, Text = default, AutoButtonColor = false,
    })
    corner(btn, 5)
    local state = default
    btn.MouseButton1Click:Connect(function()
        local i = table.find(options, state) or 0
        state = options[(i % #options) + 1]
        btn.Text = state
        cb(state)
    end)
    return { Get = function() return state end }
end

local function button(parent, text, cb)
    local b = mk("TextButton", {
        Parent = parent, Size = UDim2.new(1, -4, 0, 26), BackgroundColor3 = T.ELEM,
        Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = T.TEXT,
        Text = text, AutoButtonColor = false,
    })
    corner(b, 6)
    b.MouseButton1Click:Connect(cb)
    return b
end

--============================= PAGE AIMBOT ================================
local pAim = pages["Aimbot"]
section(pAim, "Général")
toggle(pAim, "Activer l'aimbot", Config.Aimbot.Enabled, function(v) Config.Aimbot.Enabled = v end)
dropdown(pAim, "Mode", { "Hold", "Toggle" }, Config.Aimbot.Mode, function(v) Config.Aimbot.Mode = v end)
keybind(pAim, "Touche d'aim", Config.Aimbot.Key, function(k) Config.Aimbot.Key = k end)

section(pAim, "Réglages")
slider(pAim, "FOV", 10, 500, Config.Aimbot.FOV, function(v) Config.Aimbot.FOV = v end)
slider(pAim, "Lissage", 0.02, 1, Config.Aimbot.Smoothness, function(v) Config.Aimbot.Smoothness = v end)
slider(pAim, "Prédiction", 0, 0.4, Config.Aimbot.Prediction, function(v) Config.Aimbot.Prediction = v end)
dropdown(pAim, "Hitbox", { "Head", "HumanoidRootPart", "UpperTorso" }, Config.Aimbot.Hitbox, function(v) Config.Aimbot.Hitbox = v end)

section(pAim, "Filtres")
toggle(pAim, "Vérif. équipe", Config.Aimbot.TeamCheck, function(v) Config.Aimbot.TeamCheck = v end)
toggle(pAim, "Vérif. murs", Config.Aimbot.WallCheck, function(v) Config.Aimbot.WallCheck = v end)
toggle(pAim, "Verrouiller la cible", Config.Aimbot.LockTarget, function(v) Config.Aimbot.LockTarget = v end)
toggle(pAim, "Afficher le cercle FOV", Config.Aimbot.ShowFOV, function(v) Config.Aimbot.ShowFOV = v end)

--============================== PAGE ESP ==================================
local pEsp = pages["ESP"]
section(pEsp, "Général")
toggle(pEsp, "Activer l'ESP", Config.ESP.Enabled, function(v) Config.ESP.Enabled = v end)
slider(pEsp, "Distance max", 50, 5000, Config.ESP.MaxDist, function(v) Config.ESP.MaxDist = v end)
slider(pEsp, "Taille du texte", 8, 22, Config.ESP.TextSize, function(v) Config.ESP.TextSize = v end)

section(pEsp, "Éléments")
toggle(pEsp, "Boîtes", Config.ESP.Box, function(v) Config.ESP.Box = v end)
toggle(pEsp, "Pseudo", Config.ESP.Name, function(v) Config.ESP.Name = v end)
toggle(pEsp, "Barre de vie", Config.ESP.Health, function(v) Config.ESP.Health = v end)
toggle(pEsp, "Distance", Config.ESP.Distance, function(v) Config.ESP.Distance = v end)
toggle(pEsp, "Traits (tracers)", Config.ESP.Tracer, function(v) Config.ESP.Tracer = v end)
toggle(pEsp, "Chams (surbrillance)", Config.ESP.Chams, function(v) Config.ESP.Chams = v end)

section(pEsp, "Filtres")
toggle(pEsp, "Couleur d'équipe", Config.ESP.TeamCheck, function(v) Config.ESP.TeamCheck = v end)

--============================ PAGE JOUEURS ================================
local pPlr = pages["Joueurs"]
local plrList = mk("Frame", { Parent = pPlr, Size = UDim2.new(1, -4, 0, 10), BackgroundTransparency = 1 })
mk("UIListLayout", { Parent = plrList, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder })

local function refreshPlayers()
    for _, c in ipairs(plrList:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    for i, plr in ipairs(Players:GetPlayers()) do
        local row = mk("Frame", {
            Parent = plrList, Size = UDim2.new(1, 0, 0, 28),
            BackgroundColor3 = T.PANEL, BorderSizePixel = 0, LayoutOrder = i,
        })
        corner(row, 5)
        local _, hum = alive(plr)
        mk("TextLabel", {
            Parent = row, BackgroundTransparency = 1, Size = UDim2.new(0.5, -8, 1, 0),
            Position = UDim2.new(0, 8, 0, 0), Font = Enum.Font.Gotham, TextSize = 12,
            TextColor3 = (plr == LP) and T.ACCENT or T.TEXT,
            Text = plr.Name .. (plr == LP and " (moi)" or ""),
            TextXAlignment = Enum.TextXAlignment.Left,
        })
        mk("TextLabel", {
            Parent = row, BackgroundTransparency = 1, Size = UDim2.new(0, 60, 1, 0),
            Position = UDim2.new(0.5, 0, 0, 0), Font = Enum.Font.GothamBold, TextSize = 12,
            TextColor3 = hum and T.GOOD or T.DIM,
            Text = hum and (math.floor(hum.Health) .. " HP") or "mort",
            TextXAlignment = Enum.TextXAlignment.Left,
        })
        local spec = mk("TextButton", {
            Parent = row, Size = UDim2.new(0, 50, 0, 20), Position = UDim2.new(1, -112, 0.5, -10),
            BackgroundColor3 = T.ELEM, Font = Enum.Font.GothamBold, TextSize = 11,
            TextColor3 = T.TEXT, Text = "Spec", AutoButtonColor = false,
        })
        corner(spec, 4)
        spec.MouseButton1Click:Connect(function()
            local _, h = alive(plr)
            if h then Camera.CameraSubject = h end
        end)
        local tp = mk("TextButton", {
            Parent = row, Size = UDim2.new(0, 50, 0, 20), Position = UDim2.new(1, -56, 0.5, -10),
            BackgroundColor3 = T.ELEM, Font = Enum.Font.GothamBold, TextSize = 11,
            TextColor3 = T.TEXT, Text = "TP", AutoButtonColor = false,
        })
        corner(tp, 4)
        tp.MouseButton1Click:Connect(function()
            local _, _, r = alive(plr)
            local _, _, mr = alive(LP)
            if r and mr then mr.CFrame = r.CFrame * CFrame.new(0, 0, 3) end
        end)
    end
    plrList.Size = UDim2.new(1, -4, 0, math.max(10, #Players:GetPlayers() * 32))
end

button(pPlr, "Rafraîchir la liste", refreshPlayers)
refreshPlayers()
onConn(Players.PlayerAdded:Connect(function() task.wait(0.3); refreshPlayers() end))
onConn(Players.PlayerRemoving:Connect(function() task.wait(0.1); refreshPlayers() end))

--============================= PAGE DIVERS ================================
local pMisc = pages["Divers"]
section(pMisc, "Visuel")
toggle(pMisc, "Fullbright", Config.Misc.Fullbright, function(v)
    Config.Misc.Fullbright = v
    local l = game:GetService("Lighting")
    if v then
        l.Brightness, l.ClockTime, l.FogEnd = 3, 14, 1e6
    else
        l.Brightness, l.FogEnd = 2, 100000
    end
end)
toggle(pMisc, "Watermark", Config.Misc.Watermark, function(v) Config.Misc.Watermark = v end)

section(pMisc, "Interface")
keybind(pMisc, "Touche du menu", Config.Misc.MenuKey, function(k) Config.Misc.MenuKey = k end)

section(pMisc, "Actions")
button(pMisc, "Reset du personnage", function()
    local c = LP.Character
    if c then local h = c:FindFirstChildOfClass("Humanoid"); if h then h.Health = 0 end end
end)
button(pMisc, "Décharger " .. META.Name, function()
    if getgenv().Marea then getgenv().Marea.Unload() end
end)

--============================= WATERMARK ==================================
local wm = mk("TextLabel", {
    Parent = gui, BackgroundTransparency = 1,
    Position = UDim2.new(0, 14, 1, -32), Size = UDim2.new(0, 300, 0, 20),
    Font = Enum.Font.GothamBlack, TextSize = 14, TextColor3 = T.TEXT,
    Text = "MAREA", TextXAlignment = Enum.TextXAlignment.Left,
    TextStrokeTransparency = 0.6, TextStrokeColor3 = Color3.new(0, 0, 0),
})
mk("TextLabel", {
    Parent = gui, BackgroundTransparency = 1,
    Position = UDim2.new(0, 68, 1, -30), Size = UDim2.new(0, 300, 0, 20),
    Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = T.ACCENT,
    Text = "v" .. META.Version, TextXAlignment = Enum.TextXAlignment.Left,
    TextStrokeTransparency = 0.7, TextStrokeColor3 = Color3.new(0, 0, 0),
})
mk("TextLabel", {
    Parent = gui, BackgroundTransparency = 1,
    Position = UDim2.new(0, 14, 1, -17), Size = UDim2.new(0, 300, 0, 20),
    Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = T.DIM,
    Text = META.Tagline, TextXAlignment = Enum.TextXAlignment.Left,
    TextStrokeTransparency = 0.8, TextStrokeColor3 = Color3.new(0, 0, 0),
})

--========================= DRAG & MINIMIZE ================================
local dragging, dragStart, startPos = false, nil, nil
titlebar.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging, dragStart, startPos = true, i.Position, main.Position
    end
end)
onConn(UserInputService.InputChanged:Connect(function(i)
    if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
        local d = i.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end))
onConn(UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end))

local minimized = false
minimize.MouseButton1Click:Connect(function()
    minimized = not minimized
    local target = minimized and UDim2.new(0, 520, 0, 36) or UDim2.new(0, 520, 0, 360)
    sidebar.Visible = not minimized
    content.Visible = not minimized
    TweenService:Create(main, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { Size = target }):Play()
    minimize.Text = minimized and "+" or "—"
end)

selectTab("Aimbot")

--============================ NOTIFICATIONS ===============================
local function notify(text, color)
    local n = mk("TextLabel", {
        Parent = gui, Size = UDim2.new(0, 240, 0, 30),
        Position = UDim2.new(1, -260, 1, -50), BackgroundColor3 = T.PANEL,
        Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = color or T.TEXT,
        Text = text, BorderSizePixel = 0, TextTransparency = 1, BackgroundTransparency = 1,
    })
    corner(n, 6) stroke(n, color or T.STROKE, 1)
    TweenService:Create(n, TweenInfo.new(0.2), {
        TextTransparency = 0, BackgroundTransparency = 0,
        Position = UDim2.new(1, -260, 1, -60),
    }):Play()
    task.delay(2.2, function()
        TweenService:Create(n, TweenInfo.new(0.25), {
            TextTransparency = 1, BackgroundTransparency = 1,
            Position = UDim2.new(1, -260, 1, -50),
        }):Play()
        task.wait(0.3)
        n:Destroy()
    end)
end

--============================= TOUCHES ====================================
onConn(UserInputService.InputBegan:Connect(function(input, gpe)
    if keyMatches(input, Config.Misc.MenuKey) then
        main.Visible = not main.Visible
        return
    end
    if gpe then return end
    if keyMatches(input, Config.Aimbot.Key) then
        if Config.Aimbot.Mode == "Toggle" then
            aimToggle = not aimToggle
            notify(aimToggle and "AIM  •  ON" or "AIM  •  OFF", aimToggle and T.GOOD or T.DIM)
        else
            aimHold = true
        end
    end
end))

onConn(UserInputService.InputEnded:Connect(function(input)
    if keyMatches(input, Config.Aimbot.Key) and Config.Aimbot.Mode == "Hold" then
        aimHold = false
    end
end))

--============================= BOUCLE =====================================
onConn(RunService.RenderStepped:Connect(function(dt)
    local aiming = Config.Aimbot.Enabled and (aimHold or aimToggle)
    if aiming then
        runAimbot(dt)
    elseif not Config.Aimbot.LockTarget then
        lockedTarget = nil
    end

    if fovCircle then
        fovCircle.Visible = Config.Aimbot.Enabled and Config.Aimbot.ShowFOV
        fovCircle.Position = Vector2.new(Mouse.X, Mouse.Y)
        fovCircle.Radius = Config.Aimbot.FOV
    end

    wm.Visible = Config.Misc.Watermark
    updateESP()
end))

--============================= UNLOAD =====================================
local function unload()
    for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
    for _, d in ipairs(Drawings) do pcall(function() d:Remove() end) end
    for plr in pairs(espObjects) do destroyESP(plr) end
    pcall(function() gui:Destroy() end)
    pcall(function() if espGui then espGui:Destroy() end end)
    getgenv().Marea = nil
    print(("[%s] déchargé."):format(META.Name))
end

getgenv().Marea = {
    Name    = META.Name,
    Version = META.Version,
    Config  = Config,
    Unload  = unload,
}

banner()
notify("MAREA v" .. META.Version .. "  •  MAJ DROITE = menu", T.ACCENT)
