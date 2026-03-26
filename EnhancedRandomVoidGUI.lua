local fenv = getfenv()
fenv.require = function() end

math.randomseed(os.time())

local RunService = game:GetService('RunService')
local Players = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')
local Workspace = game:GetService('Workspace')
local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- [ 清除舊版 GUI ]
-- ==========================================
local function ForceCleanOldGUIs()
    local guiNamesToDelete = {'VoidGUI', 'UltimateVoidGUI', 'OblivionProtocolGUI'}
    for _, guiName in ipairs(guiNamesToDelete) do
        pcall(function()
            local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
            if playerGui and playerGui:FindFirstChild(guiName) then
                playerGui[guiName]:Destroy()
            end
            local coreGui = game:GetService("CoreGui")
            if coreGui and coreGui:FindFirstChild(guiName) then
                coreGui[guiName]:Destroy()
            end
        end)
    end
end
ForceCleanOldGUIs()

-- [ 狀態與記憶體 ]
local isMasterActive = false
local connections = {}
local originalPhysicalProperties = {}
local originalStates = {}
local originalFallenHeight = Workspace.FallenPartsDestroyHeight
local lastSafeCFrame = nil

local originalSizes = setmetatable({}, {__mode = "k"})
local originalProjSizes = setmetatable({}, {__mode = "k"})
local myProjectiles = setmetatable({}, {__mode = "k"})

-- 肉體白名單 (確保能打出傷害)
local coreBodyParts = {
    ["HumanoidRootPart"] = true, ["Head"] = true, ["Torso"] = true, 
    ["UpperTorso"] = true, ["LowerTorso"] = true, ["Left Arm"] = true, 
    ["Right Arm"] = true, ["Left Leg"] = true, ["Right Leg"] = true, 
    ["LeftUpperArm"] = true, ["RightUpperArm"] = true, ["LeftLowerArm"] = true, 
    ["RightLowerArm"] = true, ["LeftUpperLeg"] = true, ["RightUpperLeg"] = true, 
    ["LeftLowerLeg"] = true, ["RightLowerLeg"] = true, ["LeftFoot"] = true, 
    ["RightFoot"] = true, ["LeftHand"] = true, ["RightHand"] = true
}

local function GetHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild('HumanoidRootPart')
end

local function GetHum()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild('Humanoid')
end

-- ==========================================
-- [ ★ 防卡死版：底層 Metatable 幻術 ★ ]
-- ==========================================
local OldNamecall
local OldNewIndex
local OldIndex

if hookmetamethod then
    OldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        -- 【防崩潰】確保傳入的是 Instance
        if isMasterActive and typeof(self) == "Instance" then
            if method == "Kick" or method == "kick" then
                if self == LocalPlayer then return nil end
            elseif method == "TakeDamage" or method == "BreakJoints" then
                local char = LocalPlayer.Character
                if char and (self == char or self:IsDescendantOf(char)) then return nil end
            end
        end
        return OldNamecall(self, ...)
    end)

    OldNewIndex = hookmetamethod(game, "__newindex", function(self, key, value)
        if isMasterActive and not checkcaller() and typeof(self) == "Instance" then
            if key == "Health" and self:IsA("Humanoid") then
                local char = LocalPlayer.Character
                if char and self:IsDescendantOf(char) then
                    return -- 鎖定血量寫入，維持 0 血狀態
                end
            end
        end
        return OldNewIndex(self, key, value)
    end)

    OldIndex = hookmetamethod(game, "__index", function(self, key)
        if isMasterActive and not checkcaller() and typeof(self) == "Instance" then
            if self:IsA("Humanoid") then
                local char = LocalPlayer.Character
                if char and self:IsDescendantOf(char) then
                    -- 【修復無限遞迴】使用 OldIndex 獲取 MaxHealth，防止 Stack Overflow
                    if key == "Health" then return OldIndex(self, "MaxHealth") end
                    if key == "Dead" then return false end
                end
            end
        end
        return OldIndex(self, key)
    end)
end

-- ==========================================
-- [ 效能優化版：敵人破甲與 Hitbox 處理 ]
-- ==========================================
local function ProcessEnemyPart(part)
    if not part:IsA("BasePart") or part.Name == "HumanoidRootPart" then return end
    
    if not coreBodyParts[part.Name] then
        -- 剝奪背部盾牌、飾品、武器的空間判定
        part.CanCollide = false
        part.CanTouch = false
        pcall(function() part.CanQuery = false end)
        
        if part.Parent:IsA("Accessory") or part.Parent:IsA("Tool") or part.Name:lower():match("shield") then
            part.Transparency = 1
            if part.Size.X > 0.1 then part.Size = Vector3.new(0.01, 0.01, 0.01) end
        end
    else
        -- 保留肉體判定
        part.CanTouch = true
        pcall(function() part.CanQuery = true end)
    end
