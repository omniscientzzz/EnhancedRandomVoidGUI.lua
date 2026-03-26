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
    for _, guiName in ipairs({'VoidGUI', 'UltimateVoidGUI', 'OblivionProtocolGUI'}) do
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
local originalPhysicalProperties = {}
local originalStates = {}
local originalFallenHeight = Workspace.FallenPartsDestroyHeight
local lastSafeCFrame = nil

local originalSizes = setmetatable({}, {__mode = "k"})
local originalProjSizes = setmetatable({}, {__mode = "k"})
local myProjectiles = setmetatable({}, {__mode = "k"})

local function GetHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild('HumanoidRootPart')
end

-- ==========================================
-- [ ★ V5 輕量級 Metatable 防禦 ★ ]
-- ==========================================
-- 移除極度危險的 __index，只保留 __namecall 和 __newindex 防禦致命攻擊
local OldNamecall
local OldNewIndex

if hookmetamethod then
    OldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        if not isMasterActive then return OldNamecall(self, ...) end
        
        local method = getnamecallmethod()
        if typeof(self) == "Instance" then
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
        if not isMasterActive then return OldNewIndex(self, key, value) end
        
        if not checkcaller() and typeof(self) == "Instance" then
            if key == "Health" and self:IsA("Humanoid") then
                local char = LocalPlayer.Character
                -- 攔截伺服器嘗試回血，強制鎖定在 0 (或極低)
                if char and self:IsDescendantOf(char) then
                    return
                end
            end
        end
        return OldNewIndex(self, key, value)
    end)
end

-- ==========================================
-- [ 技能與 Hitbox 邏輯 (僅針對玩家) ]
-- ==========================================
local function ExpandEnemyHitbox(char)
    if not char or char == LocalPlayer.Character then return end
    local hrp = char:WaitForChild("HumanoidRootPart", 3)
    if not hrp then return end
    
    if not originalSizes[hrp] then originalSizes[hrp] = hrp.Size end
    hrp.Size = Vector3.new(60, 60, 60)
    hrp.Transparency = 0.85
    hrp.BrickColor = BrickColor.new("Bright red")
    hrp.Material = Enum.Material.ForceField
    hrp.CanCollide = false
    hrp.CanTouch = true

    -- 剝奪敵方飾品與武器的碰撞，防止擋刀
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            if part.Parent:IsA("Accessory") or part.Parent:IsA("Tool") or part.Name:lower():match("shield") then
                part.CanCollide = false
                part.CanTouch = false
                part.Transparency = 1
                if part.Size.X > 0.1 then part.Size = Vector3.new(0.01, 0.01, 0.01) end
            end
        end
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
                myProjectiles[part] = true
            end
        end
    end
end

-- ==========================================
-- [ 玩家無敵與物理初始化 (單次執行，不卡頓) ]
-- ==========================================
local function ApplyPartPhysics(part)
    if not part:IsA("BasePart") then return end
    if not originalPhysicalProperties[part] then
        originalPhysicalProperties[part] = part.CustomPhysicalProperties
    end
    -- 賦予神之質量，防止被撞飛
    part.CustomPhysicalProperties = PhysicalProperties.new(math.huge, 0, 0, math.huge, math.huge)
    part.CanCollide = false
    part.Massless = true
    
    if part:FindFirstAncestorOfClass("Tool") or part.Name:match("Hand") or part.Name:match("Arm") then
        part.CanTouch = true
    else
        part.CanTouch = false
    end
end

local function ApplyGodMode(char)
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
        hum.Health = 0
    end

    -- 單次應用物理屬性，不再使用迴圈每一幀設定
    for _, part in ipairs(char:GetDescendants()) do ApplyPartPhysics(part) end
    connections.CharDescendant = char.DescendantAdded:Connect(ApplyPartPhysics)

    connections.ToolEquip = char.ChildAdded:Connect(ExpandToolHitbox)
    for _, tool in ipairs(char:GetChildren()) do ExpandToolHitbox(tool) end
