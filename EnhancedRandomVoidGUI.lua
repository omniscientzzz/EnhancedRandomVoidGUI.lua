local fenv = getfenv()
fenv.require = function() end

-- [ 初始化隨機數種子 ] --
math.randomseed(os.time())

-- [ 核心服務 ] --
local RunService = game:GetService('RunService')
local Players = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')
local LocalPlayer = Players.LocalPlayer

-- [ 狀態變數 ] --
local isActive = false
local teleportCount = 0
local teleportConnection = nil

local toggles = {
    AbsoluteMass = false,
    Untouchable = false,
    AntiBring = false,
    AntiFling = false,
    Noclip = false
}
local connections = {}
local originalPhysicalProperties = {}

-- [ 輔助函數 ] --
local function GetHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild('HumanoidRootPart')
end

local function GetHum()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild('Humanoid')
end

-- 產生極度遙遠且不可預測的座標偏移量 (強化版 Void TP)
local function GetRandomVoidOffset()
    local randX = (math.random() - 0.5) * 20000000000
    local randY = (math.random() - 0.5) * 20000000000 
    local randZ = (math.random() - 0.5) * 20000000000
    return Vector3.new(randX, randY, randZ)
end

-- ==========================================
-- [ GUI 介面設計 - 經典融合版 ]
-- ==========================================
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'UltimateVoidGUI'
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new('Frame')
MainFrame.Name = 'MainFrame'
MainFrame.Size = UDim2.new(0, 230, 0, 420)
MainFrame.Position = UDim2.new(1, -250, 1, -440)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new('UICorner')
UICorner.CornerRadius = UDim.new(0, 12)
UICorner.Parent = MainFrame

local UIStroke = Instance.new('UIStroke')
UIStroke.Color = Color3.fromRGB(120, 40, 255)
UIStroke.Thickness = 2
UIStroke.Parent = MainFrame

-- [ 頂部標題列 ]
local TopBar = Instance.new('Frame')
TopBar.Size = UDim2.new(1, 0, 0, 44)
TopBar.BackgroundColor3 = Color3.fromRGB(30, 20, 60)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame
Instance.new('UICorner', TopBar).CornerRadius = UDim.new(0, 12)

local TopBarFix = Instance.new('Frame')
TopBarFix.Size = UDim2.new(1, 0, 0, 16)
TopBarFix.Position = UDim2.new(0, 0, 1, -16)
TopBarFix.BackgroundColor3 = Color3.fromRGB(30, 20, 60)
TopBarFix.BorderSizePixel = 0
TopBarFix.Parent = TopBar

