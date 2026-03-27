local fenv = getfenv()
fenv.require = function() end

-- [[ VOID x AEGIS V20: THE SINGULARITY (極端非對稱判定版) ]] --
-- 敵人 Hitbox 擴張至極限 (2048)
-- 自身 Hitbox 壓縮至極限 (0.05)

local Players = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')
local RunService = game:GetService('RunService')

local LocalPlayer = Players.LocalPlayer
local toggleKey = Enum.KeyCode.P

-- ==========================================
-- [ 核心奇點參數 ]
-- ==========================================
local OVERFLOW_VAL = 2e22
local QUANTUM_RADIUS = 500000
local FORCEFIELD_RADIUS = 100
local MAX_HITBOX = Vector3.new(2048, 2048, 2048) -- 敵人極大化
local MIN_HITBOX = Vector3.new(0.05, 0.05, 0.05) -- 自身極小化 (Roblox 引擎極限)

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
-- [ 異步 Hitbox 處理 (極端放大與極端縮小) ]
-- ==========================================
task.spawn(function()
    while true do
        task.wait(0.5)
        if isActive then
            -- [1] 放大敵人 (最大化)
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character then
                    -- 用戶指定的絕對路徑擴張
                    pcall(function()
                        if workspace:FindFirstChild(plr.Name) and workspace[plr.Name]:FindFirstChild("HitboxHead") then
                            workspace[plr.Name].HitboxHead.Size = MAX_HITBOX
                            workspace[plr.Name].HitboxHead.Transparency = 0.85
                            workspace[plr.Name].HitboxHead.CanCollide = false
                            workspace[plr.Name].HitboxHead.Massless = true
                        end
                    end)

                    -- 備用：連同 HumanoidRootPart 一起放大
                    pcall(function()
                        local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
                        if hrp and hrp.Size.X < 2000 then
                            hrp.Size = MAX_HITBOX
                            hrp.Transparency = 0.85
                            hrp.CanCollide = false
                        end
                    end)
                end
            end

            -- [2] 縮小自己 (最小化)
            local myChar = LocalPlayer.Character
            if myChar then
                -- 將自己的核心受擊部位全部縮小成一個點
                local shrinkTargets = {"HitboxHead", "Head", "HumanoidRootPart", "Torso", "UpperTorso"}
                for _, partName in ipairs(shrinkTargets) do
                    local part = myChar:FindFirstChild(partName)
                    if part then
                        pcall(function()
                            part.Size = MIN_HITBOX
                            part.Transparency = 1 -- 讓自己完全隱形，敵人連殘影都看不到
                        end)
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
ScreenGui.Name = 'VoidSingularityGUI'
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = game:GetService('CoreGui') end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new('Frame')
MainFrame.Name = 'MainFrame'
MainFrame.Size = UDim2.new(0, 310, 0, 310) 
MainFrame.Position = UDim2.new(0.85, -50, 0.75, -110)
MainFrame.BackgroundColor3 = Color3.fromRGB(5, 0, 15) 
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true 
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new('UICorner', MainFrame)
MainCorner.CornerRadius = UDim.new(0, 8)

local MainStroke = Instance.new('UIStroke', MainFrame)
MainStroke.Color = Color3.fromRGB(150, 0, 255)
MainStroke.Thickness = 2

local TitleText = Instance.new('TextLabel', MainFrame)
TitleText.Size = UDim2.new(1, 0, 0, 30)
TitleText.BackgroundTransparency = 1
TitleText.Text = '🌌 V20 THE SINGULARITY'
TitleText.TextColor3 = Color3.fromRGB(200, 100, 255)
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
ToggleBtn.BackgroundColor3 = Color3.fromRGB(40, 0, 80)
ToggleBtn.Text = 'ENTER SINGULARITY [P]'
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 14
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = MainFrame
Instance.new('UICorner', ToggleBtn).CornerRadius = UDim.new(0, 4)

local StatsText = Instance.new('TextLabel', MainFrame)
StatsText.Size = UDim2.new(1, 0, 0, 180)
StatsText.Position = UDim2.new(0.1, 0, 0, 115)
StatsText.BackgroundTransparency = 1
StatsText.Text = '[✓] Enemy Hitbox Maximize (2048)\n[✓] Self Hitbox Minimize (0.05)\n[✓] Quantum Jitter (500k Studs)\n[✓] Aimbot Crash Inject (2e22)\n[✓] Blackhole Shield (100 Studs)\n[✓] True Ghosting & Noclip\n[✓] UE & ESP Bypass Denial'
StatsText.TextColor3 = Color3.fromRGB(220, 180, 255)
StatsText.TextSize = 12
StatsText.TextXAlignment = Enum.TextXAlignment.Left
StatsText.Font = Enum.Font.Code
StatsText.Parent = MainFrame

-- ==========================================
-- [ 引擎：奇點防禦機制啟動 ]
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

    characterConnection = char.ChildAdded:Connect(function(child)
        if isActive and child:IsA("Weld") and child.Name == "SeatWeld" then
            task.delay(0, function() pcall(function() child:Destroy() end) end)
        end
    end)

    workspaceConnection = workspace.DescendantAdded:Connect(function(desc)
        if not isActive then return end
        if desc:IsA("Explosion") then
            desc.BlastRadius = 0
            desc.BlastPressure = 0
            task.delay(0, function() pcall(function() desc:Destroy() end) end)
        end
    end)

    heartbeatConnection = RunService.Heartbeat:Connect(function()
        if not isActive then return end
        local currentChar = LocalPlayer.Character
        if not currentChar then return end

        for _, part in ipairs(currentChar:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
                pcall(function() part.CanTouch = false part.CanQuery = false end)
            end
        end
        
        local currentHum = currentChar:FindFirstChild("Humanoid")
        if currentHum and currentHum.Sit then
            currentHum.Sit = false
            currentHum:ChangeState(Enum.HumanoidStateType.Jumping)
        end

        if realCFrame then
            local threats = workspace:GetPartBoundsInRadius(realCFrame.Position, FORCEFIELD_RADIUS, overlapParams)
            for _, threat in ipairs(threats) do
                if threat:IsA("BasePart") and threat.Size.Magnitude < 100 then
                    pcall(function() threat.CanTouch = false threat.CanQuery = false end)
                    if not threat.Anchored then
                        threat.AssemblyLinearVelocity = Vector3.new(OVERFLOW_VAL, OVERFLOW_VAL, OVERFLOW_VAL)
                        threat.AssemblyAngularVelocity = Vector3.new(OVERFLOW_VAL, OVERFLOW_VAL, OVERFLOW_VAL)
                    end
                end
            end
        end
    end)

    renderConnection = RunService.RenderStepped:Connect(function()
        if not isActive then return end
        local currentHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if currentHrp and realCFrame then
            currentHrp.CFrame = realCFrame
            currentHrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            currentHrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end
    end)

    steppedConnection = RunService.Stepped:Connect(function()
        if not isActive then return end
        local currentHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if currentHrp then
            realCFrame = currentHrp.CFrame
            local quantumOffset = Vector3.new(
                math.random(-QUANTUM_RADIUS, QUANTUM_RADIUS),
                math.random(100000, QUANTUM_RADIUS),
                math.random(-QUANTUM_RADIUS, QUANTUM_RADIUS)
            )
            local spinbotAngle = CFrame.Angles(
                math.rad(math.random(0, 360)), 
                math.rad(math.random(0, 360)), 
                math.rad(math.random(0, 360))
            )
            currentHrp.CFrame = (realCFrame + quantumOffset) * spinbotAngle
            currentHrp.AssemblyLinearVelocity = Vector3.new(OVERFLOW_VAL, OVERFLOW_VAL, OVERFLOW_VAL)
            currentHrp.AssemblyAngularVelocity = Vector3.new(OVERFLOW_VAL, OVERFLOW_VAL, OVERFLOW_VAL)
        end
    end)
end

local function RestoreHitboxes()
    -- 恢復敵人
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            pcall(function()
                if workspace:FindFirstChild(plr.Name) and workspace[plr.Name]:FindFirstChild("HitboxHead") then
                    workspace[plr.Name].HitboxHead.Size = Vector3.new(2, 1, 1)
                    workspace[plr.Name].HitboxHead.Transparency = 0
                end
            end)
            pcall(function()
                if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                    plr.Character.HumanoidRootPart.Size = Vector3.new(2, 2, 1)
                    plr.Character.HumanoidRootPart.Transparency = 1
                end
            end)
        end
    end
    -- 恢復自己
    local myChar = LocalPlayer.Character
    if myChar then
        pcall(function() myChar.Head.Size = Vector3.new(2, 1, 1) myChar.Head.Transparency = 0 end)
        pcall(function() myChar.HumanoidRootPart.Size = Vector3.new(2, 2, 1) myChar.HumanoidRootPart.Transparency = 1 end)
        pcall(function() if myChar:FindFirstChild("HitboxHead") then myChar.HitboxHead.Size = Vector3.new(2, 1, 1) myChar.HitboxHead.Transparency = 0 end end)
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
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                pcall(function() part.CanTouch = true part.CanQuery = true end)
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
        StatusText.Text = 'STATUS: SINGULARITY'
        StatusText.TextColor3 = Color3.fromRGB(150, 0, 255)
        MainStroke.Color = Color3.fromRGB(150, 0, 255)
        ToggleBtn.Text = 'EXIT SINGULARITY [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(80, 0, 150) or Color3.fromRGB(60, 0, 100)
    else
        StatusText.Text = 'STATUS: VULNERABLE'
        StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
        MainStroke.Color = Color3.fromRGB(100, 100, 100)
        ToggleBtn.Text = 'ENTER SINGULARITY [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(60, 0, 100) or Color3.fromRGB(40, 0, 80)
    end
end

ToggleBtn.MouseEnter:Connect(function() isHovering = true UpdateUI() end)
ToggleBtn.MouseLeave:Connect(function() isHovering = false UpdateUI() end)
ToggleBtn.MouseButton1Click:Connect(function() isActive = not isActive UpdateUI() if isActive then StartApotheosis() else StopApotheosis() end end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == toggleKey then
        isActive = not isActive UpdateUI() if isActive then StartApotheosis() else StopApotheosis() end
    end
end)

LocalPlayer.CharacterAdded:Connect(function(newChar)
    if isActive then task.wait(0.5) overlapParams.FilterDescendantsInstances = {newChar} StartApotheosis() end
end)

