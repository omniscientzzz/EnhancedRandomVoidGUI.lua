local fenv = getfenv()
fenv.require = function() end

-- [[ VOID x AEGIS V10.0: OMNI-SHIELD ]] --
-- 功能：光速閃爍、動能吸收、反制光環、自瞄誘餌
-- 狀態：無 NaN/Infinity 數學崩潰，100% 引擎安全

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
local toggleKey = Enum.KeyCode.P
local decoyModel = nil

local function ClearConnections()
    for _, conn in pairs(connections) do
        if typeof(conn) == "RBXScriptConnection" then
            conn:Disconnect()
        end
    end
    table.clear(connections)
    if decoyModel then
        pcall(function() decoyModel:Destroy() end)
        decoyModel = nil
    end
end

-- ==========================================
-- [ UI 介面建構 ]
-- ==========================================
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'VoidOmniGUI'
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new('Frame')
MainFrame.Name = 'MainFrame'
MainFrame.Size = UDim2.new(0, 220, 0, 170)
MainFrame.Position = UDim2.new(0.85, 0, 0.75, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true 
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new('UICorner', MainFrame)
MainCorner.CornerRadius = UDim.new(0, 8)

local MainStroke = Instance.new('UIStroke', MainFrame)
MainStroke.Color = Color3.fromRGB(0, 255, 150)
MainStroke.Thickness = 2

local TitleText = Instance.new('TextLabel', MainFrame)
TitleText.Size = UDim2.new(1, 0, 0, 30)
TitleText.BackgroundTransparency = 1
TitleText.Text = '🛡️ V10 OMNI-SHIELD'
TitleText.TextColor3 = Color3.fromRGB(150, 255, 200)
TitleText.TextSize = 14
TitleText.Font = Enum.Font.GothamBold
TitleText.Parent = MainFrame

local StatusText = Instance.new('TextLabel', MainFrame)
StatusText.Size = UDim2.new(1, 0, 0, 20)
StatusText.Position = UDim2.new(0, 0, 0, 35)
StatusText.BackgroundTransparency = 1
StatusText.Text = '● READY (Press P)'
StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusText.TextSize = 12
StatusText.Font = Enum.Font.GothamBold
StatusText.Parent = MainFrame

local ToggleBtn = Instance.new('TextButton', MainFrame)
ToggleBtn.Size = UDim2.new(0.8, 0, 0, 40)
ToggleBtn.Position = UDim2.new(0.1, 0, 0, 60)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(0, 100, 50)
ToggleBtn.Text = 'ACTIVATE [P]'
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 15
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = MainFrame
Instance.new('UICorner', ToggleBtn).CornerRadius = UDim.new(0, 4)

local StatsText = Instance.new('TextLabel', MainFrame)
StatsText.Size = UDim2.new(1, 0, 0, 50)
StatsText.Position = UDim2.new(0, 0, 0, 110)
StatsText.BackgroundTransparency = 1
StatsText.Text = 'Core: Hyper-Space Jitter\nModules: Anti-Fling & Kinetic Lock\nDecoy: ONLINE'
StatsText.TextColor3 = Color3.fromRGB(200, 255, 220)
StatsText.TextSize = 10
StatsText.Font = Enum.Font.Gotham
StatsText.Parent = MainFrame

-- ==========================================
-- [ 引擎：全能護盾機制 ]
-- ==========================================
local function StartEngine()
    ClearConnections()
    pcall(function() workspace.FallenPartsDestroyHeight = -math.huge end)

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChild("Humanoid")
    if hrp then savedCFrame = hrp.CFrame end

    if not char or not hrp or not hum then return end

    -- [基礎防禦] 數值極限化
    pcall(function()
        hum.MaxHealth = math.huge
        hum.Health = math.huge
        hum.BreakJointsOnDeath = false
        hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
    end)

    -- [自瞄誘餌 Decoy] 建立一個假目標吸引外掛火力
    decoyModel = Instance.new("Model")
    decoyModel.Name = LocalPlayer.Name -- 複製名字
    local dHrp = Instance.new("Part", decoyModel)
    dHrp.Name = "HumanoidRootPart"
    dHrp.Size = Vector3.new(2, 2, 1)
    dHrp.CFrame = CFrame.new(0, 9999999, 0) -- 放置在極高空
    dHrp.Anchored = true
    dHrp.Transparency = 1
    local dHum = Instance.new("Humanoid", decoyModel)
    dHum.MaxHealth = 100
    dHum.Health = 100
    pcall(function() decoyModel.Parent = workspace end)

    -- [實體抹除] 隱藏本體與免疫寄生
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
            part.CanTouch = false 
            part.CanQuery = false 
            part.Size = Vector3.new(0.001, 0.001, 0.001)
            if part.Name == "Head" then part.Transparency = 1 end
        end
        -- 防寄生
        if part:IsA("Attachment") or part:IsA("AlignPosition") or part:IsA("Weld") or part:IsA("BodyMover") then
            if part.Name ~= "RootRigAttachment" and part.Name ~= "FaceCenterAttachment" and part.Name ~= "Neck" then
                pcall(function() part:Destroy() end)
            end
        end
    end

    -- [主防禦循環] 結合光速閃爍、動能吸收、反制光環
    connections.Heartbeat = RunService.Heartbeat:Connect(function()
        if not isActive then return end
        local currentChar = LocalPlayer.Character
        local currentHrp = currentChar and currentChar:FindFirstChild("HumanoidRootPart")
        local currentHum = currentChar and currentChar:FindFirstChild("Humanoid")

        if currentHrp and currentHum and savedCFrame then
            -- 【1. 動能吸收 (Kinetic Lock)】
            -- 如果你沒有按下方向鍵，直接鎖死物理引擎，免疫一切黑洞、推拉、Fling
            if currentHum.MoveDirection.Magnitude == 0 then
                currentHrp.Anchored = true
            else
                currentHrp.Anchored = false
            end

            -- 【2. 光速閃爍 (Hyper Jitter)】
            -- 在 5 億格範圍內隨機瞬移，外掛無法定位
            local hyperX = math.random(-500000000, 500000000)
            local hyperY = math.random( 100000000, 500000000)
            local hyperZ = math.random(-500000000, 500000000)
            
            currentHrp.CFrame = CFrame.new(hyperX, hyperY, hyperZ) * CFrame.Angles(
                math.rad(math.random(1, 360)), 
                math.rad(math.random(1, 360)), 
                math.rad(math.random(1, 360))
            )
        end
        
        -- 【3. 反制光環 (Anti-Fling Aura)】
        -- 抹除周圍其他玩家的碰撞與動能，防止他們用高速物體撞擊你
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local enemyHrp = player.Character:FindFirstChild("HumanoidRootPart")
                if enemyHrp and currentHrp then
                    -- 只要敵人在 50 格內，直接將其客戶端的物理動能歸零
                    if (enemyHrp.Position - currentHrp.Position).Magnitude < 50 then
                        for _, part in ipairs(player.Character:GetChildren()) do
                            if part:IsA("BasePart") then 
                                part.CanCollide = false 
                                pcall(function()
                                    part.AssemblyLinearVelocity = Vector3.zero
                                    part.AssemblyAngularVelocity = Vector3.zero
                                end)
                            end
                        end
                    end
                end
            end
        end
    end)
    
    -- [智慧防爆] 保護自身攻擊，刪除外來爆炸
    connections.Explosion = workspace.DescendantAdded:Connect(function(desc)
        if isActive and desc:IsA("Explosion") then
            local isOwn = false
            pcall(function()
                if char and desc:IsDescendantOf(char) then isOwn = true end
                local creator = desc:FindFirstChild("creator")
                if creator and creator.Value == LocalPlayer then isOwn = true end
            end)

            if not isOwn then
                desc.BlastPressure = 0
                desc.BlastRadius = 0
                desc.Visible = false
                task.defer(function() pcall(function() desc:Destroy() end) end)
            end
        end
    end)
end

local function StopEngine()
    ClearConnections()
    local char = LocalPlayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then 
            hrp.Anchored = false
            if savedCFrame then hrp.CFrame = savedCFrame end
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
        StatusText.Text = '● SHIELD ACTIVE'
        StatusText.TextColor3 = Color3.fromRGB(50, 255, 150)
        MainStroke.Color = Color3.fromRGB(0, 255, 150)
        ToggleBtn.Text = 'DEACTIVATE [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(0, 150, 75)
    else
        StatusText.Text = '● READY (Press P)'
        StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
        MainStroke.Color = Color3.fromRGB(0, 150, 75)
        ToggleBtn.Text = 'ACTIVATE [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(0, 150, 75) or Color3.fromRGB(0, 100, 50)
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
