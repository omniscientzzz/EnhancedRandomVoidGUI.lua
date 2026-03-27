local fenv = getfenv()
fenv.require = function() end

-- [[ VOID x AEGIS V19.3: ABSOLUTE AEGIS (極致防禦版 / 無 Hook) ]] --
-- 突破物理引擎限制，採用「幽靈化」與「絕對力場」達到無敵
-- 完全免疫 Raycast (射線)、.Touched (接觸)、以及大部分 AoE 攻擊

local Players = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')
local RunService = game:GetService('RunService')

local LocalPlayer = Players.LocalPlayer
local toggleKey = Enum.KeyCode.P

-- ==========================================
-- [ 核心參數設置 ]
-- ==========================================
local v15 = 9e9 -- 極端破壞伺服器預判的推力
local v16 = -9e9 
local JITTER_STRENGTH = 50000 -- 萬級距的座標偏移，閃避所有伺服器範圍判定
local FORCEFIELD_RADIUS = 35 -- 絕對防禦力場半徑
local ENEMY_HITBOX_SIZE = Vector3.new(60, 60, 60) 

local isActive = false
local realCFrame = nil
local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Exclude

-- 連接池
local steppedConnection = nil
local renderConnection = nil
local heartbeatConnection = nil
local workspaceConnection = nil
local characterConnection = nil

-- ==========================================
-- [ 異步 Hitbox 處理 (維持效能) ]
-- ==========================================
task.spawn(function()
    while true do
        task.wait(0.5)
        if isActive then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character then
                    local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
                    if hrp and hrp.Size.X < ENEMY_HITBOX_SIZE.X then
                        hrp.Size = ENEMY_HITBOX_SIZE
                        hrp.Transparency = 0.7
                        hrp.CanCollide = false
                    end
                end
            end
        end
    end
end)

-- ==========================================
-- [ GUI 建構 ]
-- ==========================================
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'VoidApotheosisGUI'
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = game:GetService('CoreGui') end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new('Frame')
MainFrame.Name = 'MainFrame'
MainFrame.Size = UDim2.new(0, 300, 0, 270)
MainFrame.Position = UDim2.new(0.85, -40, 0.75, -70)
MainFrame.BackgroundColor3 = Color3.fromRGB(10, 5, 15)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true 
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new('UICorner', MainFrame)
MainCorner.CornerRadius = UDim.new(0, 8)

local MainStroke = Instance.new('UIStroke', MainFrame)
MainStroke.Color = Color3.fromRGB(255, 50, 100)
MainStroke.Thickness = 2

local TitleText = Instance.new('TextLabel', MainFrame)
TitleText.Size = UDim2.new(1, 0, 0, 30)
TitleText.BackgroundTransparency = 1
TitleText.Text = '🛡️ V19.3 ABSOLUTE AEGIS'
TitleText.TextColor3 = Color3.fromRGB(255, 150, 150)
TitleText.TextSize = 16
TitleText.Font = Enum.Font.GothamBlack
TitleText.Parent = MainFrame

local StatusText = Instance.new('TextLabel', MainFrame)
StatusText.Size = UDim2.new(1, 0, 0, 20)
StatusText.Position = UDim2.new(0, 0, 0, 35)
StatusText.BackgroundTransparency = 1
StatusText.Text = 'STATUS: VULNERABLE'
StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusText.TextSize = 12
StatusText.Font = Enum.Font.GothamBold
StatusText.Parent = MainFrame

local ToggleBtn = Instance.new('TextButton', MainFrame)
ToggleBtn.Size = UDim2.new(0.8, 0, 0, 40)
ToggleBtn.Position = UDim2.new(0.1, 0, 0, 65)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(80, 20, 30)
ToggleBtn.Text = 'ACTIVATE SHIELD [P]'
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 14
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = MainFrame
Instance.new('UICorner', ToggleBtn).CornerRadius = UDim.new(0, 4)

local StatsText = Instance.new('TextLabel', MainFrame)
StatsText.Size = UDim2.new(1, 0, 0, 140)
StatsText.Position = UDim2.new(0.1, 0, 0, 115)
StatsText.BackgroundTransparency = 1
StatsText.Text = '[✓] Absolute Forcefield (35 Studs)\n[✓] Ghosting (Raycast Immune)\n[✓] Touch & Collide Disabled\n[✓] Null-Space Coordinate Desync\n[✓] Projectile Deflection\n[✓] Weapon Neuter (No Hitbox)'
StatsText.TextColor3 = Color3.fromRGB(255, 200, 200)
StatsText.TextSize = 12
StatsText.TextXAlignment = Enum.TextXAlignment.Left
StatsText.Font = Enum.Font.Code
StatsText.Parent = MainFrame

