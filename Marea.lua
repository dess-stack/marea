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
--  Menu : RIGHT SHIFT        Aim : E (hold, remappable)
--  Execs: Solara / Delta / Wave / Xeno / Krnl / Synapse / Script-Ware
--  Raw  : raw.githubusercontent.com/<USER>/<REPO>/main/Marea.lua
--===========================================================================
]]
--===========================================================================
--  KEY SYSTEM  •  MAREA  •  clé 24h liée au HWID
--  Édite uniquement KEYCONFIG (URL de ton Worker Cloudflare).
--===========================================================================
--===========================================================================
--  KEY SYSTEM  •  MAREA  •  PandaAuth  (serviceId: mareascript)
--  À coller tout en haut du script, avant "local META".
--===========================================================================
local KEYCONFIG = {
    SERVICE_ID   = "mareascript",
    SAVE_FILE    = "marea_key.json",
    OFFLINE_PASS = true,   -- true = laisse passer si l'API PandaAuth est down
}

local function keyGate()
    local Players          = game:GetService("Players")
    local UserInputService = game:GetService("UserInputService")
    local TweenService     = game:GetService("TweenService")
    local HttpService      = game:GetService("HttpService")
    local LP               = Players.LocalPlayer

    local hasFS   = typeof(writefile) == "function" and typeof(readfile) == "function"
    local hasClip = typeof(setclipboard) == "function"

    local C = {
        BG     = Color3.fromRGB(13, 15, 18),
        PANEL  = Color3.fromRGB(18, 21, 25),
        ELEM   = Color3.fromRGB(28, 32, 38),
        STROKE = Color3.fromRGB(42, 48, 56),
        ACCENT = Color3.fromRGB(0, 200, 190),
        GOLD   = Color3.fromRGB(232, 193, 112),
        TEXT   = Color3.fromRGB(233, 238, 242),
        DIM    = Color3.fromRGB(138, 148, 158),
        BAD    = Color3.fromRGB(255, 90, 90),
        GOOD   = Color3.fromRGB(60, 200, 120),
    }

    local function mk(cls, props)
        local i = Instance.new(cls)
        for k, v in pairs(props or {}) do i[k] = v end
        return i
    end
    local function corner(o, r) mk("UICorner", { CornerRadius = UDim.new(0, r or 6), Parent = o }) end
    local function stroke(o, c, t) mk("UIStroke", { Color = c or C.STROKE, Thickness = t or 1, Parent = o }) end
    local function gradient(o, a, b, rot)
        local g = mk("UIGradient", { Parent = o, Rotation = rot or 0 })
        g.Color = ColorSequence.new(a, b)
        return g
    end
    local function spaced(s) return (s:gsub(".", "%1 ")):sub(1, -2) end

    -- SDK PandaAuth --------------------------------------------------------
    local sdkOk, src = pcall(game.HttpGet, game, "https://secure.pandauth.com/pv4/lib")
    if not sdkOk or not src then
        warn("[MAREA] SDK PandaAuth injoignable - mode degrade")
        return KEYCONFIG.OFFLINE_PASS
    end
    local PUSL = loadstring(src)()
    if not PUSL or type(PUSL.configure) ~= "function" then
        warn("[MAREA] SDK PandaAuth invalide - mode degrade")
        return KEYCONFIG.OFFLINE_PASS
    end

    PUSL.configure({
        serviceId    = KEYCONFIG.SERVICE_ID,
        debug        = false,
        kickOnDetect = false,
    })

    local GETKEY_URL = PUSL.getKeyUrl() or "https://pandauth.com"
    local HWID = (type(PUSL.hwid) == "function" and PUSL.hwid()) or "unknown"

    -- Cache ---------------------------------------------------------------
    local function loadCache()
        if not hasFS then return nil end
        local ok, data = pcall(function()
            if not isfile(KEYCONFIG.SAVE_FILE) then return nil end
            return HttpService:JSONDecode(readfile(KEYCONFIG.SAVE_FILE))
        end)
        return (ok and type(data) == "table") and data or nil
    end
    local function saveCache(t)
        if not hasFS then return end
        pcall(writefile, KEYCONFIG.SAVE_FILE, HttpService:JSONEncode(t))
    end

    -- Validation : on ne kick jamais sur un simple false, seuls certains
    -- codes sont fatals. Le reste = transitoire -> on retente.
    local FATAL = {
        INVALID_KEY = "Cle inconnue ou expiree",
        NO_SERVICE  = "Service introuvable (serviceId ?)",
        NO_HTTP     = "Ton executor bloque les requetes HTTP",
        NO_KEY      = "Aucune cle fournie",
        IDENTITY    = "Identite refusee, reessaie",
    }

    local function authenticate(key)
        for attempt = 1, 4 do
            local ok, reason, isPremium = PUSL.validateEx(key)
            if ok then return true, nil, isPremium end
            if FATAL[reason] then return false, FATAL[reason] end
            task.wait(attempt * 3)
        end
        return false, "Serveur injoignable, reessaie dans un instant"
    end

    -- Fast path : cle deja en cache ---------------------------------------
    local cache = loadCache()
    if cache and cache.key and (cache.expires or 0) > os.time() then
        local ok, _, premium = authenticate(cache.key)
        if ok then
            print(("[MAREA] cle en cache valide (%s)%s"):format(
                PUSL.getExpiryFormatted() or "?", premium and " [premium]" or ""))
            return true
        end
    end

    -- UI -------------------------------------------------------------------
    local gui = mk("ScreenGui", {
        Name = "MareaKeySystem", ResetOnSpawn = false,
        IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    pcall(function() gui.Parent = game:GetService("CoreGui") end)
    if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end

    local shadow = mk("Frame", {
        Parent = gui, Size = UDim2.new(0, 400, 0, 232),
        Position = UDim2.new(0.5, 3, 0.5, 5), AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5,
        BorderSizePixel = 0, ZIndex = 0,
    })
    corner(shadow, 12)

    local main = mk("Frame", {
        Parent = gui, Size = UDim2.new(0, 400, 0, 232),
        Position = UDim2.new(0.5, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = C.BG, BorderSizePixel = 0, ZIndex = 2,
    })
    corner(main, 12)
    stroke(main, C.STROKE, 1)

    local bar = mk("Frame", {
        Parent = main, Size = UDim2.new(1, 0, 0, 46),
        BackgroundColor3 = C.PANEL, BorderSizePixel = 0, ZIndex = 3,
    })
    corner(bar, 12)
    mk("Frame", {
        Parent = bar, Size = UDim2.new(1, 0, 0, 12), Position = UDim2.new(0, 0, 1, -12),
        BackgroundColor3 = C.PANEL, BorderSizePixel = 0, ZIndex = 3,
    })
    local div = mk("Frame", {
        Parent = bar, Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = C.ACCENT, BorderSizePixel = 0, ZIndex = 4,
    })
    local divGrad = gradient(div, C.ACCENT, C.GOLD, 0)
    TweenService:Create(divGrad, TweenInfo.new(3.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { Offset = Vector2.new(0.6, 0) }):Play()

    local mark = mk("Frame", {
        Parent = bar, Size = UDim2.new(0, 28, 0, 28), Position = UDim2.new(0, 14, 0.5, -14),
        BackgroundColor3 = C.ACCENT, BorderSizePixel = 0, ZIndex = 5,
    })
    corner(mark, 7)
    gradient(mark, C.ACCENT, C.GOLD, 45)
    mk("TextLabel", {
        Parent = mark, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
        Font = Enum.Font.GothamBlack, TextSize = 16, TextColor3 = Color3.fromRGB(10, 20, 22),
        Text = "M", ZIndex = 6,
    })

    local word = mk("TextLabel", {
        Parent = bar, BackgroundTransparency = 1, Position = UDim2.new(0, 50, 0, 7),
        Size = UDim2.new(0, 140, 0, 18), Font = Enum.Font.GothamBlack, TextSize = 15,
        TextColor3 = Color3.new(1, 1, 1), Text = spaced("MAREA"),
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
    })
    gradient(word, C.ACCENT, C.GOLD, 0)

    mk("TextLabel", {
        Parent = bar, BackgroundTransparency = 1, Position = UDim2.new(0, 51, 0, 26),
        Size = UDim2.new(0, 200, 0, 12), Font = Enum.Font.GothamBold, TextSize = 8,
        TextColor3 = C.DIM, Text = spaced("KEY SYSTEM"),
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
    })

    local close = mk("TextButton", {
        Parent = bar, Size = UDim2.new(0, 24, 0, 24), Position = UDim2.new(1, -32, 0.5, -12),
        BackgroundColor3 = C.ELEM, Font = Enum.Font.GothamBold, TextSize = 14,
        TextColor3 = C.TEXT, Text = "×", AutoButtonColor = false, ZIndex = 5,
    })
    corner(close, 6)

    mk("TextLabel", {
        Parent = main, BackgroundTransparency = 1, Position = UDim2.new(0, 22, 0, 56),
        Size = UDim2.new(1, -44, 0, 16), Font = Enum.Font.Gotham, TextSize = 12,
        TextColor3 = C.DIM, Text = "Colle ta cle (valable 24h) pour lancer le script",
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3,
    })

    local box = mk("TextBox", {
        Parent = main, Position = UDim2.new(0, 22, 0, 78), Size = UDim2.new(1, -44, 0, 34),
        BackgroundColor3 = C.ELEM, BorderSizePixel = 0, Font = Enum.Font.Code,
        TextSize = 14, TextColor3 = C.TEXT, PlaceholderText = "colle ta cle ici",
        PlaceholderColor3 = Color3.fromRGB(110, 118, 128), ClearTextOnFocus = false,
        Text = "", ZIndex = 3,
    })
    corner(box, 8)
    local boxStroke = stroke(box, C.STROKE, 1)

    local validate = mk("TextButton", {
        Parent = main, Position = UDim2.new(0, 22, 0, 122), Size = UDim2.new(0.5, -26, 0, 32),
        BackgroundColor3 = C.ACCENT, Font = Enum.Font.GothamBold, TextSize = 12,
        TextColor3 = Color3.fromRGB(8, 18, 20), Text = "VALIDER",
        AutoButtonColor = false, ZIndex = 3,
    })
    corner(validate, 7)

    local getkey = mk("TextButton", {
        Parent = main, Position = UDim2.new(0.5, 4, 0, 122), Size = UDim2.new(0.5, -26, 0, 32),
        BackgroundColor3 = C.ELEM, Font = Enum.Font.GothamBold, TextSize = 11,
        TextColor3 = C.TEXT, Text = "OBTENIR UNE CLE", AutoButtonColor = false, ZIndex = 3,
    })
    corner(getkey, 7)
    stroke(getkey, C.STROKE, 1)

    local status = mk("TextLabel", {
        Parent = main, BackgroundTransparency = 1, Position = UDim2.new(0, 22, 0, 162),
        Size = UDim2.new(1, -44, 0, 32), Font = Enum.Font.Gotham, TextSize = 11,
        TextColor3 = C.DIM, Text = "", TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 3,
    })

    mk("TextLabel", {
        Parent = main, BackgroundTransparency = 1, Position = UDim2.new(0, 22, 1, -26),
        Size = UDim2.new(1, -44, 0, 14), Font = Enum.Font.Gotham, TextSize = 9,
        TextColor3 = Color3.fromRGB(96, 104, 114),
        Text = ("cle liee a cet appareil  •  hwid %s"):format(HWID:sub(1, 8)),
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3,
    })

    -- Drag ------------------------------------------------------------------
    local dragging, dragStart, startPos = false, nil, nil
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging, dragStart, startPos = true, i.Position, main.Position
        end
    end)
    local dragConn = UserInputService.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                      startPos.Y.Scale, startPos.Y.Offset + d.Y)
            shadow.Position = main.Position + UDim2.new(0, 3, 0, 5)
        end
    end)
    local endConn = UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)

    -- Logique ---------------------------------------------------------------
    local result, closed, busy = nil, false, false

    local function fail(msg)
        status.TextColor3 = C.BAD
        status.Text = msg
        TweenService:Create(boxStroke, TweenInfo.new(0.1), { Color = C.BAD }):Play()
        task.delay(0.7, function()
            if boxStroke then
                TweenService:Create(boxStroke, TweenInfo.new(0.3), { Color = C.STROKE }):Play()
            end
        end)
    end

    local function tryValidate()
        if busy or result then return end
        local key = (box.Text:gsub("%s", ""))
        if #key < 4 then return fail("Cle trop courte") end

        busy = true
        validate.Text = "..."
        status.TextColor3 = C.GOLD
        status.Text = "Verification aupres de PandaAuth..."

        local ok, reason, premium = authenticate(key)
        busy = false
        validate.Text = "VALIDER"

        if ok then
            result = { key = key, expires = PUSL.getExpiryUnix() or (os.time() + 86400) }
            status.TextColor3 = C.GOOD
            status.Text = ("Cle valide (%s)%s - lancement..."):format(
                PUSL.getExpiryFormatted() or "24h", premium and " [PREMIUM]" or "")
            task.wait(0.7)
        else
            fail(reason or "cle refusee")
        end
    end

    validate.MouseButton1Click:Connect(tryValidate)
    box.FocusLost:Connect(function(enter)
        if enter and box.Text ~= "" then tryValidate() end
    end)
    box:GetPropertyChangedSignal("Text"):Connect(function()
        if result then return end
        status.Text = ""
        status.TextColor3 = C.DIM
    end)

    getkey.MouseButton1Click:Connect(function()
        if hasClip then pcall(setclipboard, GETKEY_URL) end
        status.TextColor3 = C.GOLD
        status.Text = hasClip and "Lien copie ! Ouvre-le dans ton navigateur."
            or ("Ouvre : " .. GETKEY_URL)
    end)

    close.MouseButton1Click:Connect(function() closed = true end)

    while not result and not closed do task.wait(0.1) end

    pcall(function() dragConn:Disconnect() end)
    pcall(function() endConn:Disconnect() end)
    pcall(function() gui:Destroy() end)

    if not result then
        print("[MAREA] gate annule")
        return false
    end

    saveCache({ key = result.key, expires = result.expires })
    return true
