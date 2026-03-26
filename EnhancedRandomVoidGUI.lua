local fenv = getfenv()
fenv.require = function() end

local RunService = game:GetService('RunService')
local Players = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')
local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- [ 清除舊版 GUI ]
-- ==========================================
local function ForceCleanOldGUIs()
    for _, guiName in ipairs({'VoidGUI', 'UltimateVoidGUI', 'OblivionProtocolGUI', 'AegisGUI', 'ZeroLagGUI'}) do
        pcall(function()
            local pg = LocalPlayer:FindFirstChild("PlayerGui")
            if pg and pg:FindFirstChild(guiName) then pg[guiName]:Destroy() end
            local cg = game:GetService("CoreGui")
            if cg and cg:FindFirstChild(guiName) then cg[guiName]:Destroy() end
        end)
    end
end
ForceCleanOldGUIs()

-- [ 狀態與記憶體 ]
local isMasterActive = false
local connections = {}
local originalEnemySizes = {}
local originalPhysicalProps = {}
local originalStates = {}
local myForceField = nil

-- ==========================================
-- [ 極簡 Hitbox 邏輯 ]
-- ==========================================
local function ExpandEnemyHitbox(char)
    if not char or char == LocalPlayer.Character then return end
    local hrp = char:WaitForChild("HumanoidRootPart", 3)
    if not hrp then return end
    
    if not originalEnemySizes[hrp] then originalEnemySizes[hrp] = hrp.Size end
    
    hrp.Size = Vector3.new(60, 60, 60)
    hrp.Transparency = 0.8
    hrp.BrickColor = BrickColor.new("Bright red")
    hrp.Material = Enum.Material.ForceField
    hrp.CanCollide = false
end

local function RestoreEnemyHitboxes()
    for hrp, size in pairs(originalEnemySizes) do
        if hrp and hrp.Parent then hrp.Size = size hrp.Transparency = 1 end
    end
    originalEnemySizes = {}
end

-- ==========================================
-- [ 核心防禦：幽靈觸碰與無限質量 ]
-- ==========================================
local function ApplyPartPhysics(part)
    if not part:IsA("BasePart") then return end
    if not originalPhysicalProps[part] then
        originalPhysicalProps[part] = { Prop = part.CustomPhysicalProperties, Touch = part.CanTouch }
    end
    
    part.CustomPhysicalProperties = PhysicalProperties.new(math.huge, 0, 0, math.huge, math.huge)
    part.Massless = true
    
    if not part:FindFirstAncestorOfClass("Tool") then
        part.CanTouch = false
    end
end

-- ==========================================
-- [ Anti-Remote Kill (事件驅動，零延遲) ]
-- ==========================================
local function ApplyAntiKill(char)
    local hum = char:WaitForChild("Humanoid", 3)
    local hrp = char:WaitForChild("HumanoidRootPart", 3)
    if not hum or not hrp then return end

    -- 1. 瞬間鎖血 (取代無限迴圈，只有扣血時觸發，效能極佳)
    connections.HealthLock = hum:GetPropertyChangedSignal("Health"):Connect(function()
        if isMasterActive and hum.Health < hum.MaxHealth and hum.Health > 0 then
            hum.Health = hum.MaxHealth
        end
    end)

    -- 2. 免疫遠程處決狀態
    hum.BreakJointsOnDeath = false 
    hum.RequiresNeck = false       
    local badStates = {
        Enum.HumanoidStateType.Dead, Enum.HumanoidStateType.Ragdoll,
        Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Stunned
    }
    for _, s in ipairs(badStates) do
        if originalStates[s] == nil then pcall(function() originalStates[s] = hum:GetStateEnabled(s) end) end
        pcall(function() hum:SetStateEnabled(s, false) end)
    end

    -- 3. 反外掛強制綁定 (Anti-Attach/Bring)
    connections.AntiAttach = char.DescendantAdded:Connect(function(desc)
        if not isMasterActive then return end
        if desc:IsA("BodyVelocity") or desc:IsA("BodyPosition") or desc:IsA("RocketPropulsion") or desc:IsA("WeldConstraint") then
            -- 如果外掛試圖把異常推力或綁定物放在你的根部位，瞬間銷毀
            if desc.Parent == hrp then
                task.defer(function() pcall(function() desc:Destroy() end) end)
            end
        end
    end)
end

local function ApplyAegisMode(char)
    if not char then return end
    if not isMasterActive then return end

    if not myForceField or not myForceField.Parent then
        myForceField = Instance.new("ForceField")
        myForceField.Visible = false
        myForceField.Parent = char
    end

    ApplyAntiKill(char)

    for _, part in ipairs(char:GetDescendants()) do ApplyPartPhysics(part) end
    connections.CharDescendant = char.DescendantAdded:Connect(ApplyPartPhysics)
end

-- ==========================================
-- [ UI 介面設定 ]
-- ==========================================
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'ZeroLagGUI'
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999999
pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new('Frame')
MainFrame.Name = 'MainFrame'
MainFrame.Size = UDim2.new(0, 260, 0, 100)
MainFrame.Position = UDim2.new(0.5, -130, 0.5, -50)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui
Instance.new('UICorner', MainFrame).CornerRadius = UDim.new(0, 6)

local UIStroke = Instance.new('UIStroke')
UIStroke.Color = Color3.fromRGB(0, 255, 150)
UIStroke.Thickness = 2
UIStroke.Parent = MainFrame

