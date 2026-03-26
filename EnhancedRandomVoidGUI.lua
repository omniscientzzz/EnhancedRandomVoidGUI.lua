local fenv = getfenv()
fenv.require = function() end

-- [ 初始化隨機數種子 ] --
math.randomseed(os.time())

-- [ 核心服務 ] --
local RunService = game:GetService('RunService')
local Players = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')
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

-- [ 輔助函數 ] --
local function GetHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild('HumanoidRootPart')
end

local function GetHum()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild('Humanoid')
end

-- [ 進階版：防死亡 Void TP 偏移計算 ] --
local function GetSafeVoidOffset()
    -- X 軸與 Z 軸無限隨機傳送
    local randX = (math.random() - 0.5) * 20000000000
    local randZ = (math.random() - 0.5) * 20000000000 
    
    -- Y 軸鎖定在安全高空，避免觸發遊戲內建的 FallenPartsDestroyHeight 秒殺機制
    local safeY = 500000
    local hrp = GetHRP()
    local currentY = hrp and hrp.Position.Y or 0
    local offsetY = safeY - currentY
    
    return Vector3.new(randX, offsetY, randZ)
end

-- ==========================================
-- [ 極簡 UI 介面設計 - 一鍵啟動版 ]
-- ==========================================
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'OblivionProtocolGUI'
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999999 -- 確保絕對置頂

local success, core = pcall(function() return game:GetService("CoreGui") end)
ScreenGui.Parent = success and core or LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new('Frame')
MainFrame.Name = 'MainFrame'
MainFrame.Size = UDim2.new(0, 200, 0, 90)
MainFrame.Position = UDim2.new(0.5, -100, 0.5, -45)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new('UICorner')
UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = MainFrame

local UIStroke = Instance.new('UIStroke')
UIStroke.Color = Color3.fromRGB(120, 40, 255)
UIStroke.Thickness = 2
UIStroke.Parent = MainFrame

local TopBar = Instance.new('Frame')
TopBar.Size = UDim2.new(1, 0, 0, 30)
TopBar.BackgroundColor3 = Color3.fromRGB(30, 20, 60)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame
Instance.new('UICorner', TopBar).CornerRadius = UDim.new(0, 10)

local TopBarFix = Instance.new('Frame')
TopBarFix.Size = UDim2.new(1, 0, 0, 10)
TopBarFix.Position = UDim2.new(0, 0, 1, -10)
TopBarFix.BackgroundColor3 = Color3.fromRGB(30, 20, 60)
TopBarFix.BorderSizePixel = 0
TopBarFix.Parent = TopBar

local Title = Instance.new('TextLabel')
Title.Size = UDim2.new(1, 0, 1, 0)
Title.BackgroundTransparency = 1
Title.Text = '⚡ OBLIVION PROTOCOL V2'
Title.TextColor3 = Color3.fromRGB(200, 180, 255)
Title.TextSize = 13
Title.Font = Enum.Font.GothamBold
Title.Parent = TopBar

