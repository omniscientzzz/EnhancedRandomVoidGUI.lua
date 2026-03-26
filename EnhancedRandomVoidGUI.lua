local fenv = getfenv()
fenv.require = function() end

-- [ 初始化隨機數種子 ] --
math.randomseed(os.time())

-- [ 核心服務 ] --
local RunService = game:GetService('RunService')
local Players = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')
local Workspace = game:GetService('Workspace')
local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- [ 終極防呆機制：強力清除所有舊版 GUI ]
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

-- [ 狀態變數與連接池 ] --
local isMasterActive = false
local connections = {}
local originalPhysicalProperties = {}
local originalStates = {}
local originalFallenHeight = Workspace.FallenPartsDestroyHeight
local lastSafeCFrame = nil

-- 新增：Hitbox 還原與白名單記憶體 (使用弱引用避免內存洩漏)
local originalSizes = setmetatable({}, {__mode = "k"})
local originalProjSizes = setmetatable({}, {__mode = "k"})
local myProjectiles = setmetatable({}, {__mode = "k"}) -- 【新】我方投擲物/武器白名單

-- [ 輔助函數 ] --
local function GetHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild('HumanoidRootPart')
end

local function GetHum()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild('Humanoid')
end

-- ==========================================
-- [ 修正：安全極限 Hitbox 擴張 & 絕對破甲 ]
-- ==========================================
local function ExpandEnemyHitbox(char)
    if not char or char == LocalPlayer.Character then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    
    if hrp then
        if not originalSizes[hrp] then originalSizes[hrp] = hrp.Size end
        -- 修正：將尺寸改為 60。2048 過大會導致 Roblox 物理引擎放棄計算 Touch 事件
        hrp.Size = Vector3.new(60, 60, 60)
        hrp.Transparency = 0.85
        hrp.BrickColor = BrickColor.new("Bright red")
        hrp.Material = Enum.Material.ForceField
        hrp.CanCollide = false
        hrp.CanTouch = true -- 核心必須可以被傷害
    end

    -- 【絕對破甲】剝奪敵人身上所有的裝備、盾牌、武器的碰撞與觸碰
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            part.CanCollide = false
            part.CanTouch = false
        end
    end
end

local function ExpandToolHitbox(tool)
    if tool:IsA("Tool") then
        myProjectiles[tool] = true -- 將武器加入白名單
        for _, part in ipairs(tool:GetDescendants()) do
            if part:IsA("BasePart") and part.Name == "Handle" then
                if not originalProjSizes[part] then originalProjSizes[part] = part.Size end
                part.Size = Vector3.new(60, 60, 60)
                part.Transparency = 0.8
                part.BrickColor = BrickColor.new("Cyan")
                part.Material = Enum.Material.ForceField
                part.Massless = true
                part.CanCollide = false
                part.CanTouch = true -- 【穿透機制】確保我們武器保有傷害
                myProjectiles[part] = true -- 零件也加入白名單
            end
        end
    end
end

-- ==========================================
-- [ 單次防禦屬性套用 (因應重生自動恢復) ]
-- ==========================================
local function ApplyOneTimeSetups(char)
    if not char then return end
    local hum = char:WaitForChild("Humanoid", 3)
    local hrp = char:WaitForChild("HumanoidRootPart", 3)
    
    if not isMasterActive then return end

    -- [ 防禦 1：網路休眠 (隱身於物理演算) ]
    if hrp then
        pcall(function() sethiddenproperty(hrp, "NetworkIsSleeping", true) end)
        lastSafeCFrame = hrp.CFrame
    end

    -- [ 防禦 2：神級狀態與血量強制鎖定 ]
    if hum then
        hum.MaxHealth = math.huge
        hum.Health = math.huge
        
        if connections.HealthLock then connections.HealthLock:Disconnect() end
        
        -- 嚴格監聽血量變化，任何微小扣血瞬間補滿
        connections.HealthLock = hum:GetPropertyChangedSignal("Health"):Connect(function()
            if hum.Health < hum.MaxHealth and isMasterActive then
                hum.Health = hum.MaxHealth
            end
        end)

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
    end

    -- 裝備武器時自動放大武器判定並加入白名單
    connections.ToolEquip = char.ChildAdded:Connect(ExpandToolHitbox)
    for _, tool in ipairs(char:GetChildren()) do
        ExpandToolHitbox(tool)
    end
