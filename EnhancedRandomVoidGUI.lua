local fenv = getfenv()
fenv.require = function() end

-- [[ VOID x AEGIS V40: IMMORTAL (不朽・極限自癒與狀態欺騙) ]] --
-- 終極對策：針對「無視距離、直接扣血」的 Remote Event 濫用。
-- 核心 1：Auto-Heal Loop (極限自癒) - 在血量低於 100 的瞬間，強制鎖定回滿。
-- 核心 2：State Spoofing (狀態欺騙) - 欺騙本地端與部分外掛，假裝你已經處於「死亡」狀態。
-- 核心 3：Forcefield Spam (護盾濫發) - 瘋狂生成官方無敵護盾，觸發潛在的無敵幀。

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')

local LocalPlayer = Players.LocalPlayer
local toggleKey = Enum.KeyCode.P

local isActive = false
local connections = {}

-- ==========================================
-- [ GUI 建構 (不朽 - 聖潔白金) ]
-- ==========================================
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'AegisV40GUI'
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = game:GetService('CoreGui') end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new('Frame')
MainFrame.Name = 'MainFrame'
MainFrame.Size = UDim2.new(0, 360, 0, 360)
MainFrame.Position = UDim2.new(0.85, -60, 0.75, -130)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true 
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new('UICorner', MainFrame)
MainCorner.CornerRadius = UDim.new(0, 6)

local MainStroke = Instance.new('UIStroke', MainFrame)
MainStroke.Color = Color3.fromRGB(255, 255, 200)
MainStroke.Thickness = 2

local TitleText = Instance.new('TextLabel', MainFrame)
TitleText.Size = UDim2.new(1, 0, 0, 30)
TitleText.BackgroundTransparency = 1
TitleText.Text = '👑 V40 WRAITH (IMMORTAL)'
TitleText.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleText.TextSize = 15
TitleText.Font = Enum.Font.GothamBlack
TitleText.Parent = MainFrame

local StatusText = Instance.new('TextLabel', MainFrame)
StatusText.Size = UDim2.new(1, 0, 0, 20)
StatusText.Position = UDim2.new(0, 0, 0, 35)
StatusText.BackgroundTransparency = 1
StatusText.Text = 'IMMORTAL MODE: DISABLED'
StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusText.TextSize = 12
StatusText.Font = Enum.Font.GothamBold
StatusText.Parent = MainFrame

local ToggleBtn = Instance.new('TextButton', MainFrame)
ToggleBtn.Size = UDim2.new(0.8, 0, 0, 40)
ToggleBtn.Position = UDim2.new(0.1, 0, 0, 65)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 40)
ToggleBtn.Text = 'ENGAGE IMMORTALITY [P]'
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 14
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = MainFrame
Instance.new('UICorner', ToggleBtn).CornerRadius = UDim.new(0, 4)

local StatsText = Instance.new('TextLabel', MainFrame)
StatsText.Size = UDim2.new(1, 0, 0, 230)
StatsText.Position = UDim2.new(0.1, 0, 0, 115)
StatsText.BackgroundTransparency = 1
StatsText.Text = '[✓] Extreme Auto-Heal Loop (Client-Side)\n[✓] State Spoofing (Fake Death)\n[✓] Forcefield Spamming\n[!] Warning: Server Override Possible\n\nAbandoning physical defense. We now\nforce your health to maximum on every\nsingle frame and spoof your state to\nconfuse enemy targeting scripts.'
StatsText.TextColor3 = Color3.fromRGB(255, 255, 220)
StatsText.TextSize = 11
StatsText.TextXAlignment = Enum.TextXAlignment.Left
StatsText.Font = Enum.Font.Code
StatsText.Parent = MainFrame

-- ==========================================
-- [ 核心 1：極限自癒與狀態欺騙 (Immortal Loop) ]
-- ==========================================
local function InitiateImmortality()
    local char = LocalPlayer.Character
    if not char then return end
    
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    -- 啟動極限迴圈
    local renderConn = RunService.RenderStepped:Connect(function()
        if not isActive then return end
        
        -- 1. 極限自癒 (如果伺服器允許客戶端修改血量，這將會讓你無敵)
        if hum.Health > 0 and hum.Health < hum.MaxHealth then
            pcall(function()
                hum.Health = hum.MaxHealth
            end)
        end

        -- 2. 狀態欺騙 (State Spoofing)
        -- 讓你的角色在本地端處於「死亡」狀態 (State 15) 或「物理癱瘓」狀態
        -- 許多粗劣的外掛在掃描目標時，如果發現目標 State == Dead，就會跳過不打
        pcall(function()
            hum:ChangeState(Enum.HumanoidStateType.Dead) 
            -- 注意：這可能會導致你自己的視角或動作變得很奇怪，但為了活命必須妥協
        end)

        -- 3. 護盾濫發 (Forcefield Spam)
        -- 持續生成官方護盾，試圖觸發遊戲內置的重生無敵幀
        if not char:FindFirstChild("ImmortalForceField") then
            local ff = Instance.new("ForceField")
            ff.Name = "ImmortalForceField"
            ff.Visible = false
            ff.Parent = char
        end
    end)
    table.insert(connections, renderConn)

    -- 監聽血量變化事件，一旦扣血瞬間補滿 (比 RenderStepped 更即時)
    local healthConn = hum.HealthChanged:Connect(function(health)
        if isActive and health > 0 and health < hum.MaxHealth then
            pcall(function()
                hum.Health = hum.MaxHealth
            end)
        end
    end)
    table.insert(connections, healthConn)
end

-- ==========================================
-- [ 系統生命週期控制 ]
-- ==========================================
local function StartImmortality()
    local char = LocalPlayer.Character
    if char then
        InitiateImmortality()
    end
end

local function StopImmortality()
    for _, conn in ipairs(connections) do
        conn:Disconnect()
    end
    connections = {}
    
    local char = LocalPlayer.Character
    if char then
        local ff = char:FindFirstChild("ImmortalForceField")
        if ff then ff:Destroy() end
        
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function()
                hum:ChangeState(Enum.HumanoidStateType.Running) -- 試圖恢復正常狀態
            end)
        end
    end
end

-- ==========================================
-- [ UI 與控制邏輯 ]
-- ==========================================
local isHovering = false

local function UpdateUI()
    if isActive then
        StatusText.Text = 'IMMORTAL MODE: ACTIVE'
        StatusText.TextColor3 = Color3.fromRGB(255, 255, 200)
        MainStroke.Color = Color3.fromRGB(255, 255, 200)
        ToggleBtn.Text = 'DISENGAGE [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(100, 100, 80) or Color3.fromRGB(80, 80, 60)
    else
        StatusText.Text = 'IMMORTAL MODE: DISABLED'
        StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
        MainStroke.Color = Color3.fromRGB(100, 100, 100)
        ToggleBtn.Text = 'ENGAGE IMMORTALITY [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(70, 70, 60) or Color3.fromRGB(50, 50, 40)
    end
end

local function ToggleSystem()
    isActive = not isActive
    UpdateUI()
    if isActive then StartImmortality() else StopImmortality() end
end

ToggleBtn.MouseEnter:Connect(function() isHovering = true UpdateUI() end)
ToggleBtn.MouseLeave:Connect(function() isHovering = false UpdateUI() end)
ToggleBtn.MouseButton1Click:Connect(ToggleSystem)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == toggleKey then
        ToggleSystem()
    end
end)

LocalPlayer.CharacterAdded:Connect(function(newChar)
    if isActive then
        newChar:WaitForChild("Humanoid")
        InitiateImmortality()
    end
end)

