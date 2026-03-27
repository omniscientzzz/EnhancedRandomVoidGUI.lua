local fenv = getfenv()
fenv.require = function() end

-- [[ VOID x AEGIS V8: QUANTUM EVASION ]] --
-- 功能：真實虛空、無限小自轉、智慧防爆、快捷鍵[P]、全防禦(Fling/Touch/Raycast/Sit)
-- 新增：Quantum Jitter (每幀 10萬距離隨機瞬移)、Velocity Spoofing (破壞預測型自瞄與追蹤彈)

local RunService = game:GetService('RunService')
local Players = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')
local CoreGui = game:GetService('CoreGui')
local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- [ 核心狀態管理 ]
-- ==========================================
local isActive = false
local connections = {}
local savedCFrame = nil 
local teleportCount = 0
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
-- [ UI 介面建構 ]
-- ==========================================
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'VoidQuantumGUI'
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new('Frame')
MainFrame.Name = 'MainFrame'
MainFrame.Size = UDim2.new(0, 190, 0, 160)
MainFrame.Position = UDim2.new(0.85, 0, 0.8, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(5, 5, 15)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true 
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new('UICorner', MainFrame)
MainCorner.CornerRadius = UDim.new(0, 12)

local MainStroke = Instance.new('UIStroke', MainFrame)
MainStroke.Color = Color3.fromRGB(0, 255, 255)
MainStroke.Thickness = 2

local TitleText = Instance.new('TextLabel', MainFrame)
TitleText.Size = UDim2.new(1, 0, 0, 30)
TitleText.BackgroundTransparency = 1
TitleText.Text = '🌌 V8 QUANTUM'
TitleText.TextColor3 = Color3.fromRGB(150, 255, 255)
TitleText.TextSize = 13
TitleText.Font = Enum.Font.GothamBold
TitleText.Parent = MainFrame

local StatusText = Instance.new('TextLabel', MainFrame)
StatusText.Size = UDim2.new(1, 0, 0, 20)
StatusText.Position = UDim2.new(0, 0, 0, 35)
StatusText.BackgroundTransparency = 1
StatusText.Text = '● READY (Press P)'
StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusText.TextSize = 11
StatusText.Font = Enum.Font.GothamBold
StatusText.Parent = MainFrame

local ToggleBtn = Instance.new('TextButton', MainFrame)
ToggleBtn.Size = UDim2.new(0.8, 0, 0, 40)
ToggleBtn.Position = UDim2.new(0.1, 0, 0, 60)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(0, 100, 150)
ToggleBtn.Text = 'START [P]'
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 15
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = MainFrame
Instance.new('UICorner', ToggleBtn).CornerRadius = UDim.new(0, 8)

local StatsText = Instance.new('TextLabel', MainFrame)
StatsText.Size = UDim2.new(1, 0, 0, 45)
StatsText.Position = UDim2.new(0, 0, 0, 110)
StatsText.BackgroundTransparency = 1
StatsText.Text = 'Evasion: QUANTUM JITTER\nSpoofing: ACTIVE\nHit Probability: 0.00%'
StatsText.TextColor3 = Color3.fromRGB(100, 200, 255)
StatsText.TextSize = 10
StatsText.Font = Enum.Font.Gotham
StatsText.Parent = MainFrame

-- ==========================================
-- [ 引擎：量子迴避與絕對防禦 ]
-- ==========================================
local function StartEngine()
    ClearConnections()
    teleportCount = 0
    pcall(function() workspace.FallenPartsDestroyHeight = -math.huge end)

    local char = LocalPlayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then savedCFrame = hrp.CFrame end
    end

    local function OptimizeCharacter(c)
        if not c then return end
        local hum = c:WaitForChild("Humanoid")
        pcall(function()
            hum.MaxHealth = math.huge
            hum.Health = math.huge
            hum.BreakJointsOnDeath = false
            hum.RequiresNeck = false
            hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
            hum.Sit = false
            hum.PlatformStand = false
        end)
    end
    
    OptimizeCharacter(char)

    -- [1. Hitbox 無效化與反觸碰/反射線]
    connections.Stepped = RunService.Stepped:Connect(function()
        if not isActive then return end
        local currentChar = LocalPlayer.Character
        if currentChar then
            for _, part in ipairs(currentChar:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                    part.CanTouch = false 
                    part.CanQuery = false 
                    part.Size = Vector3.new(0.001, 0.001, 0.001)
                    if part.Name == "Head" then part.Transparency = 1 end
                end
            end
            
            for _, obj in ipairs(currentChar:GetDescendants()) do
                if obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("BodyMover") then 
                    obj:Destroy() 
                end
            end
        end

        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                for _, part in ipairs(player.Character:GetChildren()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
            end
        end
    end)

    -- [2. 量子閃爍 (Quantum Jitter) & 速度欺騙 (Velocity Spoofing)]
    connections.Heartbeat = RunService.Heartbeat:Connect(function()
        if not isActive then return end
        local currentChar = LocalPlayer.Character
        if currentChar and savedCFrame then
            local hrp = currentChar:FindFirstChild("HumanoidRootPart")
            if hrp then
                -- 【量子閃爍】：不再待在固定的虛空，而是每幀在 10 萬格半徑內瘋狂隨機瞬移
                local jitterX = math.random(-100000, 100000)
                local jitterY = math.random(-100000, 100000)
                local jitterZ = math.random(-100000, 100000)
                
                local voidPos = Vector3.new(
                    savedCFrame.X - 1489021035.8 + jitterX, 
                    savedCFrame.Y + jitterY, 
                    savedCFrame.Z + 1547417969.8 + jitterZ
                )
                
                -- 全向隨機自轉
                hrp.CFrame = CFrame.new(voidPos) * CFrame.Angles(
                    math.rad(math.random(1, 360)), 
                    math.rad(math.random(1, 360)), 
                    math.rad(math.random(1, 360))
                )

                -- 【速度欺騙】：賦予極端假速度，讓伺服器預測型自瞄與導彈的數學公式徹底崩潰 (飛向宇宙)
                hrp.AssemblyLinearVelocity = Vector3.new(
                    math.random(-999999, 999999), 
                    math.random(-999999, 999999), 
                    math.random(-999999, 999999)
                )
                hrp.AssemblyAngularVelocity = Vector3.zero
            end
        end
    end)
    
    -- [3. 智慧防爆 (保留自身投擲物)]
    connections.Explosion = workspace.DescendantAdded:Connect(function(desc)
        if isActive and desc:IsA("Explosion") then
            local currentChar = LocalPlayer.Character
            local isOwn = false
            
            pcall(function()
                if currentChar and desc:IsDescendantOf(currentChar) then isOwn = true end
                local creator = desc:FindFirstChild("creator") or (desc.Parent and desc.Parent:FindFirstChild("creator"))
                if creator and creator:IsA("ObjectValue") and creator.Value == LocalPlayer then isOwn = true end
                if desc.Parent and desc.Parent.Name == LocalPlayer.Name then isOwn = true end
                if desc.Parent and desc.Parent:IsA("Tool") and currentChar and desc.Parent:IsDescendantOf(currentChar) then isOwn = true end
            end)

            if isOwn then return end
            
            desc.BlastPressure = 0
            desc.BlastRadius = 0
            desc.Visible = false
            task.defer(function() pcall(function() desc:Destroy() end) end)
        end
    end)
end

local function StopEngine()
    ClearConnections()
    local char = LocalPlayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp and savedCFrame then
            hrp.CFrame = savedCFrame
            hrp.AssemblyLinearVelocity = Vector3.zero -- 關閉時必須將欺騙速度歸零，否則會飛出地圖
            hrp.AssemblyAngularVelocity = Vector3.zero
        end

        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanTouch = true
                part.CanQuery = true
                part.Size = Vector3.new(1, 1, 1)
                if part.Name == "Head" then part.Transparency = 0 end
            end
        end
        if char:FindFirstChild("Humanoid") then
            char.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
            char.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
            char.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
        end
    end
end

-- ==========================================
-- [ 快捷鍵與 UI 互動邏輯 ]
-- ==========================================
local isHovering = false
local isDebouncing = false

local function UpdateUI()
    if isActive then
        StatusText.Text = '● QUANTUM EVASION'
        StatusText.TextColor3 = Color3.fromRGB(0, 255, 255)
        ToggleBtn.Text = 'RETURN [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(200, 50, 50) or Color3.fromRGB(180, 40, 40)
    else
        StatusText.Text = '● READY (Press P)'
        StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
        ToggleBtn.Text = 'START [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(0, 180, 255) or Color3.fromRGB(0, 100, 150)
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

