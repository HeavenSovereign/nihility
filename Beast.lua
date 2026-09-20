local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")
local VirtualInputManager = game:GetService("VirtualInputManager")
local PathfindingService = game:GetService("PathfindingService")

local RuntimeEnv = (getgenv and getgenv()) or _G
local PersistedSettings = {}
if type(RuntimeEnv.__IslandEscapeSettings) == "table" then
    for key, value in pairs(RuntimeEnv.__IslandEscapeSettings) do PersistedSettings[key] = value end
end
if RuntimeEnv.__IslandEscapeCleanup then
    pcall(RuntimeEnv.__IslandEscapeCleanup)
end

-- Remove a menu left behind by versions that predate the runtime cleanup.
for _, child in ipairs(CoreGui:GetChildren()) do
    if child.Name == "Config" then pcall(function() child:Destroy() end) end
end

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- ========== AUTO-FIND PATHS ==========
local Events = ReplicatedStorage:WaitForChild("Events")
local GameFolder = Workspace:WaitForChild("Game")
local Entities = GameFolder:WaitForChild("Entities")

-- ========== MOB NAME TRANSLATIONS ==========
local MobTranslations = {
    ["野人弓箭手"] = "Wild Archer", ["野人长矛手"] = "Wild Spearman",
    ["野人战士"] = "Wild Warrior", ["章鱼怪大副"] = "Octopus Mate",
    ["章鱼怪海盗"] = "Octopus Pirate", ["章鱼怪火枪手"] = "Octopus Musketeer",
    ["章鱼怪船长"] = "Octopus Captain", ["小触手"] = "Small Tentacle",
    ["大触手"] = "Big Tentacle", ["章鱼触手"] = "Octopus Tentacle",
    ["熟章鱼触手"] = "Cooked Tentacle", ["森林守护者"] = "Forest Guardian",
    ["原始部落"] = "Primitive Tribe", ["原始部落盔甲"] = "Tribal Armor",
    ["森林守护者盔甲"] = "Guardian Armor", ["森林守护者鞋子"] = "Guardian Boots",
    ["章鱼船锚"] = "Octopus Anchor", ["章鱼大炮"] = "Octopus Cannon",
    ["火焰法杖"] = "Fire Staff", ["原始部落火把"] = "Tribal Torch",
    ["原始部落长矛"] = "Tribal Spear", ["原始部落回力镖"] = "Tribal Boomerang",
    ["森林守护者飞斧"] = "Guardian Flying Axe", ["章鱼大炮弹道"] = "Octopus Cannonball",
    ["章鱼怪大副弹道"] = "Mate Projectile", ["章鱼怪火枪手弹道"] = "Musketeer Bullet",
    ["野人弓箭手弹道"] = "Archer Arrow", ["原始部落回力镖弹道"] = "Boomerang Projectile",
    ["森林守护者飞斧弹道"] = "Guardian Axe Projectile", ["火球"] = "Fireball",
    ["海鸥"] = "Seagull", ["木材"] = "Wood", ["石头"] = "Stone",
    ["铁矿石"] = "Iron Ore", ["铁矿"] = "Iron Ore", ["塑料桶"] = "Plastic Bucket",
    ["熟肉"] = "Cooked Meat", ["生肉"] = "Raw Meat", ["木地板"] = "Wood Floor",
    ["木墙"] = "Wood Wall", ["木半墙"] = "Wood Half Wall", ["木斜板"] = "Wood Slope",
    ["木刺路障"] = "Wood Spike Barricade", ["火炬"] = "Torch", ["制作台"] = "Workbench",
    ["木头"] = "Wood", ["树"] = "Tree", ["树干"] = "Tree Trunk", ["树叶"] = "Leaves",
    ["岩石"] = "Rock", ["草"] = "Grass", ["纤维"] = "Fiber", ["浆果"] = "Berries",
    ["椰子"] = "Coconut", ["鸡"] = "Chicken", ["鸡蛋"] = "Egg", ["羽毛"] = "Feather",
    ["熊"] = "Bear", ["熊皮"] = "Bear Pelt", ["蛇"] = "Snake", ["蛇牙"] = "Snake Tooth",
    ["蜘蛛"] = "Spider", ["蜘蛛网"] = "Spider Web", ["宝箱"] = "Chest",
    ["熔炉"] = "Furnace", ["冶炼"] = "Smelting"
}

local TranslationOrder = {
    "森林守护者盔甲", "森林守护者鞋子", "森林守护者飞斧弹道", "原始部落回力镖弹道",
    "章鱼怪火枪手弹道", "章鱼怪大副弹道", "野人弓箭手弹道", "木刺路障",
    "原始部落回力镖", "原始部落长矛", "原始部落火把", "森林守护者飞斧",
    "章鱼怪火枪手", "章鱼怪船长", "章鱼怪海盗", "章鱼怪大副",
    "野人弓箭手", "野人长矛手", "野人战士", "熟章鱼触手", "章鱼触手",
    "森林守护者", "原始部落盔甲", "原始部落", "章鱼大炮弹道", "章鱼船锚",
    "章鱼大炮", "火焰法杖", "木半墙", "木地板", "木斜板", "制作台",
    "铁矿石", "塑料桶", "熟肉", "生肉", "树干", "树叶", "岩石", "木材",
    "木头", "石头", "纤维", "浆果", "椰子", "鸡蛋", "羽毛", "熊皮",
    "蛇牙", "蜘蛛网", "宝箱", "熔炉", "冶炼", "小触手", "大触手", "海鸥",
    "木墙", "火炬", "铁矿", "火球", "树", "草", "鸡", "熊", "蛇", "蜘蛛"
}

local function HasNonEnglishBytes(text)
    return tostring(text or ""):find("[\128-\255]") ~= nil
end

local function TranslateName(name, fallback)
    local original = tostring(name or "")
    if MobTranslations[original] then return MobTranslations[original] end
    local translated = original
    for _, source in ipairs(TranslationOrder) do
        if translated:find(source, 1, true) then
            translated = translated:gsub(source, MobTranslations[source])
        end
    end
    if HasNonEnglishBytes(translated) then return fallback or "UNKNOWN" end
    if translated == "" then return fallback or "UNKNOWN" end
    return translated
end

-- ========== SETTINGS ==========
local Settings = {
    MenuOpen = false,
    MenuKey = Enum.KeyCode.P,
    
    StealthMode = true,
    HumanizationEnabled = true,
    MissChance = 15,
    RandomMoveEnabled = true,
    
    -- Player ESP
    ESPEnabled = true,
    ESPBox = true,
    ESPName = true,
    ESPDistance = true,
    ESPHealthBar = true,
    ESPHealthText = true,
    ESPHealthMode = "percent",
    ESPMaxDistance = 1500,
    
    -- Mob ESP
    MobESPEnabled = true,
    MobESPBox = true,
    MobESPName = true,
    MobESPHealthBar = true,
    MobESPHealthText = true,
    MobESPHealthMode = "fraction",
    MobESPMaxDistance = 800,

    -- Resource ESP
    ResourceESPEnabled = true,
    ResourceESPHighlight = true,
    ResourceESPName = true,
    ResourceESPDistance = true,
    ResourceESPChests = true,
    ResourceESPIron = true,
    ResourceESPStone = true,
    ResourceESPWood = true,
    ResourceESPOther = true,
    ResourceESPMaxDistance = 2000,
    InstantChestOpen = true,
    InstantFurnace = true,
    
    -- Hitbox
    HitboxEnabled = false,
    HitboxSize = 12,
    
    -- Aimbot
    AimbotEnabled = true,
    AimPart = "Head",
    Smoothing = 0.22,
    FOV = 150,
    AimbotMaxDistance = 400,
    AutoShoot = true,
    ShootDelay = 0.18,
    
    -- Kill Aura
    KillAuraEnabled = false,
    KillAuraRange = 35,
    KillAuraDelay = 0.25,
    KillAuraMaxTargets = 3,
    
    -- Player Mods
    SpeedEnabled = false,
    SpeedValue = 32,
    JumpEnabled = false,
    JumpValue = 75,
    FlyEnabled = false,
    FlySpeed = 60,
    NoclipEnabled = false,
    InstantInteractEnabled = true,
    
    -- Auto Farm
    AutoFarm = false,
    FarmMoveToTargets = true,
    FarmCollectDrops = true,
    FarmWood = true,
    FarmStone = true,
    FarmIronOre = true,
    FarmBerries = true,
    FarmCoconut = true,
    FarmChickenFeather = false,
    FarmBearPelt = false,
    FarmSnakeTooth = false,
    FarmSpiderWeb = false,
    FarmRange = 1500,
    FarmDelay = 0.3,

    -- Survival
    AutoSurvival = false,
    SurvivalHuntChicken = true,
    SurvivalCollectMeat = true,
    SurvivalCollectBerries = true,
    SurvivalCookFood = true,
    SurvivalAutoEat = true,
    SurvivalEatThreshold = 60,
    SurvivalEatTarget = 90,
    SurvivalSearchDistance = 1500,
    
    NightMode = false
}

-- Preserve the user's choices across reinjection; explicit UNLOAD still turns features off.
for key, value in pairs(PersistedSettings) do
    if Settings[key] ~= nil and type(Settings[key]) == type(value) then Settings[key] = value end
end
-- Repair inconsistent values persisted by older versions before the buttons are created.
Settings.StealthMode = Settings.HumanizationEnabled and Settings.RandomMoveEnabled
Settings.MenuOpen = false
RuntimeEnv.__IslandEscapeSettings = Settings

-- ========== STORAGE ==========
local PlayerESP = {}
local MobESP = {}
local ResourceESP = {}
local HitboxCache = {}
local LastKillAura = 0
local LastShot = 0
local LastHumanMove = 0
local LastFarm = 0
local LastFarmMove = 0
local LastFarmAttack = 0
local LastSurvival = 0
local LastEat = 0
local AutoEatBusy = false
local CollectUntil = 0
local CurrentFarmTarget = nil
local CurrentFarmPhase = "idle"
local CurrentMoveGoal = nil
local CurrentWaypoints = nil
local CurrentWaypointIndex = 1
local LastPathCompute = 0
local LastProgressPosition = nil
local LastProgressTime = 0
local LastMoveCommandPosition = nil
local LastMoveCommandTime = 0
local StuckRecoveryAttempts = 0
local LastRecoveryTime = 0
local MenuGui = nil
local MainFrame = nil
local ContentFrame = nil
local NihilityLogoImage = nil
local NihilityLogoFallback = nil

-- Set of proximity prompts; populated once and maintained by descendant events.
local FarmableCache = {}
local FarmDropCache = {}
local FarmResourceCache = {}
local TaskTextObjects = {}
local ToggleViews = {}
local SliderConnections = {}
local HumanoidDefaults = setmetatable({}, {__mode = "k"})
local NoclipDefaults = setmetatable({}, {__mode = "k"})
local PromptHoldDefaults = setmetatable({}, {__mode = "k"})
local FurnacePromptCooldowns = setmetatable({}, {__mode = "k"})
local FlyBodyVelocity = nil
local FlyBodyGyro = nil
local FlyConnection = nil
local NoclipConnection = nil
local LightingDefaults = {
    Brightness = Lighting.Brightness,
    FogEnd = Lighting.FogEnd,
    GlobalShadows = Lighting.GlobalShadows,
    Ambient = Lighting.Ambient
}
local RuntimeAlive = true
local RuntimeConnections = {}
local CleanupRunning = false

local function TrackConnection(connection)
    table.insert(RuntimeConnections, connection)
    return connection
end

-- ========== FLY + NOCLIP ==========
local function GetCharacterRoot()
    local character = LocalPlayer.Character
    if not character then return nil, nil end
    return character:FindFirstChild("HumanoidRootPart"), character:FindFirstChildOfClass("Humanoid")
end

local function StopFly()
    if FlyConnection then
        pcall(function() FlyConnection:Disconnect() end)
        FlyConnection = nil
    end
    if FlyBodyVelocity then pcall(function() FlyBodyVelocity:Destroy() end); FlyBodyVelocity = nil end
    if FlyBodyGyro then pcall(function() FlyBodyGyro:Destroy() end); FlyBodyGyro = nil end
end

local function StartFly()
    local root, humanoid = GetCharacterRoot()
    if FlyConnection and not FlyConnection.Connected then FlyConnection = nil end
    if not root or not humanoid or FlyConnection then return end

    FlyBodyVelocity = Instance.new("BodyVelocity")
    FlyBodyVelocity.Name = "_IslandFlyVelocity"
    FlyBodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    FlyBodyVelocity.Velocity = Vector3.zero
    FlyBodyVelocity.P = 1e5
    FlyBodyVelocity.Parent = root

    FlyBodyGyro = Instance.new("BodyGyro")
    FlyBodyGyro.Name = "_IslandFlyGyro"
    FlyBodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    FlyBodyGyro.P = 1e4
    FlyBodyGyro.D = 500
    FlyBodyGyro.CFrame = root.CFrame
    FlyBodyGyro.Parent = root

    FlyConnection = TrackConnection(RunService.RenderStepped:Connect(function()
        if not RuntimeAlive or not Settings.FlyEnabled then return end
        local currentRoot, currentHumanoid = GetCharacterRoot()
        if not currentRoot or not currentHumanoid then return end

        if not FlyBodyVelocity or FlyBodyVelocity.Parent ~= currentRoot then
            if FlyBodyVelocity then pcall(function() FlyBodyVelocity:Destroy() end) end
            FlyBodyVelocity = Instance.new("BodyVelocity")
            FlyBodyVelocity.Name = "_IslandFlyVelocity"
            FlyBodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
            FlyBodyVelocity.P = 1e5
            FlyBodyVelocity.Parent = currentRoot
        end
        if not FlyBodyGyro or FlyBodyGyro.Parent ~= currentRoot then
            if FlyBodyGyro then pcall(function() FlyBodyGyro:Destroy() end) end
            FlyBodyGyro = Instance.new("BodyGyro")
            FlyBodyGyro.Name = "_IslandFlyGyro"
            FlyBodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
            FlyBodyGyro.P = 1e4
            FlyBodyGyro.D = 500
            FlyBodyGyro.Parent = currentRoot
        end

        local camera = Workspace.CurrentCamera or Camera
        if not camera then return end
        local moveDirection = Vector3.zero
        local cameraFrame = camera.CFrame
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDirection = moveDirection + cameraFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDirection = moveDirection - cameraFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDirection = moveDirection - cameraFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDirection = moveDirection + cameraFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDirection = moveDirection + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDirection = moveDirection - Vector3.new(0, 1, 0) end
        if moveDirection.Magnitude > 0 then moveDirection = moveDirection.Unit * Settings.FlySpeed end

        FlyBodyVelocity.Velocity = moveDirection
        FlyBodyGyro.CFrame = CFrame.new(currentRoot.Position, currentRoot.Position + cameraFrame.LookVector)
    end))
end

local function ApplyNoclip()
    local character = LocalPlayer.Character
    if not character then return end
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            if not NoclipDefaults[part] then
                NoclipDefaults[part] = {
                    CanCollide = part.CanCollide,
                    CanQuery = part.CanQuery,
                    CanTouch = part.CanTouch
                }
            end
            pcall(function()
                part.CanCollide = false
                part.CanQuery = false
                part.CanTouch = false
            end)
        end
    end
end

local function StopNoclip()
    if NoclipConnection then
        pcall(function() NoclipConnection:Disconnect() end)
        NoclipConnection = nil
    end
    for part, defaults in pairs(NoclipDefaults) do
        if part and part.Parent then
            part.CanCollide = defaults.CanCollide
            part.CanQuery = defaults.CanQuery
            part.CanTouch = defaults.CanTouch
        end
        NoclipDefaults[part] = nil
    end
end

local function StartNoclip()
    if NoclipConnection and not NoclipConnection.Connected then NoclipConnection = nil end
    if NoclipConnection then return end
    ApplyNoclip()
    NoclipConnection = TrackConnection(RunService.Stepped:Connect(function()
        if RuntimeAlive and Settings.NoclipEnabled then ApplyNoclip() end
    end))