local Title = Instance.new('TextLabel')
Title.Size = UDim2.new(1, -16, 1, 0)
Title.Position = UDim2.new(0, 14, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = '⚡ VOID + AEGIS'
Title.TextColor3 = Color3.fromRGB(200, 180, 255)
Title.TextSize = 15
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar

-- ==========================================
-- [ 上半部：經典 Void TP 區塊 ]
-- ==========================================
local StatusLabel = Instance.new('TextLabel')
StatusLabel.Size = UDim2.new(1, -20, 0, 28)
StatusLabel.Position = UDim2.new(0, 10, 0, 50)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = '● IDLE'
StatusLabel.TextColor3 = Color3.fromRGB(120, 120, 140)
StatusLabel.TextSize = 13
StatusLabel.Font = Enum.Font.GothamBold
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Parent = MainFrame

local ToggleButton = Instance.new('TextButton')
ToggleButton.Size = UDim2.new(1, -20, 0, 54)
ToggleButton.Position = UDim2.new(0, 10, 0, 80)
ToggleButton.BackgroundColor3 = Color3.fromRGB(70, 40, 160)
ToggleButton.BorderSizePixel = 0
ToggleButton.Text = 'START'
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.TextSize = 17
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.Parent = MainFrame
Instance.new('UICorner', ToggleButton).CornerRadius = UDim.new(0, 10)

local CountLabel = Instance.new('TextLabel')
CountLabel.Size = UDim2.new(1, -20, 0, 22)
CountLabel.Position = UDim2.new(0, 10, 0, 138)
CountLabel.BackgroundTransparency = 1
CountLabel.Text = 'Teleports: 0'
CountLabel.TextColor3 = Color3.fromRGB(100, 100, 120)
CountLabel.TextSize = 12
CountLabel.Font = Enum.Font.Gotham
CountLabel.TextXAlignment = Enum.TextXAlignment.Left
CountLabel.Parent = MainFrame

local Divider = Instance.new('Frame')
Divider.Size = UDim2.new(1, -20, 0, 2)
Divider.Position = UDim2.new(0, 10, 0, 165)
Divider.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
Divider.BorderSizePixel = 0
Divider.Parent = MainFrame

-- ==========================================
-- [ 下半部：極致物理防禦區塊 ]
-- ==========================================
local Container = Instance.new('ScrollingFrame', MainFrame)
Container.Size = UDim2.new(1, -20, 1, -180)
Container.Position = UDim2.new(0, 10, 0, 175)
Container.BackgroundTransparency = 1
Container.ScrollBarThickness = 2
Container.ScrollBarImageColor3 = Color3.fromRGB(120, 40, 255)
Container.UIListLayout = Instance.new('UIListLayout', Container)
Container.UIListLayout.Padding = UDim.new(0, 6)
Container.UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder

local function CreateDefButton(text, colorOff, colorOn, callback)
    local btn = Instance.new('TextButton')
    btn.Size = UDim2.new(1, 0, 0, 32)
    btn.BackgroundColor3 = colorOff
    btn.Text = text .. ' [OFF]'
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    Instance.new('UICorner', btn).CornerRadius = UDim.new(0, 4)
    btn.Parent = Container
    
    local isOn = false
    btn.Activated:Connect(function()
        isOn = not isOn
        if isOn then
            btn.BackgroundColor3 = colorOn
            btn.Text = text .. ' [ON]'
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            btn.BackgroundColor3 = colorOff
            btn.Text = text .. ' [OFF]'
            btn.TextColor3 = Color3.fromRGB(200, 200, 200)
        end
        callback(isOn, btn)
    end)
    return btn
end

-- ==========================================
-- [ 邏輯區：Void TP ]
-- ==========================================
local function UpdateUI()
    if isActive then
        StatusLabel.Text = '● ACTIVE'
        StatusLabel.TextColor3 = Color3.fromRGB(120, 255, 160)
        ToggleButton.Text = 'STOP'
        ToggleButton.BackgroundColor3 = Color3.fromRGB(160, 40, 60)
    else
        StatusLabel.Text = '● IDLE'
        StatusLabel.TextColor3 = Color3.fromRGB(120, 120, 140)
        ToggleButton.Text = 'START'
        ToggleButton.BackgroundColor3 = Color3.fromRGB(70, 40, 160)
    end
    CountLabel.Text = 'Teleports: ' .. teleportCount
end

local function ToggleVoid()
    isActive = not isActive
    
    if isActive then
        teleportCount = teleportCount + 1
        UpdateUI()
        if teleportConnection then teleportConnection:Disconnect() end
        
        teleportConnection = RunService.Heartbeat:Connect(function()
            local hrp = GetHRP()
            if hrp then
                local randomOffset = GetRandomVoidOffset()
                hrp.CFrame = CFrame.new(hrp.Position.X + randomOffset.X, hrp.Position.Y + randomOffset.Y, hrp.Position.Z + randomOffset.Z)
            end
        end)
    else
        UpdateUI()
        if teleportConnection then
            teleportConnection:Disconnect()
            teleportConnection = nil
        end
    end
end

ToggleButton.MouseEnter:Connect(function()
    ToggleButton.BackgroundColor3 = isActive and Color3.fromRGB(180, 60, 80) or Color3.fromRGB(100, 60, 200)
end)

ToggleButton.MouseLeave:Connect(UpdateUI) -- 修復原版 Bug
ToggleButton.Activated:Connect(ToggleVoid)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed then
        if input.KeyCode == Enum.KeyCode.P then
            ToggleVoid()
        elseif input.KeyCode == Enum.KeyCode.RightShift then
            MainFrame.Visible = not MainFrame.Visible
        end
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    if isActive then
        teleportCount = teleportCount + 1
        UpdateUI()
    end
end)