end

local function ExpandEnemyHitbox(char)
    if not char or char == LocalPlayer.Character then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    
    if hrp then
        if not originalSizes[hrp] then originalSizes[hrp] = hrp.Size end
        hrp.Size = Vector3.new(60, 60, 60)
        hrp.Transparency = 0.85
        hrp.BrickColor = BrickColor.new("Bright red")
        hrp.Material = Enum.Material.ForceField
        hrp.CanCollide = false
        hrp.CanTouch = true
    end

    for _, part in ipairs(char:GetDescendants()) do
        ProcessEnemyPart(part)
    end
end

local function ExpandToolHitbox(tool)
    if tool:IsA("Tool") then
        myProjectiles[tool] = true
        for _, part in ipairs(tool:GetDescendants()) do
            if part:IsA("BasePart") and part.Name == "Handle" then
                if not originalProjSizes[part] then originalProjSizes[part] = part.Size end
                part.Size = Vector3.new(60, 60, 60)
                part.Transparency = 0.8
                part.BrickColor = BrickColor.new("Cyan")
                part.Material = Enum.Material.ForceField
                part.Massless = true
                part.CanCollide = false
                part.CanTouch = true
                pcall(function() part.CanQuery = true end)
                myProjectiles[part] = true
            end
        end
    end
end

-- ==========================================
-- [ 玩家初始化：喪屍無敵 & 防禦套用 ]
-- ==========================================
local function ApplyOneTimeSetups(char)
    if not char then return end
    local hum = char:WaitForChild("Humanoid", 3)
    local hrp = char:WaitForChild("HumanoidRootPart", 3)
    
    if not isMasterActive then return end

    if hrp then
        pcall(function() sethiddenproperty(hrp, "NetworkIsSleeping", true) end)
        lastSafeCFrame = hrp.CFrame
    end

    if hum then
        hum.BreakJointsOnDeath = false 
        hum.RequiresNeck = false       
        
        local badStates = {
            Enum.HumanoidStateType.Dead, Enum.HumanoidStateType.Ragdoll,
            Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Physics,
            Enum.HumanoidStateType.PlatformStanding, Enum.HumanoidStateType.Stunned,
            Enum.HumanoidStateType.Seated
        }
        for _, s in ipairs(badStates) do
            if originalStates[s] == nil then originalStates[s] = hum:GetStateEnabled(s) end
            hum:SetStateEnabled(s, false)
        end

        hum.Health = 0 -- 觸發 0 血量伺服器欺騙
    end

    connections.ToolEquip = char.ChildAdded:Connect(ExpandToolHitbox)
    for _, tool in ipairs(char:GetChildren()) do
        ExpandToolHitbox(tool)
    end
end

LocalPlayer.CharacterAdded:Connect(function(char)
    originalPhysicalProperties = {}
    if isMasterActive then
        task.spawn(function()
            task.wait(0.2)
            ApplyOneTimeSetups(char)
        end)
    end
end)

-- ==========================================
-- [ UI 介面 ]
-- ==========================================
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'OblivionProtocolGUI'
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999999

local success, core = pcall(function() return game:GetService("CoreGui") end)
ScreenGui.Parent = success and core or LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new('Frame')
MainFrame.Name = 'MainFrame'
MainFrame.Size = UDim2.new(0, 260, 0, 100)
MainFrame.Position = UDim2.new(0.5, -130, 0.5, -50)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 10, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new('UICorner')
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

local UIStroke = Instance.new('UIStroke')
UIStroke.Color = Color3.fromRGB(170, 0, 255)
UIStroke.Thickness = 2
UIStroke.Parent = MainFrame

local TopBar = Instance.new('Frame')
TopBar.Size = UDim2.new(1, 0, 0, 30)
TopBar.BackgroundColor3 = Color3.fromRGB(40, 20, 60)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame
Instance.new('UICorner', TopBar).CornerRadius = UDim.new(0, 8)

local TopBarFix = Instance.new('Frame')
TopBarFix.Size = UDim2.new(1, 0, 0, 10)
TopBarFix.Position = UDim2.new(0, 0, 1, -10)
TopBarFix.BackgroundColor3 = Color3.fromRGB(40, 20, 60)
TopBarFix.BorderSizePixel = 0
TopBarFix.Parent = TopBar

local Title = Instance.new('TextLabel')
Title.Size = UDim2.new(1, 0, 1, 0)
Title.BackgroundTransparency = 1
Title.Text = '⚡ OBLIVION PROTOCOL V4'
Title.TextColor3 = Color3.fromRGB(220, 180, 255)
Title.TextSize = 13
Title.Font = Enum.Font.GothamBold
Title.Parent = TopBar