end

local CleanupRuntime
CleanupRuntime = function()
    if CleanupRunning then return end
    CleanupRunning = true
    RuntimeAlive = false

    for _, setting in ipairs({
        "ESPEnabled", "MobESPEnabled", "ResourceESPEnabled", "AimbotEnabled", "AutoShoot", "KillAuraEnabled",
        "HitboxEnabled", "SpeedEnabled", "JumpEnabled", "FlyEnabled", "NoclipEnabled",
        "AutoFarm", "AutoSurvival", "NightMode"
    }) do
        Settings[setting] = false
    end

    StopFly()
    StopNoclip()

    CurrentFarmTarget = nil
    CurrentFarmPhase = "unloaded"
    CollectUntil = 0
    CurrentMoveGoal = nil
    CurrentWaypoints = nil
    LastProgressPosition = nil
    LastMoveCommandPosition = nil
    StuckRecoveryAttempts = 0

    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        pcall(function() humanoid:Move(Vector3.zero, false) end)
        if root then pcall(function() humanoid:MoveTo(root.Position) end) end
    end

    for _, connection in ipairs(RuntimeConnections) do
        pcall(function() connection:Disconnect() end)
    end
    RuntimeConnections = {}

    for _, data in pairs(PlayerESP) do
        pcall(function() data.Box:Destroy() end)
        pcall(function() data.NameTag:Destroy() end)
    end
    for _, data in pairs(MobESP) do
        pcall(function() data.Highlight:Destroy() end)
        pcall(function() data.Billboard:Destroy() end)
    end
    for resource, data in pairs(ResourceESP) do
        pcall(function() data.Highlight:Destroy() end)
        pcall(function() data.Billboard:Destroy() end)
        ResourceESP[resource] = nil
    end
    for prompt, holdDuration in pairs(PromptHoldDefaults) do
        if prompt and prompt.Parent then pcall(function() prompt.HoldDuration = holdDuration end) end
        PromptHoldDefaults[prompt] = nil
    end
    for mob, data in pairs(HitboxCache) do
        for part, originalSize in pairs(data.OriginalSizes or {}) do
            if part and part.Parent then part.Size = originalSize end
        end
        HitboxCache[mob] = nil
    end
    for humanoid, defaults in pairs(HumanoidDefaults) do
        if humanoid and humanoid.Parent then
            humanoid.WalkSpeed = defaults.WalkSpeed
            humanoid.JumpPower = defaults.JumpPower
            humanoid.UseJumpPower = defaults.UseJumpPower
        end
    end

    if MenuGui then pcall(function() MenuGui:Destroy() end) end
    MenuGui = nil
    MainFrame = nil
    ContentFrame = nil
    NihilityLogoImage = nil
    NihilityLogoFallback = nil
    Lighting.Brightness = LightingDefaults.Brightness
    Lighting.FogEnd = LightingDefaults.FogEnd
    Lighting.GlobalShadows = LightingDefaults.GlobalShadows
    Lighting.Ambient = LightingDefaults.Ambient
    if RuntimeEnv.__IslandEscapeCleanup == CleanupRuntime then
        RuntimeEnv.__IslandEscapeCleanup = nil
    end
    print("Island Escape unloaded")
end
RuntimeEnv.__IslandEscapeCleanup = CleanupRuntime

-- ========== UTILS ==========
local function RandomDelay(base)
    return base + (math.random() - 0.5) * 0.3
end

local function ShouldMiss()
    return math.random(1, 100) <= Settings.MissChance
end

local function HumanizeMouse()
    if not Settings.RandomMoveEnabled then return end
    if tick() - LastHumanMove < math.random(4, 10) then return end
    LastHumanMove = tick()
    if mousemoverel and math.random(1, 5) == 1 then
        mousemoverel(math.random(-2, 2), math.random(-2, 2))
    end
end

local function GetPosition(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst.Position
    elseif inst:IsA("Model") then
        local primary = inst.PrimaryPart or inst:FindFirstChild("HumanoidRootPart") or inst:FindFirstChild("Head") or inst:FindFirstChildWhichIsA("BasePart")
        return primary and primary.Position or nil
    elseif inst:IsA("Attachment") then return inst.WorldPosition end
    return nil
end

local function FormatHealth(hum, mode)
    if mode == "fraction" then
        return math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth)
    else
        return math.floor((hum.Health / hum.MaxHealth) * 100) .. "%"
    end
end

-- ========== PLAYER ESP ==========
local function CreatePlayerESP(player)
    if player == LocalPlayer then return end
    if PlayerESP[player] then return end
    PlayerESP[player] = {}
    
    local function Setup(char)
        if not char then return end
        if PlayerESP[player].Box then PlayerESP[player].Box:Destroy() end
        if PlayerESP[player].NameTag then PlayerESP[player].NameTag:Destroy() end
        
        local hum = char:WaitForChild("Humanoid", 3)
        local head = char:FindFirstChild("Head")
        if not hum or not head then return end
        
        local highlight = Instance.new("Highlight")
        highlight.Name = "HL" .. math.random(1000, 9999)
        highlight.Adornee = char
        highlight.FillColor = Color3.fromRGB(255, 50, 50)
        highlight.FillTransparency = 0.7
        highlight.OutlineColor = Color3.fromRGB(255, 50, 50)
        highlight.OutlineTransparency = 0
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Enabled = false
        highlight.Parent = CoreGui
        
        local bb = Instance.new("BillboardGui")
        bb.Name = "BB" .. math.random(1000, 9999)
        bb.Adornee = head
        bb.Size = UDim2.new(0, 200, 0, 70)
        bb.StudsOffset = Vector3.new(0, 3, 0)
        bb.AlwaysOnTop = true
        bb.MaxDistance = 1500
        bb.Enabled = false
        bb.Parent = CoreGui
        
        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(1, 0, 0, 20)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text = player.Name
        nameLbl.TextColor3 = Color3.fromRGB(255, 100, 100)
        nameLbl.TextStrokeTransparency = 0
        nameLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
        nameLbl.TextSize = 14
        nameLbl.Font = Enum.Font.GothamBold
        nameLbl.Visible = false
        nameLbl.Parent = bb
        
        local distLbl = Instance.new("TextLabel")
        distLbl.Size = UDim2.new(1, 0, 0, 16)
        distLbl.Position = UDim2.new(0, 0, 0, 20)
        distLbl.BackgroundTransparency = 1
        distLbl.Text = "0"
        distLbl.TextColor3 = Color3.new(1, 1, 1)
        distLbl.TextStrokeTransparency = 0
        distLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
        distLbl.TextSize = 12
        distLbl.Font = Enum.Font.Gotham
        distLbl.Visible = false
        distLbl.Parent = bb
        
        local healthBg = Instance.new("Frame")
        healthBg.Size = UDim2.new(0.8, 0, 0, 6)
        healthBg.Position = UDim2.new(0.1, 0, 0, 38)
        healthBg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        healthBg.BorderSizePixel = 0
        healthBg.Visible = false
        healthBg.Parent = bb
        
        local healthBar = Instance.new("Frame")
        healthBar.Size = UDim2.new(1, 0, 1, 0)
        healthBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
        healthBar.BorderSizePixel = 0
        healthBar.Parent = healthBg
        
        local healthTxt = Instance.new("TextLabel")
        healthTxt.Size = UDim2.new(1, 0, 0, 16)
        healthTxt.Position = UDim2.new(0, 0, 0, 46)
        healthTxt.BackgroundTransparency = 1
        healthTxt.Text = "100/100"
        healthTxt.TextColor3 = Color3.new(1, 1, 1)
        healthTxt.TextStrokeTransparency = 0
        healthTxt.TextStrokeColor3 = Color3.new(0, 0, 0)
        healthTxt.TextSize = 11
        healthTxt.Font = Enum.Font.Gotham
        healthTxt.Visible = false
        healthTxt.Parent = bb
        
        PlayerESP[player] = {
            Box = highlight, NameTag = bb, HealthBg = healthBg, HealthBar = healthBar,
            HealthText = healthTxt, NameLabel = nameLbl, DistLabel = distLbl,
            Humanoid = hum, Head = head, Character = char
        }
    end
    
    if player.Character then Setup(player.Character) end
    TrackConnection(player.CharacterAdded:Connect(function(c)
        task.wait(0.5); Setup(c)
    end))
end

-- Clean, single update function for ALL player ESP
local function UpdatePlayerESP()
    for player, data in pairs(PlayerESP) do
        if not data.Character or not data.Character.Parent or not data.Head.Parent then
            continue
        end
        
        local lc = LocalPlayer.Character
        local lh = lc and lc:FindFirstChild("Head")
        if not lh then continue end
        
        local hum = data.Humanoid
        local dist = (data.Head.Position - lh.Position).Magnitude
        local inRange = dist <= Settings.ESPMaxDistance and hum and hum.Health > 0
        
        -- Master enabled check
        local show = Settings.ESPEnabled and inRange
        data.Box.Enabled = show and Settings.ESPBox
        data.NameTag.Enabled = show
        data.NameLabel.Visible = show and Settings.ESPName
        data.DistLabel.Visible = show and Settings.ESPDistance
        data.HealthBg.Visible = show and Settings.ESPHealthBar
        data.HealthText.Visible = show and Settings.ESPHealthText
        
        if show then
            if Settings.ESPHealthBar and hum then
                local pct = hum.Health / hum.MaxHealth
                data.HealthBar.Size = UDim2.new(pct, 0, 1, 0)
                data.HealthBar.BackgroundColor3 = Color3.fromRGB(255 * (1 - pct), 255 * pct, 0)
            end
            if Settings.ESPHealthText and hum then
                data.HealthText.Text = FormatHealth(hum, Settings.ESPHealthMode)
            end
            data.DistLabel.Text = math.floor(dist) .. " studs"
        end
    end
end

-- ========== MOB ESP ==========
local function IsMob(model)
    if not model or not model:IsA("Model") then return false end
    if Players:GetPlayerFromCharacter(model) then return false end
    local hum = model:FindFirstChildOfClass("Humanoid")
    local root = model:FindFirstChild("HumanoidRootPart")
    return hum and root
end

local function CreateMobESP(mob)
    if MobESP[mob] then return end
    if not IsMob(mob) then return end
    
    local hum = mob:FindFirstChildOfClass("Humanoid")
    local head = mob:FindFirstChild("Head") or mob:FindFirstChild("HumanoidRootPart") or mob.PrimaryPart
    if not hum or not head then return end
    
    local displayName = TranslateName(mob.Name, "MOB / NPC")
    
    local highlight = Instance.new("Highlight")
    highlight.Name = "H" .. math.random(1000, 9999)
    highlight.Adornee = mob
    highlight.FillColor = Color3.fromRGB(255, 100, 100)
    highlight.FillTransparency = 0.75
    highlight.OutlineColor = Color3.fromRGB(255, 100, 100)
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Enabled = false
    highlight.Parent = CoreGui
    
    local bb = Instance.new("BillboardGui")
    bb.Name = "B" .. math.random(1000, 9999)
    bb.Adornee = head
    bb.Size = UDim2.new(0, 200, 0, 70)
    bb.StudsOffset = Vector3.new(0, 2, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 800
    bb.Enabled = false
    bb.Parent = CoreGui
    
    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, 0, 0, 20)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = displayName
    nameLbl.TextColor3 = Color3.fromRGB(255, 100, 100)
    nameLbl.TextStrokeTransparency = 0
    nameLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
    nameLbl.TextSize = 13
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.Visible = false
    nameLbl.Parent = bb
    
    local hpLbl = Instance.new("TextLabel")
    hpLbl.Size = UDim2.new(1, 0, 0, 16)
    hpLbl.Position = UDim2.new(0, 0, 0, 20)
    hpLbl.BackgroundTransparency = 1
    hpLbl.Text = "HP"
    hpLbl.TextColor3 = Color3.new(1, 1, 1)
    hpLbl.TextStrokeTransparency = 0
    hpLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
    hpLbl.TextSize = 11
    hpLbl.Font = Enum.Font.Gotham
    hpLbl.Visible = false
    hpLbl.Parent = bb
    
    local healthBg = Instance.new("Frame")
    healthBg.Size = UDim2.new(0.8, 0, 0, 6)
    healthBg.Position = UDim2.new(0.1, 0, 0, 38)
    healthBg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    healthBg.BorderSizePixel = 0
    healthBg.Visible = false
    healthBg.Parent = bb
    
    local healthBar = Instance.new("Frame")
    healthBar.Size = UDim2.new(1, 0, 1, 0)
    healthBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    healthBar.BorderSizePixel = 0
    healthBar.Parent = healthBg
    
    MobESP[mob] = {
        Highlight = highlight, Billboard = bb, NameLabel = nameLbl,
        HPLabel = hpLbl, HealthBg = healthBg, HealthBar = healthBar,
        Humanoid = hum, Head = head
    }
    
    TrackConnection(mob.AncestryChanged:Connect(function()
        if not mob.Parent then
            pcall(function() highlight:Destroy() end)
            pcall(function() bb:Destroy() end)
            MobESP[mob] = nil
        end
    end))
end

-- Clean, single update function for ALL mob ESP
local function UpdateMobESP()
    for mob, data in pairs(MobESP) do
        if not mob.Parent or not data.Humanoid or data.Humanoid.Health <= 0 then
            pcall(function() data.Highlight:Destroy() end)
            pcall(function() data.Billboard:Destroy() end)
            MobESP[mob] = nil
            continue
        end
        
        local mobPos = GetPosition(data.Head)
        if not mobPos then continue end
        
        local lc = LocalPlayer.Character
        local lh = lc and lc:FindFirstChild("Head")
        if not lh then continue end
        
        local dist = (mobPos - lh.Position).Magnitude
        local inRange = dist <= Settings.MobESPMaxDistance
        local show = Settings.MobESPEnabled and inRange
        
        data.Highlight.Enabled = show and Settings.MobESPBox
        data.Billboard.Enabled = show
        data.NameLabel.Visible = show and Settings.MobESPName
        data.HPLabel.Visible = show and Settings.MobESPHealthText
        data.HealthBg.Visible = show and Settings.MobESPHealthBar
        
        if show then
            if Settings.MobESPHealthBar then
                local pct = data.Humanoid.Health / data.Humanoid.MaxHealth
                data.HealthBar.Size = UDim2.new(pct, 0, 1, 0)
                data.HealthBar.BackgroundColor3 = Color3.fromRGB(255 * (1 - pct), 255 * pct, 0)
            end
            if Settings.MobESPHealthText then
                data.HPLabel.Text = FormatHealth(data.Humanoid, Settings.MobESPHealthMode)
                local pct = data.Humanoid.Health / data.Humanoid.MaxHealth
                data.NameLabel.TextColor3 = Color3.fromRGB(255, math.clamp(255 * pct, 50, 255), 50)
            end
        end
    end
end

local function ScanMobs()
    if not Entities then return end
    for index, obj in ipairs(Entities:GetChildren()) do
        if IsMob(obj) then CreateMobESP(obj) end
        if index % 20 == 0 then task.wait() end
    end
end

