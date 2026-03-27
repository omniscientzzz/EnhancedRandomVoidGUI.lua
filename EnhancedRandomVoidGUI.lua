local fenv = getfenv()
fenv.require = function() end

-- [[ VOID x AEGIS V19.2: PURE APOTHEOSIS (無 Hook 純淨版) ]] --
-- 移除了 hookmetamethod，解決與其他腳本的衝突及潛在的底層卡頓
-- 保留了異步處理、淺層遍歷與核心無敵機制

local Players = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')
local RunService = game:GetService('RunService')

local LocalPlayer = Players.LocalPlayer
local toggleKey = Enum.KeyCode.P

-- ==========================================
-- [ 核心參數設置 ]
-- ==========================================
local v15 = 2e22 
local v16 = 2e22 
local SHADOW_OFFSET = Vector3.new(0, 50000, 0)
local JITTER_STRENGTH = 10 
local ENEMY_HITBOX_SIZE = Vector3.new(60, 60, 60) 
local PROJECTILE_SIZE = Vector3.new(40, 40, 40) 

local isActive = false
local realCFrame = nil

-- 連接池
local steppedConnection = nil
local renderConnection = nil
local heartbeatConnection = nil
local workspaceConnection = nil
local characterConnection = nil

-- ==========================================
-- [ 異步 Hitbox 處理 (防止卡頓) ]
-- ==========================================
task.spawn(function()
    while true do
        task.wait(0.5) -- 每 0.5 秒更新一次
        if isActive then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character then
                    local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
                    -- 只有在尚未放大的情況下才修改，避免重複觸發屬性更新
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
MainFrame.Size = UDim2.new(0, 280, 0, 260)
MainFrame.Position = UDim2.new(0.85, -20, 0.75, -60)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 5, 20)
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
TitleText.Text = '⚡ V19.2 (NO HOOK)'
TitleText.TextColor3 = Color3.fromRGB(150, 255, 200)
TitleText.TextSize = 15
TitleText.Font = Enum.Font.GothamBlack
TitleText.Parent = MainFrame

local StatusText = Instance.new('TextLabel', MainFrame)
StatusText.Size = UDim2.new(1, 0, 0, 20)
StatusText.Position = UDim2.new(0, 0, 0, 35)
StatusText.BackgroundTransparency = 1
StatusText.Text = 'STATUS: MORTAL'
StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusText.TextSize = 12
StatusText.Font = Enum.Font.GothamBold
StatusText.Parent = MainFrame

local ToggleBtn = Instance.new('TextButton', MainFrame)
ToggleBtn.Size = UDim2.new(0.8, 0, 0, 40)
ToggleBtn.Position = UDim2.new(0.1, 0, 0, 65)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(20, 60, 40)
ToggleBtn.Text = 'ASCEND [P]'
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 14
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = MainFrame
Instance.new('UICorner', ToggleBtn).CornerRadius = UDim.new(0, 4)

local StatsText = Instance.new('TextLabel', MainFrame)
StatsText.Size = UDim2.new(1, 0, 0, 130)
StatsText.Position = UDim2.new(0.1, 0, 0, 115)
StatsText.BackgroundTransparency = 1
StatsText.Text = '[✓] Core God Mode\n[✗] Hook Removed (Better FPS)\n[✓] Explosion Immunity\n[✓] Anti-Seat (Event Driven)\n[✓] Async Hitboxes (No Lag)\n[✓] Smart Projectiles'
StatsText.TextColor3 = Color3.fromRGB(200, 255, 220)
StatsText.TextSize = 11
StatsText.TextXAlignment = Enum.TextXAlignment.Left
StatsText.Font = Enum.Font.Code
StatsText.Parent = MainFrame