end

local KEY_OK = keyGate()
if not KEY_OK then return end
print("[MAREA] cle validee - demarrage")
local META = {
    Name    = "Marea",
    Version = "1.1.0",
    Tagline = "ADRIATIC AIM SUITE",
    Author  = "you",
    Repo    = "github.com/<USER>/<REPO>",
}

getgenv = getgenv or function() return _G end
if getgenv().Marea and getgenv().Marea.Unload then pcall(getgenv().Marea.Unload) end

--============================= SERVICES ===================================
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local GuiService       = game:GetService("GuiService")
local Workspace        = game:GetService("Workspace")

local LP     = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

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

--=============================== BRAND ====================================
local BRAND = {
    ACCENT  = Color3.fromRGB(0, 200, 190),
    ACCENT2 = Color3.fromRGB(232, 193, 112),
    ENEMY   = Color3.fromRGB(255, 90, 90),
    ALLY    = Color3.fromRGB(0, 200, 190),
    LOCK    = Color3.fromRGB(255, 205, 90),
}

local function banner()
    print([[
   __  __    _    ____  _____    _
  |  \/  |  / \  |  _ \| ____|  / \
  | |\/| | / _ \ | |_) |  _|   / _ \
  | |  | |/ ___ \|  _ <| |___ / ___ \
  |_|  |_/_/   \_\_| \_\_____/_/   \_\
]])
    print(("  %s v%s  |  %s"):format(META.Name, META.Version, META.Tagline))
    print(("  repo: %s"):format(META.Repo))
    local ok, exec = pcall(function() return identifyexecutor() end)
    print(("  executor: %s  |  %s"):format(ok and exec or "unknown", os.date("%Y-%m-%d %H:%M")))