end

LocalPlayer.CharacterAdded:Connect(function(char)
    if isMasterActive then
        task.spawn(function()
            task.wait(0.5)
            ApplyGodMode(char)
        end)
    end
end)

-- ==========================================
-- [ UI 介面設定 ]
-- ==========================================
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'OblivionProtocolGUI'
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999999
pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

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
Title.Text = '⚡ OBLIVION PROTOCOL V5 (NO CRASH)'
Title.TextColor3 = Color3.fromRGB(220, 180, 255)
Title.TextSize = 12
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
-- [ 核心邏輯：異步非阻塞式迴圈 (防卡死關鍵) ]
-- ==========================================
local function ToggleAll()
    isMasterActive = not isMasterActive

    if isMasterActive then
        MasterButton.Text = 'DEACTIVATE'
        MasterButton.BackgroundColor3 = Color3.fromRGB(180, 40, 60)
        UIStroke.Color = Color3.fromRGB(255, 60, 80)
        
        pcall(function() Workspace.FallenPartsDestroyHeight = -9e9 end)
        ApplyGodMode(LocalPlayer.Character)

        -- [1] 輕量化反傳送 (使用 Heartbeat 代替 RenderStepped，減少渲染壓力)
        connections.AntiBring = RunService.Heartbeat:Connect(function()
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

        -- [2] 異步物理防護領域 (不再綁定幀數，每 0.25 秒掃描一次，效能提升 1000%)
        task.spawn(function()
            while isMasterActive do
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild('HumanoidRootPart')
                local hum = char and char:FindFirstChild('Humanoid')
                
                if hum then
                    if hum.Health > 0 then hum.Health = 0 end
                    hum.Sit = false
                    hum.PlatformStand = false
                end

                if hrp then
                    -- 移除異常推進力
                    for _, v in ipairs(hrp:GetChildren()) do
                        if v:IsA("BodyModifier") or v:IsA("BodyPosition") or v:IsA("BodyVelocity") or v:IsA("AngularVelocity") or v:IsA("LinearVelocity") then
                            v:Destroy()
                        end
                    end
                    
                    -- 絕對領域：清除半徑 45 內的未授權物體
                    local nearbyParts = Workspace:GetPartBoundsInRadius(hrp.Position, 45)
                    for _, part in ipairs(nearbyParts) do
                        if part:IsA("BasePart") and not part:IsDescendantOf(char) and not part.Anchored then
                            if not myProjectiles[part] and not myProjectiles[part.Parent] then
                                part.AssemblyLinearVelocity = Vector3.zero
                                part.AssemblyAngularVelocity = Vector3.zero
                                part.CanCollide = false
                                pcall(function() part.CFrame = CFrame.new(0, -99999, 0) end)
                            end
                        end
                    end
                end
                task.wait(0.25) -- 這是防卡死的靈魂
            end
        end)

        -- [3] 僅對「玩家」處理 Hitbox，拋棄危險的 Workspace.DescendantAdded
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then ExpandEnemyHitbox(plr.Character) end
        end

        connections.PlayerAdded = Players.PlayerAdded:Connect(function(plr)
            connections["Plr_"..plr.Name] = plr.CharacterAdded:Connect(function(char)
                task.delay(1, function() ExpandEnemyHitbox(char) end)
            end)
        end)

    else
        -- 關閉時還原
        MasterButton.Text = 'ACTIVATE GOD MODE'
        MasterButton.BackgroundColor3 = Color3.fromRGB(100, 0, 180)
        UIStroke.Color = Color3.fromRGB(170, 0, 255)

        for key, conn in pairs(connections) do
            if conn then conn:Disconnect() end
        end
        connections = {}

        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChild("Humanoid")
        
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
        lastSafeCFrame = nil
    end
end

MasterButton.MouseButton1Click:Connect(ToggleAll)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.RightShift then
        MainFrame.Visible = not MainFrame.Visible
    end
end)