-- ========== KILL AURA ==========
local function KillAura(force)
    if not force and not Settings.KillAuraEnabled then return end
    if tick() - LastKillAura < Settings.KillAuraDelay then return end
    LastKillAura = tick()
    
    local attackRemote = Events:FindFirstChild("attackMobRemote")
    if not attackRemote then return end
    
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    local targets = {}
    for mob, data in pairs(MobESP) do
        if not mob.Parent or not data.Humanoid or data.Humanoid.Health <= 0 then continue end
        local mobPos = GetPosition(data.Head)
        if not mobPos then continue end
        local dist = (mobPos - root.Position).Magnitude
        if dist <= Settings.KillAuraRange then
            table.insert(targets, {mob = mob, data = data, dist = dist})
        end
    end
    
    table.sort(targets, function(a, b) return a.dist < b.dist end)
    
    for i = 1, math.min(#targets, Settings.KillAuraMaxTargets) do
        local t = targets[i]
        pcall(function() attackRemote:FireServer(t.mob, t.data.Humanoid) end)
    end
end

-- ========== AIMBOT ==========
local function GetBestTarget()
    local best, bestDist = nil, Settings.FOV
    local mousePos = UserInputService:GetMouseLocation()
    local lc = LocalPlayer.Character
    local lh = lc and lc:FindFirstChild("Head")
    if not lh then return nil end
    
    for mob, data in pairs(MobESP) do
        if not mob.Parent or not data.Humanoid or data.Humanoid.Health <= 0 then continue end
        local part = mob:FindFirstChild(Settings.AimPart) or data.Head
        if not part then continue end
        local partPos = GetPosition(part)
        if not partPos then continue end
        local dist = (partPos - lh.Position).Magnitude
        if dist > Settings.AimbotMaxDistance then continue end
        local sp = Camera:WorldToViewportPoint(partPos)
        if sp.Z <= 0 then continue end
        local screenPos = Vector2.new(sp.X, sp.Y)
        local screenDist = (mousePos - screenPos).Magnitude
        if screenDist < bestDist then
            bestDist = screenDist
            best = {Mob = mob, Part = part, ScreenPos = screenPos, Humanoid = data.Humanoid}
        end
    end
    return best
end

local function AimAtTarget(t)
    if not t then return end
    if Settings.HumanizationEnabled and ShouldMiss() then return end
    local mousePos = UserInputService:GetMouseLocation()
    local delta = t.ScreenPos - mousePos
    delta = delta * Settings.Smoothing
    if mousemoverel then
        mousemoverel(delta.X, delta.Y)
    end
    if Settings.AutoShoot and t.Humanoid.Health > 0 then
        local now = tick()
        if now - LastShot > RandomDelay(Settings.ShootDelay) then
            mouse1click()
            LastShot = now
        end
    end
end

-- ========== HITBOX ==========
local function CreateHitbox(mob)
    if HitboxCache[mob] or not IsMob(mob) then return end
    local parts = {"HumanoidRootPart", "Head"}
    HitboxCache[mob] = {OriginalSizes = {}, Parts = {}}
    for _, name in ipairs(parts) do
        local p = mob:FindFirstChild(name)
        if p and p:IsA("BasePart") then
            HitboxCache[mob].OriginalSizes[p] = p.Size
            p.Size = Vector3.new(Settings.HitboxSize, Settings.HitboxSize, Settings.HitboxSize)
            table.insert(HitboxCache[mob].Parts, p)
        end
    end
end

local function RemoveHitbox(mob)
    if not HitboxCache[mob] then return end
    for p, size in pairs(HitboxCache[mob].OriginalSizes) do
        if p and p.Parent then p.Size = size end
    end
    HitboxCache[mob] = nil
end

local function UpdateHitboxes()
    for mob, data in pairs(HitboxCache) do
        if not mob.Parent then RemoveHitbox(mob); continue end
        for _, p in ipairs(data.Parts) do
            if p and p.Parent and p.Size ~= Vector3.new(Settings.HitboxSize, Settings.HitboxSize, Settings.HitboxSize) then
                p.Size = Vector3.new(Settings.HitboxSize, Settings.HitboxSize, Settings.HitboxSize)
            end
        end
    end
end

-- ========== PLAYER MODS ==========
local function ApplyMods()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if not HumanoidDefaults[hum] then
        HumanoidDefaults[hum] = {
            WalkSpeed = hum.WalkSpeed,
            JumpPower = hum.JumpPower,
            UseJumpPower = hum.UseJumpPower
        }
    end
    local defaults = HumanoidDefaults[hum]
    if Settings.SpeedEnabled then hum.WalkSpeed = Settings.SpeedValue
    else hum.WalkSpeed = defaults.WalkSpeed end
    if Settings.JumpEnabled then hum.JumpPower = Settings.JumpValue; hum.UseJumpPower = true
    else
        hum.JumpPower = defaults.JumpPower
        hum.UseJumpPower = defaults.UseJumpPower
    end
end

-- ========== AUTO FARM (OPTIMIZED - CACHED) ==========
local FarmItems = {
    {key = "FarmWood", names = {"wood", "tree", "log", "branch", "oak", "palm", "木材", "木头", "树"}},
    {key = "FarmStone", names = {"stone", "rock", "boulder", "pebble", "石头", "岩石"}},
    {key = "FarmIronOre", names = {"iron", "ore", "crystal", "ironstone", "铁矿石", "铁矿"}},
    {key = "FarmBerries", names = {"berr", "fruit", "bush", "浆果"}},
    {key = "FarmCoconut", names = {"coconut", "椰子"}},
    {key = "FarmChickenFeather", names = {"chicken", "feather", "鸡", "羽毛"}},
    {key = "FarmBearPelt", names = {"bear", "pelt", "熊", "熊皮"}},
    {key = "FarmSnakeTooth", names = {"snake", "tooth", "蛇", "蛇牙"}},
    {key = "FarmSpiderWeb", names = {"spider", "web", "silk", "蜘蛛", "蜘蛛网"}}
}

-- Crafted objects also contain words such as "wood". They are not harvest nodes.
local FarmResourceExclusions = {
    "wall", "floor", "foundation", "barricade", "spike", "slope", "roof", "door", "window",
    "workbench", "crafting", "furniture", "building", "structure", "torch",
    "木墙", "木地板", "木半墙", "木斜板", "木刺路障", "制作台", "火炬"
}

local PreferredResourceParts = {
    "trunk", "stem", "stump", "log", "wood", "tree", "root", "rock", "stone", "ore", "iron",
    "crystal", "bush", "berry", "coconut", "树干", "木材", "木头", "石头", "岩石", "铁矿"
}

local LowPriorityResourceParts = {"leaf", "leaves", "foliage", "crown", "canopy", "树叶"}

local function ShouldFarmItem(itemName)
    if not itemName then return false end
    local lower = itemName:lower()
    for _, farm in ipairs(FarmItems) do
        if Settings[farm.key] then
            for _, n in ipairs(farm.names) do
                if lower:find(n) then return true end
            end
        end
    end
    return false
end

local function IsFarmableObject(obj)
    if not obj then return false end
    if ShouldFarmItem(obj.Name) then return true end
    local p1 = obj.Parent
    if p1 and ShouldFarmItem(p1.Name) then return true end
    if p1 then
        local p2 = p1.Parent
        if p2 and ShouldFarmItem(p2.Name) then return true end
    end
    if obj:IsA("Model") then
        for _, child in pairs(obj:GetChildren()) do
            if ShouldFarmItem(child.Name) then return true end
        end
    end
    return false
end

local function GetPromptPosition(prompt)
    if not prompt or not prompt.Parent then return nil end
    local holder = prompt.Parent
    if holder:IsA("Attachment") then return holder.WorldPosition end
    if holder:IsA("BasePart") then return holder.Position end
    return GetPosition(holder)
end

local function ContainsAny(text, words)
    text = string.lower(tostring(text or ""))
    for _, word in ipairs(words) do
        if text:find(word, 1, true) then return true end
    end
    return false
end

local function GetPromptDescriptor(prompt)
    local parts = {prompt.Name, prompt.ActionText, prompt.ObjectText}
    local parent = prompt.Parent
    for _ = 1, 4 do
        if not parent then break end
        table.insert(parts, parent.Name)
        parent = parent.Parent
    end
    return string.lower(table.concat(parts, " "))
end

local function IsChestPrompt(prompt)
    return ContainsAny(GetPromptDescriptor(prompt), {
        "chest", "treasure", "loot crate", "supply crate", "supply box", "open crate", "宝箱"
    })
end

local function IsFurnacePrompt(prompt)
    return ContainsAny(GetPromptDescriptor(prompt), {
        "furnace", "smelt", "smelter", "forge", "refine", "iron output", "collect iron",
        "blast furnace", "熔炉", "冶炼", "铁"
    })
end

local function ShouldMakePromptInstant(prompt)
    if Settings.InstantInteractEnabled then return true end
    if Settings.InstantChestOpen and IsChestPrompt(prompt) then return true end
    if Settings.InstantFurnace and IsFurnacePrompt(prompt) then return true end
    return false
end

local function ApplyInstantPrompt(prompt)
    if not prompt or not prompt.Parent or not prompt:IsA("ProximityPrompt") then return end
    if ShouldMakePromptInstant(prompt) then
        if PromptHoldDefaults[prompt] == nil then PromptHoldDefaults[prompt] = prompt.HoldDuration end
        pcall(function() prompt.HoldDuration = 0 end)
    elseif PromptHoldDefaults[prompt] ~= nil then
        local original = PromptHoldDefaults[prompt]
        pcall(function() prompt.HoldDuration = original end)
        PromptHoldDefaults[prompt] = nil
    end
end

local function RefreshInstantPrompts()
    for prompt in pairs(FarmableCache) do
        if prompt.Parent then ApplyInstantPrompt(prompt) else FarmableCache[prompt] = nil end
    end
    for prompt, original in pairs(PromptHoldDefaults) do
        if not prompt.Parent then
            PromptHoldDefaults[prompt] = nil
        elseif not ShouldMakePromptInstant(prompt) then
            pcall(function() prompt.HoldDuration = original end)
            PromptHoldDefaults[prompt] = nil
        end
    end
end

local function TriggerPromptInstantly(prompt)
    if not prompt or not prompt.Parent or not prompt.Enabled then return false end
    ApplyInstantPrompt(prompt)
    if fireproximityprompt then return pcall(function() fireproximityprompt(prompt, 0) end) end
    return pcall(function()
        prompt:InputHoldBegin()
        task.wait()
        prompt:InputHoldEnd()
    end)
end

local function HasIronOreInInventory()
    local character = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:FindFirstChild("Backpack")
    for _, container in ipairs({character, backpack}) do
        if container then
            for _, object in ipairs(container:GetChildren()) do
                if object:IsA("Tool") and ContainsAny(object.Name, {"iron ore", "ironore", "铁矿石", "铁矿"}) then
                    return true
                end
            end
        end
    end
    return false
end

local function TryInstantFurnace()
    if not Settings.InstantFurnace then return false end
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    local hasOre = HasIronOreInInventory()
    local triggered = false

    for prompt in pairs(FarmableCache) do
        if prompt.Parent and prompt.Enabled and IsFurnacePrompt(prompt) then
            local position = GetPromptPosition(prompt)
            local distance = position and (position - root.Position).Magnitude or math.huge
            local description = GetPromptDescriptor(prompt)
            local isOutput = ContainsAny(description, {"collect", "take", "output", "claim", "get iron"})
            local cooldown = FurnacePromptCooldowns[prompt] or 0
            if distance <= prompt.MaxActivationDistance + 2 and (hasOre or isOutput) and tick() - cooldown >= 0.45 then
                FurnacePromptCooldowns[prompt] = tick()
                if TriggerPromptInstantly(prompt) then triggered = true end
            end
        end
    end
    return triggered
end

local CollectWords = {"collect", "pick up", "pickup", "take", "grab", "loot", "claim", "reward"}
local FoodWords = {
    "meat", "cooked meat", "raw meat", "cooked tentacle", "tentacle", "octopus",
    "berry", "berries", "food", "drumstick", "chicken", "egg", "coconut", "steak",
    "fish", "mushroom", "apple", "banana", "bread", "ration", "meal",
    "熟肉", "生肉", "熟章鱼触手", "章鱼触手", "鸡", "鸡蛋", "浆果", "椰子"
}
local CookWords = {"cook", "campfire", "fireplace", "grill", "roast", "stove", "cooking"}

local function IsFoodName(name)
    return ContainsAny(name, FoodWords)
end

local function IsCollectPrompt(prompt)
    return ContainsAny(GetPromptDescriptor(prompt), CollectWords)
end

local function IsKnownFarmName(name)
    local lower = string.lower(tostring(name or ""))
    for _, farm in ipairs(FarmItems) do
        for _, keyword in ipairs(farm.names) do
            if lower:find(keyword, 1, true) then return true end
        end
    end
    return false
end

local function GetObjectDescriptor(object)
    if not object then return "" end
    local parts = {object.Name}
    local parent = object.Parent
    for _ = 1, 4 do
        if not parent or parent == GameFolder then break end
        table.insert(parts, parent.Name)
        parent = parent.Parent
    end
    return string.lower(table.concat(parts, " "))
end

local function GetLocalResourceDescriptor(object)
    if not object then return "" end
    local parts = {object.Name}
    if object:IsA("BasePart") and object.Parent then
        table.insert(parts, object.Parent.Name)
    elseif object:IsA("Model") then
        for _, child in ipairs(object:GetChildren()) do
            if child:IsA("BasePart") or child:IsA("Model") then table.insert(parts, child.Name) end
        end
    end
    return string.lower(table.concat(parts, " "))
end

local function IsExcludedFarmResource(object)
    if not object then return true end
    local parts = {object.Name}
    local model = object:IsA("Model") and object or object:FindFirstAncestorOfClass("Model")
    if model and model ~= object then table.insert(parts, model.Name) end
    return ContainsAny(table.concat(parts, " "), FarmResourceExclusions)
end

local function GetBestResourcePart(object, fromPosition)
    if not object or not object.Parent then return nil end
    if object:IsA("BasePart") then return object end
    if object:IsA("Tool") then return object:FindFirstChild("Handle") end
    if not object:IsA("Model") then return nil end

    local bestPart, bestScore = nil, math.huge
    for _, candidate in ipairs(object:GetDescendants()) do
        if candidate:IsA("BasePart") and candidate.Transparency < 0.98 then
            local name = string.lower(candidate.Name)
            local score = fromPosition and (candidate.Position - fromPosition).Magnitude or 0
            if ContainsAny(name, PreferredResourceParts) then score = score - 10000 end
            if ContainsAny(name, LowPriorityResourceParts) then score = score + 20000 end
            if not candidate.CanCollide then score = score + 25 end
            if score < bestScore then bestPart, bestScore = candidate, score end
        end
    end
    return bestPart or object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart", true)
end

local function GetFarmApproachPosition(character, root, object, targetPart)
    local offset = root.Position - targetPart.Position
    local flatOffset = Vector3.new(offset.X, 0, offset.Z)
    if flatOffset.Magnitude < 0.1 then flatOffset = Vector3.new(0, 0, 1) end
    local radius = math.clamp(math.max(targetPart.Size.X, targetPart.Size.Z) * 0.5 + 3.5, 4.5, 12)
    local wanted = targetPart.Position + flatOffset.Unit * radius

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {character, object}
    params.IgnoreWater = false
    local origin = Vector3.new(wanted.X, math.max(wanted.Y, targetPart.Position.Y) + 25, wanted.Z)
    local result = Workspace:Raycast(origin, Vector3.new(0, -100, 0), params)
    if result then return result.Position + Vector3.new(0, 3, 0) end
    return Vector3.new(wanted.X, root.Position.Y, wanted.Z)
end

local function IsWorldResource(object)
    if not object or (not object:IsA("Model") and not object:IsA("BasePart")) then return false end
    if object:IsA("BasePart") and not object.Anchored then return false end
    if LocalPlayer.Character and object:IsDescendantOf(LocalPlayer.Character) then return false end
    if IsExcludedFarmResource(object) then return false end
    return IsKnownFarmName(GetLocalResourceDescriptor(object))
end

-- ========== RESOURCE / CHEST ESP ==========
local function GetResourceESPDescriptor(object)
    local parts = {GetObjectDescriptor(object), GetLocalResourceDescriptor(object)}
    if object and object:IsA("Model") then
        local prompt = object:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt then table.insert(parts, GetPromptDescriptor(prompt)) end
        local queue = object:GetChildren()
        local index = 1
        while index <= #queue and index <= 80 do
            local descendant = queue[index]
            index = index + 1
            table.insert(parts, descendant.Name)
            for attributeName, value in pairs(descendant:GetAttributes()) do
                if ContainsAny(attributeName, {"iron", "ore", "stone", "drop", "reward", "resource"}) then
                    table.insert(parts, attributeName .. " " .. tostring(value))
                elseif type(value) == "string" and ContainsAny(value, {"iron", "ore", "stone"}) then
                    table.insert(parts, value)
                end
            end
            for _, child in ipairs(descendant:GetChildren()) do
                if #queue >= 80 then break end
                queue[#queue + 1] = child
            end
        end
    end
    return string.lower(table.concat(parts, " "))
end

local function LooksLikeIronBearingStone(object)
    if not object or not object:IsA("Model") then return false end
    for _, part in ipairs(object:GetDescendants()) do
        if part:IsA("BasePart") and part.Transparency < 0.95 then
            if part.Material == Enum.Material.Metal then return true end
            local color = part.Color
            local reddishOre = color.R > 0.30 and color.R > color.G * 1.25 and color.R > color.B * 1.25
            local bluishOre = color.B > 0.30 and color.B > color.R * 1.25 and color.B > color.G * 1.10
            if reddishOre or bluishOre then return true end
        end
    end
    return false
end

local function ClassifyResourceESP(object)
    if not object or not object.Parent then return nil end
    local model = object:IsA("Model") and object or object:FindFirstAncestorOfClass("Model")
    if model and (model:FindFirstChildOfClass("Humanoid") or Players:GetPlayerFromCharacter(model)) then return nil end
    if object:FindFirstAncestorOfClass("Player") or object:IsDescendantOf(LocalPlayer) then return nil end
    if LocalPlayer.Character and object:IsDescendantOf(LocalPlayer.Character) then return nil end

    local description = GetResourceESPDescriptor(object)
    if ContainsAny(description, {"chest", "treasure", "loot crate", "supply crate", "supply box", "宝箱"}) then
        return "Chest", "CHEST", Color3.fromRGB(255, 205, 55)
    end
    if IsExcludedFarmResource(object) then return nil end
    local hasStone = ContainsAny(description, {"stone", "rock", "boulder", "石头", "岩石"})
    local hasIron = ContainsAny(description, {
        "iron ore", "ironore", "iron deposit", "ore deposit", "iron vein", "metal vein", "铁矿石", "铁矿"
    })
    if not hasIron and hasStone then hasIron = LooksLikeIronBearingStone(model or object) end
    if hasIron then
        local label = hasStone and "STONE + IRON ORE" or "IRON ORE"
        return "Iron", label, Color3.fromRGB(175, 195, 220)
    end
    if hasStone then
        return "Stone", "STONE", Color3.fromRGB(165, 165, 175)
    end
    if ContainsAny(description, {"tree", "wood", "log", "branch", "stump", "oak", "palm", "木材", "木头", "树"}) then
        return "Wood", "TREE / WOOD", Color3.fromRGB(80, 220, 105)
    end
    if ContainsAny(description, {"berry", "berries", "浆果"}) then
        return "Other", "BERRIES", Color3.fromRGB(220, 80, 180)
    end
    if ContainsAny(description, {"coconut", "椰子"}) then
        return "Other", "COCONUT", Color3.fromRGB(210, 155, 85)
    end
    -- Fiber/grass is intentionally excluded from both ESP and Auto Farm.
    if ContainsAny(description, {"grass", "fiber", "plant", "草", "纤维"}) then return nil end
    if IsKnownFarmName(description) then
        return "Other", string.upper(TranslateName(object.Name, "RESOURCE")), Color3.fromRGB(80, 190, 255)
    end
    return nil
end

local function NormalizeResourceESPObject(object)
    if not object or not object.Parent then return nil end
    if not object:IsA("Model") and not object:IsA("BasePart") and not object:IsA("Tool") then return nil end

    local baseModel = object:IsA("Model") and object or object:FindFirstAncestorOfClass("Model")
    if baseModel and baseModel:FindFirstChildOfClass("Humanoid") then return nil end

    local best = nil
    local containerNames = {
        resources = true, resourcefolder = true, trees = true, forest = true,
        rocks = true, stones = true, ores = true, map = true, world = true
    }
    local current = baseModel
    while current and current:IsA("Model") do
        local ownName = string.lower(current.Name):gsub("[%s_%-]", "")
        local directlyNamed = ContainsAny(ownName, {
            "chest", "treasure", "crate", "ironore", "iron", "ore", "stone", "rock",
            "tree", "wood", "log", "stump", "berry", "coconut"
        })
        local hasPrompt = current:FindFirstChildWhichIsA("ProximityPrompt", true) ~= nil
        local childModelCount = 0
        for _, child in ipairs(current:GetChildren()) do
            if child:IsA("Model") then childModelCount = childModelCount + 1 end
        end
        local looksLikeSingleObject = childModelCount == 0
        if not containerNames[ownName] and (directlyNamed or hasPrompt or looksLikeSingleObject)
            and ClassifyResourceESP(current) then
            best = current
        end
        current = current.Parent
    end
    if best then return best end
    if not object:IsA("Model") and not baseModel and ClassifyResourceESP(object) then return object end
    return nil
end

local function CreateResourceESP(object)
    local existingModel = object:IsA("Model") and object or object:FindFirstAncestorOfClass("Model")
    local currentModel = existingModel
    while currentModel and currentModel:IsA("Model") do
        if ResourceESP[currentModel] then return end
        currentModel = currentModel.Parent
    end
    local resource = NormalizeResourceESPObject(object)
    if not resource then return end
    local category, displayName, color = ClassifyResourceESP(resource)
    if not category then return end

    if ResourceESP[resource] then
        ResourceESP[resource].Category = category
        ResourceESP[resource].DisplayName = displayName
        ResourceESP[resource].Color = color
        return
    end

    local adorneePart = GetBestResourcePart(resource)
    if not adorneePart then return end

    local highlight = Instance.new("Highlight")
    highlight.Name = "ResourceHL" .. math.random(1000, 9999)
    highlight.Adornee = resource:IsA("Tool") and adorneePart or resource
    highlight.FillColor = color
    highlight.FillTransparency = 0.72
    highlight.OutlineColor = color
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Enabled = false
    highlight.Parent = CoreGui

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ResourceBB" .. math.random(1000, 9999)
    billboard.Adornee = adorneePart
    billboard.Size = UDim2.new(0, 190, 0, 42)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = Settings.ResourceESPMaxDistance
    billboard.Enabled = false
    billboard.Parent = CoreGui

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0, 20)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = displayName
    nameLabel.TextColor3 = color
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    nameLabel.TextSize = 13
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.Parent = billboard

    local distanceLabel = Instance.new("TextLabel")
    distanceLabel.Size = UDim2.new(1, 0, 0, 16)
    distanceLabel.Position = UDim2.new(0, 0, 0, 20)
    distanceLabel.BackgroundTransparency = 1
    distanceLabel.Text = "0 studs"
    distanceLabel.TextColor3 = Color3.new(1, 1, 1)
    distanceLabel.TextStrokeTransparency = 0
    distanceLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    distanceLabel.TextSize = 11
    distanceLabel.Font = Enum.Font.Gotham
    distanceLabel.Parent = billboard

    ResourceESP[resource] = {
        Highlight = highlight,
        Billboard = billboard,
        NameLabel = nameLabel,
        DistanceLabel = distanceLabel,
        Part = adorneePart,
        Category = category,
        DisplayName = displayName,
        Color = color
    }
end

local function IsResourceESPCategoryEnabled(category)
    if category == "Chest" then return Settings.ResourceESPChests end
    if category == "Iron" then return Settings.ResourceESPIron end
    if category == "Stone" then return Settings.ResourceESPStone end
    if category == "Wood" then return Settings.ResourceESPWood end
    return Settings.ResourceESPOther
end

local function UpdateResourceESP()
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    for resource, data in pairs(ResourceESP) do
        if not resource.Parent or not data.Part or not data.Part.Parent then
            pcall(function() data.Highlight:Destroy() end)
            pcall(function() data.Billboard:Destroy() end)
            ResourceESP[resource] = nil
            continue
        end

        local distance = root and (data.Part.Position - root.Position).Magnitude or math.huge
        local show = Settings.ResourceESPEnabled
            and IsResourceESPCategoryEnabled(data.Category)
            and distance <= Settings.ResourceESPMaxDistance

        data.Highlight.Enabled = show and Settings.ResourceESPHighlight
        data.Billboard.Enabled = show
        data.NameLabel.Visible = show and Settings.ResourceESPName
        data.DistanceLabel.Visible = show and Settings.ResourceESPDistance
        data.Billboard.MaxDistance = Settings.ResourceESPMaxDistance
        if show then
            data.NameLabel.Text = data.DisplayName
            data.NameLabel.TextColor3 = data.Color
            data.DistanceLabel.Text = math.floor(distance) .. " studs"
        end
    end
end

local function SelectedFarmResourceMatch(description, object)
    if ShouldFarmItem(description) then return true end
    if not Settings.FarmIronOre or not ContainsAny(description, {"stone", "rock", "boulder", "石头", "岩石"}) then
        return false
    end
    local model = object and (object:IsA("Model") and object or object:FindFirstAncestorOfClass("Model"))
    return LooksLikeIronBearingStone(model)
end

local function TrackFarmObject(obj)
    if not obj then return end
    local shouldCreateResourceESP = false
    if obj:IsA("ProximityPrompt") then
        FarmableCache[obj] = true
        ApplyInstantPrompt(obj)
        local promptModel = obj:FindFirstAncestorOfClass("Model")
        if promptModel then CreateResourceESP(promptModel) end
    elseif obj:IsA("Model") and IsFoodName(GetLocalResourceDescriptor(obj))
        and not obj:FindFirstChildOfClass("Humanoid") then
        FarmDropCache[obj] = true
        shouldCreateResourceESP = true
    elseif obj:IsA("Tool") and (IsKnownFarmName(obj.Name) or IsFoodName(obj.Name)) then
        FarmDropCache[obj] = true
        shouldCreateResourceESP = true
    elseif obj:IsA("BasePart") and not obj.Anchored and (IsKnownFarmName(obj.Name) or IsFoodName(GetObjectDescriptor(obj))) then
        local model = obj:FindFirstAncestorOfClass("Model")
        if not (model and model:FindFirstChildOfClass("Humanoid")) then FarmDropCache[obj] = true end
        shouldCreateResourceESP = true
    end
    if IsWorldResource(obj) then
        local resource = obj
        if obj:IsA("BasePart") then
            local model = obj:FindFirstAncestorOfClass("Model")
            if model and IsWorldResource(model) then resource = model end
        end
        FarmResourceCache[resource] = true
        shouldCreateResourceESP = true
    elseif obj:IsA("Model") then
        local description = GetLocalResourceDescriptor(obj)
        shouldCreateResourceESP = IsKnownFarmName(description)
            or ContainsAny(description, {"chest", "treasure", "crate", "宝箱"})
    end
    if shouldCreateResourceESP then CreateResourceESP(obj) end
end

local function UntrackFarmObject(obj)
    FarmableCache[obj] = nil
    FarmDropCache[obj] = nil
    FarmResourceCache[obj] = nil
    if ResourceESP[obj] then
        pcall(function() ResourceESP[obj].Highlight:Destroy() end)
        pcall(function() ResourceESP[obj].Billboard:Destroy() end)
        ResourceESP[obj] = nil
    end
end

local function TrackTaskText(obj)
    if obj and (obj:IsA("TextLabel") or obj:IsA("TextButton")) then TaskTextObjects[obj] = true end
end

local function UntrackTaskText(obj)
    TaskTextObjects[obj] = nil
end

local MoveFarmCharacter

local function TraverseDescendantsIncrementally(root, callback, timeBudget)
    local queue = root:GetChildren()
    local index = 1
    local budget = timeBudget or 0.002
    while RuntimeAlive and index <= #queue do
        local sliceStarted = os.clock()
        repeat
            local object = queue[index]
            index = index + 1
            callback(object)
            for _, child in ipairs(object:GetChildren()) do queue[#queue + 1] = child end
        until index > #queue or os.clock() - sliceStarted >= budget
        if index <= #queue then task.wait() end
    end
end

local function BuildFarmableCache()
    FarmableCache = {}
    FarmDropCache = {}
    FarmResourceCache = {}
    TraverseDescendantsIncrementally(Workspace, TrackFarmObject, 0.002)
end

local function BuildTaskTextCache()
    TaskTextObjects = {}
    TraverseDescendantsIncrementally(PlayerGui, TrackTaskText, 0.002)
end

MoveFarmCharacter = function(humanoid, root, position, forceMove)
    if not forceMove and not Settings.FarmMoveToTargets then return false end
    local now = tick()
    local distanceToGoal = (root.Position - position).Magnitude
    if distanceToGoal <= 3 then
        if LastMoveCommandPosition and (LastMoveCommandPosition - root.Position).Magnitude > 0.5 then
            humanoid:MoveTo(root.Position)
        end
        CurrentMoveGoal = nil
        CurrentWaypoints = nil
        LastMoveCommandPosition = root.Position
        LastMoveCommandTime = now
        StuckRecoveryAttempts = 0
        return true
    end
    if now - LastFarmMove < 0.1 then return true end
    LastFarmMove = now

    local goalChanged = not CurrentMoveGoal or (CurrentMoveGoal - position).Magnitude > 6
    if goalChanged then
        CurrentMoveGoal = position
        CurrentWaypoints = nil
        CurrentWaypointIndex = 1
        LastProgressPosition = root.Position
        LastProgressTime = now
        LastMoveCommandPosition = nil
        StuckRecoveryAttempts = 0
    end

    local movedDistance = LastProgressPosition and (root.Position - LastProgressPosition).Magnitude or math.huge
    if not LastProgressPosition or movedDistance >= 0.75 then
        LastProgressPosition = root.Position
        LastProgressTime = now
        StuckRecoveryAttempts = 0
    end
    local stuck = LastProgressPosition and now - LastProgressTime > 2.25

    if (goalChanged or not CurrentWaypoints or stuck) and now - LastPathCompute > 0.45 then
        LastPathCompute = now
        CurrentMoveGoal = position
        CurrentWaypoints = nil
        CurrentWaypointIndex = 1

        local path = PathfindingService:CreatePath({
            AgentRadius = 2.5,
            AgentHeight = 5,
            AgentCanJump = true,
            AgentCanClimb = true,
            WaypointSpacing = 4
        })
        local success = pcall(function() path:ComputeAsync(root.Position, position) end)
        if success and path.Status == Enum.PathStatus.Success then
            CurrentWaypoints = path:GetWaypoints()
            CurrentWaypointIndex = math.min(2, #CurrentWaypoints)
        end
    end

    local movePosition = position
    if CurrentWaypoints and #CurrentWaypoints > 0 then
        while CurrentWaypointIndex <= #CurrentWaypoints
            and (CurrentWaypoints[CurrentWaypointIndex].Position - root.Position).Magnitude <= 4 do
            CurrentWaypointIndex = CurrentWaypointIndex + 1
        end
        local waypoint = CurrentWaypoints[math.min(CurrentWaypointIndex, #CurrentWaypoints)]
        if waypoint then
            movePosition = waypoint.Position
            if waypoint.Action == Enum.PathWaypointAction.Jump then humanoid.Jump = true end
        end
    end

    if stuck and now - LastRecoveryTime > 0.8 then
        LastRecoveryTime = now
        StuckRecoveryAttempts = StuckRecoveryAttempts + 1
        humanoid.Jump = true
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        local side = StuckRecoveryAttempts % 2 == 0 and -1 or 1
        local forward = position - root.Position
        forward = forward.Magnitude > 0 and forward.Unit or root.CFrame.LookVector
        movePosition = root.Position + forward * 5 + root.CFrame.RightVector * side * 4
        CurrentWaypoints = nil
        LastProgressPosition = root.Position
        LastProgressTime = now
    end

    local shouldIssueMove = not LastMoveCommandPosition
        or (LastMoveCommandPosition - movePosition).Magnitude > 1.25
        or now - LastMoveCommandTime > 1.25
    if shouldIssueMove then
        humanoid:MoveTo(movePosition)
        LastMoveCommandPosition = movePosition
        LastMoveCommandTime = now
    end
    return true
end

local function StopFarmCharacter(humanoid, root)
    humanoid:MoveTo(root.Position)
    CurrentMoveGoal = nil
    CurrentWaypoints = nil
    CurrentWaypointIndex = 1
    LastMoveCommandPosition = root.Position
    LastMoveCommandTime = tick()
    LastProgressPosition = root.Position
    LastProgressTime = tick()
    StuckRecoveryAttempts = 0
end

local function GetDropPart(object)
    if not object or not object.Parent then return nil end
    if object:IsA("Tool") then return object:FindFirstChild("Handle") end
    if object:IsA("BasePart") then return object end
    if object:IsA("Model") then return GetBestResourcePart(object) end
    return nil
end

local function TryCollectLooseDrop(root, humanoid, matcher, maxDistance, forceMove)
    if not Settings.FarmCollectDrops and not matcher then return false end
    local searchDistance = maxDistance or Settings.FarmRange
    local nearestPart, nearestDistance, nearestScore = nil, searchDistance, math.huge
    for object in pairs(FarmDropCache) do
        local part = GetDropPart(object)
        if not part then
            FarmDropCache[object] = nil
        elseif not matcher or matcher(GetObjectDescriptor(object), object) then
            local distance = (part.Position - root.Position).Magnitude
            local score = distance - (part == CurrentFarmTarget and 40 or 0)
            if distance <= searchDistance and score < nearestScore then
                nearestPart, nearestDistance, nearestScore = part, distance, score
            end
        end
    end
    if not nearestPart then return false end

    CurrentFarmPhase = "collect"
    CurrentFarmTarget = nearestPart
    if nearestDistance > 5 then
        MoveFarmCharacter(humanoid, root, nearestPart.Position, forceMove)
    else
        StopFarmCharacter(humanoid, root)
        pcall(function()
            if firetouchinterest then
                firetouchinterest(root, nearestPart, 0)
                firetouchinterest(root, nearestPart, 1)
            end
        end)
    end
    return true
end

local function FindAndEquipTool(character, humanoid, targetDescription)
    local preferred = {"tool", "knife", "sword", "spear", "axe", "pick"}
    if ContainsAny(targetDescription, {"wood", "tree", "log", "oak", "palm"}) then
        preferred = {"axe", "hatchet", "wood"}
    elseif ContainsAny(targetDescription, {"stone", "rock", "ore", "iron", "crystal"}) then
        preferred = {"pickaxe", "pick", "hammer"}
    elseif ContainsAny(targetDescription, {"berry", "bush"}) then
        preferred = {"sickle", "knife", "machete", "axe"}
    elseif ContainsAny(targetDescription, {"chicken", "bear", "snake", "spider"}) then
        preferred = {"sword", "knife", "spear", "axe", "bow"}
    end

    local tools = {}
    for _, object in ipairs(character:GetChildren()) do
        if object:IsA("Tool") then table.insert(tools, object) end
    end
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        for _, object in ipairs(backpack:GetChildren()) do
            if object:IsA("Tool") then table.insert(tools, object) end
        end
    end

    local selected = nil
    for _, keyword in ipairs(preferred) do
        for _, tool in ipairs(tools) do
            if string.lower(tool.Name):find(keyword, 1, true) then selected = tool; break end
        end
        if selected then break end
    end
    selected = selected or tools[1]
    if selected and selected.Parent ~= character then pcall(function() humanoid:EquipTool(selected) end) end
    return selected
end

local function ActivateAtTarget(character, humanoid, description, targetPart, targetObject)
    if tick() - LastFarmAttack < math.max(Settings.FarmDelay, 0.15) then return end
    LastFarmAttack = tick()

    local root = character and character:FindFirstChild("HumanoidRootPart")
    if root and targetPart and targetPart.Parent then
        local lookPosition = Vector3.new(targetPart.Position.X, root.Position.Y, targetPart.Position.Z)
        if (lookPosition - root.Position).Magnitude > 0.05 then
            pcall(function() root.CFrame = CFrame.lookAt(root.Position, lookPosition) end)
        end
        if Camera then
            pcall(function()
                Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, targetPart.Position)
            end)
        end
    end

    if targetObject and targetObject.Parent then
        local prompt = targetObject:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt and prompt.Enabled and fireproximityprompt then
            local promptPosition = GetPromptPosition(prompt)
            if not root or not promptPosition or (promptPosition - root.Position).Magnitude <= prompt.MaxActivationDistance + 1 then
                pcall(function() fireproximityprompt(prompt) end)
                CollectUntil = tick() + 5
                return
            end
        end

        local clickDetector = targetObject:FindFirstChildWhichIsA("ClickDetector", true)
        if clickDetector and fireclickdetector then
            local detectorPart = clickDetector.Parent
            local detectorPosition = detectorPart and detectorPart:IsA("BasePart") and detectorPart.Position or nil
            if not root or not detectorPosition or (detectorPosition - root.Position).Magnitude <= clickDetector.MaxActivationDistance + 1 then
                pcall(function() fireclickdetector(clickDetector) end)
                CollectUntil = tick() + 5
                return
            end
        end

        local targetModel = targetObject:IsA("Model") and targetObject or targetObject:FindFirstAncestorOfClass("Model")
        local targetHumanoid = targetModel and targetModel:FindFirstChildOfClass("Humanoid")
        local attackRemote = targetHumanoid and Events:FindFirstChild("attackMobRemote")
        if attackRemote then
            pcall(function() attackRemote:FireServer(targetModel, targetHumanoid) end)
        end
    end

    local tool = FindAndEquipTool(character, humanoid, description)
    if tool then
        pcall(function() tool:Activate() end)
    end

    local clickedTarget = false
    if targetPart and targetPart.Parent and Camera then
        local screenPosition, visible = Camera:WorldToViewportPoint(targetPart.Position)
        if visible and screenPosition.Z > 0 then
            clickedTarget = true
            pcall(function()
                VirtualInputManager:SendMouseButtonEvent(screenPosition.X, screenPosition.Y, 0, true, game, 0)
                task.wait(0.03)
                VirtualInputManager:SendMouseButtonEvent(screenPosition.X, screenPosition.Y, 0, false, game, 0)
            end)
        end
    end
    if not clickedTarget and not tool and mouse1click then
        pcall(mouse1click)
    end
    CollectUntil = tick() + 5
end

local function TryFarmWorldResource(character, root, humanoid, matcher, phase, searchDistance, forceMove)
    local maximumDistance = searchDistance or Settings.FarmRange
    local nearest, nearestPart, nearestHitPosition, nearestDistance, nearestScore = nil, nil, nil, maximumDistance, math.huge
    for object in pairs(FarmResourceCache) do
        if not object.Parent or IsExcludedFarmResource(object) then
            FarmResourceCache[object] = nil
        else
            local description = GetObjectDescriptor(object)
            if (not matcher or matcher(description, object)) then
                local part = GetBestResourcePart(object, root.Position)
                if part then
                    local hitPosition = part.Position
                    pcall(function() hitPosition = part:GetClosestPointOnSurface(root.Position) end)
                    local distance = (hitPosition - root.Position).Magnitude
                    local score = distance - (object == CurrentFarmTarget and 60 or 0)
                    if distance <= maximumDistance and score < nearestScore then
                        nearest, nearestPart, nearestHitPosition, nearestDistance, nearestScore = object, part, hitPosition, distance, score
                    end
                end
            end
        end
    end
    if not nearest then return false end

    CurrentFarmTarget = nearest
    CurrentFarmPhase = phase or "farm-object"
    local strikeDistance = math.clamp(math.max(nearestPart.Size.X, nearestPart.Size.Z) * 0.5 + 5, 7, 12)
    if nearestDistance > strikeDistance then
        local approachPosition = GetFarmApproachPosition(character, root, nearest, nearestPart)
        MoveFarmCharacter(humanoid, root, approachPosition, forceMove)
    else
        StopFarmCharacter(humanoid, root)
        ActivateAtTarget(character, humanoid, GetObjectDescriptor(nearest), nearestPart, nearest)
    end
    return true
end

local function NormalizeSurvivalPercent(value, maximum, hasExplicitMaximum)
    if type(value) ~= "number" then return nil end
    if not hasExplicitMaximum and value >= 0 and value <= 1 then
        return math.clamp(value * 100, 0, 100)
    end
    return math.clamp(value / math.max(tonumber(maximum) or 100, 1) * 100, 0, 100)
end

local function GetObjectContext(object, levels)
    local names = {}
    local current = object
    for _ = 1, levels or 7 do
        if not current then break end
        table.insert(names, current.Name)
        current = current.Parent
    end
    return string.lower(table.concat(names, " "))
end

local function GetAttributeMaximum(source, attributeName, attributes)
    local wanted = {
        ["max" .. string.lower(attributeName)] = true,
        [string.lower(attributeName) .. "max"] = true,
        ["maximum" .. string.lower(attributeName)] = true,
        [string.lower(attributeName) .. "maximum"] = true
    }
    for name, value in pairs(attributes) do
        if wanted[string.lower(name)] and type(value) == "number" then return value, true end
    end
    return 100, false
end

local function GetSurvivalPercent(humanoid)
    local strongNames = {hunger = true, satiety = true, fullness = true}
    local acceptableNames = {hunger = true, food = true, satiety = true, fullness = true}
    local sources = {LocalPlayer, LocalPlayer.Character, humanoid}

    -- Attributes are the most reliable source. Match names without depending on capitalization.
    for _, source in ipairs(sources) do
        if source then
            local attributes = source:GetAttributes()
            for name, value in pairs(attributes) do
                if acceptableNames[string.lower(name)] and type(value) == "number" then
                    local maximum, explicit = GetAttributeMaximum(source, name, attributes)
                    return NormalizeSurvivalPercent(value, maximum, explicit)
                end
            end
        end
    end

    -- Search replicated stat values. Prefer Hunger/Satiety/Fullness over a generic Food counter.
    local bestObject, bestScore = nil, math.huge
    for _, source in ipairs({LocalPlayer, LocalPlayer.Character, PlayerGui}) do
        if source then
            for _, object in ipairs(source:GetDescendants()) do
                if object:IsA("NumberValue") or object:IsA("IntValue") then
                    local lowerName = string.lower(object.Name)
                    local context = GetObjectContext(object, 6)
                    local score = nil
                    if strongNames[lowerName] then score = 0
                    elseif lowerName == "food" and ContainsAny(context, {"stat", "survival", "hunger"}) then score = 10
                    elseif ContainsAny(lowerName, {"hunger", "satiety", "fullness"}) then score = 20 end
                    if score and score < bestScore then bestObject, bestScore = object, score end
                end
            end
        end
    end
    if bestObject then
        local maximum = bestObject:GetAttribute("Max") or bestObject:GetAttribute("Maximum")
        local explicit = type(maximum) == "number"
        if not explicit and bestObject.Parent then
            for _, maxName in ipairs({"Max" .. bestObject.Name, bestObject.Name .. "Max", "Max", "Maximum"}) do
                local sibling = bestObject.Parent:FindFirstChild(maxName)
                if sibling and (sibling:IsA("NumberValue") or sibling:IsA("IntValue")) then
                    maximum, explicit = sibling.Value, true
                    break
                end
            end
        end
        return NormalizeSurvivalPercent(bestObject.Value, maximum or 100, explicit)
    end

    -- Text-based HUDs may be nested several frames deep, so include ancestor names in the context.
    for object in pairs(TaskTextObjects) do
        if object.Parent and object.Visible then
            local context = GetObjectContext(object, 8)
            if ContainsAny(context, {"hunger", "satiety", "fullness", "foodbar", "food bar"}) then
                local text = tostring(object.Text)
                local percent = text:match("(%d+%.?%d*)%s*%%")
                if percent then return math.clamp(tonumber(percent), 0, 100) end
                local current, maximum = text:match("(%d+%.?%d*)%s*/%s*(%d+%.?%d*)")
                if current and maximum then
                    return math.clamp(tonumber(current) / math.max(tonumber(maximum), 1) * 100, 0, 100)
                end
            end
        end
    end

    -- Last reliable HUD fallback: a clearly named hunger/satiety/fullness fill bar.
    for _, object in ipairs(PlayerGui:GetDescendants()) do
        if object:IsA("GuiObject") and object.Visible then
            local context = GetObjectContext(object, 7)
            local isSurvivalBar = ContainsAny(context, {"hunger", "satiety", "fullness"})
                and ContainsAny(string.lower(object.Name), {"fill", "bar", "progress", "value"})
            if isSurvivalBar then
                local scale = object.Size.X.Scale
                if scale >= 0 and scale <= 1 then return math.clamp(scale * 100, 0, 100) end
            end
        end
    end

    return nil
end

local function FindFoodTool(character)
    local candidates = {}
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:FindFirstChild("Backpack")
    for _, container in ipairs({character, backpack}) do
        if container then
            for _, object in ipairs(container:GetChildren()) do
                if object:IsA("Tool") and IsFoodName(object.Name) then table.insert(candidates, object) end
            end
        end
    end
    table.sort(candidates, function(a, b)
        local aName, bName = string.lower(a.Name), string.lower(b.Name)
        local aScore = ContainsAny(aName, {"cooked", "berry", "food", "熟肉"}) and 0 or 1
        local bScore = ContainsAny(bName, {"cooked", "berry", "food", "熟肉"}) and 0 or 1
        return aScore < bScore
    end)
    return candidates[1]
end

local function HasRawMeat(character)
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:FindFirstChild("Backpack")
    for _, container in ipairs({character, backpack}) do
        if container then
            for _, object in ipairs(container:GetChildren()) do
                if object:IsA("Tool") and ContainsAny(object.Name, {"raw meat", "rawmeat", "生肉"}) then return true end
            end
        end
    end
    return false
end

local function FindEquippedWeapon(character)
    for _, object in ipairs(character:GetChildren()) do
        if object:IsA("Tool") and not IsFoodName(object.Name) then return object end
    end
    return nil
end

local function RestoreEquippedWeapon(character, humanoid, savedTool, savedName)
    if not character or not humanoid or humanoid.Health <= 0 then return end
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:FindFirstChild("Backpack")
    local tool = savedTool
    if not tool or not tool.Parent then
        for _, container in ipairs({character, backpack}) do
            if container then
                local candidate = container:FindFirstChild(savedName or "")
                if candidate and candidate:IsA("Tool") then tool = candidate; break end
            end
        end
    end
    if tool and tool.Parent and tool.Parent ~= character then
        pcall(function() humanoid:EquipTool(tool) end)
    end
end

local function GetFoodAmountSignature(food)
    if not food or not food.Parent then return "consumed" end
    local values = {food.Parent:GetFullName()}
    for _, attributeName in ipairs({"Amount", "Count", "Quantity", "Stack", "Uses"}) do
        local value = food:GetAttribute(attributeName)
        if value ~= nil then table.insert(values, attributeName .. "=" .. tostring(value)) end
    end
    for _, object in ipairs(food:GetDescendants()) do
        if (object:IsA("NumberValue") or object:IsA("IntValue"))
            and ContainsAny(object.Name, {"amount", "count", "quantity", "stack", "uses"}) then
            table.insert(values, object:GetFullName() .. "=" .. tostring(object.Value))
        end
    end
    return table.concat(values, "|")
end

local function RunAutoEatSequence(character, humanoid)
    local savedTool = FindEquippedWeapon(character)
    local savedName = savedTool and savedTool.Name or nil
    local sequenceStarted = tick()
    local unconfirmedAttempts = 0

    local ok, err = pcall(function()
        while RuntimeAlive and Settings.AutoSurvival and Settings.SurvivalAutoEat do
            local hungerBefore = GetSurvivalPercent(humanoid)
            local eatTarget = math.max(Settings.SurvivalEatTarget, Settings.SurvivalEatThreshold)
            if not hungerBefore or hungerBefore >= eatTarget then break end
            if not character.Parent or humanoid.Health <= 0 then break end

            local food = FindFoodTool(character)
            if not food then break end
            if Settings.SurvivalCookFood and ContainsAny(food.Name, {"raw meat", "rawmeat", "生肉"}) then break end

            if food.Parent ~= character then pcall(function() humanoid:EquipTool(food) end) end
            local equipDeadline = tick() + 2
            while food.Parent and food.Parent ~= character and tick() < equipDeadline do task.wait(0.05) end
            if not food.Parent or food.Parent ~= character then break end

            local readyDeadline = tick() + 3
            while food.Parent and food.Enabled == false and tick() < readyDeadline do task.wait(0.10) end
            if not food.Parent then continue end

            local amountBefore = GetFoodAmountSignature(food)
            local activatedAt = tick()
            local sawDisabled = food.Enabled == false
            pcall(function() food:Activate() end)
            LastEat = tick()
            CurrentFarmPhase = "eat"

            local biteConfirmed = false
            local biteDeadline = tick() + 6
            while RuntimeAlive and tick() < biteDeadline do
                task.wait(0.10)
                if food.Parent and food.Enabled == false then sawDisabled = true end
                local hungerNow = GetSurvivalPercent(humanoid)
                local amountChanged = GetFoodAmountSignature(food) ~= amountBefore
                local cooldownFinished = sawDisabled and food.Parent and food.Enabled ~= false
                if not food.Parent or amountChanged or (hungerNow and hungerNow > hungerBefore + 0.1)
                    or (cooldownFinished and tick() - activatedAt >= 0.75) then
                    biteConfirmed = true
                    break
                end
            end

            while RuntimeAlive and tick() - activatedAt < 1.25 do task.wait(0.10) end
            if biteConfirmed then unconfirmedAttempts = 0 else unconfirmedAttempts = unconfirmedAttempts + 1 end
            if unconfirmedAttempts >= 2 or tick() - sequenceStarted > 35 then break end
            task.wait(0.20)
        end
    end)

    RestoreEquippedWeapon(character, humanoid, savedTool, savedName)
    if not ok then error(err) end
end

local function TryUseFood(character, humanoid)
    if AutoEatBusy then return true end
    if not Settings.SurvivalAutoEat or tick() - LastEat < 1 then return false end
    local survivalPercent = GetSurvivalPercent(humanoid)
    if not survivalPercent or survivalPercent > Settings.SurvivalEatThreshold then return false end

    local food = FindFoodTool(character)
    if not food then return false end
    if Settings.SurvivalCookFood and ContainsAny(food.Name, {"raw meat", "rawmeat", "生肉"}) then return false end

    AutoEatBusy = true
    task.spawn(function()
        local ok, err = pcall(function() RunAutoEatSequence(character, humanoid) end)
        AutoEatBusy = false
        if not ok then warn("Auto Eat error: " .. tostring(err)) end
    end)
    return true
end

local function TrySurvivalPrompt(root, humanoid, hasRawMeat)
    local nearest, nearestPosition, nearestDistance, kind = nil, nil, Settings.SurvivalSearchDistance, nil
    for prompt in pairs(FarmableCache) do
        if not prompt.Parent then
            FarmableCache[prompt] = nil
        elseif prompt.Enabled then
            local description = GetPromptDescriptor(prompt)
            local promptKind = nil
            if Settings.SurvivalCookFood and hasRawMeat and ContainsAny(description, CookWords) then
                promptKind = "cook"
            elseif Settings.SurvivalCollectMeat and ContainsAny(description, {
                "meat", "drumstick", "egg", "tentacle", "octopus", "熟肉", "生肉", "熟章鱼触手", "章鱼触手"
            }) then
                promptKind = "collect-food"
            elseif Settings.SurvivalCollectBerries and ContainsAny(description, {"berry", "berries", "fruit"}) then
                promptKind = "collect-food"
            end
            local position = promptKind and GetPromptPosition(prompt) or nil
            if position then
                local distance = (position - root.Position).Magnitude
                if distance < nearestDistance then
                    nearest, nearestPosition, nearestDistance, kind = prompt, position, distance, promptKind
                end
            end
        end
    end
    if not nearest then return false end
    CurrentFarmTarget, CurrentFarmPhase = nearest, kind
    local activationDistance = math.max(4, nearest.MaxActivationDistance - 1)
    if nearestDistance > activationDistance then
        MoveFarmCharacter(humanoid, root, nearestPosition, true)
    else
        pcall(function() fireproximityprompt(nearest) end)
        CollectUntil = tick() + 4
    end
    return true
end

local function TryHuntChicken(character, root, humanoid)
    if not Settings.SurvivalHuntChicken then return false end
    local nearestMob, nearestDistance = nil, Settings.SurvivalSearchDistance
    for mob, data in pairs(MobESP) do
        if mob.Parent and data.Humanoid and data.Humanoid.Health > 0
            and ContainsAny(mob.Name .. " " .. TranslateName(mob.Name), {"chicken", "hen", "rooster", "鸡"}) then
            local distance = (data.Head.Position - root.Position).Magnitude
            if distance < nearestDistance then nearestMob, nearestDistance = {mob = mob, data = data}, distance end
        end
    end
    if not nearestMob then
        return TryFarmWorldResource(character, root, humanoid, function(description)
            return ContainsAny(description, {"chicken", "hen", "rooster", "鸡"})
        end, "hunt-chicken", Settings.SurvivalSearchDistance, true)
    end

    CurrentFarmTarget, CurrentFarmPhase = nearestMob.mob, "hunt-chicken"
    if nearestDistance > math.max(8, Settings.KillAuraRange - 3) then
        MoveFarmCharacter(humanoid, root, nearestMob.data.Head.Position, true)
    else
        ActivateAtTarget(character, humanoid, "chicken")
        local attackRemote = Events:FindFirstChild("attackMobRemote")
        if attackRemote then pcall(function() attackRemote:FireServer(nearestMob.mob, nearestMob.data.Humanoid) end) end
    end
    return true
end

local function AutoSurvival()
    if not Settings.AutoSurvival or tick() - LastSurvival < 0.25 then return false end
    LastSurvival = tick()
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid then return false end

    if TryUseFood(character, humanoid) then return true end
    local hasRawMeat = HasRawMeat(character)
    if TrySurvivalPrompt(root, humanoid, hasRawMeat) then return true end
    if TryCollectLooseDrop(root, humanoid, function(description)
        local meat = Settings.SurvivalCollectMeat and ContainsAny(description, {
            "meat", "drumstick", "chicken", "egg", "tentacle", "octopus", "熟肉", "生肉", "章鱼触手"
        })
        local berries = Settings.SurvivalCollectBerries and ContainsAny(description, {"berry", "berries", "fruit"})
        return meat or berries
    end, Settings.SurvivalSearchDistance, true) then return true end
    if Settings.SurvivalCollectBerries and TryFarmWorldResource(character, root, humanoid, function(description)
        return ContainsAny(description, {"berry", "berries", "fruit", "bush"})
    end, "find-berries", Settings.SurvivalSearchDistance, true) then return true end
    return TryHuntChicken(character, root, humanoid)
end

local function AutoFarm()
    if not Settings.AutoFarm then return end
    if tick() - LastFarm < Settings.FarmDelay then return end
    LastFarm = tick()

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid then return end
    local myPos = root.Position
    local function MatchesSelectedFarmResource(description, object)
        return SelectedFarmResourceMatch(description, object)
    end

    if Settings.FarmCollectDrops and tick() < CollectUntil and TryCollectLooseDrop(
        root, humanoid, MatchesSelectedFarmResource, Settings.FarmRange
    ) then return end

    local nearest, nearestDistance, nearestKind = nil, Settings.FarmRange, nil
    for prompt in pairs(FarmableCache) do
        if not prompt.Parent then
            FarmableCache[prompt] = nil
        elseif prompt.Enabled then
            local position = GetPromptPosition(prompt)
            if position then
                local distance = (position - myPos).Magnitude
                local description = GetPromptDescriptor(prompt)
                local kind = nil
                if IsCollectPrompt(prompt) then
                    if Settings.FarmCollectDrops
                        and MatchesSelectedFarmResource(description, prompt)
                        and (tick() < CollectUntil or distance <= 80) then
                        kind = "collect"
                    end
                elseif MatchesSelectedFarmResource(description, prompt) then
                    kind = "farm"
                end

                local priorityDistance = distance
                if kind == "collect" then priorityDistance = distance - 5000 end
                if prompt == CurrentFarmTarget then priorityDistance = priorityDistance - 750 end
                if kind and distance <= Settings.FarmRange and priorityDistance < nearestDistance then
                    nearest, nearestDistance, nearestKind = prompt, priorityDistance, kind
                end
            end
        end
    end

    if nearest then
        local position = GetPromptPosition(nearest)
        local actualDistance = position and (position - root.Position).Magnitude or math.huge
        local activationDistance = math.max(4, nearest.MaxActivationDistance - 1)
        CurrentFarmTarget = nearest
        CurrentFarmPhase = nearestKind
        if actualDistance > activationDistance then
            MoveFarmCharacter(humanoid, root, position)
        else
            StopFarmCharacter(humanoid, root)
            pcall(function() fireproximityprompt(nearest) end)
            if nearestKind == "farm" then CollectUntil = tick() + 5 end
        end
        return
    end

    if TryFarmWorldResource(char, root, humanoid, function(description, object)
        return MatchesSelectedFarmResource(description, object)
    end, "farm-object", Settings.FarmRange) then return end

    if Settings.FarmCollectDrops and TryCollectLooseDrop(
        root, humanoid, MatchesSelectedFarmResource, Settings.FarmRange
    ) then return end

    -- No target means idle. Never punch the air as a fallback.
    CurrentFarmTarget = nil
    CurrentFarmPhase = "idle"
end

-- ========== MENU COLORS ==========
local BLUE = Color3.fromRGB(205, 212, 225)
local BLUE_DARK = Color3.fromRGB(54, 59, 70)
local BLUE_GLOW = Color3.fromRGB(245, 248, 255)
local BG_DARK = Color3.fromRGB(5, 6, 9)
local BG_MID = Color3.fromRGB(11, 13, 18)
local BG_LIGHT = Color3.fromRGB(27, 30, 38)
local TEXT = Color3.fromRGB(238, 241, 247)
local TEXT_DIM = Color3.fromRGB(139, 145, 157)

local NIHILITY_LOGO_BASE64 = [[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]]

local function DecodeMenuLogoBase64(data)
    local decoders = {}
    if type(crypt) == "table" then
        if type(crypt.base64decode) == "function" then table.insert(decoders, crypt.base64decode) end
        if type(crypt.base64) == "table" and type(crypt.base64.decode) == "function" then
            table.insert(decoders, crypt.base64.decode)
        end
    end
    if type(syn) == "table" and type(syn.crypt) == "table"
        and type(syn.crypt.base64) == "table" and type(syn.crypt.base64.decode) == "function" then
        table.insert(decoders, syn.crypt.base64.decode)
    end
    if type(base64_decode) == "function" then table.insert(decoders, base64_decode) end
    for _, decoder in ipairs(decoders) do
        local ok, decoded = pcall(decoder, data)
        if ok and type(decoded) == "string" and #decoded > 100 then return decoded end
    end

    local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local values = {}
    for index = 1, #alphabet do values[alphabet:byte(index)] = index - 1 end
    local output = {}
    for index = 1, #data, 4 do
        local a = values[data:byte(index)]
        local b = values[data:byte(index + 1)]
        local c = values[data:byte(index + 2)]
        local d = values[data:byte(index + 3)]
        if a and b then
            local combined = a * 262144 + b * 4096 + (c or 0) * 64 + (d or 0)
            output[#output + 1] = string.char(math.floor(combined / 65536) % 256)
            if c then output[#output + 1] = string.char(math.floor(combined / 256) % 256) end
            if d then output[#output + 1] = string.char(combined % 256) end
        end
        if index % 16384 == 1 then task.wait() end
    end
    return table.concat(output)
end

local function ResolveNihilityLogoAsset()
    local assetLoader = getcustomasset or getsynasset
    if type(writefile) ~= "function" or type(assetLoader) ~= "function" then return "" end
    local logoPath = "nihility_island_escape_logo.png"
    local cached = false
    if type(isfile) == "function" then
        local checked, exists = pcall(isfile, logoPath)
        cached = checked and exists
    end
    if not cached then
        local decodedLogo = DecodeMenuLogoBase64(NIHILITY_LOGO_BASE64)
        local ok = pcall(function() writefile(logoPath, decodedLogo) end)
        if not ok then return "" end
    end
    local loaded, asset = pcall(assetLoader, logoPath)
    return loaded and asset or ""
end

local NIHILITY_LOGO_ASSET = ""
NihilityLogoImage = nil
NihilityLogoFallback = nil

-- ========== NIGHT MODE ==========
local function UpdateNightMode()
    if not Settings.NightMode then return end
    local clockTime = Lighting.ClockTime
    local isNight = clockTime >= 18 or clockTime <= 6
    if isNight then
        Lighting.Brightness = 2
        Lighting.FogEnd = 10000
        Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.fromRGB(128, 128, 128)
    end
end

local function RestoreLighting()
    Lighting.Brightness = LightingDefaults.Brightness
    Lighting.FogEnd = LightingDefaults.FogEnd
    Lighting.GlobalShadows = LightingDefaults.GlobalShadows
    Lighting.Ambient = LightingDefaults.Ambient
end

local function RefreshToggleViews(setting)
    local views = ToggleViews[setting]
    if not views then return end
    for button in pairs(views) do
        if button and button.Parent then
            local enabled = Settings[setting] == true
            button.BackgroundColor3 = enabled and BLUE or BG_LIGHT
            button.Text = enabled and "ON" or "OFF"
            button.TextColor3 = enabled and Color3.new(1, 1, 1) or TEXT_DIM
        else
            views[button] = nil
        end
    end
end

local function SetSetting(setting, value)
    if type(Settings[setting]) ~= "boolean" then
        warn("Invalid toggle setting: " .. tostring(setting))
        return
    end

    local enabled = value == true
    if setting == "StealthMode" then
        -- Update the complete group atomically. Recursive SetSetting calls could
        -- briefly calculate StealthMode from one old child value and leave its
        -- button showing OFF even though Humanization was already enabled.
        Settings.StealthMode = enabled
        Settings.HumanizationEnabled = enabled
        Settings.RandomMoveEnabled = enabled
        RefreshToggleViews("StealthMode")
        RefreshToggleViews("HumanizationEnabled")
        RefreshToggleViews("RandomMoveEnabled")
    else
        Settings[setting] = enabled
        RefreshToggleViews(setting)
        if setting == "HumanizationEnabled" or setting == "RandomMoveEnabled" then
            Settings.StealthMode = Settings.HumanizationEnabled and Settings.RandomMoveEnabled
            RefreshToggleViews("StealthMode")
        end
    end

    local ok, err = pcall(function()
        if setting == "HitboxEnabled" then
            if Settings.HitboxEnabled then
                for mob in pairs(MobESP) do CreateHitbox(mob) end
            else
                for mob in pairs(HitboxCache) do RemoveHitbox(mob) end
            end
        elseif setting == "NightMode" then
            if Settings.NightMode then UpdateNightMode() else RestoreLighting() end
        elseif setting == "AutoFarm" and not Settings.AutoFarm then
            CurrentFarmTarget = nil
            CurrentFarmPhase = "idle"
            CollectUntil = 0
            CurrentMoveGoal = nil
            CurrentWaypoints = nil
            LastProgressPosition = nil
            LastMoveCommandPosition = nil
            StuckRecoveryAttempts = 0
            local character = LocalPlayer.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local root = character and character:FindFirstChild("HumanoidRootPart")
            if humanoid and root then humanoid:MoveTo(root.Position) end
        elseif setting == "AutoSurvival" and not Settings.AutoSurvival and not Settings.AutoFarm then
            CurrentFarmTarget = nil
            CurrentFarmPhase = "idle"
            CurrentMoveGoal = nil
            CurrentWaypoints = nil
            LastProgressPosition = nil
            LastMoveCommandPosition = nil
            StuckRecoveryAttempts = 0
            local character = LocalPlayer.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local root = character and character:FindFirstChild("HumanoidRootPart")
            if humanoid and root then humanoid:MoveTo(root.Position) end
        elseif setting == "FlyEnabled" then
            if Settings.FlyEnabled then StartFly() else StopFly() end
        elseif setting == "NoclipEnabled" then
            if Settings.NoclipEnabled then StartNoclip() else StopNoclip() end
        elseif setting == "InstantInteractEnabled" or setting == "InstantChestOpen"
            or setting == "InstantFurnace" then
            RefreshInstantPrompts()
        elseif setting == "SpeedEnabled" or setting == "JumpEnabled" then
            ApplyMods()
        elseif setting == "ESPEnabled" or setting == "ESPBox" or setting == "ESPName"
            or setting == "ESPDistance" or setting == "ESPHealthBar" or setting == "ESPHealthText" then
            UpdatePlayerESP()
        elseif setting == "MobESPEnabled" or setting == "MobESPBox" or setting == "MobESPName"
            or setting == "MobESPHealthBar" or setting == "MobESPHealthText" then
            UpdateMobESP()
        elseif setting == "ResourceESPEnabled" or setting == "ResourceESPHighlight"
            or setting == "ResourceESPName" or setting == "ResourceESPDistance"
            or setting == "ResourceESPChests" or setting == "ResourceESPIron"
            or setting == "ResourceESPStone" or setting == "ResourceESPWood"
            or setting == "ResourceESPOther" then
            UpdateResourceESP()
        end
    end)
    if not ok then warn("Toggle side effect failed [" .. setting .. "]: " .. tostring(err)) end

    -- Always finish from the authoritative Settings table so every visible
    -- toggle can be switched both ON and OFF without stale button text.
    RefreshToggleViews(setting)
    if setting == "StealthMode" then
        RefreshToggleViews("HumanizationEnabled")
        RefreshToggleViews("RandomMoveEnabled")
    end
end

-- ========== MENU ==========
local function AddCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 6)
    c.Parent = parent
    return c
end

local function CreateToggle(parent, text, setting)
    assert(type(Settings[setting]) == "boolean", "Toggle requires boolean setting: " .. tostring(setting))

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 30)
    frame.BackgroundTransparency = 1
    
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.7, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = TEXT
    lbl.TextSize = 13
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame
    
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 60, 0, 24)
    btn.Position = UDim2.new(1, -65, 0.5, -12)
    btn.BackgroundColor3 = Settings[setting] and BLUE or BG_LIGHT
    btn.Text = Settings[setting] and "ON" or "OFF"
    btn.TextColor3 = Settings[setting] and Color3.new(1, 1, 1) or TEXT_DIM
    btn.TextSize = 11
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.Active = true
    btn.Selectable = true
    btn.AutoButtonColor = false
    btn.Parent = frame
    AddCorner(btn, 4)

    ToggleViews[setting] = ToggleViews[setting] or {}
    ToggleViews[setting][btn] = true

    btn.Destroying:Connect(function()
        if ToggleViews[setting] then ToggleViews[setting][btn] = nil end
    end)

    btn.Activated:Connect(function()
        SetSetting(setting, not Settings[setting])
    end)
    
    return frame
end

local function CreateSlider(parent, text, setting, min, max, step)
    step = step or 1
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 45)
    frame.BackgroundTransparency = 1
    
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 20)
    lbl.BackgroundTransparency = 1
    local function FormatValue(value)
        if step < 1 then return string.format("%.2f", value) end
        return tostring(math.floor(value + 0.5))
    end
    lbl.Text = text .. ": " .. FormatValue(Settings[setting])
    lbl.TextColor3 = TEXT
    lbl.TextSize = 13
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame
    
    local slider = Instance.new("Frame")
    slider.Size = UDim2.new(1, -10, 0, 8)
    slider.Position = UDim2.new(0, 5, 0, 28)
    slider.BackgroundColor3 = BG_LIGHT
    slider.BorderSizePixel = 0
    slider.Parent = frame
    AddCorner(slider, 4)
    
    local pct = (Settings[setting] - min) / (max - min)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(pct, 0, 1, 0)
    fill.BackgroundColor3 = BLUE
    fill.BorderSizePixel = 0
    fill.Parent = slider
    AddCorner(fill, 4)
    
    local dragging = false
    slider.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)
    local moveConnection = UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local x = i.Position.X - slider.AbsolutePosition.X
            local p = math.clamp(x / slider.AbsoluteSize.X, 0, 1)
            local raw = min + p * (max - min)
            local value = math.floor((raw / step) + 0.5) * step
            Settings[setting] = math.clamp(value, min, max)
            fill.Size = UDim2.new(p, 0, 1, 0)
            lbl.Text = text .. ": " .. FormatValue(Settings[setting])
        end
    end)

    local endConnection = UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    SliderConnections[frame] = {moveConnection, endConnection}
    frame.Destroying:Connect(function()
        local connections = SliderConnections[frame]
        if connections then
            for _, connection in ipairs(connections) do connection:Disconnect() end
            SliderConnections[frame] = nil
        end
    end)
    
    return frame