end

--=============================== CONFIG ===================================
local Config = {
    Aimbot = {
        Enabled    = false,
        Key        = Enum.KeyCode.E,
        Mode       = "Hold",       -- Hold / Toggle
        Origin     = "Mouse",      -- Mouse / Center
        TeamCheck  = true,
        WallCheck  = true,
        FOV        = 140,
        ShowFOV    = true,
        Smoothness = 0.30,
        Hitbox     = "Head",
        Prediction = 0.12,
        LockTarget = false,
    },
    ESP = {
        Enabled    = true,
        Box        = true,
        Name       = true,
        Health     = true,
        Distance   = true,
        Tracer     = false,
        Chams      = false,
        TargetRing = true,
        TeamCheck  = false,
        MaxDist    = 1000,
        TextSize   = 13,
    },
    Misc = {
        Fullbright = false,
        Watermark  = true,
        StatusBar  = true,
        MenuKey    = Enum.KeyCode.RightShift,
    },
}

--=============================== HELPERS ==================================
local function alive(plr)
    local char = plr.Character
    if not char then return nil end
    local hum  = char:FindFirstChildOfClass("Humanoid")
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
    return input.KeyCode == key or input.UserInputType == key
end

-- Screen space (Drawing) vs viewport space (camera math) --------------------
local function guiInset()
    local ok, inset = pcall(function() return GuiService:GetGuiInset() end)
    return (ok and inset) or Vector2.new(0, 0)
end

local function mouseViewport()   -- viewport space, matches WorldToViewportPoint
    local p = UserInputService:GetMouseLocation()
    local i = guiInset()
    return Vector2.new(p.X - i.X, p.Y - i.Y)
end

local function aimOrigin()       -- viewport space
    if Config.Aimbot.Origin == "Center" then
        local vp = Camera.ViewportSize
        return Vector2.new(vp.X / 2, vp.Y / 2)
    end
    return mouseViewport()
end

local function toScreen(v) return v + guiInset() end

--=============================== AIMBOT ===================================
local aimHold, aimToggle = false, false
local lockedTarget, currentTarget = nil, nil

local function aimPart(plr)
    local char = plr.Character
    if not char then return nil end
    return char:FindFirstChild(Config.Aimbot.Hitbox)
        or char:FindFirstChild("Head")
        or char:FindFirstChild("HumanoidRootPart")
        or char:FindFirstChild("UpperTorso")
        or char:FindFirstChild("Torso")
end

-- Returns the target part only if it is IN FRONT of the camera and INSIDE the FOV
local function inFov(part, ref, fov)
    local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
    if not onScreen then return false end
    if sp.Z <= 0 then return false end          -- <-- the actual fix: behind camera
    local d = (Vector2.new(sp.X, sp.Y) - ref).Magnitude
    if d > fov then return false end
    return true, d
