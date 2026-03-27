local fenv = getfenv()
fenv.require = function() end

-- [[ VOID x AEGIS V16.0: PHANTOM ]] --
-- 狀態：終極無敵 (Hitbox Nullification + Vertical Desync)
-- 核心：高空坐標分離 (50000 Studs) + 速度超載 (2e22) + 視覺平滑拉回

local Players = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')
local RunService = game:GetService('RunService')

local LocalPlayer = Players.LocalPlayer
local toggleKey = Enum.KeyCode.P

-- ==========================================
-- [ 核心常數 (V16 幽靈防禦機制) ]
-- ==========================================
local VERTICAL_OFFSET = 50000 -- 將真實 Hitbox 藏在 50000 單位的高空
local VELOCITY_OVERLOAD = 2e22 -- 保留 V15 破壞預測的機制
local isActive = false

local realCFrame = nil
local heartbeatConnection = nil
local renderConnection = nil

-- ==========================================
-- [ 終極警示 UI 建構 (V16 幽靈版) ]
-- ==========================================
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'VoidPhantomGUI'
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = game:GetService('CoreGui') end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new('Frame')
MainFrame.Name = 'MainFrame'
MainFrame.Size = UDim2.new(0, 240, 0, 200)
MainFrame.Position = UDim2.new(0.85, -20, 0.75, -20)
MainFrame.BackgroundColor3 = Color3.fromRGB(10, 15, 20) -- 幽靈深藍色調
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true 
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new('UICorner', MainFrame)
MainCorner.CornerRadius = UDim.new(0, 8)

local MainStroke = Instance.new('UIStroke', MainFrame)
MainStroke.Color = Color3.fromRGB(50, 150, 255)
MainStroke.Thickness = 2

local TitleText = Instance.new('TextLabel', MainFrame)
TitleText.Size = UDim2.new(1, 0, 0, 30)
TitleText.BackgroundTransparency = 1
TitleText.Text = '👻 V16 PHANTOM'
TitleText.TextColor3 = Color3.fromRGB(150, 200, 255)
TitleText.TextSize = 16
TitleText.Font = Enum.Font.GothamBlack
TitleText.Parent = MainFrame

local StatusText = Instance.new('TextLabel', MainFrame)
StatusText.Size = UDim2.new(1, 0, 0, 20)
StatusText.Position = UDim2.new(0, 0, 0, 35)
StatusText.BackgroundTransparency = 1
StatusText.Text = 'HITBOX: VULNERABLE'
StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusText.TextSize = 12
StatusText.Font = Enum.Font.GothamBold
StatusText.Parent = MainFrame

local ToggleBtn = Instance.new('TextButton', MainFrame)
ToggleBtn.Size = UDim2.new(0.8, 0, 0, 40)
ToggleBtn.Position = UDim2.new(0.1, 0, 0, 65)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(20, 60, 100)
ToggleBtn.Text = 'BECOME GHOST [P]'
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 15
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = MainFrame
Instance.new('UICorner', ToggleBtn).CornerRadius = UDim.new(0, 4)

local StatsText = Instance.new('TextLabel', MainFrame)
StatsText.Size = UDim2.new(1, 0, 0, 70)
StatsText.Position = UDim2.new(0, 0, 0, 115)
StatsText.BackgroundTransparency = 1
StatsText.Text = '[-] Hitbox: Y+50000 (Sky)\n[-] Anti-Web: Vertical Only\n[-] Prediction: Overloaded'
StatsText.TextColor3 = Color3.fromRGB(150, 180, 255)
StatsText.TextSize = 12
StatsText.Font = Enum.Font.Code
StatsText.Parent = MainFrame

-- ==========================================
-- [ 引擎：Hitbox 靈魂出竅 (Phantom Desync) ]
-- ==========================================
local function StartDesync()
    local char = LocalPlayer.Character
    if not char then return end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then return end

    hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)

    -- [核心1: 伺服器端欺騙] (Heartbeat 在物理計算之後，同步給伺服器之前)
    heartbeatConnection = RunService.Heartbeat:Connect(function()
        if not isActive then return end
        local currentHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if currentHrp then
            -- 1. 記錄你在地面上的真實位置
            realCFrame = currentHrp.CFrame
            
            -- 2. 產生微小的隨機偏移 (恢復 V13 的混亂感，但限制在極小範圍，防止產生拉扯網)
            local chaosX = math.random(-5, 5)
            local chaosZ = math.random(-5, 5)
            
            -- 3. 瘋狂隨機旋轉角度 (Anti-Aim)，防止高空 Hitbox 被爆頭
            local randomAngle = CFrame.Angles(
                math.rad(math.random(-360, 360)), 
                math.rad(math.random(-360, 360)), 
                math.rad(math.random(-360, 360))
            )

            -- 4. 瞬間將 Hitbox 送往 50000 單位的高空
            currentHrp.CFrame = (realCFrame + Vector3.new(chaosX, VERTICAL_OFFSET, chaosZ)) * randomAngle
            
            -- 5. 注入極端速度，讓對方的預測自瞄徹底崩潰
            currentHrp.AssemblyLinearVelocity = Vector3.new(VELOCITY_OVERLOAD, VELOCITY_OVERLOAD, VELOCITY_OVERLOAD)
            currentHrp.AssemblyAngularVelocity = Vector3.new(VELOCITY_OVERLOAD, VELOCITY_OVERLOAD, VELOCITY_OVERLOAD)
        end
    end)

    -- [核心2: 客戶端平滑] (RenderStepped 在畫面渲染之前)
    renderConnection = RunService.RenderStepped:Connect(function()
        if not isActive then return end
        local currentHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if currentHrp and realCFrame then
            -- 在畫面繪製前，瞬間將你的視角和位置拉回地面。
            -- 這樣你依然可以正常行走、開槍，但你在伺服器眼裡已經在平流層了。
            currentHrp.CFrame = realCFrame
        end
    end)
end

local function StopDesync()
    if heartbeatConnection then heartbeatConnection:Disconnect() end
    if renderConnection then renderConnection:Disconnect() end
    
    local char = LocalPlayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp and realCFrame then
            -- 關閉時安全降落回地面
            hrp.CFrame = realCFrame
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
        StatusText.Text = '👻 HITBOX: UNTOUCHABLE'
        StatusText.TextColor3 = Color3.fromRGB(50, 255, 150)
        MainStroke.Color = Color3.fromRGB(50, 255, 150)
        ToggleBtn.Text = 'REVERT [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(0, 150, 100) or Color3.fromRGB(0, 180, 120)
    else
        StatusText.Text = 'HITBOX: VULNERABLE'
        StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
        MainStroke.Color = Color3.fromRGB(50, 150, 255)
        ToggleBtn.Text = 'BECOME GHOST [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(30, 80, 130) or Color3.fromRGB(20, 60, 100)
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