end

local function CreateCycle(parent, text, setting, options)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 30)
    frame.BackgroundTransparency = 1
    
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.5, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = TEXT
    lbl.TextSize = 13
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame
    
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 120, 0, 24)
    btn.Position = UDim2.new(1, -125, 0.5, -12)
    btn.BackgroundColor3 = BG_LIGHT
    btn.Text = tostring(Settings[setting])
    btn.TextColor3 = BLUE_GLOW
    btn.TextSize = 11
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.Parent = frame
    AddCorner(btn, 4)
    
    btn.Activated:Connect(function()
        local curr = tostring(Settings[setting])
        local idx = 1
        for i, opt in ipairs(options) do
            if tostring(opt) == curr then idx = i; break end
        end
        idx = (idx % #options) + 1
        Settings[setting] = options[idx]
        btn.Text = tostring(options[idx])
    end)
    
    return frame
end

local function CreateSection(parent, text)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 28)
    frame.BackgroundTransparency = 1
    
    local line = Instance.new("Frame")
    line.Size = UDim2.new(0, 3, 0.7, 0)
    line.Position = UDim2.new(0, 0, 0.15, 0)
    line.BackgroundColor3 = BLUE
    line.BorderSizePixel = 0
    line.Parent = frame
    AddCorner(line, 2)
    
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -10, 1, 0)
    l.Position = UDim2.new(0, 10, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = BLUE_GLOW
    l.TextSize = 13
    l.Font = Enum.Font.GothamBold
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = frame
    
    return frame
end

local function RenderTab(tabName)
    if ContentFrame:FindFirstChild("CurrentTab") then
        ContentFrame.CurrentTab:Destroy()
    end
    
    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "CurrentTab"
    scroll.Size = UDim2.new(1, 0, 1, 0)
    scroll.BackgroundTransparency = 1
    scroll.ScrollBarThickness = 4
    scroll.ScrollBarImageColor3 = BLUE
    scroll.BorderSizePixel = 0
    scroll.Parent = ContentFrame
    
    local y = 0
    local function add(item)
        item.Position = UDim2.new(0, 0, 0, y)
        item.Parent = scroll
        y = y + item.Size.Y.Offset + 4
    end
    
    if tabName == "ESP" then
        add(CreateSection(scroll, "PLAYER ESP"))
        add(CreateToggle(scroll, "Enable", "ESPEnabled"))
        add(CreateToggle(scroll, "Box", "ESPBox"))
        add(CreateToggle(scroll, "Name", "ESPName"))
        add(CreateToggle(scroll, "Distance", "ESPDistance"))
        add(CreateToggle(scroll, "Health Bar", "ESPHealthBar"))
        add(CreateToggle(scroll, "Health Numbers", "ESPHealthText"))
        add(CreateCycle(scroll, "Health Format", "ESPHealthMode", {"percent", "fraction"}))
        add(CreateSlider(scroll, "Max Distance", "ESPMaxDistance", 100, 5000))
        
        y = y + 10
        add(CreateSection(scroll, "MOB/NPC ESP"))
        add(CreateToggle(scroll, "Enable", "MobESPEnabled"))
        add(CreateToggle(scroll, "Box", "MobESPBox"))
        add(CreateToggle(scroll, "Name", "MobESPName"))
        add(CreateToggle(scroll, "Health Bar", "MobESPHealthBar"))
        add(CreateToggle(scroll, "Health Numbers", "MobESPHealthText"))
        add(CreateCycle(scroll, "Health Format", "MobESPHealthMode", {"fraction", "percent"}))
        add(CreateSlider(scroll, "Mob Distance", "MobESPMaxDistance", 100, 3000))

        y = y + 10
        add(CreateSection(scroll, "HITBOX EXPANDER"))
        add(CreateToggle(scroll, "Enable Hitbox", "HitboxEnabled"))
        add(CreateSlider(scroll, "Hitbox Size", "HitboxSize", 3, 30))
    end

    if tabName == "Resources" then
        add(CreateSection(scroll, "RESOURCE / CHEST ESP"))
        add(CreateToggle(scroll, "Enable", "ResourceESPEnabled"))
        add(CreateToggle(scroll, "Highlight", "ResourceESPHighlight"))
        add(CreateToggle(scroll, "Name", "ResourceESPName"))
        add(CreateToggle(scroll, "Distance", "ResourceESPDistance"))
        add(CreateToggle(scroll, "Chests", "ResourceESPChests"))
        add(CreateToggle(scroll, "Iron Ore / Iron Stone", "ResourceESPIron"))
        add(CreateToggle(scroll, "Normal Stone / Rock", "ResourceESPStone"))
        add(CreateToggle(scroll, "Tree / Wood", "ResourceESPWood"))
        add(CreateToggle(scroll, "Other Resources", "ResourceESPOther"))
        add(CreateSlider(scroll, "Resource Distance", "ResourceESPMaxDistance", 100, 5000, 50))

        y = y + 10
        add(CreateSection(scroll, "INSTANT LOOT / SMELTING"))
        add(CreateToggle(scroll, "Instant Chest Open", "InstantChestOpen"))
        add(CreateToggle(scroll, "Instant Furnace", "InstantFurnace"))
    end
    
    if tabName == "Aim" then
        add(CreateSection(scroll, "AIMBOT"))
        add(CreateToggle(scroll, "Enable Aimbot", "AimbotEnabled"))
        add(CreateToggle(scroll, "Auto Shoot", "AutoShoot"))
        add(CreateSlider(scroll, "FOV", "FOV", 50, 500))
        add(CreateSlider(scroll, "Max Distance", "AimbotMaxDistance", 50, 2000))
        add(CreateSlider(scroll, "Smoothing", "Smoothing", 0.01, 1, 0.01))
        
        y = y + 10
        add(CreateSection(scroll, "KILL AURA"))
        add(CreateToggle(scroll, "Enable Kill Aura", "KillAuraEnabled"))
        add(CreateSlider(scroll, "Range", "KillAuraRange", 10, 100))
        add(CreateSlider(scroll, "Max Targets", "KillAuraMaxTargets", 1, 10))
        
        y = y + 10
        add(CreateSection(scroll, "STEALTH"))
        add(CreateToggle(scroll, "Stealth Mode", "StealthMode"))
        add(CreateToggle(scroll, "Humanization", "HumanizationEnabled"))
        add(CreateSlider(scroll, "Miss Chance %", "MissChance", 0, 50))
        add(CreateToggle(scroll, "Random Mouse", "RandomMoveEnabled"))
    end
    
    if tabName == "Misc" then
        add(CreateSection(scroll, "PLAYER MODS"))
        add(CreateToggle(scroll, "Speed Hack", "SpeedEnabled"))
        add(CreateSlider(scroll, "Speed Value", "SpeedValue", 16, 100))
        add(CreateToggle(scroll, "Jump Power", "JumpEnabled"))
        add(CreateSlider(scroll, "Jump Value", "JumpValue", 50, 200))

        y = y + 10
        add(CreateSection(scroll, "MOVEMENT"))
        add(CreateToggle(scroll, "Fly (F)", "FlyEnabled"))
        add(CreateSlider(scroll, "Fly Speed", "FlySpeed", 10, 250, 5))
        add(CreateToggle(scroll, "Noclip (N)", "NoclipEnabled"))

        y = y + 10
        add(CreateSection(scroll, "INTERACTION"))
        add(CreateToggle(scroll, "Instant Interact (Doors & More)", "InstantInteractEnabled"))
    end

    if tabName == "Auto Farm" then
        add(CreateSection(scroll, "AUTO FARM"))
        add(CreateToggle(scroll, "Enable Auto Farm", "AutoFarm"))
        add(CreateToggle(scroll, "Move To Targets", "FarmMoveToTargets"))
        add(CreateToggle(scroll, "Collect Drops", "FarmCollectDrops"))
        add(CreateSlider(scroll, "Search Distance", "FarmRange", 100, 5000, 50))
        add(CreateSlider(scroll, "Farm Delay", "FarmDelay", 0.05, 1, 0.05))
        
        y = y + 5
        add(CreateSection(scroll, "RESOURCES"))
        add(CreateToggle(scroll, "Wood / Tree", "FarmWood"))
        add(CreateToggle(scroll, "Stone / Rock", "FarmStone"))
        add(CreateToggle(scroll, "Iron Ore", "FarmIronOre"))
        add(CreateToggle(scroll, "Berries", "FarmBerries"))
        add(CreateToggle(scroll, "Coconut", "FarmCoconut"))
        add(CreateToggle(scroll, "Chicken Feather", "FarmChickenFeather"))
        add(CreateToggle(scroll, "Bear Pelt", "FarmBearPelt"))
        add(CreateToggle(scroll, "Snake Tooth", "FarmSnakeTooth"))
        add(CreateToggle(scroll, "Spider Web", "FarmSpiderWeb"))
    end

    if tabName == "Survival" then
        add(CreateSection(scroll, "SURVIVAL"))
        add(CreateToggle(scroll, "Enable Survival", "AutoSurvival"))
        add(CreateToggle(scroll, "Hunt Chicken", "SurvivalHuntChicken"))
        add(CreateToggle(scroll, "Collect Meat", "SurvivalCollectMeat"))
        add(CreateToggle(scroll, "Collect Berries", "SurvivalCollectBerries"))
        add(CreateToggle(scroll, "Cook Raw Food", "SurvivalCookFood"))
        add(CreateToggle(scroll, "Auto Eat", "SurvivalAutoEat"))
        add(CreateSlider(scroll, "Eat Below %", "SurvivalEatThreshold", 10, 90, 5))
        add(CreateSlider(scroll, "Eat Until %", "SurvivalEatTarget", 60, 100, 5))
        add(CreateSlider(scroll, "Survival Search", "SurvivalSearchDistance", 100, 5000, 50))
        
        y = y + 10
        add(CreateSection(scroll, "NIGHT SURVIVAL"))
        add(CreateToggle(scroll, "Auto Fullbright at Night", "NightMode"))
    end
    
    scroll.CanvasSize = UDim2.new(0, 0, 0, y + 20)
end

local function CreateMenu()
    if MenuGui then MenuGui:Destroy() end
    
    MenuGui = Instance.new("ScreenGui")
    MenuGui.Name = "Config"
    MenuGui.ResetOnSpawn = false
    MenuGui.Parent = CoreGui
    MenuGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 560, 0, 440)
    MainFrame.Position = UDim2.new(0.5, -280, 0.5, -220)
    MainFrame.BackgroundColor3 = BG_DARK
    MainFrame.BorderSizePixel = 0
    MainFrame.Visible = false
    MainFrame.Active = true
    MainFrame.Draggable = false
    MainFrame.ClipsDescendants = true
    MainFrame.Parent = MenuGui
    AddCorner(MainFrame, 12)

    local mainGradient = Instance.new("UIGradient")
    mainGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(14, 16, 22)),
        ColorSequenceKeypoint.new(0.5, BG_DARK),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(3, 4, 6))
    })
    mainGradient.Rotation = 115
    mainGradient.Parent = MainFrame
    
    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = BLUE
    mainStroke.Thickness = 1.25
    mainStroke.Transparency = 0.12
    mainStroke.Parent = MainFrame
    
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 64)
    titleBar.BackgroundColor3 = BG_MID
    titleBar.BorderSizePixel = 0
    titleBar.Active = true
    titleBar.Parent = MainFrame
    AddCorner(titleBar, 12)

    local titleGradient = Instance.new("UIGradient")
    titleGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(31, 34, 42)),
        ColorSequenceKeypoint.new(0.38, Color3.fromRGB(13, 15, 20)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(6, 7, 10))
    })
    titleGradient.Rotation = 8
    titleGradient.Parent = titleBar

    local dragging = false
    local dragInput = nil
    local dragStart = nil
    local frameStart = nil
    TrackConnection(titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            frameStart = MainFrame.Position
            TrackConnection(input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end))
        end
    end))
    TrackConnection(titleBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end))
    TrackConnection(UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput and dragStart and frameStart then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(
                frameStart.X.Scale, frameStart.X.Offset + delta.X,
                frameStart.Y.Scale, frameStart.Y.Offset + delta.Y
            )
        end
    end))
    
    local coverRect = Instance.new("Frame")
    coverRect.Size = UDim2.new(1, 0, 0, 15)
    coverRect.Position = UDim2.new(0, 0, 1, -15)
    coverRect.BackgroundColor3 = BG_MID
    coverRect.BorderSizePixel = 0
    coverRect.Parent = titleBar
    
    local logoBg = Instance.new("Frame")
    logoBg.Size = UDim2.new(0, 52, 0, 52)
    logoBg.Position = UDim2.new(0, 8, 0.5, -26)
    logoBg.BackgroundColor3 = Color3.fromRGB(220, 226, 238)
    logoBg.BackgroundTransparency = 0.88
    logoBg.BorderSizePixel = 0
    logoBg.Parent = titleBar
    AddCorner(logoBg, 10)

    local logoStroke = Instance.new("UIStroke")
    logoStroke.Color = BLUE_GLOW
    logoStroke.Thickness = 1.3
    logoStroke.Transparency = 0.18
    logoStroke.Parent = logoBg

    local logoGradient = Instance.new("UIGradient")
    logoGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(81, 87, 101)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 235, 246))
    })
    logoGradient.Rotation = 135
    logoGradient.Parent = logoBg
    
    NihilityLogoImage = Instance.new("ImageLabel")
    NihilityLogoImage.Size = UDim2.new(1, -4, 1, -4)
    NihilityLogoImage.Position = UDim2.new(0, 2, 0, 2)
    NihilityLogoImage.BackgroundTransparency = 1
    NihilityLogoImage.Image = NIHILITY_LOGO_ASSET
    NihilityLogoImage.ScaleType = Enum.ScaleType.Fit
    NihilityLogoImage.Visible = NIHILITY_LOGO_ASSET ~= ""
    NihilityLogoImage.Parent = logoBg

    NihilityLogoFallback = Instance.new("TextLabel")
    NihilityLogoFallback.Size = UDim2.new(1, 0, 1, 0)
    NihilityLogoFallback.BackgroundTransparency = 1
    NihilityLogoFallback.Text = "N"
    NihilityLogoFallback.TextColor3 = BLUE_GLOW
    NihilityLogoFallback.TextSize = 24
    NihilityLogoFallback.Font = Enum.Font.GothamBold
    NihilityLogoFallback.Visible = NIHILITY_LOGO_ASSET == ""
    NihilityLogoFallback.Parent = logoBg
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.7, 0, 0.7, 0)
    title.Position = UDim2.new(0, 72, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "NIHILITY"
    title.TextColor3 = BLUE_GLOW
    title.TextSize = 17
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextYAlignment = Enum.TextYAlignment.Center
    title.Parent = titleBar
    
    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(0.7, 0, 0.3, 0)
    subtitle.Position = UDim2.new(0, 72, 0.64, 0)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "ISLAND ESCAPE / STEALTH v8.7"
    subtitle.TextColor3 = TEXT_DIM
    subtitle.TextSize = 9
    subtitle.Font = Enum.Font.GothamBold
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.Parent = titleBar
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -38, 0.5, -14)
    closeBtn.BackgroundColor3 = BG_LIGHT
    closeBtn.Text = "X"
    closeBtn.TextColor3 = TEXT
    closeBtn.TextSize = 14
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.BorderSizePixel = 0
    closeBtn.Parent = titleBar
    AddCorner(closeBtn, 6)
    
    closeBtn.Activated:Connect(function()
        MainFrame.Visible = false
        Settings.MenuOpen = false
    end)
    
    local tabBar = Instance.new("Frame")
    tabBar.Size = UDim2.new(0, 138, 1, -64)
    tabBar.Position = UDim2.new(0, 0, 0, 64)
    tabBar.BackgroundColor3 = BG_MID
    tabBar.BorderSizePixel = 0
    tabBar.Parent = MainFrame

    local tabGradient = Instance.new("UIGradient")
    tabGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(17, 19, 25)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(6, 7, 10))
    })
    tabGradient.Rotation = 90
    tabGradient.Parent = tabBar
    
    local accentLine = Instance.new("Frame")
    accentLine.Size = UDim2.new(0, 2, 1, 0)
    accentLine.Position = UDim2.new(1, -2, 0, 0)
    accentLine.BackgroundColor3 = BLUE
    accentLine.BorderSizePixel = 0
    accentLine.Parent = tabBar
    
    ContentFrame = Instance.new("Frame")
    ContentFrame.Size = UDim2.new(1, -158, 1, -94)
    ContentFrame.Position = UDim2.new(0, 148, 0, 74)
    ContentFrame.BackgroundTransparency = 1
    ContentFrame.Parent = MainFrame
    
    local tabs = {"ESP", "Aim", "Resources", "Auto Farm", "Survival", "Misc"}
    
    local tabBtns = {}
    local tabIndicator = Instance.new("Frame")
    tabIndicator.Size = UDim2.new(0, 3, 0, 40)
    tabIndicator.Position = UDim2.new(0, 0, 0, 15)
    tabIndicator.BackgroundColor3 = BLUE
    tabIndicator.BorderSizePixel = 0
    tabIndicator.Parent = tabBar
    AddCorner(tabIndicator, 2)
    
    local function selectTab(name)
        for n, b in pairs(tabBtns) do
            local active = n == name
            b.BackgroundColor3 = active and BLUE_DARK or Color3.fromRGB(0, 0, 0)
            b.BackgroundTransparency = active and 0 or 1
            b.TextColor3 = active and Color3.new(1, 1, 1) or TEXT_DIM
            if active then
                tabIndicator.Position = UDim2.new(0, 0, 0, b.Position.Y.Offset)
            end
        end
        RenderTab(name)
    end
    
    for i, tabName in ipairs(tabs) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -10, 0, 40)
        b.Position = UDim2.new(0, 5, 0, 10 + (i-1) * 50)
        b.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        b.BackgroundTransparency = 1
        b.Text = "   " .. tabName
        b.TextColor3 = TEXT_DIM
        b.TextSize = 14
        b.Font = Enum.Font.GothamBold
        b.BorderSizePixel = 0
        b.TextXAlignment = Enum.TextXAlignment.Left
        b.Parent = tabBar
        AddCorner(b, 6)
        tabBtns[tabName] = b
        
        b.Activated:Connect(function()
            selectTab(tabName)
        end)
    end

    local unloadBtn = Instance.new("TextButton")
    unloadBtn.Size = UDim2.new(1, -18, 0, 36)
    unloadBtn.Position = UDim2.new(0, 9, 1, -47)
    unloadBtn.BackgroundColor3 = Color3.fromRGB(58, 25, 31)
    unloadBtn.Text = "UNLOAD"
    unloadBtn.TextColor3 = Color3.fromRGB(255, 105, 120)
    unloadBtn.TextSize = 12
    unloadBtn.Font = Enum.Font.GothamBold
    unloadBtn.BorderSizePixel = 0
    unloadBtn.AutoButtonColor = false
    unloadBtn.Parent = tabBar
    AddCorner(unloadBtn, 7)

    local unloadStroke = Instance.new("UIStroke")
    unloadStroke.Color = Color3.fromRGB(130, 45, 58)
    unloadStroke.Thickness = 1
    unloadStroke.Parent = unloadBtn

    local unloadArmed = false
    local unloadConfirmation = 0
    unloadBtn.Activated:Connect(function()
        if unloadArmed then
            CleanupRuntime()
            return
        end

        unloadArmed = true
        unloadConfirmation = unloadConfirmation + 1
        local confirmation = unloadConfirmation
        unloadBtn.Text = "CLICK TO CONFIRM"
        unloadBtn.BackgroundColor3 = Color3.fromRGB(125, 32, 45)
        unloadBtn.TextColor3 = Color3.new(1, 1, 1)
        task.delay(3, function()
            if unloadBtn.Parent and unloadArmed and confirmation == unloadConfirmation then
                unloadArmed = false
                unloadBtn.Text = "UNLOAD"
                unloadBtn.BackgroundColor3 = Color3.fromRGB(58, 25, 31)
                unloadBtn.TextColor3 = Color3.fromRGB(255, 105, 120)
            end
        end)
    end)
    
    local footer = Instance.new("TextLabel")
    footer.Size = UDim2.new(1, -158, 0, 20)
    footer.Position = UDim2.new(0, 148, 1, -25)
    footer.BackgroundTransparency = 1
    footer.Text = "P = Menu | F = Fly | N = Noclip | K = Aura | H = Hitbox"
    footer.TextColor3 = TEXT_DIM
    footer.TextSize = 10
    footer.Font = Enum.Font.Gotham
    footer.TextXAlignment = Enum.TextXAlignment.Right
    footer.Parent = MainFrame
    
    selectTab("ESP")