end

-- ==========================================
-- [ 角色重生監聽 ]
-- ==========================================
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
-- [ 極簡 UI 介面設計 - 一鍵啟動版 ]
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
MainFrame.Size = UDim2.new(0, 240, 0, 95)
MainFrame.Position = UDim2.new(0.5, -120, 0.5, -45)
MainFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new('UICorner')
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

local UIStroke = Instance.new('UIStroke')
UIStroke.Color = Color3.fromRGB(0, 255, 170)
UIStroke.Thickness = 2
UIStroke.Parent = MainFrame

local TopBar = Instance.new('Frame')
TopBar.Size = UDim2.new(1, 0, 0, 30)
TopBar.BackgroundColor3 = Color3.fromRGB(20, 40, 30)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame
Instance.new('UICorner', TopBar).CornerRadius = UDim.new(0, 8)

local TopBarFix = Instance.new('Frame')
TopBarFix.Size = UDim2.new(1, 0, 0, 10)
TopBarFix.Position = UDim2.new(0, 0, 1, -10)
TopBarFix.BackgroundColor3 = Color3.fromRGB(20, 40, 30)
TopBarFix.BorderSizePixel = 0
TopBarFix.Parent = TopBar

local Title = Instance.new('TextLabel')
Title.Size = UDim2.new(1, 0, 1, 0)
Title.BackgroundTransparency = 1
Title.Text = '⚡ OBLIVION: ANNIHILATION'
Title.TextColor3 = Color3.fromRGB(180, 255, 220)
Title.TextSize = 13
Title.Font = Enum.Font.GothamBold
Title.Parent = TopBar

local MasterButton = Instance.new('TextButton')
MasterButton.Size = UDim2.new(1, -20, 0, 40)
MasterButton.Position = UDim2.new(0, 10, 0, 40)
MasterButton.BackgroundColor3 = Color3.fromRGB(0, 160, 100)
MasterButton.BorderSizePixel = 0
MasterButton.Text = 'ACTIVATE NULLIFICATION'
MasterButton.TextColor3 = Color3.fromRGB(255, 255, 255)
MasterButton.TextSize = 12
MasterButton.Font = Enum.Font.GothamBold
MasterButton.Parent = MainFrame
Instance.new('UICorner', MasterButton).CornerRadius = UDim.new(0, 6)

