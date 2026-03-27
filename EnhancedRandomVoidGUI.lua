local fenv = getfenv()
fenv.require = function() end

-- [[ VOID x AEGIS V9: ZERO DIMENSION ]] --
-- 功能：真實虛空、智慧防爆、快捷鍵[P]、防控制
-- 終極升級：Infinity Velocity(無限大速度欺騙)、Hyper-Space Jitter(5億距離光速閃爍)

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
ScreenGui.Name = 'VoidZeroGUI'
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new('Frame')
MainFrame.Name = 'MainFrame'
MainFrame.Size = UDim2.new(0, 200, 0, 160)
MainFrame.Position = UDim2.new(0.85, 0, 0.8, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true 
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new('UICorner', MainFrame)
MainCorner.CornerRadius = UDim.new(0, 8)

local MainStroke = Instance.new('UIStroke', MainFrame)
MainStroke.Color = Color3.fromRGB(255, 0, 0)
MainStroke.Thickness = 2

local TitleText = Instance.new('TextLabel', MainFrame)
TitleText.Size = UDim2.new(1, 0, 0, 30)
TitleText.BackgroundTransparency = 1
TitleText.Text = '⬛ V9 ZERO DIMENSION'
TitleText.TextColor3 = Color3.fromRGB(255, 100, 100)
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
ToggleBtn.BackgroundColor3 = Color3.fromRGB(100, 0, 0)
ToggleBtn.Text = 'START [P]'
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 15
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = MainFrame
Instance.new('UICorner', ToggleBtn).CornerRadius = UDim.new(0, 4)

local StatsText = Instance.new('TextLabel', MainFrame)
StatsText.Size = UDim2.new(1, 0, 0, 45)
StatsText.Position = UDim2.new(0, 0, 0, 110)
StatsText.BackgroundTransparency = 1
StatsText.Text = 'Evasion: HYPER-SPACE (500M)\nSpoofing: INFINITY (NaN)\nHit Probability: ABSOLUTE 0%'
StatsText.TextColor3 = Color3.fromRGB(255, 150, 150)
StatsText.TextSize = 10
StatsText.Font = Enum.Font.Gotham
StatsText.Parent = MainFrame

-- ==========================================
-- [ 引擎：零維度極限防禦 ]
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

    -- [1. 實體抹除與免疫寄生]
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
                
                -- 防寄生：消除所有外掛試圖綁定在你身上的限制器、繩索或炸彈
                if part:IsA("Attachment") or part:IsA("AlignPosition") or part:IsA("Weld") or part:IsA("BodyMover") or part:IsA("Fire") then
                    -- 保留原本的骨架，只清除異常附加物
                    if part.Name ~= "RootRigAttachment" and part.Name ~= "FaceCenterAttachment" and part.Name ~= "Neck" then
                        pcall(function() part:Destroy() end)
                    end
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

    -- [2. 億級光速閃爍 & Infinity (NaN) 數學崩潰]
    connections.Heartbeat = RunService.Heartbeat:Connect(function()
        if not isActive then return end
        local currentChar = LocalPlayer.Character
        if currentChar and savedCFrame then
            local hrp = currentChar:FindFirstChild("HumanoidRootPart")
            if hrp then
                -- 【億級光速閃爍】：每秒 60 次，在正負 5 億的座標內瘋狂瞬移
                -- 任何試圖獲取你座標的外掛，傳送過去時你早就在幾億格之外了
                local hyperX = math.random(-500000000, 500000000)
                local hyperY = math.random( 100000000, 500000000) -- Y軸保持極高空，防止接觸任何地圖邊界死角
                local hyperZ = math.random(-500000000, 500000000)
                
                hrp.CFrame = CFrame.new(hyperX, hyperY, hyperZ) * CFrame.Angles(
                    math.rad(math.random(1, 360)), 
                    math.rad(math.random(1, 360)), 
                    math.rad(math.random(1, 360))
                )

                -- 【Infinity 數學崩潰】：給予無限大(Infinity)的速度
                -- 追蹤型外掛計算距離與時間時，會發生除以 0 的 NaN (Not a Number) 崩潰！
                pcall(function()
                    hrp.AssemblyLinearVelocity = Vector3.new(math.huge, math.huge, math.huge)
                    hrp.AssemblyAngularVelocity = Vector3.new(math.huge, math.huge, math.huge)
                end)
            end
        end
    end)
    
    -- [3. 智慧防爆 (保護自身攻擊)]
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
            -- 關閉時必須解除無限大速度，否則會被系統踢出或物理崩潰
            hrp.AssemblyLinearVelocity = Vector3.zero 
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
-- [ UI 互動邏輯 ]
-- ==========================================
local isHovering = false
local isDebouncing = false

local function UpdateUI()
    if isActive then
        StatusText.Text = '● ZERO DIMENSION'
        StatusText.TextColor3 = Color3.fromRGB(255, 50, 50)
        MainStroke.Color = Color3.fromRGB(255, 0, 0)
        ToggleBtn.Text = 'RETURN [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(200, 0, 0) or Color3.fromRGB(150, 0, 0)
    else
        StatusText.Text = '● READY (Press P)'
        StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
        MainStroke.Color = Color3.fromRGB(150, 0, 0)
        ToggleBtn.Text = 'START [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(150, 0, 0) or Color3.fromRGB(100, 0, 0)
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