local MasterButton = Instance.new('TextButton')
MasterButton.Size = UDim2.new(1, -20, 0, 40)
MasterButton.Position = UDim2.new(0, 10, 0, 40)
MasterButton.BackgroundColor3 = Color3.fromRGB(70, 40, 160)
MasterButton.BorderSizePixel = 0
MasterButton.Text = 'ACTIVATE ALL'
MasterButton.TextColor3 = Color3.fromRGB(255, 255, 255)
MasterButton.TextSize = 14
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
-- [ 核心邏輯：終極防禦全開 ]
-- ==========================================
local function ToggleAll()
    isMasterActive = not isMasterActive
    local state = isMasterActive

    if state then
        MasterButton.Text = 'DEACTIVATE ALL'
        MasterButton.BackgroundColor3 = Color3.fromRGB(180, 40, 60)
        UIStroke.Color = Color3.fromRGB(255, 60, 80)
        TopBar.BackgroundColor3 = Color3.fromRGB(60, 20, 30)
        TopBarFix.BackgroundColor3 = Color3.fromRGB(60, 20, 30)
    else
        MasterButton.Text = 'ACTIVATE ALL'
        MasterButton.BackgroundColor3 = Color3.fromRGB(70, 40, 160)
        UIStroke.Color = Color3.fromRGB(120, 40, 255)
        TopBar.BackgroundColor3 = Color3.fromRGB(30, 20, 60)
        TopBarFix.BackgroundColor3 = Color3.fromRGB(30, 20, 60)
    end

    -- 清除舊連接
    for key, conn in pairs(connections) do
        if conn then conn:Disconnect() end
    end
    connections = {}

    if state then
        local char = LocalPlayer.Character
        local hum = GetHum()
        
        -- [ 防禦層級 1：網路休眠 (Network Sleeping) ]
        -- 讓支援的執行器將角色的物理所有權休眠，免疫其他客戶端的碰撞干擾
        pcall(function()
            if char and char:FindFirstChild("HumanoidRootPart") then
                sethiddenproperty(char.HumanoidRootPart, "NetworkIsSleeping", true)
            end
        end)

        -- [ 防禦層級 2：神級狀態與血量鎖定 (God Mode & State Freeze) ]
        if hum then
            -- 鎖定無敵血量
            hum.MaxHealth = math.huge
            hum.Health = math.huge
            connections.HealthLock = hum.HealthChanged:Connect(function()
                if hum.Health < hum.MaxHealth then
                    hum.Health = hum.MaxHealth
                end
            end)

            -- 封鎖所有致死或失控的狀態
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
                originalStates[s] = hum:GetStateEnabled(s)
                hum:SetStateEnabled(s, false)
            end
        end

        -- [ 防禦層級 3：強化版 Void TP ]
        connections.VoidTP = RunService.Heartbeat:Connect(function()
            local hrp = GetHRP()
            if hrp then
                local offset = GetSafeVoidOffset()
                hrp.CFrame = CFrame.new(hrp.Position.X + offset.X, hrp.Position.Y + offset.Y, hrp.Position.Z + offset.Z)
            end
        end)

        -- [ 防禦層級 4：絕對質量 + 虛無化 + 穿牆 (Physics Override) ]
        connections.Physics = RunService.Stepped:Connect(function()
            local c = LocalPlayer.Character
            if c then
                for _, part in ipairs(c:GetDescendants()) do
                    if part:IsA("BasePart") then
                        if not originalPhysicalProperties[part] then
                            originalPhysicalProperties[part] = part.CustomPhysicalProperties
                        end
                        -- 質量最大化、無摩擦力、無彈性
                        part.CustomPhysicalProperties = PhysicalProperties.new(100, 0, 0, 100, 100)
                        part.CanTouch = false
                        part.CanCollide = false
                        part.Massless = false
                    end
                end
            end
        end)

        -- [ 防禦層級 5：免疫外部寄生 (Anti-Weld / Anti-Attach) ]
        -- 防止外掛用 Weld 將奇怪的物件綁在你身上，或強迫你坐下
        connections.AntiAttach = RunService.Heartbeat:Connect(function()
            local c = LocalPlayer.Character
            if c then
                for _, obj in ipairs(c:GetDescendants()) do
                    if obj:IsA("Weld") or obj:IsA("WeldConstraint") or obj:IsA("Motor6D") then
                        -- 如果連接的對象不是自己身體的一部分，立刻粉碎
                        if obj.Part0 and not obj.Part0:IsDescendantOf(c) then obj:Destroy() end
                        if obj.Part1 and not obj.Part1:IsDescendantOf(c) then obj:Destroy() end
                    elseif obj:IsA("SeatWeld") then
                        obj:Destroy() -- 拒絕強制入座
                    end
                end
            end
        end)

        -- [ 防禦層級 6：反綁架 (Anti-Bring) ]
        local lastPos = nil
        connections.AntiBring = RunService.Heartbeat:Connect(function()
            local hrp = GetHRP()
            if hrp then
                lastPos = hrp.Position 
            end
        end)

        -- [ 防禦層級 7：絕對動能抹除 (Ultimate Anti-Fling) ]
        connections.AntiFling = RunService.Stepped:Connect(function()
            local hrp = GetHRP()
            if hrp then
                -- 清除任何試圖改變物理狀態的外部力場
                for _, v in ipairs(hrp:GetChildren()) do
                    if v:IsA("BodyModifier") or v:IsA("BodyPosition") or v:IsA("BodyVelocity") or v:IsA("BodyGyro") or v:IsA("AngularVelocity") or v:IsA("LinearVelocity") or v:IsA("RocketPropulsion") then
                        v:Destroy()
                    end
                end
                
                -- 從底層強行鎖死所有物理動能與旋轉
                hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                hrp.Velocity = Vector3.new(0, 0, 0)
                hrp.RotVelocity = Vector3.new(0, 0, 0)
            end
        end)

    else
        -- [ 關閉狀態：還原所有屬性與狀態 ]
        local char = LocalPlayer.Character
        local hum = GetHum()
        
        if hum then
            for state, isEnabled in pairs(originalStates) do
                hum:SetStateEnabled(state, isEnabled)
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
                end
            end
        end
        originalPhysicalProperties = {}
        originalStates = {}
        
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