-- [ 拖曳功能 ]
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
-- [ 核心邏輯：絕對防禦 + 殲滅判定全開 ]
-- ==========================================
local function ToggleAll()
    isMasterActive = not isMasterActive
    local state = isMasterActive

    if state then
        MasterButton.Text = 'DEACTIVATE'
        MasterButton.BackgroundColor3 = Color3.fromRGB(180, 40, 60)
        UIStroke.Color = Color3.fromRGB(255, 60, 80)
        TopBar.BackgroundColor3 = Color3.fromRGB(60, 20, 30)
        TopBarFix.BackgroundColor3 = Color3.fromRGB(60, 20, 30)
        Title.TextColor3 = Color3.fromRGB(255, 180, 180)
    else
        MasterButton.Text = 'ACTIVATE NULLIFICATION'
        MasterButton.BackgroundColor3 = Color3.fromRGB(0, 160, 100)
        UIStroke.Color = Color3.fromRGB(0, 255, 170)
        TopBar.BackgroundColor3 = Color3.fromRGB(20, 40, 30)
        TopBarFix.BackgroundColor3 = Color3.fromRGB(20, 40, 30)
        Title.TextColor3 = Color3.fromRGB(180, 255, 220)
    end

    -- 清除舊連接
    for key, conn in pairs(connections) do
        if conn then conn:Disconnect() end
    end
    connections = {}

    if state then
        ApplyOneTimeSetups(LocalPlayer.Character)

        -- [ 防禦 3：世界底線突破 (免疫虛空秒殺) ]
        pcall(function() Workspace.FallenPartsDestroyHeight = -9e9 end)

        -- [ 防禦 4：環境武裝解除 (拆除秒殺磚與爆炸) ]
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("TouchTransmitter") then obj:Destroy() end
        end

        -- [ 防禦 5：真・反綁架錨點 (Anti-Bring & Anchor) + 虛空折返 ]
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
                        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    else
                        lastSafeCFrame = hrp.CFrame
                    end
                else
                    lastSafeCFrame = hrp.CFrame
                end
                if hrp.Anchored then hrp.Anchored = false end
            end
        end)

        -- [ 防禦 6：引擎級虛無化 + 不擇手段的絕對領域 ]
        connections.PhysicsStepped = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild('HumanoidRootPart')

            if char then
                -- 虛無化自身物理碰撞
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        if not originalPhysicalProperties[part] then
                            originalPhysicalProperties[part] = part.CustomPhysicalProperties
                        end
                        part.CustomPhysicalProperties = PhysicalProperties.new(math.huge, 0, 0, math.huge, math.huge)
                        part.CanCollide = false
                        
                        -- 【關鍵修復】保留自己手部與武器的觸碰判定，否則自己無法攻擊！
                        if part:FindFirstAncestorOfClass("Tool") or part.Name:match("Hand") or part.Name:match("Arm") then
                            part.CanTouch = true
                        else
                            part.CanTouch = false
                        end
                        part.Massless = true
                    end
                end
                
                -- 確保自己不受動能影響
                if hrp then
                    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                    
                    -- 【不擇手段的絕對領域】粉碎半徑 20 內的威脅
                    local nearbyParts = Workspace:GetPartBoundsInRadius(hrp.Position, 20)
                    for _, part in ipairs(nearbyParts) do
                        if part:IsA("BasePart") and not part:IsDescendantOf(char) and not part.Anchored then
                            -- 【白名單過濾】如果是我們的投擲物，領域將會放行
                            if not myProjectiles[part] and not myProjectiles[part.Parent] then
                                part.AssemblyLinearVelocity = Vector3.zero
                                part.AssemblyAngularVelocity = Vector3.zero
                                part.CanCollide = false
                                part.CanTouch = false
                                -- 【直接抹消】連擋路都不給，把敵方投擲物強制傳送到地底虛空
                                pcall(function() part.CFrame = CFrame.new(0, -99999, 0) end)
                            end
                        end
                    end
                end
            end
        end)

        -- [ 防禦 7：心跳級免疫外部寄生、反控場、持續破甲 ]
        connections.AntiAttach = RunService.Heartbeat:Connect(function()
            local char = LocalPlayer.Character
            if char then
                local hrp = char:FindFirstChild('HumanoidRootPart')
                local hum = char:FindFirstChild('Humanoid')
                
                local cam = Workspace.CurrentCamera
                if cam and hum and cam.CameraSubject ~= hum then
                    cam.CameraSubject = hum
                    cam.CameraType = Enum.CameraType.Custom
                end

                if hrp then
                    for _, v in ipairs(hrp:GetChildren()) do
                        if v:IsA("BodyModifier") or v:IsA("BodyPosition") or v:IsA("BodyVelocity") or v:IsA("BodyGyro") or v:IsA("AngularVelocity") or v:IsA("LinearVelocity") or v:IsA("RocketPropulsion") then
                            v:Destroy()
                        end
                    end
                end

                for _, obj in ipairs(char:GetDescendants()) do
                    if obj:IsA("Weld") or obj:IsA("WeldConstraint") or obj:IsA("Motor6D") then
                        if obj.Part0 and not obj.Part0:IsDescendantOf(char) then obj:Destroy() end
                        if obj.Part1 and not obj.Part1:IsDescendantOf(char) then obj:Destroy() end
                    elseif obj:IsA("SeatWeld") then
                        obj:Destroy()
                    end
                end
                
                if hum then
                    if hum.Health < hum.MaxHealth then hum.Health = hum.MaxHealth end
                    if hum.Sit then hum.Sit = false end
                    if hum.PlatformStand then hum.PlatformStand = false end
                end
            end

            -- 【主動破甲】每幀掃描場上所有敵人，只要他們掏出盾牌/武器，瞬間剝奪判定
            for _, obj in ipairs(Workspace:GetChildren()) do
                if obj:IsA("Model") and obj ~= char and obj:FindFirstChild("Humanoid") then
                    for _, part in ipairs(obj:GetDescendants()) do
                        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                            part.CanCollide = false
                            part.CanTouch = false
                        end
                    end
                end
            end
        end)

        -- ==========================================
        -- [ 殲滅 8：全體敵人/NPC Hitbox 與 投擲物極限化 ]
        -- ==========================================
        
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") and obj:FindFirstChild("Humanoid") then ExpandEnemyHitbox(obj) end
        end

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

            -- 掃描自我投擲物並加入白名單
            if obj:IsA("BasePart") then
                local hrp = GetHRP()
                if hrp then
                    task.defer(function()
                        if obj and obj.Parent and not obj.Anchored and not obj:IsDescendantOf(LocalPlayer.Character) then
                            local distance = (obj.Position - hrp.Position).Magnitude
                            -- 生成在你身邊的投擲物，高機率是你的攻擊
                            if distance < 25 then
                                myProjectiles[obj] = true -- 【加入白名單】
                                if not originalProjSizes[obj] then originalProjSizes[obj] = obj.Size end
                                obj.Size = Vector3.new(60, 60, 60)
                                obj.Transparency = 0.5
                                obj.BrickColor = BrickColor.new("Cyan")
                                obj.Material = Enum.Material.ForceField
                                obj.CanCollide = false
                                obj.CanTouch = true -- 確保有傷害
                                pcall(function() obj.CanQuery = true end)
                                obj.Massless = true
                            end
                        end
                    end)
                end
            end
        end)

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                connections["Plr_"..plr.Name] = plr.CharacterAdded:Connect(function(char)
                    task.delay(0.5, function() ExpandEnemyHitbox(char) end)
                end)
            end
        end
        connections.NewPlayer = Players.PlayerAdded:Connect(function(plr)
            connections["Plr_"..plr.Name] = plr.CharacterAdded:Connect(function(char)
                task.delay(0.5, function() ExpandEnemyHitbox(char) end)
            end)
        end)

    else
        -- [ 關閉狀態：還原所有屬性與環境 ]
        local char = LocalPlayer.Character
        local hum = GetHum()
        local hrp = GetHRP()
        
        pcall(function() Workspace.FallenPartsDestroyHeight = originalFallenHeight end)

        if hum then
            for stateType, isEnabled in pairs(originalStates) do
                hum:SetStateEnabled(stateType, isEnabled)
            end
        end

        if char then
            for part, props in pairs(originalPhysicalProperties) do
                if part and part.Parent then part.CustomPhysicalProperties = props end
            end
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanTouch = true end
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
        myProjectiles = setmetatable({}, {__mode = "k"}) -- 清空白名單
        lastSafeCFrame = nil
        
        pcall(function() if hrp then sethiddenproperty(hrp, "NetworkIsSleeping", false) end end)
    end
end

-- ==========================================
-- [ 事件綁定 ]
-- ==========================================
MasterButton.MouseButton1Click:Connect(ToggleAll)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed then
        if input.KeyCode == Enum.KeyCode.P then
            ToggleAll()
        elseif input.KeyCode == Enum.KeyCode.RightShift then
            MainFrame.Visible = not MainFrame.Visible
        end
    end
end)
