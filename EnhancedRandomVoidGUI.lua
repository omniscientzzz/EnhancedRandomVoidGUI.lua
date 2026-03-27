local fenv = getfenv()
fenv.require = function() end

-- [[ VOID x AEGIS V14.0: ABSOLUTE ZERO ]] --
-- 狀態：神權防禦模式 (God-Tier Anti-Manipulation)
-- 目標：反制 Resolver, Advanced Mimic, Server-Side Projectile Teleport
-- 原理：混沌隨機偏移、真·NaN 向量毒化、動畫引擎破壞

local RunService = game:GetService('RunService')
local Players = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')
local CoreGui = game:GetService('CoreGui')
local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- [ 系統狀態與常數 ]
-- ==========================================
local isActive = false
local connections = {}
local toggleKey = Enum.KeyCode.P

-- 真·NaN (Not a Number) 生成
-- 任何外掛嘗試將 NaN 帶入距離或軌跡公式，都會導致腳本錯誤 (Error)
local NaN = 0/0
local NaNVector = Vector3.new(NaN, NaN, NaN)

local function ClearConnections()
    for _, conn in pairs(connections) do
        if typeof(conn) == "RBXScriptConnection" then
            conn:Disconnect()
        end
    end
    table.clear(connections)
end

-- ==========================================
-- [ 終極警示 UI 建構 (V14 絕對零度版) ]
-- ==========================================
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'VoidAbsoluteZeroGUI'
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new('Frame')
MainFrame.Name = 'MainFrame'
MainFrame.Size = UDim2.new(0, 260, 0, 220)
MainFrame.Position = UDim2.new(0.85, -20, 0.75, -20)
MainFrame.BackgroundColor3 = Color3.fromRGB(5, 10, 20) -- 深邃冰冷色調
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true 
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new('UICorner', MainFrame)
MainCorner.CornerRadius = UDim.new(0, 6)

local MainStroke = Instance.new('UIStroke', MainFrame)
MainStroke.Color = Color3.fromRGB(0, 150, 255)
MainStroke.Thickness = 2

local TitleText = Instance.new('TextLabel', MainFrame)
TitleText.Size = UDim2.new(1, 0, 0, 30)
TitleText.BackgroundTransparency = 1
TitleText.Text = '❄ V14 ABSOLUTE ZERO'
TitleText.TextColor3 = Color3.fromRGB(0, 200, 255)
TitleText.TextSize = 16
TitleText.Font = Enum.Font.GothamBlack
TitleText.Parent = MainFrame

local StatusText = Instance.new('TextLabel', MainFrame)
StatusText.Size = UDim2.new(1, 0, 0, 20)
StatusText.Position = UDim2.new(0, 0, 0, 35)
StatusText.BackgroundTransparency = 1
StatusText.Text = 'SYSTEM OFFLINE'
StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusText.TextSize = 12
StatusText.Font = Enum.Font.GothamBold
StatusText.Parent = MainFrame

local ToggleBtn = Instance.new('TextButton', MainFrame)
ToggleBtn.Size = UDim2.new(0.8, 0, 0, 40)
ToggleBtn.Position = UDim2.new(0.1, 0, 0, 65)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(0, 50, 100)
ToggleBtn.Text = 'ENGAGE [P]'
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 15
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = MainFrame
Instance.new('UICorner', ToggleBtn).CornerRadius = UDim.new(0, 4)

local StatsText = Instance.new('TextLabel', MainFrame)
StatsText.Size = UDim2.new(1, 0, 0, 80)
StatsText.Position = UDim2.new(0, 0, 0, 120)
StatsText.BackgroundTransparency = 1
StatsText.Text = '[!] Chaos Jitter: Active\n[!] Velocity: 0/0 (NaN)\n[!] Rig Animator: Destroyed\n[!] Hitbox: Desynced'
StatsText.TextColor3 = Color3.fromRGB(100, 200, 255)
StatsText.TextSize = 11
StatsText.Font = Enum.Font.Code
StatsText.Parent = MainFrame