-- ==========================================
-- [ 引擎：絕對防禦機制啟動 ]
-- ==========================================
local function StartApotheosis()
    local char = LocalPlayer.Character
    if not char then return end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then return end

    hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
    
    realCFrame = hrp.CFrame
    overlapParams.FilterDescendantsInstances = {char}

    -- 事件驅動：防強制黏著
    characterConnection = char.ChildAdded:Connect(function(child)
        if isActive and child:IsA("Weld") and child.Name == "SeatWeld" then
            task.delay(0, function() pcall(function() child:Destroy() end) end)
        end
    end)

    -- 事件驅動：處理瞬間生成的爆炸與物件
    workspaceConnection = workspace.DescendantAdded:Connect(function(desc)
        if not isActive then return end
        if desc:IsA("Explosion") then
            desc.BlastRadius = 0
            desc.BlastPressure = 0
            task.delay(0, function() pcall(function() desc:Destroy() end) end)
        end
    end)

    -- [核心 1] Heartbeat：幽靈化與絕對力場
    heartbeatConnection = RunService.Heartbeat:Connect(function()
        if not isActive then return end
        local currentChar = LocalPlayer.Character
        if not currentChar then return end

        -- 1. 幽靈化自身：徹底阻絕射線(CanQuery)與觸碰(CanTouch)
        for _, part in ipairs(currentChar:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
                pcall(function()
                    part.CanTouch = false
                    part.CanQuery = false -- 使敵方 RaycastHitbox 完全無法選中你
                end)
            end
        end
        
        local currentHum = currentChar:FindFirstChild("Humanoid")
        if currentHum and currentHum.Sit then
            currentHum.Sit = false
            currentHum:ChangeState(Enum.HumanoidStateType.Jumping)
        end

        -- 2. 絕對力場 (Aegis Forcefield)：摧毀/反彈靠近的威脅
        if realCFrame then
            local threats = workspace:GetPartBoundsInRadius(realCFrame.Position, FORCEFIELD_RADIUS, overlapParams)
            for _, threat in ipairs(threats) do
                if threat:IsA("BasePart") and threat.Size.Magnitude < 100 then
                    -- 剝奪敵方武器/投擲物的傷害判定
                    pcall(function() threat.CanTouch = false end)
                    pcall(function() threat.CanQuery = false end)
                    
                    -- 若為未錨定的投擲物或敵方玩家的部位，施加極端斥力反彈
                    if not threat.Anchored then
                        local dir = (threat.Position - realCFrame.Position).Unit
                        -- NaN 或極大向量直接破壞敵方物理
                        threat.AssemblyLinearVelocity = dir * 15000 
                        threat.AssemblyAngularVelocity = Vector3.new(1000, 1000, 1000)
                    end
                end
            end
        end
    end)

    -- [核心 2] RenderStepped：視覺修正
    renderConnection = RunService.RenderStepped:Connect(function()
        if not isActive then return end
        local currentHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if currentHrp and realCFrame then
            currentHrp.CFrame = realCFrame
            currentHrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            currentHrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end
    end)

    -- [核心 3] Stepped：Null-Space 極端物理閃避
    steppedConnection = RunService.Stepped:Connect(function()
        if not isActive then return end
        local currentHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if currentHrp then
            realCFrame = currentHrp.CFrame
            
            -- 將物理實體送到萬級別的隨機深空，並附加極端速度
            local nullSpaceCFrame = realCFrame + Vector3.new(
                math.random(-JITTER_STRENGTH, JITTER_STRENGTH),
                math.random(50000, 100000), -- 高空
                math.random(-JITTER_STRENGTH, JITTER_STRENGTH)
            )

            currentHrp.CFrame = nullSpaceCFrame
            -- 使用極端負值破壞伺服器的物理預測 (Desync)
            currentHrp.AssemblyLinearVelocity = Vector3.new(v15, v16, v15)
            currentHrp.AssemblyAngularVelocity = Vector3.new(v15, v16, v15)
        end
    end)
end

local function RestoreHitboxes()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local enemyHrp = plr.Character.HumanoidRootPart
            enemyHrp.Size = Vector3.new(2, 2, 1) 
            enemyHrp.Transparency = 1
        end
    end
end

local function StopApotheosis()
    if renderConnection then renderConnection:Disconnect() end
    if steppedConnection then steppedConnection:Disconnect() end
    if heartbeatConnection then heartbeatConnection:Disconnect() end
    if workspaceConnection then workspaceConnection:Disconnect() end
    if characterConnection then characterConnection:Disconnect() end
    
    RestoreHitboxes()
    
    local char = LocalPlayer.Character
    if char then
        -- 恢復本體屬性
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                pcall(function()
                    part.CanTouch = true
                    part.CanQuery = true
                end)
            end
        end

        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp and realCFrame then
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
        StatusText.Text = 'STATUS: ABSOLUTE IMMUNITY'
        StatusText.TextColor3 = Color3.fromRGB(255, 50, 100)
        MainStroke.Color = Color3.fromRGB(255, 50, 100)
        ToggleBtn.Text = 'DEACTIVATE [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(120, 30, 40) or Color3.fromRGB(90, 20, 30)
    else
        StatusText.Text = 'STATUS: VULNERABLE'
        StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
        MainStroke.Color = Color3.fromRGB(100, 100, 100)
        ToggleBtn.Text = 'ACTIVATE SHIELD [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(60, 20, 30) or Color3.fromRGB(40, 15, 20)
    end
end

local function ToggleSystem()
    isActive = not isActive
    UpdateUI()
    if isActive then StartApotheosis() else StopApotheosis() end
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
        task.wait(0.5)
        overlapParams.FilterDescendantsInstances = {newChar}
        StartApotheosis()
    end
end)