end

local function closestTarget()
    local ref = aimOrigin()
    local fov = Config.Aimbot.FOV
    local best, bestScore = nil, math.huge

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and isEnemy(plr) and alive(plr) then
            local part = aimPart(plr)
            if part then
                local ok, d = inFov(part, ref, fov)
                if ok and d < bestScore then
                    if not Config.Aimbot.WallCheck or isVisible(part) then
                        best, bestScore = plr, d
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
    if target and not Config.Aimbot.LockTarget then target = nil end

    if not target then
        target = closestTarget()
        lockedTarget = Config.Aimbot.LockTarget and target or nil
    end

    currentTarget = target
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
local espObjects, espGui = {}, nil

local fovCircle = DRAWING and mkDraw("Circle") or nil
if fovCircle then
    fovCircle.Thickness, fovCircle.Filled = 1, false
    fovCircle.NumSides, fovCircle.Transparency = 64, 0.45
    fovCircle.Color = BRAND.ACCENT
end

local targetRing = DRAWING and mkDraw("Circle") or nil
if targetRing then
    targetRing.Thickness, targetRing.Filled = 2, false
    targetRing.NumSides, targetRing.Transparency = 40, 0.15
    targetRing.Color = BRAND.LOCK
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
            box = mkDraw("Square"), name = mkDraw("Text"), dist = mkDraw("Text"),
            tracer = mkDraw("Line"), hbg = mkDraw("Square"), hfill = mkDraw("Square"),
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
        espGui.Name, espGui.ResetOnSpawn, espGui.IgnoreGuiInset = "MareaESP", false, true
        pcall(function() espGui.Parent = game:GetService("CoreGui") end)
        if not espGui.Parent then espGui.Parent = LP:WaitForChild("PlayerGui") end
    end

    local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    if not root then return nil end

    local bb = Instance.new("BillboardGui")
    bb.Name, bb.Size, bb.AlwaysOnTop = "MareaESP", UDim2.new(0, 60, 0, 90), true
    bb.StudsOffset, bb.Adornee, bb.Parent = Vector3.new(0, 3, 0), root, root

    local box = Instance.new("Frame")
    box.BackgroundTransparency, box.Size, box.Parent = 1, UDim2.fromScale(1, 1), bb
    local st = Instance.new("UIStroke")
    st.Thickness, st.Parent = 1.5, box

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency, label.Size = 1, UDim2.new(1, 0, 0, 14)
    label.Position, label.Font, label.TextSize = UDim2.new(0, 0, 0, -16), Enum.Font.GothamBold, 12
    label.TextStrokeTransparency, label.Parent = 0, bb

    return { bb = bb, stroke = st, label = label, fallback = true }
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
                    h.Name, h.DepthMode = "MareaHL", Enum.HighlightDepthMode.AlwaysOnTop
                    h.FillTransparency, h.OutlineTransparency = 0.65, 0
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
                            toScreen(Vector2.new(minX, minY)), Vector2.new(w, hgt), color

                        o.name.Visible = Config.ESP.Name
                        o.name.Text, o.name.Size, o.name.Color = plr.Name, Config.ESP.TextSize, color
                        o.name.Position = toScreen(Vector2.new(cx, minY - Config.ESP.TextSize - 4))

                        o.dist.Visible = Config.ESP.Distance
                        o.dist.Text  = string.format("%d m", math.floor(dist))
                        o.dist.Size  = Config.ESP.TextSize - 1
                        o.dist.Color = Color3.fromRGB(235, 235, 245)
                        o.dist.Position = toScreen(Vector2.new(cx, maxY + 3))

                        o.tracer.Visible = Config.ESP.Tracer
                        o.tracer.From, o.tracer.To, o.tracer.Color =
                            toScreen(Vector2.new(vp.X / 2, vp.Y)), toScreen(Vector2.new(cx, maxY)), color
                        o.tracer.Thickness = 1

                        local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                        o.hbg.Visible, o.hfill.Visible = Config.ESP.Health, Config.ESP.Health
                        o.hbg.Position, o.hbg.Size, o.hbg.Color =
                            toScreen(Vector2.new(minX - 6, minY)), Vector2.new(3, hgt), Color3.fromRGB(25, 25, 30)
                        o.hfill.Position = toScreen(Vector2.new(minX - 6, minY + hgt * (1 - pct)))
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

onConn(Players.PlayerRemoving:Connect(function(p) destroyESP(p) end))