-- ==========================================
-- [ 引擎：絕對反制邏輯 ]
-- ==========================================
local function StartEngine()
    ClearConnections()

    local char = LocalPlayer.Character
    if not char then return end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    
    if not hrp or not hum then return end

    -- 【1. Hitbox 徹底隔離與動畫凍結】
    -- 外掛經常鎖定頭部或依賴動畫同步來預測位置。
    -- 我們直接摧毀 Animator，讓你在伺服器上變成一個不會動的僵硬模型，切斷動畫預測。
    -- 同時刪除所有飾品 (Accessories)，因為很多外掛會掃描飾品作為額外的判定點。
    pcall(function()
        local animator = hum:FindFirstChildOfClass("Animator")
        if animator then animator:Destroy() end
    end)

    for _, v in pairs(char:GetDescendants()) do
        if v:IsA("Accessory") or v:IsA("Tool") then
            pcall(function() v:Destroy() end)
        end
    end

    -- 半透明化與無碰撞處理
    for _, part in pairs(char:GetChildren()) do
        if part:IsA("BasePart") then
            pcall(function()
                part.CanCollide = false
                part.Massless = true
                part.Transparency = 0.5
            end)
        end
    end

    local RealPosition = hrp.CFrame

    -- 【2. 混沌震盪與真·虛無向量 (Chaos Jitter & True NaN)】
    -- 這是在 Heartbeat (物理模擬後，網路同步前) 執行的最核心破壞。
    connections.Heartbeat = RunService.Heartbeat:Connect(function()
        if not isActive then return end
        local currentHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not currentHrp then return end

        -- 記錄你真實操作的座標
        RealPosition = currentHrp.CFrame
        
        -- 生成極端混亂的隨機座標 (X, Y, Z 皆在十萬格範圍內亂跳)
        -- Resolver 根本無法預測完全隨機的數值，Mimic 傳送點會瞬間崩潰
        local chaosOffset = Vector3.new(
            math.random(-100000, 100000),
            math.random(50000, 150000), 
            math.random(-100000, 100000)
        )
        currentHrp.CFrame = RealPosition + chaosOffset

        -- 將速度設為 NaN (0/0)
        -- 當外掛讀取你的速度來計算「彈道提前量」或「傳送終點」時，
        -- NaN 會像病毒一樣感染他們的數學公式，導致外掛崩潰 (Math Error)
        currentHrp.AssemblyLinearVelocity = NaNVector
        currentHrp.AssemblyAngularVelocity = NaNVector
    end)
    
    -- 【3. 本機畫面與物理還原 (Client Stabilizer)】
    -- 在畫面渲染前，把你從混亂的虛空中拉回真實位置，讓你可以正常走動與瞄準。
    connections.RenderStepped = RunService.RenderStepped:Connect(function()
        if not isActive then return end
        local currentHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if currentHrp then
            currentHrp.CFrame = RealPosition
        end
    end)
end

local function StopEngine()
    ClearConnections()
    local char = LocalPlayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
            hrp.AssemblyAngularVelocity = Vector3.new(0,0,0)
        end
        for _, part in pairs(char:GetChildren()) do
            if part:IsA("BasePart") then
                part.Transparency = 0
            end
        end
    end
end

-- ==========================================
-- [ UI 互動邏輯 ]
-- ==========================================
local isHovering = false
local isDebouncing = false

local function UpdateUI()
    if isActive then
        StatusText.Text = '❄ OBLIVION: ABSOLUTE'
        StatusText.TextColor3 = Color3.fromRGB(0, 255, 255)
        MainStroke.Color = Color3.fromRGB(0, 255, 255)
        ToggleBtn.Text = 'DISENGAGE [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(0, 100, 200) or Color3.fromRGB(0, 150, 255)
    else
        StatusText.Text = 'SYSTEM OFFLINE'
        StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
        MainStroke.Color = Color3.fromRGB(0, 100, 150)
        ToggleBtn.Text = 'ENGAGE [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(0, 60, 120) or Color3.fromRGB(0, 50, 100)
    end
end

local function HandleToggle()
    if isDebouncing then return end
    isDebouncing = true
    isActive = not isActive
    UpdateUI()
    if isActive then StartEngine() else StopEngine() end
    task.wait(0.3)
    isDebouncing = false
end

ToggleBtn.MouseEnter:Connect(function() isHovering = true UpdateUI() end)
ToggleBtn.MouseLeave:Connect(function() isHovering = false UpdateUI() end)
ToggleBtn.MouseButton1Click:Connect(HandleToggle)

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if gameProcessedEvent then return end
    if input.KeyCode == toggleKey then HandleToggle() end
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.delay(1, function() if isActive then StartEngine() end end)
end)