end

local function ToggleMenu()
    if not MainFrame then CreateMenu() end
    Settings.MenuOpen = not Settings.MenuOpen
    MainFrame.Visible = Settings.MenuOpen
end

-- ========== ANTI-DETECTION ==========
local function SetupAntiDetection()
    pcall(function()
        local mt = getrawmetatable(game)
        if mt then
            local oldNamecall = mt.__namecall
            setreadonly(mt, false)
            mt.__namecall = newcclosure(function(self, ...)
                local method = getnamecallmethod()
                if method == "FindFirstChild" then
                    local name = ...
                    if name == "Config" then return nil end
                end
                return oldNamecall(self, ...)
            end)
            setreadonly(mt, true)
        end
    end)
end

-- ========== INIT ==========
print("Nihility Island Escape v8.7 loading...")

TrackConnection(LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    if Settings.NoclipEnabled then ApplyNoclip() end
    if Settings.FlyEnabled then
        StopFly()
        task.wait(0.1)
        StartFly()
    end
end))

task.spawn(function()
    for _, player in ipairs(Players:GetPlayers()) do
        if not RuntimeAlive then return end
        if player ~= LocalPlayer then CreatePlayerESP(player) end
        task.wait()
    end
end)

TrackConnection(Players.PlayerAdded:Connect(function(p)
    if p ~= LocalPlayer then
        task.wait(0.5)
        CreatePlayerESP(p)
    end
end))

