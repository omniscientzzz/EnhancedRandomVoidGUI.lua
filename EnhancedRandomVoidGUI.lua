local fenv = getfenv()
fenv.require = function() end

-- [[ VOID x AEGIS V15.0: SINGULARITY ]] --
-- 狀態：浮點數溢位防禦 (Velocity Desync / Float Overflow)
-- 核心：2e22 速度去同步、微小座標震盪 (0.00001) 阻斷插值

local Players = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')
local RunService = game:GetService('RunService')

local LocalPlayer = Players.LocalPlayer
local toggleKey = Enum.KeyCode.P

-- ==========================================
-- [ 核心常數 (來自頂級 Desync 邏輯) ]
-- ==========================================
local OVERLOAD_VAL = 2e22 -- 足以讓任何預測自瞄 (Prediction Aimbot) 計算出 Infinity 而崩潰的值
local MICRO_OFFSET = 0.00001 -- 強制伺服器更新狀態，但不影響視覺的微小震盪

local isActive = false
local heartbeatConnection = nil
local renderConnection = nil

-- ==========================================
-- [ 終極警示 UI 建構 (V15 奇點版) ]
-- ==========================================
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'VoidSingularityGUI'
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = game:GetService('CoreGui') end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new('Frame')
MainFrame.Name = 'MainFrame'
MainFrame.Size = UDim2.new(0, 240, 0, 200)
MainFrame.Position = UDim2.new(0.85, -20, 0.75, -20)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 10, 25) -- 虛空紫暗色調
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true 
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new('UICorner', MainFrame)
MainCorner.CornerRadius = UDim.new(0, 8)

local MainStroke = Instance.new('UIStroke', MainFrame)
MainStroke.Color = Color3.fromRGB(150, 50, 255)
MainStroke.Thickness = 2

local TitleText = Instance.new('TextLabel', MainFrame)
TitleText.Size = UDim2.new(1, 0, 0, 30)
TitleText.BackgroundTransparency = 1
TitleText.Text = '⚛ V15 SINGULARITY'
TitleText.TextColor3 = Color3.fromRGB(200, 150, 255)
TitleText.TextSize = 16
TitleText.Font = Enum.Font.GothamBlack
TitleText.Parent = MainFrame

local StatusText = Instance.new('TextLabel', MainFrame)
StatusText.Size = UDim2.new(1, 0, 0, 20)
StatusText.Position = UDim2.new(0, 0, 0, 35)
StatusText.BackgroundTransparency = 1
StatusText.Text = 'DESYNC: INACTIVE'
StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusText.TextSize = 12
StatusText.Font = Enum.Font.GothamBold
StatusText.Parent = MainFrame

local ToggleBtn = Instance.new('TextButton', MainFrame)
ToggleBtn.Size = UDim2.new(0.8, 0, 0, 40)
ToggleBtn.Position = UDim2.new(0.1, 0, 0, 65)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(60, 20, 100)
ToggleBtn.Text = 'ENGAGE [P]'
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 15
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = MainFrame
Instance.new('UICorner', ToggleBtn).CornerRadius = UDim.new(0, 4)

local StatsText = Instance.new('TextLabel', MainFrame)
StatsText.Size = UDim2.new(1, 0, 0, 70)
StatsText.Position = UDim2.new(0, 0, 0, 115)
StatsText.BackgroundTransparency = 1
StatsText.Text = '[-] Target Vel: 2e22\n[-] Sync Offset: 0.00001\n[-] Prediction: Overloaded'
StatsText.TextColor3 = Color3.fromRGB(180, 150, 255)
StatsText.TextSize = 12
StatsText.Font = Enum.Font.Code
StatsText.Parent = MainFrame

-- ==========================================
-- [ 引擎：Velocity Desync (速度去同步) ]
-- ==========================================
local function StartDesync()
    local char = LocalPlayer.Character
    if not char then return end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then return end

    -- 防止極端速度導致角色跌倒或布娃娃狀態
    hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)

    -- [核心防禦] 伺服器端速度欺騙 (Heartbeat 在物理計算前執行)
    -- 我們向伺服器發送極端巨大的速度 (2e22)，這會直接讓所有預測自瞄 (Prediction) 
    -- 計算出的未來位置變成 Infinity，導致對方的子彈打向地圖邊界。
    heartbeatConnection = RunService.Heartbeat:Connect(function()
        if not isActive then return end
        local currentHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if currentHrp then
            -- 1. 注入毀滅性的物理向量
            currentHrp.AssemblyLinearVelocity = Vector3.new(OVERLOAD_VAL, OVERLOAD_VAL, OVERLOAD_VAL)
            currentHrp.AssemblyAngularVelocity = Vector3.new(OVERLOAD_VAL, OVERLOAD_VAL, OVERLOAD_VAL)
            
            -- 2. 微小座標震盪 (利用 0.00001 強制伺服器接受這個假速度，不讓它休眠)
            currentHrp.CFrame = currentHrp.CFrame * CFrame.new(0, MICRO_OFFSET, 0)
        end
    end)

    -- [本機穩定器] 用戶端視覺修正 (RenderStepped 在畫面渲染前執行)
    -- 為了不讓你自己真的飛到宇宙邊緣，我們在畫面渲染前，瞬間把速度歸零。
    -- 這樣你在自己畫面上能正常走路，但在伺服器眼裡，你是一顆以 2e22 速度移動的超光速粒子。
    renderConnection = RunService.RenderStepped:Connect(function()
        if not isActive then return end
        local currentHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if currentHrp then
            currentHrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            currentHrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end
    end)
end

local function StopDesync()
    if heartbeatConnection then heartbeatConnection:Disconnect() end
    if renderConnection then renderConnection:Disconnect() end
    
    local char = LocalPlayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end
    end
end

-- ==========================================
-- [ UI 與控制邏輯 ]
-- ==========================================
local isHovering = false

local function UpdateUI()
    if isActive then
        StatusText.Text = '⚛ OVERLOAD: ACTIVE'
        StatusText.TextColor3 = Color3.fromRGB(255, 50, 255)
        MainStroke.Color = Color3.fromRGB(255, 50, 255)
        ToggleBtn.Text = 'DISENGAGE [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(150, 0, 200) or Color3.fromRGB(180, 0, 255)
    else
        StatusText.Text = 'DESYNC: INACTIVE'
        StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
        MainStroke.Color = Color3.fromRGB(150, 50, 255)
        ToggleBtn.Text = 'ENGAGE [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(80, 30, 130) or Color3.fromRGB(60, 20, 100)
    end
end

local function ToggleSystem()
    isActive = not isActive
    UpdateUI()
    if isActive then StartDesync() else StopDesync() end
end

ToggleBtn.MouseEnter:Connect(function() isHovering = true UpdateUI() end)
ToggleBtn.MouseLeave:Connect(function() isHovering = false UpdateUI() end)
ToggleBtn.MouseButton1Click:Connect(ToggleSystem)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == toggleKey then
        ToggleSystem()
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    if isActive then
        task.wait(0.5)
        StartDesync()
    end
end)
