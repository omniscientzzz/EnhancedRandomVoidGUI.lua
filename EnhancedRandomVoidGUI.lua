local fenv = getfenv()
fenv.require = function() end

-- [[ VOID x AEGIS V6: EXTREME HYBRID (True Void Edition) ]] --
-- 功能：真正虛空傳送(視角與本體皆入虛空)、無限小自轉、防爆、防遠程、縮小版UI
-- 座標：X -1489021035.8, Z +1547417969.8

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
local savedCFrame = nil -- 用於記錄進入虛空前的位置
local teleportCount = 0

local function ClearConnections()
    for _, conn in pairs(connections) do
        if typeof(conn) == "RBXScriptConnection" then
            conn:Disconnect()
        end
    end
    table.clear(connections)
end

-- ==========================================
-- [ UI 介面建構 (縮小且可移動) ]
-- ==========================================
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'VoidExtremeGUI'
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new('Frame')
MainFrame.Name = 'MainFrame'
MainFrame.Size = UDim2.new(0, 180, 0, 140)
MainFrame.Position = UDim2.new(0.85, 0, 0.8, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true 
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new('UICorner', MainFrame)
MainCorner.CornerRadius = UDim.new(0, 12)

local MainStroke = Instance.new('UIStroke', MainFrame)
MainStroke.Color = Color3.fromRGB(120, 50, 255)
MainStroke.Thickness = 2

local TitleText = Instance.new('TextLabel', MainFrame)
TitleText.Size = UDim2.new(1, 0, 0, 30)
TitleText.BackgroundTransparency = 1
TitleText.Text = '⚡ TRUE VOID'
TitleText.TextColor3 = Color3.fromRGB(200, 180, 255)
TitleText.TextSize = 13
TitleText.Font = Enum.Font.GothamBold
TitleText.Parent = MainFrame

local StatusText = Instance.new('TextLabel', MainFrame)
StatusText.Size = UDim2.new(1, 0, 0, 20)
StatusText.Position = UDim2.new(0, 0, 0, 35)
StatusText.BackgroundTransparency = 1
StatusText.Text = '● READY'
StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusText.TextSize = 11
StatusText.Font = Enum.Font.GothamBold
StatusText.Parent = MainFrame

local ToggleBtn = Instance.new('TextButton', MainFrame)
ToggleBtn.Size = UDim2.new(0.8, 0, 0, 40)
ToggleBtn.Position = UDim2.new(0.1, 0, 0, 60)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 150)
ToggleBtn.Text = 'START'
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 15
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = MainFrame
Instance.new('UICorner', ToggleBtn).CornerRadius = UDim.new(0, 8)

local StatsText = Instance.new('TextLabel', MainFrame)
StatsText.Size = UDim2.new(1, 0, 0, 20)
StatsText.Position = UDim2.new(0, 0, 0, 110)
StatsText.BackgroundTransparency = 1
StatsText.Text = 'TP: 0 | Defense: OK'
StatsText.TextColor3 = Color3.fromRGB(80, 80, 120)
StatsText.TextSize = 10
StatsText.Font = Enum.Font.Gotham
StatsText.Parent = MainFrame

-- ==========================================
-- [ 引擎：無敵與防禦邏輯 ]
-- ==========================================
local function StartEngine()
    ClearConnections()
    teleportCount = 0
    pcall(function() workspace.FallenPartsDestroyHeight = -math.huge end)

    local char = LocalPlayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then 
            savedCFrame = hrp.CFrame -- 記錄進入虛空前的真實地圖位置
        end
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
        end)
    end
    
    OptimizeCharacter(char)

    -- [1. 自我 Hitbox 最小化]
    connections.Stepped = RunService.Stepped:Connect(function()
        if not isActive then return end
        local currentChar = LocalPlayer.Character
        if currentChar then
            for _, part in ipairs(currentChar:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                    part.Size = Vector3.new(0.001, 0.001, 0.001)
                    if part.Name == "Head" then part.Transparency = 1 end
                end
            end
            
            -- 自動清除自身有害狀態
            for _, obj in ipairs(currentChar:GetDescendants()) do
                if obj:IsA("Fire") or obj:IsA("Smoke") then obj:Destroy() end
            end
        end

        -- [2. 關閉敵人碰撞]
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                for _, part in ipairs(player.Character:GetChildren()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
            end
        end
    end)

    -- [3. True Void 傳送邏輯 (視角與本體皆在虛空)]
    connections.Heartbeat = RunService.Heartbeat:Connect(function()
        if not isActive then return end
        local currentChar = LocalPlayer.Character
        if currentChar and savedCFrame then
            local hrp = currentChar:FindFirstChild("HumanoidRootPart")
            if hrp then
                -- 真實傳送至虛空，並加上隨機自轉干擾鎖定
                local voidPos = Vector3.new(savedCFrame.X - 1489021035.8, savedCFrame.Y, savedCFrame.Z + 1547417969.8)
                hrp.CFrame = CFrame.new(voidPos) * CFrame.Angles(0, math.rad(math.random(1, 360)), 0)
                
                teleportCount = teleportCount + 1
                StatsText.Text = 'TP: '..tostring(teleportCount)..' | Void: ON'
            end
        end
    end)
    
    -- [4. 智慧 Anti-Explosion (保留自身投擲物)]
    connections.Explosion = workspace.DescendantAdded:Connect(function(desc)
        if isActive and desc:IsA("Explosion") then
            local currentChar = LocalPlayer.Character
            local isOwn = false
            
            pcall(function()
                if currentChar and desc:IsDescendantOf(currentChar) then isOwn = true end
                
                local creator = desc:FindFirstChild("creator") or (desc.Parent and desc.Parent:FindFirstChild("creator"))
                if creator and creator:IsA("ObjectValue") and creator.Value == LocalPlayer then
                    isOwn = true
                end
                
                if desc.Parent and desc.Parent.Name == LocalPlayer.Name then isOwn = true end
                
                if desc.Parent and desc.Parent:IsA("Tool") and currentChar and desc.Parent:IsDescendantOf(currentChar) then
                    isOwn = true
                end
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
        -- 將玩家從虛空傳送回開啟前的地圖位置
        if hrp and savedCFrame then
            hrp.CFrame = savedCFrame
        end

        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Size = Vector3.new(1, 1, 1)
                if part.Name == "Head" then part.Transparency = 0 end
            end
        end
        if char:FindFirstChild("Humanoid") then
            char.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
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
        StatusText.Text = '● IN THE VOID'
        StatusText.TextColor3 = Color3.fromRGB(0, 255, 150)
        ToggleBtn.Text = 'RETURN'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(200, 50, 50) or Color3.fromRGB(150, 30, 30)
    else
        StatusText.Text = '● ON THE MAP'
        StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
        ToggleBtn.Text = 'TO VOID'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(100, 50, 255) or Color3.fromRGB(60, 30, 150)
    end
end

ToggleBtn.MouseEnter:Connect(function() isHovering = true UpdateUI() end)
ToggleBtn.MouseLeave:Connect(function() isHovering = false UpdateUI() end)
ToggleBtn.MouseButton1Click:Connect(function()
    if isDebouncing then return end
    isDebouncing = true
    isActive = not isActive
    UpdateUI()
    if isActive then StartEngine() else StopEngine() end
    task.wait(0.3)
    isDebouncing = false
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.delay(1, function() if isActive then StartEngine() end end)
end)