TrackConnection(Players.PlayerRemoving:Connect(function(p)
    if PlayerESP[p] then
        pcall(function() PlayerESP[p].Box:Destroy() end)
        pcall(function() PlayerESP[p].NameTag:Destroy() end)
        PlayerESP[p] = nil
    end
end))

if Entities then
    TrackConnection(Entities.DescendantAdded:Connect(function(obj)
        if obj:IsA("Model") then
            task.wait(0.3)
            if IsMob(obj) then CreateMobESP(obj) end
        end
    end))
end

TrackConnection(Workspace.DescendantAdded:Connect(TrackFarmObject))
TrackConnection(Workspace.DescendantRemoving:Connect(UntrackFarmObject))
TrackConnection(PlayerGui.DescendantAdded:Connect(TrackTaskText))
TrackConnection(PlayerGui.DescendantRemoving:Connect(UntrackTaskText))
task.spawn(BuildFarmableCache)
task.spawn(BuildTaskTextCache)

task.spawn(function()
    task.wait(2)
    while RuntimeAlive do
        pcall(ScanMobs)
        task.wait(4)
    end
end)

TrackConnection(UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Settings.MenuKey then ToggleMenu() end
    
    if input.KeyCode == Enum.KeyCode.F then
        SetSetting("FlyEnabled", not Settings.FlyEnabled)
    end

    if input.KeyCode == Enum.KeyCode.N then
        SetSetting("NoclipEnabled", not Settings.NoclipEnabled)
    end
    
    if input.KeyCode == Enum.KeyCode.K then
        SetSetting("KillAuraEnabled", not Settings.KillAuraEnabled)
    end
    
    if input.KeyCode == Enum.KeyCode.H then
        SetSetting("HitboxEnabled", not Settings.HitboxEnabled)
    end
end))

