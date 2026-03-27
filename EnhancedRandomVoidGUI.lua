local fenv = getfenv()
fenv.require = function() end

-- [[ VOID x AEGIS V19.0: APOTHEOSIS (神化) ]] --
-- 狀態：神化模式 (V1~V18 全面繼承 + 遠端防殺 + 爆炸免疫 + 無限Hitbox)

local Players = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')
local RunService = game:GetService('RunService')

local LocalPlayer = Players.LocalPlayer
local toggleKey = Enum.KeyCode.P

-- ==========================================
-- [ 核心參數設置 ]
-- ==========================================
local v15 = 2e22 -- 速度過載 (X/Z)
local v16 = 2e22 -- 速度過載 (Y)
local SHADOW_OFFSET = Vector3.new(0, 50000, 0) -- 物理脫離高度
local JITTER_STRENGTH = 10 -- 輔瞄破壞強度
local ENEMY_HITBOX_SIZE = Vector3.new(60, 60, 60) -- 敵人判定框大小
local PROJECTILE_SIZE = Vector3.new(40, 40, 40) -- 你的投擲物/子彈擴張大小

local isActive = false
local realCFrame = nil

-- 連接池
local steppedConnection = nil
local renderConnection = nil
local heartbeatConnection = nil
local workspaceConnection = nil

-- ==========================================
-- [ V19: Anti-Remote Kill (Meta-Hooking) ]
-- ==========================================
-- 攔截並阻擋惡意遠端事件 (需執行器支援 hookmetamethod)
if hookmetamethod then
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        if isActive then
            local method = getnamecallmethod()
            if method == "FireServer" or method == "InvokeServer" then
                local name = string.lower(tostring(self.Name))
                -- 攔截常見的擊殺/傷害/懲罰遠端
                if name:match("kill") or name:match("damage") or name:match("punish") or name:match("kick") or name:match("ban") then
                    return nil -- 吞噬該請求，保護本體
                end
            end
        end
        return oldNamecall(self, ...)
    end)
end

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
MainFrame.Size = UDim2.new(0, 280, 0, 280)
MainFrame.Position = UDim2.new(0.85, -20, 0.75, -60)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 5, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true 
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new('UICorner', MainFrame)
MainCorner.CornerRadius = UDim.new(0, 8)

local MainStroke = Instance.new('UIStroke', MainFrame)
MainStroke.Color = Color3.fromRGB(200, 0, 255)
MainStroke.Thickness = 2

local TitleText = Instance.new('TextLabel', MainFrame)
TitleText.Size = UDim2.new(1, 0, 0, 30)
TitleText.BackgroundTransparency = 1
TitleText.Text = '🌌 V19 APOTHEOSIS'
TitleText.TextColor3 = Color3.fromRGB(220, 150, 255)
TitleText.TextSize = 16
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
ToggleBtn.BackgroundColor3 = Color3.fromRGB(60, 20, 80)
ToggleBtn.Text = 'ASCEND [P]'
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 14
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = MainFrame
Instance.new('UICorner', ToggleBtn).CornerRadius = UDim.new(0, 4)

local StatsText = Instance.new('TextLabel', MainFrame)
StatsText.Size = UDim2.new(1, 0, 0, 150)
StatsText.Position = UDim2.new(0.1, 0, 0, 115)
StatsText.BackgroundTransparency = 1
StatsText.Text = '[✓] V1-V17 Core Mechanics\n[✓] V19: Anti-Remote Kill\n[✓] V19: Explosion Immunity\n[✓] V19: Anti-Seat/Auto-Mount\n[✓] V19: Giant Enemy Hitboxes\n[✓] V19: Projectile Expansion'
StatsText.TextColor3 = Color3.fromRGB(240, 200, 255)
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

    -- [V5] Anti-Ragdoll
    hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
    
    realCFrame = hrp.CFrame

    -- [V19] Workspace 監聽 (防爆炸 & 投擲物擴張)
    workspaceConnection = workspace.DescendantAdded:Connect(function(desc)
        if not isActive then return end
        
        -- 防爆炸：瞬間抹除爆炸威力
        if desc:IsA("Explosion") then
            desc.BlastRadius = 0
            desc.BlastPressure = 0
            desc.DestroyJointRadiusPercent = 0
            task.delay(0, function() desc:Destroy() end)
        end
        
        -- 投擲物/子彈擴張 (啟發式偵測：剛生成、高速、離我很近)
        if desc:IsA("BasePart") then
            task.delay(0.05, function() -- 等待物理引擎賦予速度
                pcall(function()
                    local myChar = LocalPlayer.Character
                    if myChar and myChar.PrimaryPart and desc.AssemblyLinearVelocity.Magnitude > 30 then
                        local dist = (desc.Position - myChar.PrimaryPart.Position).Magnitude
                        if dist < 20 then -- 判定為我的投擲物
                            desc.Size = PROJECTILE_SIZE
                            desc.Transparency = 0.5
                            desc.CanCollide = false
                        end
                    end
                end)
            end)
        end
    end)

    -- [V14 + V19] Heartbeat (穿牆 + 防強制上車)
    heartbeatConnection = RunService.Heartbeat:Connect(function()
        if not isActive then return end
        local currentChar = LocalPlayer.Character
        if currentChar then
            -- 穿牆
            for _, part in pairs(currentChar:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
            -- 防強制上車/黏著
            local currentHum = currentChar:FindFirstChild("Humanoid")
            if currentHum and currentHum.Sit then
                currentHum.Sit = false
                currentHum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
            for _, weld in pairs(currentChar:GetDescendants()) do
                if weld:IsA("Weld") and weld.Name == "SeatWeld" then
                    weld:Destroy()
                end
            end
        end
    end)

    -- [V16] RenderStepped (視覺穩定)
    renderConnection = RunService.RenderStepped:Connect(function()
        if not isActive then return end
        local currentHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if currentHrp and realCFrame then
            currentHrp.CFrame = realCFrame
            currentHrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            currentHrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end
    end)

    -- [V17 + V19] Stepped (物理脫離 + 敵人Hitbox無限化)
    steppedConnection = RunService.Stepped:Connect(function()
        if not isActive then return end
        
        -- 擴張所有敵人 Hitbox (放這裡防止伺服器強制重置大小)
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                local enemyHrp = plr.Character.HumanoidRootPart
                enemyHrp.Size = ENEMY_HITBOX_SIZE
                enemyHrp.Transparency = 0.7
                enemyHrp.CanCollide = false
            end
        end

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
            enemyHrp.Size = Vector3.new(2, 2, 1) -- 恢復預設 R6/R15 大小
            enemyHrp.Transparency = 1
        end
    end
end

local function StopApotheosis()
    if renderConnection then renderConnection:Disconnect() end
    if steppedConnection then steppedConnection:Disconnect() end
    if heartbeatConnection then heartbeatConnection:Disconnect() end
    if workspaceConnection then workspaceConnection:Disconnect() end
    
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
        StatusText.TextColor3 = Color3.fromRGB(200, 0, 255)
        MainStroke.Color = Color3.fromRGB(200, 0, 255)
        ToggleBtn.Text = 'DESCEND [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(150, 40, 100) or Color3.fromRGB(120, 30, 80)
    else
        StatusText.Text = 'STATUS: MORTAL'
        StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
        MainStroke.Color = Color3.fromRGB(100, 100, 100)
        ToggleBtn.Text = 'ASCEND [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(80, 30, 100) or Color3.fromRGB(60, 20, 80)
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