--================================= UI =====================================
local T = {
    BG     = Color3.fromRGB(13, 15, 18),
    PANEL  = Color3.fromRGB(18, 21, 25),
    ELEM   = Color3.fromRGB(28, 32, 38),
    HOVER  = Color3.fromRGB(36, 41, 48),
    STROKE = Color3.fromRGB(42, 48, 56),
    ACCENT = BRAND.ACCENT,
    GOLD   = BRAND.ACCENT2,
    TEXT   = Color3.fromRGB(233, 238, 242),
    DIM    = Color3.fromRGB(138, 148, 158),
    GOOD   = Color3.fromRGB(60, 200, 120),
    FONT   = Enum.Font.Gotham,
    BOLD   = Enum.Font.GothamBold,
    BLACK  = Enum.Font.GothamBlack,
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
local function gradient(o, a, b, rot)
    local g = mk("UIGradient", { Parent = o, Rotation = rot or 0 })
    g.Color = ColorSequence.new(a, b)
    return g
end
local function spaced(s) return table.concat({ s:gsub(".", "%1 "):gsub(" $", "") }, "") end

local gui = mk("ScreenGui", {
    Name = "Marea", ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true,
})
pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end

-- Shadow + window
local shadow = mk("Frame", {
    Parent = gui, Size = UDim2.new(0, 540, 0, 390), Position = UDim2.new(0, 62, 0, 124),
    BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.55,
    BorderSizePixel = 0, ZIndex = 0,
})
corner(shadow, 12)

local main = mk("Frame", {
    Name = "Window", Parent = gui, Size = UDim2.new(0, 540, 0, 390),
    Position = UDim2.new(0, 60, 0, 120), BackgroundColor3 = T.BG,
    BorderSizePixel = 0, ZIndex = 2,
})
corner(main, 12) stroke(main, T.STROKE, 1)

--============================= TITLEBAR ===================================
local titlebar = mk("Frame", {
    Parent = main, Size = UDim2.new(1, 0, 0, 48),
    BackgroundColor3 = T.PANEL, BorderSizePixel = 0, ZIndex = 3,
})
corner(titlebar, 12)
mk("Frame", {
    Parent = titlebar, Size = UDim2.new(1, 0, 0, 14),
    Position = UDim2.new(0, 0, 1, -14), BackgroundColor3 = T.PANEL,
    BorderSizePixel = 0, ZIndex = 3,
})
local divider = mk("Frame", {
    Parent = titlebar, Size = UDim2.new(1, 0, 0, 1),
    Position = UDim2.new(0, 0, 1, -1), BackgroundColor3 = T.ACCENT,
    BorderSizePixel = 0, ZIndex = 4,
})
gradient(divider, T.ACCENT, T.GOLD, 0)

-- Logo mark
local mark = mk("Frame", {
    Parent = titlebar, Size = UDim2.new(0, 30, 0, 30),
    Position = UDim2.new(0, 14, 0.5, -15), BackgroundColor3 = T.ACCENT,
    BorderSizePixel = 0, ZIndex = 5,
})
corner(mark, 8)
gradient(mark, BRAND.ACCENT, BRAND.ACCENT2, 45)
mk("TextLabel", {
    Parent = mark, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
    Font = T.BLACK, TextSize = 17, TextColor3 = Color3.fromRGB(10, 20, 22),
    Text = "M", ZIndex = 6,
})

-- Wordmark
local wordmark = mk("TextLabel", {
    Parent = titlebar, BackgroundTransparency = 1,
    Position = UDim2.new(0, 54, 0, 7), Size = UDim2.new(0, 160, 0, 20),
    Font = T.BLACK, TextSize = 17, TextColor3 = Color3.new(1, 1, 1),
    Text = spaced("MAREA"), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
})
local wmGrad = gradient(wordmark, BRAND.ACCENT, BRAND.ACCENT2, 0)
TweenService:Create(wmGrad, TweenInfo.new(3.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
    { Offset = Vector2.new(0.6, 0) }):Play()

mk("TextLabel", {
    Parent = titlebar, BackgroundTransparency = 1,
    Position = UDim2.new(0, 55, 0, 27), Size = UDim2.new(0, 220, 0, 12),
    Font = T.BOLD, TextSize = 8, TextColor3 = T.DIM,
    Text = spaced(META.Tagline), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
})

local pill = mk("TextLabel", {
    Parent = titlebar, BackgroundColor3 = T.ELEM,
    Position = UDim2.new(1, -122, 0.5, -8), Size = UDim2.new(0, 46, 0, 16),
    Font = T.BOLD, TextSize = 10, TextColor3 = T.ACCENT,
    Text = "v" .. META.Version, BorderSizePixel = 0, ZIndex = 5,
})
corner(pill, 4)

local minimize = mk("TextButton", {
    Parent = titlebar, Size = UDim2.new(0, 24, 0, 24),
    Position = UDim2.new(1, -32, 0.5, -12), BackgroundColor3 = T.ELEM,
    Font = T.BOLD, TextSize = 13, TextColor3 = T.TEXT, Text = "—",
    AutoButtonColor = false, ZIndex = 5,
})
corner(minimize, 6)

--============================= LAYOUT =====================================
local sidebar = mk("Frame", {
    Parent = main, Position = UDim2.new(0, 10, 0, 58),
    Size = UDim2.new(0, 122, 1, -96), BackgroundTransparency = 1, ZIndex = 3,
})
local content = mk("Frame", {
    Parent = main, Position = UDim2.new(0, 142, 0, 58),
    Size = UDim2.new(1, -152, 1, -96), BackgroundTransparency = 1, ZIndex = 3,
})

local tabs, pages = {}, {}
local order = { "Aimbot", "ESP", "Players", "Misc" }
local currentTab

local function selectTab(name)
    currentTab = name
    for n, p in pairs(pages) do p.Visible = (n == name) end
    for n, d in pairs(tabs) do
        d.holder.BackgroundColor3 = (n == name) and T.ACCENT or T.ELEM
        d.label.TextColor3 = (n == name) and Color3.fromRGB(10, 20, 22) or T.DIM
        d.bar.Visible = (n == name)
    end
end

for i, name in ipairs(order) do
    local holder = mk("Frame", {
        Parent = sidebar, Size = UDim2.new(1, 0, 0, 32),
        Position = UDim2.new(0, 0, 0, (i - 1) * 36),
        BackgroundColor3 = T.ELEM, BorderSizePixel = 0,
    })
    corner(holder, 6)

    local bar = mk("Frame", {
        Parent = holder, Size = UDim2.new(0, 3, 0, 16),
        Position = UDim2.new(0, 0, 0.5, -8),
        BackgroundColor3 = Color3.fromRGB(10, 20, 22), BorderSizePixel = 0, Visible = false,
    })
    corner(bar, 2)

    local label = mk("TextLabel", {
        Parent = holder, BackgroundTransparency = 1, Size = UDim2.new(1, -14, 1, 0),
        Position = UDim2.new(0, 14, 0, 0), Font = T.BOLD, TextSize = 12,
        TextColor3 = T.DIM, Text = name, TextXAlignment = Enum.TextXAlignment.Left,
    })

    local btn = mk("TextButton", {
        Parent = holder, Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
        Text = "", AutoButtonColor = false,
    })

    btn.MouseButton1Click:Connect(function() selectTab(name) end)
    holder.MouseEnter:Connect(function()
        if currentTab ~= name then holder.BackgroundColor3 = T.HOVER end
    end)
    holder.MouseLeave:Connect(function()
        if currentTab ~= name then holder.BackgroundColor3 = T.ELEM end
    end)

    tabs[name] = { holder = holder, label = label, bar = bar }

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

local sig = mk("Frame", {
    Parent = sidebar, Size = UDim2.new(1, 0, 0, 30),
    Position = UDim2.new(0, 2, 1, -30), BackgroundTransparency = 1,
})
mk("TextLabel", {
    Parent = sig, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14),
    Font = T.BLACK, TextSize = 10, TextColor3 = T.GOLD,
    Text = "MAREA  v" .. META.Version, TextXAlignment = Enum.TextXAlignment.Left,
})
mk("TextLabel", {
    Parent = sig, BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 14),
    Size = UDim2.new(1, 0, 0, 14), Font = T.FONT, TextSize = 9,
    TextColor3 = T.DIM, Text = spaced("ADRIATIC"), TextXAlignment = Enum.TextXAlignment.Left,
})