local MasterButton = Instance.new('TextButton')
MasterButton.Size = UDim2.new(1, -20, 0, 45)
MasterButton.Position = UDim2.new(0, 10, 0, 42)
MasterButton.BackgroundColor3 = Color3.fromRGB(100, 0, 180)
MasterButton.BorderSizePixel = 0
MasterButton.Text = 'ACTIVATE GOD MODE'
MasterButton.TextColor3 = Color3.fromRGB(255, 255, 255)
MasterButton.TextSize = 13
MasterButton.Font = Enum.Font.GothamBold
MasterButton.Parent = MainFrame
Instance.new('UICorner', MasterButton).CornerRadius = UDim.new(0, 6)

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
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- ==========================================
-- [ 核心邏輯：防卡死事件驅動迴圈 ]
-- ==========================================
local function ToggleAll()
    isMasterActive = not isMasterActive

    if isMasterActive then
        MasterButton.Text = 'DEACTIVATE'
        MasterButton.BackgroundColor3 = Color3.fromRGB(180, 40, 60)
        UIStroke.Color = Color3.fromRGB(255, 60, 80)
        TopBar.BackgroundColor3 = Color3.fromRGB(60, 20, 30)
        TopBarFix.BackgroundColor3 = Color3.fromRGB(60, 20, 30)
        Title.TextColor3 = Color3.fromRGB(255, 180, 180)
    else
        MasterButton.Text = 'ACTIVATE GOD MODE'
        MasterButton.BackgroundColor3 = Color3.fromRGB(100, 0, 180)
        UIStroke.Color = Color3.fromRGB(170, 0, 255)
        TopBar.BackgroundColor3 = Color3.fromRGB(40, 20, 60)
        TopBarFix.BackgroundColor3 = Color3.fromRGB(40, 20, 60)
        Title.TextColor3 = Color3.fromRGB(220, 180, 255)
    end

    for key, conn in pairs(connections) do
        if conn then conn:Disconnect() end
    end
    connections = {}

    if isMasterActive then
        ApplyOneTimeSetups(LocalPlayer.Character)
        pcall(function() Workspace.FallenPartsDestroyHeight = -9e9 end)

        -- 1. 輕量化反傳送與反虛空 (RenderStepped 專門處理本體 CFrame)
        connections.AntiBring = RunService.RenderStepped:Connect(function()
            local hrp = GetHRP()
            if hrp then
                if lastSafeCFrame then
                    local distance = (hrp.Position - lastSafeCFrame.Position).Magnitude
                    if hrp.Position.Y < -500 then
                        hrp.CFrame = lastSafeCFrame + Vector3.new(0, 50, 0)
                        hrp.AssemblyLinearVelocity = Vector3.zero
                    elseif distance > 150 then
                        hrp.CFrame = lastSafeCFrame
                        hrp.AssemblyLinearVelocity = Vector3.zero
                    else
                        lastSafeCFrame = hrp.CFrame
                    end
                else
                    lastSafeCFrame = hrp.CFrame
                end
                if hrp.Anchored then hrp.Anchored = false end
            end
        end)

        -- 2. 物理領域 (限制頻率，每 0.1 秒執行一次，不再卡死)
        local lastPhysicsUpdate = 0
        connections.PhysicsStepped = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild('HumanoidRootPart')

            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        if not originalPhysicalProperties[part] then
                            originalPhysicalProperties[part] = part.CustomPhysicalProperties
                        end
                        part.CustomPhysicalProperties = PhysicalProperties.new(math.huge, 0, 0, math.huge, math.huge)
                        part.CanCollide = false
                        part.Massless = true
                        
                        if part:FindFirstAncestorOfClass("Tool") or part.Name:match("Hand") or part.Name:match("Arm") then
                            part.CanTouch = true
                            pcall(function() part.CanQuery = true end)
                        else
                            part.CanTouch = false
                            pcall(function() part.CanQuery = false end)
                        end
                    end
                end
                
                -- 【防卡死優化】反 Fling 領域限流
                if hrp and (tick() - lastPhysicsUpdate > 0.1) then
                    lastPhysicsUpdate = tick()
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    hrp.AssemblyAngularVelocity = Vector3.zero
                    
                    local nearbyParts = Workspace:GetPartBoundsInRadius(hrp.Position, 45)
                    for _, part in ipairs(nearbyParts) do
                        if part:IsA("BasePart") and not part:IsDescendantOf(char) and not part.Anchored then
                            if not myProjectiles[part] and not myProjectiles[part.Parent] then
                                part.AssemblyLinearVelocity = Vector3.zero
                                part.AssemblyAngularVelocity = Vector3.zero
                                part.CanCollide = false
                                part.CanTouch = false
                                pcall(function() part.CanQuery = false end)
                                pcall(function() part.CFrame = CFrame.new(0, -99999, 0) end)
                            end
                        end
                    end
                end
            end
        end)

        -- 3. 極簡狀態維持 (維持 0 血量與拔除異常控制)
        connections.MaintainZombie = RunService.Heartbeat:Connect(function()
            local char = LocalPlayer.Character
            if char then
                local hum = char:FindFirstChild('Humanoid')
                local hrp = char:FindFirstChild('HumanoidRootPart')
                if hum then
                    if hum.Health > 0 then hum.Health = 0 end
                    if hum.Sit then hum.Sit = false end
                    if hum.PlatformStand then hum.PlatformStand = false end
                end
                
                if hrp then
                    for _, v in ipairs(hrp:GetChildren()) do
                        if v:IsA("BodyModifier") or v:IsA("BodyPosition") or v:IsA("BodyVelocity") or v:IsA("BodyGyro") or v:IsA("AngularVelocity") or v:IsA("LinearVelocity") or v:IsA("RocketPropulsion") then
                            v:Destroy()
                        end
                    end
                end
            end
        end)

        -- 4. 事件驅動：處理場上現有玩家 (單次執行)
        for _, obj in ipairs(Workspace:GetChildren()) do
            if obj:IsA("Model") and obj:FindFirstChild("Humanoid") then ExpandEnemyHitbox(obj) end
        end

        -- 5. 事件驅動：監聽新加入的物體 (取代全域迴圈掃描，效能巨幅提升)
        connections.WorldMonitor = Workspace.DescendantAdded:Connect(function(obj)
            if not isMasterActive then return end
            
            if obj:IsA("Explosion") or obj:IsA("TouchTransmitter") then
                task.defer(function() pcall(function() obj:Destroy() end) end)
                return
            end
            
            if obj:IsA("Model") then
                task.delay(0.5, function()
                    if obj and obj.Parent and obj:FindFirstChild("Humanoid") then ExpandEnemyHitbox(obj) end
                end)
            end
            
            -- 動態剝奪敵方新生成的裝備
            if obj:IsA("BasePart") and obj.Parent and obj.Parent:IsA("Model") and obj.Parent ~= LocalPlayer.Character then
                if obj.Parent:FindFirstChild("Humanoid") then
                    ProcessEnemyPart(obj)
                end
            end
        end)

        connections.NewPlayer = Players.PlayerAdded:Connect(function(plr)
            connections["Plr_"..plr.Name] = plr.CharacterAdded:Connect(function(char)
                task.delay(0.5, function() ExpandEnemyHitbox(char) end)
            end)
        end)

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                connections["Plr_"..plr.Name] = plr.CharacterAdded:Connect(function(char)
                    task.delay(0.5, function() ExpandEnemyHitbox(char) end)
                end)
            end
        end

    else
        -- 關閉時還原所有狀態
        local char = LocalPlayer.Character
        local hum = GetHum()
        
        pcall(function() Workspace.FallenPartsDestroyHeight = originalFallenHeight end)

        if hum then
            hum.RequiresNeck = true
            hum.BreakJointsOnDeath = true
            for stateType, isEnabled in pairs(originalStates) do
                hum:SetStateEnabled(stateType, isEnabled)
            end
            hum.Health = hum.MaxHealth
        end

        if char then
            for part, props in pairs(originalPhysicalProperties) do
                if part and part.Parent then part.CustomPhysicalProperties = props end
            end
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then 
                    part.CanTouch = true 
                    pcall(function() part.CanQuery = true end)
                end
            end
        end

        for part, size in pairs(originalSizes) do
            if part and part.Parent then
                part.Size = size
                part.Transparency = 1
                part.Material = Enum.Material.Plastic
            end
        end
        for part, size in pairs(originalProjSizes) do
            if part and part.Parent then
                part.Size = size
                part.Transparency = 0 
                part.Material = Enum.Material.Plastic
            end
        end

        originalPhysicalProperties = {}
        originalStates = {}
        originalSizes = setmetatable({}, {__mode = "k"})
        originalProjSizes = setmetatable({}, {__mode = "k"})
        myProjectiles = setmetatable({}, {__mode = "k"})
        lastSafeCFrame = nil
    end
end

MasterButton.MouseButton1Click:Connect(ToggleAll)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed then
        if input.KeyCode == Enum.KeyCode.RightShift then
            MainFrame.Visible = not MainFrame.Visible
        end
    end
end)
