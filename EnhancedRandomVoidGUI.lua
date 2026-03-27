local fenv = getfenv()
fenv.require = function() end

-- [[ VOID x AEGIS V13.0: OBLIVION (ANTI-MANIPULATION) ]] --
-- 狀態：極端防禦模式
-- 目標：反制 Projectile Manipulation, Bullet Mimic, Hitbox Teleport
-- 原理：CFrame 空間剝離、NaN 數據毒化、Hitbox 徹底消除

local RunService = game:GetService('RunService')
local Players = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')
local CoreGui = game:GetService('CoreGui')
local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- [ 系統狀態 ]
-- ==========================================
local isActive = false
local connections = {}
local toggleKey = Enum.KeyCode.P

local function ClearConnections()
    for _, conn in pairs(connections) do
        if typeof(conn) == "RBXScriptConnection" then
            conn:Disconnect()
        end
    end
    table.clear(connections)
end

-- ==========================================
-- [ 終極警示 UI 建構 ]
-- ==========================================
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'VoidOblivionGUI'
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new('Frame')
MainFrame.Name = 'MainFrame'
MainFrame.Size = UDim2.new(0, 250, 0, 200)
MainFrame.Position = UDim2.new(0.85, -10, 0.75, -10)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 0, 5) -- 深邃的血紅色背景
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true 
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new('UICorner', MainFrame)
MainCorner.CornerRadius = UDim.new(0, 6)

local MainStroke = Instance.new('UIStroke', MainFrame)
MainStroke.Color = Color3.fromRGB(255, 30, 30)
MainStroke.Thickness = 2

local TitleText = Instance.new('TextLabel', MainFrame)
TitleText.Size = UDim2.new(1, 0, 0, 30)
TitleText.BackgroundTransparency = 1
TitleText.Text = '☢ V13 OBLIVION'
TitleText.TextColor3 = Color3.fromRGB(255, 50, 50)
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
ToggleBtn.BackgroundColor3 = Color3.fromRGB(100, 0, 0)
ToggleBtn.Text = 'ENGAGE [P]'
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 15
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = MainFrame
Instance.new('UICorner', ToggleBtn).CornerRadius = UDim.new(0, 4)

local StatsText = Instance.new('TextLabel', MainFrame)
StatsText.Size = UDim2.new(1, 0, 0, 60)
StatsText.Position = UDim2.new(0, 0, 0, 120)
StatsText.BackgroundTransparency = 1
StatsText.Text = '[!] CFrame Offset: Active\n[!] Math Overload: 9e9 (Toxic)\n[!] Rig Disconnect: True'
StatsText.TextColor3 = Color3.fromRGB(255, 100, 100)
StatsText.TextSize = 11
StatsText.Font = Enum.Font.Code
StatsText.Parent = MainFrame

-- ==========================================
-- [ 引擎：反操縱核心邏輯 ]
-- ==========================================
local function StartEngine()
    ClearConnections()

    local char = LocalPlayer.Character
    if not char then return end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    local hum = char:FindFirstChild("Humanoid")
    
    if not hrp or not hum then return end

    -- 【1. Hitbox 徹底毀滅 (Rig Destruction)】
    -- Projectile Manipulation 需要實體來判定擊中。
    -- 我們不僅縮小頭部，還把所有除了 HRP 以外的身體部位的碰撞與重量歸零，
    -- 甚至破壞部分外觀關聯，讓伺服器無法正確計算子彈與 Hitbox 的交集。
    for _, part in pairs(char:GetChildren()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            pcall(function()
                part.CanCollide = false
                part.Massless = true
                -- 將體積壓縮到微觀級別
                part.Size = Vector3.new(0.01, 0.01, 0.01) 
                part.Transparency = 0.5 -- 半透明化以利自己觀察
            end)
        end
    end

    local RealPosition = hrp.CFrame
    local SpoofOffset = Vector3.new(0, 99999, 0) -- 將伺服器判定點移至 10 萬格高的虛空

    -- 【2. 空間剝離 (Quantum CFrame Offset)】
    -- 這是對抗 Mimic / Projectile Teleport 最有效的手段。
    -- 我們在物理運算前 (Heartbeat) 將角色傳送到十萬格高的天空。
    -- 這樣對方的外掛讀取你的座標時，會讀到天空中的座標，並把子彈傳送到天空。
    connections.Heartbeat = RunService.Heartbeat:Connect(function()
        if not isActive then return end
        local currentHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not currentHrp then return end

        -- 記錄你真實想去的位置
        RealPosition = currentHrp.CFrame
        
        -- 將伺服器上的 HRP 丟到虛空，讓外掛把子彈打向虛空
        currentHrp.CFrame = RealPosition + SpoofOffset

        -- 【3. 數據毒化 (Math Overload / NaN Venom)】
        -- 故意將速度設為 Roblox 引擎容許的極大值 (9e9 或無窮大)。
        -- 高階外掛在計算 Manipulation 軌跡時，通常會用到 Vector3 數學。
        -- 當他們把這個巨大的數字代入公式時，會引發 Lua 腳本中的 "NaN (Not a Number)" 錯誤，
        -- 這有極高機率讓對方的外掛直接當機 (Crash) 或射出無效的射線。
        currentHrp.AssemblyLinearVelocity = Vector3.new(9e9, 9e9, 9e9)
        currentHrp.AssemblyAngularVelocity = Vector3.new(9e9, 9e9, 9e9)
    end)
    
    -- 【4. 本機視覺還原 (Client Rendering Hook)】
    -- 如果我們只在 Heartbeat 改變位置，你的畫面會一直卡在天空。
    -- 必須在畫面渲染前 (RenderStepped)，把你的角色「拉回來」，讓你可以正常遊玩。
    -- (伺服器依然會認為你在天空，但你的客戶端畫面看起來在地上)
    connections.RenderStepped = RunService.RenderStepped:Connect(function()
        if not isActive then return end
        local currentHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if currentHrp then
            -- 在畫面上把角色拉回真正的地面位置
            currentHrp.CFrame = RealPosition
        end
    end)
end

local function StopEngine()
    ClearConnections()
    local char = LocalPlayer.Character
    if char then
        -- 嘗試恢復原本的物理狀態 (需重生才能完全恢復外觀)
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
        StatusText.Text = '☢ OBLIVION ACTIVE'
        StatusText.TextColor3 = Color3.fromRGB(255, 50, 50)
        MainStroke.Color = Color3.fromRGB(255, 10, 10)
        ToggleBtn.Text = 'DISENGAGE [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(150, 0, 0) or Color3.fromRGB(200, 0, 0)
    else
        StatusText.Text = 'SYSTEM OFFLINE'
        StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
        MainStroke.Color = Color3.fromRGB(100, 0, 0)
        ToggleBtn.Text = 'ENGAGE [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(120, 0, 0) or Color3.fromRGB(100, 0, 0)
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