-- ==========================================
-- [ 邏輯區：極致防禦系統 ]
-- ==========================================

-- 1. 絕對質量 (無法被撞動)
CreateDefButton('🛡️ ABSOLUTE MASS', Color3.fromRGB(30, 30, 40), Color3.fromRGB(80, 40, 180), function(state)
    toggles.AbsoluteMass = state
    local char = LocalPlayer.Character
    if not char then return end

    if state then
        local hum = GetHum()
        if hum then
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                originalPhysicalProperties[part] = part.CustomPhysicalProperties
                part.CustomPhysicalProperties = PhysicalProperties.new(100, 100, 0, 100, 100)
            end
        end
        connections.Mass = RunService.Stepped:Connect(function()
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CustomPhysicalProperties = PhysicalProperties.new(100, 100, 0, 100, 100)
                end
            end
        end)
    else
        if connections.Mass then connections.Mass:Disconnect() end
        for part, props in pairs(originalPhysicalProperties) do
            if part and part.Parent then
                part.CustomPhysicalProperties = props
            end
        end
    end
end)

-- 2. 虛無化 (免疫碰觸擊殺)
CreateDefButton('🚫 UNTOUCHABLE', Color3.fromRGB(30, 30, 40), Color3.fromRGB(180, 40, 80), function(state)
    toggles.Untouchable = state
    if state then
        connections.Untouchable = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanTouch = false end
                end
            end
        end)
    else
        if connections.Untouchable then connections.Untouchable:Disconnect() end
        local char = LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanTouch = true end
            end
        end
    end
end)

-- 3. 反傳送綁架 (Anti-Bring)
CreateDefButton('⚓ ANTI-BRING', Color3.fromRGB(30, 30, 40), Color3.fromRGB(40, 120, 180), function(state)
    toggles.AntiBring = state
    local lastPos = nil
    if state then
        connections.AntiBring = RunService.Heartbeat:Connect(function()
            local hrp = GetHRP()
            if hrp then
                -- 若 Void TP 開啟中，則不干涉
                if isActive then
                    lastPos = hrp.Position
                    return
                end
                
                if lastPos and (hrp.Position - lastPos).Magnitude > 50 and GetHum().MoveDirection.Magnitude == 0 then
                    hrp.CFrame = CFrame.new(lastPos)
                else
                    lastPos = hrp.Position
                end
            end
        end)
    else
        if connections.AntiBring then connections.AntiBring:Disconnect() end
    end
end)

-- 4. 動能抹除 (Anti-Fling V2)
CreateDefButton('🛑 VELOCITY WIPER', Color3.fromRGB(30, 30, 40), Color3.fromRGB(180, 100, 40), function(state)
    toggles.AntiFling = state
    if state then
        connections.AntiFling = RunService.Stepped:Connect(function()
            local hrp = GetHRP()
            if hrp then
                for _, v in ipairs(hrp:GetChildren()) do
                    if v:IsA("BodyMover") or v:IsA("BodyVelocity") or v:IsA("BodyGyro") or v:IsA("AngularVelocity") then
                        v:Destroy()
                    end
                end
                if hrp.RotVelocity.Magnitude > 30 or hrp.Velocity.Magnitude > 200 then
                    hrp.RotVelocity = Vector3.new(0, 0, 0)
                    hrp.Velocity = Vector3.new(0, 0, 0)
                end
            end
        end)
    else
        if connections.AntiFling then connections.AntiFling:Disconnect() end
    end
end)

-- 5. 穿牆 (Noclip)
CreateDefButton('🧱 NOCLIP', Color3.fromRGB(30, 30, 40), Color3.fromRGB(80, 160, 180), function(state)
    toggles.Noclip = state
    if state then
        connections.Noclip = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
            end
        end)
    else
        if connections.Noclip then connections.Noclip:Disconnect() end
    end
end)
