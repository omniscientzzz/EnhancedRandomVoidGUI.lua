local fenv = getfenv()
fenv.require = function() end

-- [[ VOID GUI: 原始 Void TP 公式還原版 ]] --
-- 核心邏輯：完全採用原版偏移座標 X-1489021035, Z+1547417969
-- 功能：修復按鍵開關異常、支援角色重置自動啟動、保持本地端操作視角

local RunService = game:GetService('RunService')
local Players = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')
local CoreGui = game:GetService('CoreGui')
local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- [ 核心狀態與變數 ]
-- ==========================================
local isActive = false
local connections = {}
local realCFrame = nil
local teleportCount = 0

local OriginalSizes = {}
local OriginalC0s = {}

local function ClearConnections()
    for _, conn in pairs(connections) do
        if typeof(conn) == "RBXScriptConnection" then
            conn:Disconnect()
        end
    end
    table.clear(connections)
    pcall(function() RunService:UnbindFromRenderStep("VoidRestore") end)
end

-- ==========================================
-- [ 介面建構 (VOID UI 視覺還原) ]
-- ==========================================
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'VoidGUI'
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new('Frame')
MainFrame.Name = 'MainFrame'
MainFrame.Size = UDim2.new(0, 220, 0, 180)
MainFrame.Position = UDim2.new(1, -240, 1, -200)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new('UICorner')
MainCorner.CornerRadius = UDim.new(0, 16)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new('UIStroke')
MainStroke.Color = Color3.fromRGB(80, 60, 180)
MainStroke.Thickness = 1.5
MainStroke.Parent = MainFrame

local TopBar = Instance.new('Frame')
TopBar.Size = UDim2.new(1, 0, 0, 44)
TopBar.Position = UDim2.new(0, 0, 0, 0)
TopBar.BackgroundColor3 = Color3.fromRGB(30, 20, 60)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

local TopBarCorner = Instance.new('UICorner')
TopBarCorner.CornerRadius = UDim.new(0, 16)
TopBarCorner.Parent = TopBar

local TopBarBottomFiller = Instance.new('Frame')
TopBarBottomFiller.Size = UDim2.new(1, 0, 0, 16)
TopBarBottomFiller.Position = UDim2.new(0, 0, 1, -16)
TopBarBottomFiller.BackgroundColor3 = Color3.fromRGB(30, 20, 60)
TopBarBottomFiller.BorderSizePixel = 0
TopBarBottomFiller.Parent = TopBar

local TitleText = Instance.new('TextLabel')
TitleText.Size = UDim2.new(1, -16, 1, 0)
TitleText.Position = UDim2.new(0, 14, 0, 0)
TitleText.BackgroundTransparency = 1
TitleText.Text = '⚡ VOID'
TitleText.TextColor3 = Color3.fromRGB(200, 180, 255)
TitleText.TextSize = 15
TitleText.Font = Enum.Font.GothamBold
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.Parent = TopBar

local StatusText = Instance.new('TextLabel')
StatusText.Size = UDim2.new(1, -20, 0, 28)
StatusText.Position = UDim2.new(0, 10, 0, 52)
StatusText.BackgroundTransparency = 1
StatusText.Text = '● IDLE'
StatusText.TextColor3 = Color3.fromRGB(120, 120, 140)
StatusText.TextSize = 13
StatusText.Font = Enum.Font.GothamBold
StatusText.TextXAlignment = Enum.TextXAlignment.Left
StatusText.Parent = MainFrame

local ToggleBtn = Instance.new('TextButton')
ToggleBtn.Size = UDim2.new(1, -20, 0, 54)
ToggleBtn.Position = UDim2.new(0, 10, 0, 88)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(70, 40, 160)
ToggleBtn.BorderSizePixel = 0
ToggleBtn.Text = 'START'
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 17
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = MainFrame

local BtnCorner = Instance.new('UICorner')
BtnCorner.CornerRadius = UDim.new(0, 12)
BtnCorner.Parent = ToggleBtn

local StatsText = Instance.new('TextLabel')
StatsText.Size = UDim2.new(1, -20, 0, 22)
StatsText.Position = UDim2.new(0, 10, 0, 150)
StatsText.BackgroundTransparency = 1
StatsText.Text = 'Teleports: 0'
StatsText.TextColor3 = Color3.fromRGB(80, 80, 100)
StatsText.TextSize = 11
StatsText.Font = Enum.Font.Gotham
StatsText.TextXAlignment = Enum.TextXAlignment.Left
StatsText.Parent = MainFrame