-- ========== MAIN LOOP ==========
local frameCounter = 0
local espAccumulator = 0
local resourceEspAccumulator = 0
local LastRuntimeWarning = {}

local function SafeRun(name, callback)
    local ok, result = pcall(callback)
    if not ok and (not LastRuntimeWarning[name] or tick() - LastRuntimeWarning[name] > 5) then
        LastRuntimeWarning[name] = tick()
        warn(name .. " error: " .. tostring(result))
    end
    return ok and result or false
end

TrackConnection(RunService.Heartbeat:Connect(function(dt)
    frameCounter = frameCounter + 1
    SafeRun("Player mods", ApplyMods)

    -- Keep enabled movement features alive if the game replaces character physics objects.
    if Settings.FlyEnabled and (not FlyConnection or not FlyConnection.Connected) then
        SafeRun("Fly recovery", StartFly)
    end
    if Settings.NoclipEnabled and (not NoclipConnection or not NoclipConnection.Connected) then
        SafeRun("Noclip recovery", StartNoclip)
    end
    
    -- 30 Hz is visually smooth while avoiding needless per-frame UI work.
    espAccumulator = espAccumulator + dt
    if espAccumulator >= 1 / 30 then
        espAccumulator = 0
        SafeRun("Player ESP", UpdatePlayerESP)
        SafeRun("Mob ESP", UpdateMobESP)
    end

    -- Resource ESP needs far fewer updates than player/mob ESP.
    resourceEspAccumulator = resourceEspAccumulator + dt
    if resourceEspAccumulator >= 0.15 then
        resourceEspAccumulator = 0
        SafeRun("Resource ESP", UpdateResourceESP)
        if Settings.InstantFurnace then SafeRun("Instant furnace", TryInstantFurnace) end
    end
    
    -- Hitboxes (every 2 frames)
    if Settings.HitboxEnabled and frameCounter % 2 == 0 then
        SafeRun("Hitbox", function()
            for mob in pairs(MobESP) do
                if not HitboxCache[mob] then CreateHitbox(mob) end
            end
            UpdateHitboxes()
        end)
    end
    
    -- Kill Aura (has own timing)
    if Settings.KillAuraEnabled then SafeRun("Kill aura", KillAura) end
    
    -- Survival takes movement priority; farming resumes while survival is idle.
    local survivalBusy = false
    if Settings.AutoSurvival then survivalBusy = SafeRun("Survival", AutoSurvival) end
    if Settings.AutoFarm and not survivalBusy then SafeRun("Auto farm", AutoFarm) end
    
    -- Humanize (every 5 frames)
    if frameCounter % 5 == 0 then SafeRun("Humanization", HumanizeMouse) end
    
    -- Night mode (every 10 frames)
    if Settings.NightMode and frameCounter % 10 == 0 then SafeRun("Night mode", UpdateNightMode) end
    
    -- Aimbot (only when mouse held)
    if Settings.AimbotEnabled and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        local t = GetBestTarget()
        if t then SafeRun("Aimbot", function() AimAtTarget(t) end) end
    end
end))

CreateMenu()
SetupAntiDetection()

-- Load the embedded logo after the UI and controls are ready. The fallback is
-- visible immediately, while first-time decoding yields between small chunks.
task.spawn(function()
    task.wait()
    local asset = ResolveNihilityLogoAsset()
    if not RuntimeAlive or asset == "" then return end
    NIHILITY_LOGO_ASSET = asset
    if NihilityLogoImage and NihilityLogoImage.Parent then
        NihilityLogoImage.Image = asset
        NihilityLogoImage.Visible = true
    end
    if NihilityLogoFallback and NihilityLogoFallback.Parent then
        NihilityLogoFallback.Visible = false
    end
end)