--============================= STATUS BAR =================================
local statusBar = mk("Frame", {
    Parent = main, Size = UDim2.new(1, -20, 0, 24),
    Position = UDim2.new(0, 10, 1, -30), BackgroundColor3 = T.PANEL,
    BorderSizePixel = 0, ZIndex = 3,
})
corner(statusBar, 6)
mk("Frame", {
    Parent = statusBar, Size = UDim2.new(0, 3, 0, 12),
    Position = UDim2.new(0, 8, 0.5, -6), BackgroundColor3 = T.ACCENT, BorderSizePixel = 0,
})
corner(statusBar:FindFirstChildOfClass("Frame"), 2)

local statusTarget = mk("TextLabel", {
    Parent = statusBar, BackgroundTransparency = 1, Size = UDim2.new(0.6, 0, 1, 0),
    Position = UDim2.new(0, 18, 0, 0), Font = T.BOLD, TextSize = 10,
    TextColor3 = T.DIM, Text = "TARGET  —", TextXAlignment = Enum.TextXAlignment.Left,
})
local statusFps = mk("TextLabel", {
    Parent = statusBar, BackgroundTransparency = 1, Size = UDim2.new(0.3, 0, 1, 0),
    Position = UDim2.new(0.7, 0, 0, 0), Font = T.BOLD, TextSize = 10,
    TextColor3 = T.ACCENT, Text = "60 FPS", TextXAlignment = Enum.TextXAlignment.Right,
})

--============================= COMPONENTS =================================
local function section(parent, text)
    local f = mk("Frame", { Parent = parent, Size = UDim2.new(1, -4, 0, 24), BackgroundTransparency = 1 })
    mk("TextLabel", {
        Parent = f, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
        Font = T.BOLD, TextSize = 12, TextColor3 = T.ACCENT,
        Text = string.upper(text), TextXAlignment = Enum.TextXAlignment.Left,
    })
    return f
end

local function toggle(parent, text, default, cb)
    local row = mk("Frame", { Parent = parent, Size = UDim2.new(1, -4, 0, 26), BackgroundTransparency = 1 })
    mk("TextLabel", {
        Parent = row, BackgroundTransparency = 1, Size = UDim2.new(1, -50, 1, 0),
        Font = T.FONT, TextSize = 13, TextColor3 = T.TEXT,
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
    local function render(anim)
        local goalPos = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
        if anim then
            TweenService:Create(knob, TweenInfo.new(0.14, Enum.EasingStyle.Quad), { Position = goalPos }):Play()
        else
            knob.Position = goalPos
        end
        box.BackgroundColor3 = state and T.ACCENT or T.ELEM
        knob.BackgroundColor3 = state and Color3.fromRGB(10, 20, 22) or T.DIM
    end
    box.MouseButton1Click:Connect(function()
        state = not state; render(true); cb(state)
    end)
    render(false)
    return { Set = function(v) state = v; render(true); cb(v) end, Get = function() return state end }
end

local function slider(parent, text, min, max, default, cb)
    local row = mk("Frame", { Parent = parent, Size = UDim2.new(1, -4, 0, 38), BackgroundTransparency = 1 })
    mk("TextLabel", {
        Parent = row, BackgroundTransparency = 1, Size = UDim2.new(0.7, 0, 0, 16),
        Font = T.FONT, TextSize = 13, TextColor3 = T.TEXT,
        Text = text, TextXAlignment = Enum.TextXAlignment.Left,
    })
    local value = mk("TextLabel", {
        Parent = row, BackgroundTransparency = 1, Size = UDim2.new(0.3, 0, 0, 16),
        Position = UDim2.new(0.7, 0, 0, 0), Font = T.BOLD, TextSize = 12,
        TextColor3 = T.ACCENT, Text = tostring(default), TextXAlignment = Enum.TextXAlignment.Right,
    })
    local bar = mk("TextButton", {
        Parent = row, Size = UDim2.new(1, 0, 0, 8), Position = UDim2.new(0, 0, 0, 24),
        BackgroundColor3 = T.ELEM, Text = "", AutoButtonColor = false,
    })
    corner(bar, 4)
    local fill = mk("Frame", { Parent = bar, Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = T.ACCENT, BorderSizePixel = 0 })
    corner(fill, 4)
    gradient(fill, BRAND.ACCENT, BRAND.ACCENT2, 0)

    local dragging, val = false, default
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
        Font = T.FONT, TextSize = 13, TextColor3 = T.TEXT,
        Text = text, TextXAlignment = Enum.TextXAlignment.Left,
    })
    local btn = mk("TextButton", {
        Parent = row, Size = UDim2.new(0, 70, 0, 22), Position = UDim2.new(1, -70, 0.5, -11),
        BackgroundColor3 = T.ELEM, Font = T.BOLD, TextSize = 11,
        TextColor3 = T.TEXT, Text = default and default.Name or "—", AutoButtonColor = false,
    })
    corner(btn, 5)
    local state, listening = default, false

    btn.MouseButton1Click:Connect(function()
        if listening then return end
        listening, btn.Text, btn.BackgroundColor3 = true, "...", T.ACCENT
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
        Font = T.FONT, TextSize = 13, TextColor3 = T.TEXT,
        Text = text, TextXAlignment = Enum.TextXAlignment.Left,
    })
    local btn = mk("TextButton", {
        Parent = row, Size = UDim2.new(0, 80, 0, 22), Position = UDim2.new(1, -80, 0.5, -11),
        BackgroundColor3 = T.ELEM, Font = T.BOLD, TextSize = 11,
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
        Font = T.BOLD, TextSize = 12, TextColor3 = T.TEXT, Text = text, AutoButtonColor = false,
    })
    corner(b, 6)
    b.MouseButton1Click:Connect(cb)
    return b
end