-- ==========================================
-- [ 引擎邏輯：還原 Void 原始傳送公式 ]
-- ==========================================
local function StartVoid()
    ClearConnections()
    teleportCount = 0
    table.clear(OriginalSizes)
    table.clear(OriginalC0s)
    pcall(function() workspace.FallenPartsDestroyHeight = -math.huge end)

    local char = LocalPlayer.Character
    if char and char:FindFirstChild("Humanoid") then
        local hum = char.Humanoid
        pcall(function()
            hum.MaxHealth = math.huge
            hum.Health = math.huge
            hum.BreakJointsOnDeath = false
            hum.RequiresNeck = false
            hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
        end)
    end

    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then OriginalSizes[part] = part.Size
            elseif part:IsA("Motor6D") then OriginalC0s[part] = part.C0 end
        end
    end

    -- [1. 擷取本地位置]
    connections.Stepped = RunService.Stepped:Connect(function()
        if not isActive then return end
        local currentChar = LocalPlayer.Character
        if currentChar then
            local hrp = currentChar:FindFirstChild("HumanoidRootPart")
            if hrp then
                realCFrame = hrp.CFrame
            end
            
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    for _, part in ipairs(player.Character:GetChildren()) do
                        if part:IsA("BasePart") then part.CanCollide = false end
                    end
                end
            end
        end
    end)

    -- [2. 套用 Void 原版偏移公式]
    connections.Heartbeat = RunService.Heartbeat:Connect(function()
        if not isActive then return end
        local char = LocalPlayer.Character
        if not char then return end
        
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp and realCFrame then
            local pos = realCFrame.Position
            
            -- 使用你提供的原始偏移數值
            hrp.CFrame = CFrame.new(
                pos.X + -1489021035.808403, 
                pos.Y, 
                pos.Z + 1547417969.8282743
            )
            
            teleportCount = teleportCount + 1
            StatsText.Text = 'Teleports: ' .. tostring(teleportCount)
            
            -- 防護與縮小
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Size = Vector3.new(0.01, 0.01, 0.01)
                    part.Massless = true
                    if part.Name == "Head" then part.Transparency = 1 end
                end
            end
        end
    end)

    -- [3. 本地端還原視角]
    RunService:BindToRenderStep("VoidRestore", Enum.RenderPriority.Camera.Value - 10, function()
        if not isActive then return end
        local char = LocalPlayer.Character
        if char and realCFrame then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.CFrame = realCFrame
            end
        end
    end)
    
    connections.Explosion = workspace.DescendantAdded:Connect(function(desc)
        if isActive and desc.ClassName == "Explosion" then
            desc.BlastPressure = 0
            desc.BlastRadius = 0
            task.defer(function() pcall(function() desc:Destroy() end) end)
        end
    end)
end

local function StopVoid()
    ClearConnections()
    pcall(function() workspace.FallenPartsDestroyHeight = -500 end)
    
    local char = LocalPlayer.Character
    if char then
        for part, size in pairs(OriginalSizes) do
            if part and part.Parent and part:IsDescendantOf(char) then part.Size = size end
        end
        for motor, c0 in pairs(OriginalC0s) do
            if motor and motor.Parent and motor:IsDescendantOf(char) then motor.C0 = c0 end
        end
        if char:FindFirstChild("Head") then char.Head.Transparency = 0 end

        if char:FindFirstChild("Humanoid") then
            pcall(function()
                char.Humanoid.MaxHealth = 100
                char.Humanoid.Health = 100
                char.Humanoid.RequiresNeck = true
                char.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
                char.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
            end)
        end
    end
    table.clear(OriginalSizes)
    table.clear(OriginalC0s)
end

-- ==========================================
-- [ UI 互動系統修復 ]
-- ==========================================
local isHovering = false
local isDebouncing = false

local function UpdateButtonVisuals()
    if isActive then
        StatusText.Text = '● ACTIVE'
        StatusText.TextColor3 = Color3.fromRGB(120, 255, 160)
        ToggleBtn.Text = 'STOP'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(180, 50, 70) or Color3.fromRGB(160, 40, 60)
    else
        StatusText.Text = '● IDLE'
        StatusText.TextColor3 = Color3.fromRGB(120, 120, 140)
        ToggleBtn.Text = 'START'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(100, 60, 200) or Color3.fromRGB(70, 40, 160)
    end
end

ToggleBtn.MouseEnter:Connect(function()
    isHovering = true
    UpdateButtonVisuals()
end)

ToggleBtn.MouseLeave:Connect(function()
    isHovering = false
    UpdateButtonVisuals()
end)

ToggleBtn.MouseButton1Click:Connect(function()
    if isDebouncing then return end
    isDebouncing = true
    
    isActive = not isActive
    UpdateButtonVisuals()
    
    if isActive then
        StartVoid()
    else
        StopVoid()
    end
    
    task.wait(0.2)
    isDebouncing = false
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.delay(0.5, function()
        if isActive then StartVoid() end
    end)
end)