local TopBar = Instance.new('Frame')
TopBar.Size = UDim2.new(1, 0, 0, 25)
TopBar.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame
Instance.new('UICorner', TopBar).CornerRadius = UDim.new(0, 6)

local Title = Instance.new('TextLabel')
Title.Size = UDim2.new(1, 0, 1, 0)
Title.BackgroundTransparency = 1
Title.Text = '⚡ V7.1 ZERO-LAG (Anti-Explosion)'
Title.TextColor3 = Color3.fromRGB(150, 255, 200)
Title.TextSize = 12
Title.Font = Enum.Font.GothamBold
Title.Parent = TopBar

local MasterButton = Instance.new('TextButton')
MasterButton.Size = UDim2.new(1, -20, 0, 45)
MasterButton.Position = UDim2.new(0, 10, 0, 40)
MasterButton.BackgroundColor3 = Color3.fromRGB(0, 150, 80)
MasterButton.BorderSizePixel = 0
MasterButton.Text = 'ACTIVATE DEFENSE'
MasterButton.TextColor3 = Color3.fromRGB(255, 255, 255)
MasterButton.TextSize = 14
MasterButton.Font = Enum.Font.GothamBold
MasterButton.Parent = MainFrame
Instance.new('UICorner', MasterButton).CornerRadius = UDim.new(0, 6)

-- 拖曳功能
local dragging, dragInput, dragStart, startPos
TopBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
TopBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- ==========================================
-- [ 核心啟動邏輯 ]
-- ==========================================
local function ToggleAll()
    isMasterActive = not isMasterActive

    if isMasterActive then
        MasterButton.Text = 'DEACTIVATE'
        MasterButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        UIStroke.Color = Color3.fromRGB(255, 100, 100)
        
        ApplyAegisMode(LocalPlayer.Character)
        connections.CharAdded = LocalPlayer.CharacterAdded:Connect(function(char)
            task.delay(0.5, function() ApplyAegisMode(char) end)
        end)

        -- [ Anti-Explosion (反爆炸 - 事件驅動) ]
        -- 不掃描地圖，只有當新物件生成時檢查是否為爆炸物
        connections.AntiExplode = workspace.DescendantAdded:Connect(function(desc)
            if desc:IsA("Explosion") then
                -- 瞬間瓦解爆炸威力，防止被炸飛或秒殺
                desc.BlastPressure = 0
                desc.BlastRadius = 0
                desc.DestroyJointRadiusPercent = 0
                desc.Visible = false
                task.defer(function() pcall(function() desc:Destroy() end) end)
            end
        end)

        -- 基礎維護迴圈 (處理物理狀態)
        connections.FastLoop = RunService.Heartbeat:Connect(function()
            local char = LocalPlayer.Character
            if not char then return end
            
            local hrp = char:FindFirstChild('HumanoidRootPart')
            local hum = char:FindFirstChild('Humanoid')

            if hum then
                if hum.Sit then hum.Sit = false end
                if hum.PlatformStand then hum.PlatformStand = false end
            end

            if hrp then
                -- 反虛空 (Anti-Void)
                if hrp.Position.Y < -300 then
                    hrp.CFrame = hrp.CFrame + Vector3.new(0, 400, 0)
                    hrp.AssemblyLinearVelocity = Vector3.zero
                end
                
                -- Anti-NaN Crash (防止伺服器發送無效座標導致遊戲閃退)
                if hrp.AssemblyLinearVelocity.X ~= hrp.AssemblyLinearVelocity.X then
                    hrp.AssemblyLinearVelocity = Vector3.zero
                end

                -- 反異常擊飛 (Anti-Fling)
                if hrp.AssemblyAngularVelocity.Magnitude > 50 or hrp.AssemblyLinearVelocity.Magnitude > 250 then
                    hrp.AssemblyAngularVelocity = Vector3.zero
                    hrp.AssemblyLinearVelocity = Vector3.zero
                end
            end
        end)

        -- Hitbox 放大
        for _, plr in ipairs(Players:GetPlayers()) do ExpandEnemyHitbox(plr.Character) end
        connections.PlayerAdded = Players.PlayerAdded:Connect(function(plr)
            connections["Plr_"..plr.Name] = plr.CharacterAdded:Connect(function(char)
                task.delay(1, function() ExpandEnemyHitbox(char) end)
            end)
        end)

    else
        -- 關閉與還原
        MasterButton.Text = 'ACTIVATE DEFENSE'
        MasterButton.BackgroundColor3 = Color3.fromRGB(0, 150, 80)
        UIStroke.Color = Color3.fromRGB(0, 255, 150)

        for key, conn in pairs(connections) do
            if conn then conn:Disconnect() end
        end
        connections = {}
        RestoreEnemyHitboxes()

        local char = LocalPlayer.Character
        if myForceField then myForceField:Destroy() myForceField = nil end

        if char then
            local hum = char:FindFirstChild("Humanoid")
            if hum then
                hum.RequiresNeck = true
                hum.BreakJointsOnDeath = true
                for stateType, isEnabled in pairs(originalStates) do
                    pcall(function() hum:SetStateEnabled(stateType, isEnabled) end)
                end
            end
            for part, data in pairs(originalPhysicalProps) do
                if part and part.Parent then 
                    part.CustomPhysicalProperties = data.Prop 
                    part.CanTouch = data.Touch
                end
            end
        end

        originalPhysicalProps = {}
        originalStates = {}
    end
end

MasterButton.MouseButton1Click:Connect(ToggleAll)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.RightShift then
        MainFrame.Visible = not MainFrame.Visible
    end
end)
