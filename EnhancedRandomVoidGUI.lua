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
-- [ 新增：單次防禦屬性套用 (因應重生自動恢復) ]
-- ==========================================
local function ApplyOneTimeSetups(char)
    if not char then return end
    local hum = char:WaitForChild("Humanoid", 3)
    local hrp = char:WaitForChild("HumanoidRootPart", 3)
    
    if not isMasterActive then return end

    -- [ 防禦 1：網路休眠 (隱身於物理演算) ]
    if hrp then
        pcall(function()
            sethiddenproperty(hrp, "NetworkIsSleeping", true)
        end)
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
            Enum.HumanoidStateType.Dead,
            Enum.HumanoidStateType.Ragdoll,
            Enum.HumanoidStateType.FallingDown,
            Enum.HumanoidStateType.Physics,
            Enum.HumanoidStateType.PlatformStanding,
            Enum.HumanoidStateType.Stunned,
            Enum.HumanoidStateType.Seated
        }
        for _, s in ipairs(badStates) do
            if originalStates[s] == nil then
                originalStates[s] = hum:GetStateEnabled(s)
            end
            hum:SetStateEnabled(s, false)
        end
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
MainFrame.Size = UDim2.new(0, 220, 0, 90)
MainFrame.Position = UDim2.new(0.5, -110, 0.5, -45)
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
Title.Text = '⚡ OBLIVION: ABSOLUTE'
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

-- [ 拖曳功能 ] --
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
-- [ 核心邏輯：絕對防禦全開 ]
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
        pcall(function()
            Workspace.FallenPartsDestroyHeight = -9e9
        end)

        -- [ 防禦 4：環境武裝解除 (拆除秒殺磚與爆炸) ]
        -- 第一步：清除現存的 TouchInterest (觸碰傷害判定)
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("TouchTransmitter") then
                obj:Destroy()
            end
        end
        -- 第二步：攔截未來生成的威脅
        connections.AntiEnvironment = Workspace.DescendantAdded:Connect(function(obj)
            if obj:IsA("Explosion") or obj:IsA("TouchTransmitter") then
                task.defer(function() obj:Destroy() end)
            end
        end)

        -- [ 防禦 5：真・反綁架錨點 (Anti-Bring & Anchor) ]
        -- 在畫面渲染前執行，確保不法位移在玩家看到前就被拉回
        connections.AntiBring = RunService.RenderStepped:Connect(function()
            local hrp = GetHRP()
            if hrp then
                if lastSafeCFrame then
                    -- 如果一幀內位移超過 150 Studs，判定為被惡意外掛傳送
                    local distance = (hrp.Position - lastSafeCFrame.Position).Magnitude
                    if distance > 150 then
                        hrp.CFrame = lastSafeCFrame -- 強制拉回
                        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    else
                        -- 正常移動，更新安全座標
                        lastSafeCFrame = hrp.CFrame
                    end
                else
                    lastSafeCFrame = hrp.CFrame
                end
            end
        end)

        -- [ 防禦 6：引擎級虛無化 (Stepped Collision Nullification & Anti-Fling) ]
        -- Stepped 是在 Roblox 物理引擎計算碰撞前的一刻。在這裡將 CanCollide 設為 false，能達到 100% 絕對穿透。
        connections.PhysicsStepped = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        if not originalPhysicalProperties[part] then
                            originalPhysicalProperties[part] = part.CustomPhysicalProperties
                        end
                        -- 質量最大化，消除摩擦與彈力，強制成為無法被推動的物體
                        part.CustomPhysicalProperties = PhysicalProperties.new(math.huge, 0, 0, math.huge, math.huge)
                        part.CanCollide = false
                        part.CanTouch = false
                        part.Massless = true
                    end
                end
                
                -- 強制抹除動能，防禦超高速自轉外掛
                local hrp = char:FindFirstChild('HumanoidRootPart')
                if hrp then
                    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                end
            end
        end)

        -- [ 防禦 7：心跳級免疫外部寄生 (Heartbeat Anti-Attach) ]
        -- 在物理運算後清除任何成功附著的惡意零件
        connections.AntiAttach = RunService.Heartbeat:Connect(function()
            local char = LocalPlayer.Character
            if char then
                local hrp = char:FindFirstChild('HumanoidRootPart')
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
                
                -- 持續確保血量在最高峰
                local hum = char:FindFirstChild("Humanoid")
                if hum and hum.Health < hum.MaxHealth then
                    hum.Health = hum.MaxHealth
                end
            end
        end)

    else
        -- [ 關閉狀態：還原所有屬性與環境 ]
        local char = LocalPlayer.Character
        local hum = GetHum()
        
        pcall(function()
            Workspace.FallenPartsDestroyHeight = originalFallenHeight
        end)

        if hum then
            for stateType, isEnabled in pairs(originalStates) do
                hum:SetStateEnabled(stateType, isEnabled)
            end
        end

        if char then
            for part, props in pairs(originalPhysicalProperties) do
                if part and part.Parent then
                    part.CustomPhysicalProperties = props
                end
            end
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanTouch = true
                    -- 讓引擎自行恢復 CanCollide，或者根據需求還原
                end
            end
        end
        originalPhysicalProperties = {}
        originalStates = {}
        lastSafeCFrame = nil
        
        pcall(function()
            if char and char:FindFirstChild("HumanoidRootPart") then
                sethiddenproperty(char.HumanoidRootPart, "NetworkIsSleeping", false)
            end
        end)
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