--============================= AIMBOT PAGE ================================
local pAim = pages["Aimbot"]
section(pAim, "General")
toggle(pAim, "Enable aimbot", Config.Aimbot.Enabled, function(v) Config.Aimbot.Enabled = v end)
dropdown(pAim, "Activation mode", { "Hold", "Toggle" }, Config.Aimbot.Mode, function(v) Config.Aimbot.Mode = v end)
keybind(pAim, "Aim key", Config.Aimbot.Key, function(k) Config.Aimbot.Key = k end)
dropdown(pAim, "FOV origin", { "Mouse", "Center" }, Config.Aimbot.Origin, function(v) Config.Aimbot.Origin = v end)

section(pAim, "Tuning")
slider(pAim, "FOV radius", 10, 500, Config.Aimbot.FOV, function(v) Config.Aimbot.FOV = v end)
slider(pAim, "Smoothing", 0.02, 1, Config.Aimbot.Smoothness, function(v) Config.Aimbot.Smoothness = v end)
slider(pAim, "Velocity prediction", 0, 0.4, Config.Aimbot.Prediction, function(v) Config.Aimbot.Prediction = v end)
dropdown(pAim, "Hitbox", { "Head", "HumanoidRootPart", "UpperTorso" }, Config.Aimbot.Hitbox, function(v) Config.Aimbot.Hitbox = v end)

section(pAim, "Filters")
toggle(pAim, "Team check", Config.Aimbot.TeamCheck, function(v) Config.Aimbot.TeamCheck = v end)
toggle(pAim, "Wall check", Config.Aimbot.WallCheck, function(v) Config.Aimbot.WallCheck = v end)
toggle(pAim, "Lock target", Config.Aimbot.LockTarget, function(v) Config.Aimbot.LockTarget = v end)
toggle(pAim, "Show FOV circle", Config.Aimbot.ShowFOV, function(v) Config.Aimbot.ShowFOV = v end)

--=============================== ESP PAGE =================================
local pEsp = pages["ESP"]
section(pEsp, "General")
toggle(pEsp, "Enable ESP", Config.ESP.Enabled, function(v) Config.ESP.Enabled = v end)
slider(pEsp, "Max distance", 50, 5000, Config.ESP.MaxDist, function(v) Config.ESP.MaxDist = v end)
slider(pEsp, "Text size", 8, 22, Config.ESP.TextSize, function(v) Config.ESP.TextSize = v end)

section(pEsp, "Elements")
toggle(pEsp, "Boxes", Config.ESP.Box, function(v) Config.ESP.Box = v end)
toggle(pEsp, "Names", Config.ESP.Name, function(v) Config.ESP.Name = v end)
toggle(pEsp, "Health bars", Config.ESP.Health, function(v) Config.ESP.Health = v end)
toggle(pEsp, "Distance", Config.ESP.Distance, function(v) Config.ESP.Distance = v end)
toggle(pEsp, "Tracers", Config.ESP.Tracer, function(v) Config.ESP.Tracer = v end)
toggle(pEsp, "Chams", Config.ESP.Chams, function(v) Config.ESP.Chams = v end)
toggle(pEsp, "Target ring", Config.ESP.TargetRing, function(v) Config.ESP.TargetRing = v end)

section(pEsp, "Filters")
toggle(pEsp, "Team colors", Config.ESP.TeamCheck, function(v) Config.ESP.TeamCheck = v end)