-- ==========================================
-- [ 引擎：神化機制啟動 ]
-- ==========================================
local function StartApotheosis()
    local char = LocalPlayer.Character
    if not char then return end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then return end

    -- 關閉跌倒與物理狀態
    hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
    
    realCFrame = hrp.CFrame

    -- [優化] 防強制黏著改為事件驅動
    characterConnection = char.ChildAdded:Connect(function(child)
        if isActive and child:IsA("Weld") and child.Name == "SeatWeld" then
            task.delay(0, function() pcall(function() child:Destroy() end) end)
        end
    end)

    -- [優化] 投擲物監聽早退機制
    workspaceConnection = workspace.DescendantAdded:Connect(function(desc)
        if not isActive then return end
        
        -- 直接消除爆炸傷害
        if desc:IsA("Explosion") then
            desc.BlastRadius = 0
            desc.BlastPressure = 0
            task.delay(0, function() pcall(function() desc:Destroy() end) end)
            return
        end
        
        if desc:IsA("BasePart") then
            local myChar = LocalPlayer.Character
            if not myChar or not myChar.PrimaryPart then return end
            
            pcall(function()
                -- 只有在靠近玩家時才處理投擲物
                if (desc.Position - myChar.PrimaryPart.Position).Magnitude < 15 then
                    task.delay(0.05, function()
                        pcall(function()
                            if desc.AssemblyLinearVelocity.Magnitude > 30 then
                                desc.Size = PROJECTILE_SIZE
                                desc.Transparency = 0.5
                                desc.CanCollide = false
                            end
                        end)
                    end)
                end
            end)
        end
    end)

    -- [優化] 每幀穿牆與防坐下
    heartbeatConnection = RunService.Heartbeat:Connect(function()
        if not isActive then return end
        local currentChar = LocalPlayer.Character
        if currentChar then
            -- 使用淺層掃描，極大提升效能
            for _, part in ipairs(currentChar:GetChildren()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
            
            local currentHum = currentChar:FindFirstChild("Humanoid")
            if currentHum and currentHum.Sit then
                currentHum.Sit = false
                currentHum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end)

    -- 鎖定真實座標
    renderConnection = RunService.RenderStepped:Connect(function()
        if not isActive then return end
        local currentHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if currentHrp and realCFrame then
            currentHrp.CFrame = realCFrame
            currentHrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            currentHrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end
    end)

    -- 虛擬分身發射 (無敵核心)
    steppedConnection = RunService.Stepped:Connect(function()
        if not isActive then return end
        local currentHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if currentHrp then
            realCFrame = currentHrp.CFrame
            
            local jitterOffset = Vector3.new(
                math.random(-JITTER_STRENGTH, JITTER_STRENGTH),
                math.random(-JITTER_STRENGTH, JITTER_STRENGTH),
                math.random(-JITTER_STRENGTH, JITTER_STRENGTH)
            )

            local spinbotAngle = CFrame.Angles(
                math.rad(math.random(0, 360)), 
                math.rad(math.random(0, 360)), 
                math.rad(math.random(0, 360))
            )

            -- 將 HRP 移至高空並加上高速旋轉，使伺服器無法判定受擊
            currentHrp.CFrame = (realCFrame + SHADOW_OFFSET + jitterOffset) * spinbotAngle
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
        StatusText.Text = 'STATUS: GOD MODE'
        StatusText.TextColor3 = Color3.fromRGB(0, 255, 150)
        MainStroke.Color = Color3.fromRGB(0, 255, 150)
        ToggleBtn.Text = 'DESCEND [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(30, 100, 60) or Color3.fromRGB(20, 80, 50)
    else
        StatusText.Text = 'STATUS: MORTAL'
        StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
        MainStroke.Color = Color3.fromRGB(100, 100, 100)
        ToggleBtn.Text = 'ASCEND [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(40, 80, 60) or Color3.fromRGB(20, 60, 40)
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

LocalPlayer.CharacterAdded:Connect(function()
    if isActive then
        task.wait(0.5)
        StartApotheosis()
    end
end)