--============================= PLAYERS PAGE ===============================
local pPlr = pages["Players"]
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
            Position = UDim2.new(0, 8, 0, 0), Font = T.FONT, TextSize = 12,
            TextColor3 = (plr == LP) and T.ACCENT or T.TEXT,
            Text = plr.Name .. (plr == LP and "  (you)" or ""),
            TextXAlignment = Enum.TextXAlignment.Left,
        })
        mk("TextLabel", {
            Parent = row, BackgroundTransparency = 1, Size = UDim2.new(0, 60, 1, 0),
            Position = UDim2.new(0.5, 0, 0, 0), Font = T.BOLD, TextSize = 12,
            TextColor3 = hum and T.GOOD or T.DIM,
            Text = hum and (math.floor(hum.Health) .. " HP") or "dead",
            TextXAlignment = Enum.TextXAlignment.Left,
        })

        local spec = mk("TextButton", {
            Parent = row, Size = UDim2.new(0, 50, 0, 20), Position = UDim2.new(1, -112, 0.5, -10),
            BackgroundColor3 = T.ELEM, Font = T.BOLD, TextSize = 11,
            TextColor3 = T.TEXT, Text = "Spec", AutoButtonColor = false,
        })
        corner(spec, 4)
        spec.MouseButton1Click:Connect(function()
            local _, h = alive(plr)
            if h then Camera.CameraSubject = h end
        end)

        local tp = mk("TextButton", {
            Parent = row, Size = UDim2.new(0, 50, 0, 20), Position = UDim2.new(1, -56, 0.5, -10),
            BackgroundColor3 = T.ELEM, Font = T.BOLD, TextSize = 11,
            TextColor3 = T.TEXT, Text = "TP", AutoButtonColor = false,
        })
        corner(tp, 4)
        tp.MouseButton1Click:Connect(function()
            local _, _, r  = alive(plr)
            local _, _, mr = alive(LP)
            if r and mr then mr.CFrame = r.CFrame * CFrame.new(0, 0, 3) end
        end)
    end
    plrList.Size = UDim2.new(1, -4, 0, math.max(10, #Players:GetPlayers() * 32))
end

button(pPlr, "Refresh list", refreshPlayers)
refreshPlayers()
onConn(Players.PlayerAdded:Connect(function() task.wait(0.3); refreshPlayers() end))
onConn(Players.PlayerRemoving:Connect(function() task.wait(0.1); refreshPlayers() end))

--=============================== MISC PAGE ================================
local pMisc = pages["Misc"]
section(pMisc, "Visuals")
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
toggle(pMisc, "Status bar", Config.Misc.StatusBar, function(v)
    Config.Misc.StatusBar = v
    statusBar.Visible = v
end)

section(pMisc, "Interface")
keybind(pMisc, "Menu key", Config.Misc.MenuKey, function(k) Config.Misc.MenuKey = k end)

section(pMisc, "Actions")
button(pMisc, "Reset character", function()
    local c = LP.Character
    if c then local h = c:FindFirstChildOfClass("Humanoid"); if h then h.Health = 0 end end
end)
button(pMisc, "Unload " .. META.Name, function()
    if getgenv().Marea then getgenv().Marea.Unload() end
end)

--============================= WATERMARK ==================================
local wmMark = mk("TextLabel", {
    Parent = gui, BackgroundTransparency = 1, Position = UDim2.new(0, 14, 1, -34),
    Size = UDim2.new(0, 300, 0, 20), Font = T.BLACK, TextSize = 15,
    TextColor3 = Color3.new(1, 1, 1), Text = spaced("MAREA"),
    TextXAlignment = Enum.TextXAlignment.Left, TextStrokeTransparency = 0.6,
    TextStrokeColor3 = Color3.new(0, 0, 0),
})
gradient(wmMark, BRAND.ACCENT, BRAND.ACCENT2, 0)
mk("TextLabel", {
    Parent = gui, BackgroundTransparency = 1, Position = UDim2.new(0, 14, 1, -17),
    Size = UDim2.new(0, 300, 0, 20), Font = T.FONT, TextSize = 10,
    TextColor3 = T.DIM, Text = spaced(META.Tagline),
    TextXAlignment = Enum.TextXAlignment.Left, TextStrokeTransparency = 0.8,
    TextStrokeColor3 = Color3.new(0, 0, 0),
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
        shadow.Position = main.Position + UDim2.new(0, 2, 0, 4)
    end
end))
onConn(UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end))

local minimized = false
minimize.MouseButton1Click:Connect(function()
    minimized = not minimized
    sidebar.Visible, content.Visible = not minimized, not minimized
    statusBar.Visible = (not minimized) and Config.Misc.StatusBar
    local goal = minimized and UDim2.new(0, 540, 0, 48) or UDim2.new(0, 540, 0, 390)
    TweenService:Create(main, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { Size = goal }):Play()
    TweenService:Create(shadow, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { Size = goal }):Play()
    minimize.Text = minimized and "+" or "—"
end)

selectTab("Aimbot")

--============================ NOTIFICATIONS ===============================
local function notify(text, color)
    local n = mk("Frame", {
        Parent = gui, Size = UDim2.new(0, 250, 0, 32),
        Position = UDim2.new(1, -270, 1, -50), BackgroundColor3 = T.PANEL,
        BorderSizePixel = 0, BackgroundTransparency = 1,
    })
    corner(n, 7) stroke(n, color or T.STROKE, 1)
    mk("Frame", {
        Parent = n, Size = UDim2.new(0, 3, 0, 18), Position = UDim2.new(0, 6, 0.5, -9),
        BackgroundColor3 = color or T.ACCENT, BorderSizePixel = 0,
    })
    local lbl = mk("TextLabel", {
        Parent = n, BackgroundTransparency = 1, Size = UDim2.new(1, -22, 1, 0),
        Position = UDim2.new(0, 16, 0, 0), Font = T.BOLD, TextSize = 12,
        TextColor3 = color or T.TEXT, Text = text, TextTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    TweenService:Create(n, TweenInfo.new(0.2), {
        BackgroundTransparency = 0, Position = UDim2.new(1, -270, 1, -62),
    }):Play()
    TweenService:Create(lbl, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
    task.delay(2.2, function()
        TweenService:Create(n, TweenInfo.new(0.25), {
            BackgroundTransparency = 1, Position = UDim2.new(1, -270, 1, -50),
        }):Play()
        TweenService:Create(lbl, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
        task.wait(0.3)
        n:Destroy()
    end)
end

--=============================== INPUT ====================================
onConn(UserInputService.InputBegan:Connect(function(input, gpe)
    if keyMatches(input, Config.Misc.MenuKey) then
        main.Visible, shadow.Visible = not main.Visible, not shadow.Visible
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

--=============================== LOOP =====================================
local fps, fpsAcc, fpsFrames = 60, 0, 0

onConn(RunService.RenderStepped:Connect(function(dt)
    fpsAcc, fpsFrames = fpsAcc + dt, fpsFrames + 1
    if fpsAcc >= 0.4 then
        fps = math.floor(fpsFrames / fpsAcc)
        fpsAcc, fpsFrames = 0, 0
        statusFps.Text = fps .. " FPS"
    end

    local aiming = Config.Aimbot.Enabled and (aimHold or aimToggle)
    if aiming then
        runAimbot(dt)
    else
        currentTarget = nil
        if not Config.Aimbot.LockTarget then lockedTarget = nil end
    end

    if fovCircle then
        fovCircle.Visible = Config.Aimbot.Enabled and Config.Aimbot.ShowFOV
        local ref = aimOrigin()
        fovCircle.Position = toScreen(ref)
        fovCircle.Radius = Config.Aimbot.FOV
        fovCircle.Color = (aiming and currentTarget) and BRAND.LOCK or BRAND.ACCENT
    end

    if targetRing then
        local show = Config.ESP.TargetRing and aiming and currentTarget
        targetRing.Visible = show and true or false
        if show then
            local part = aimPart(currentTarget)
            if part then
                local sp, on = Camera:WorldToViewportPoint(part.Position)
                if on and sp.Z > 0 then
                    targetRing.Position = toScreen(Vector2.new(sp.X, sp.Y))
                    targetRing.Radius = math.clamp(900 / sp.Z, 5, 70)
                    targetRing.Color = BRAND.LOCK
                else
                    targetRing.Visible = false
                end
            end
        end
    end

    if Config.Misc.StatusBar then
        statusTarget.Text = currentTarget
            and ("TARGET  " .. currentTarget.Name:upper())
            or "TARGET  —"
        statusTarget.TextColor3 = currentTarget and BRAND.LOCK or T.DIM
    end

    wmMark.Visible = Config.Misc.Watermark
    updateESP()
end))

--=============================== UNLOAD ===================================
local function unload()
    for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
    for _, d in ipairs(Drawings) do pcall(function() d:Remove() end) end
    for plr in pairs(espObjects) do destroyESP(plr) end
    pcall(function() gui:Destroy() end)
    pcall(function() if espGui then espGui:Destroy() end end)
    getgenv().Marea = nil
    print(("[%s] unloaded."):format(META.Name))
end

getgenv().Marea = {
    Name    = META.Name,
    Version = META.Version,
    Config  = Config,
    Unload  = unload,
}

banner()
notify("MAREA v" .. META.Version .. "  •  RIGHT SHIFT = menu", T.ACCENT)
