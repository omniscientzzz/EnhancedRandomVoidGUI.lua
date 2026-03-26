local fenv = getfenv()
fenv.require = function() end

-- [[ VOID x AEGIS V6: EXTREME HYBRID (Hitbox Restored) ]] --
-- 功能：無限小自轉 Hitbox (自己)、恢復敵人 Hitbox、遠程殺死防禦、爆炸自動拆除、縮小版拖拽 UI
-- 座標：完全還原 Void 原始偏移 X-1489021035, Z+1547417969

local RunService = game:GetService('RunService')
local Players = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')
local CoreGui = game:GetService('CoreGui')
local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- [ 核心狀態管理 ]
-- ==========================================
local isActive = false
local connections = {}
local realCFrame = nil
local teleportCount = 0

local function ClearConnections()
    for _, conn in pairs(connections) do
        if typeof(conn) == "RBXScriptConnection" then
            conn:Disconnect()
        end
    end
    table.clear(connections)
    pcall(function() RunService:UnbindFromRenderStep("VoidRestore") end)
end

-- ==========================================
-- [ UI 介面建構 (縮小且可移動) ]
-- ==========================================
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'VoidExtremeGUI'
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new('Frame')
MainFrame.Name = 'MainFrame'
MainFrame.Size = UDim2.new(0, 180, 0, 140)
MainFrame.Position = UDim2.new(0.85, 0, 0.8, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true 
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new('UICorner', MainFrame)
MainCorner.CornerRadius = UDim.new(0, 12)

local MainStroke = Instance.new('UIStroke', MainFrame)
MainStroke.Color = Color3.fromRGB(120, 50, 255)
MainStroke.Thickness = 2

local TitleText = Instance.new('TextLabel', MainFrame)
TitleText.Size = UDim2.new(1, 0, 0, 30)
TitleText.BackgroundTransparency = 1
TitleText.Text = '⚡ VOID EXTREME'
TitleText.TextColor3 = Color3.fromRGB(200, 180, 255)
TitleText.TextSize = 13
TitleText.Font = Enum.Font.GothamBold
TitleText.Parent = MainFrame

local StatusText = Instance.new('TextLabel', MainFrame)
StatusText.Size = UDim2.new(1, 0, 0, 20)
StatusText.Position = UDim2.new(0, 0, 0, 35)
StatusText.BackgroundTransparency = 1
StatusText.Text = '● READY'
StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusText.TextSize = 11
StatusText.Font = Enum.Font.GothamBold
StatusText.Parent = MainFrame

local ToggleBtn = Instance.new('TextButton', MainFrame)
ToggleBtn.Size = UDim2.new(0.8, 0, 0, 40)
ToggleBtn.Position = UDim2.new(0.1, 0, 0, 60)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 150)
ToggleBtn.Text = 'START'
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 15
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = MainFrame
Instance.new('UICorner', ToggleBtn).CornerRadius = UDim.new(0, 8)

local StatsText = Instance.new('TextLabel', MainFrame)
StatsText.Size = UDim2.new(1, 0, 0, 20)
StatsText.Position = UDim2.new(0, 0, 0, 110)
StatsText.BackgroundTransparency = 1
StatsText.Text = 'TP: 0 | Defense: OK'
StatsText.TextColor3 = Color3.fromRGB(80, 80, 120)
StatsText.TextSize = 10
StatsText.Font = Enum.Font.Gotham
StatsText.Parent = MainFrame

-- ==========================================
-- [ 引擎：無敵與防禦邏輯 ]
-- ==========================================
local function StartEngine()
    ClearConnections()
    teleportCount = 0
    pcall(function() workspace.FallenPartsDestroyHeight = -math.huge end)

    local function OptimizeCharacter(char)
        if not char then return end
        local hum = char:WaitForChild("Humanoid")
        pcall(function()
            hum.MaxHealth = math.huge
            hum.Health = math.huge
            hum.BreakJointsOnDeath = false
            hum.RequiresNeck = false
            -- Anti-Remote Kill 狀態鎖定
            hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        end)
    end
    
    OptimizeCharacter(LocalPlayer.Character)

    -- [1. 自我 Hitbox 最小化與旋轉干擾]
    connections.Stepped = RunService.Stepped:Connect(function()
        if not isActive then return end
        local char = LocalPlayer.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then 
                realCFrame = hrp.CFrame 
                -- 瘋狂自轉以干擾伺服器位置判定與玩家鎖定
                hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(math.random(1, 360)), 0)
            end
            
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                    part.Size = Vector3.new(0.001, 0.001, 0.001) -- 無限小體積
                    if part.Name == "Head" then part.Transparency = 1 end
                end
            end
            
            -- 自動清除有害負面狀態 (V6 特性)
            for _, obj in ipairs(char:GetDescendants()) do
                if obj:IsA("Fire") or obj:IsA("Smoke") then obj:Destroy() end
            end
        end

        -- [2. 恢復敵人 Hitbox (僅關閉碰撞，不修改大小)]
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                for _, part in ipairs(player.Character:GetChildren()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end
    end)

    -- [3. Void 原始傳送邏輯 (極端座標偏移)]
    connections.Heartbeat = RunService.Heartbeat:Connect(function()
        if not isActive then return end
        local char = LocalPlayer.Character
        if char and realCFrame then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local pos = realCFrame.Position
                -- Void 核心數值
                hrp.CFrame = CFrame.new(pos.X + -1489021035.8, pos.Y, pos.Z + 1547417969.8)
                teleportCount = teleportCount + 1
                StatsText.Text = 'TP: '..tostring(teleportCount)..' | Defense: ACTIVE'
            end
        end
    end)

    -- [4. 本地端視角還原系統]
    RunService:BindToRenderStep("VoidRestore", 199, function()
        if not isActive then return end
        local char = LocalPlayer.Character
        if char and realCFrame then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then hrp.CFrame = realCFrame end
        end
    end)
    
    -- [5. Anti-Explosion (爆炸自動拆除)]
    connections.Explosion = workspace.DescendantAdded:Connect(function(desc)
        if isActive and desc:IsA("Explosion") then
            desc.BlastPressure = 0
            desc.BlastRadius = 0
            desc.Visible = false
            task.defer(function() pcall(function() desc:Destroy() end) end)
        end
    end)
end

local function StopEngine()
    ClearConnections()
    local char = LocalPlayer.Character
    if char then
        -- 復原玩家零件大小
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Size = Vector3.new(1, 1, 1) -- 恢復基本大小
                if part.Name == "Head" then part.Transparency = 0 end
            end
        end
        if char:FindFirstChild("Humanoid") then
            char.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
        end
    end
end

-- ==========================================
-- [ UI 互動邏輯 ]
-- ==========================================
local isHovering = false
local isDebouncing = false

local function UpdateUI()
    if isActive then
        StatusText.Text = '● EXTREME ACTIVE'
        StatusText.TextColor3 = Color3.fromRGB(0, 255, 150)
        ToggleBtn.Text = 'STOP'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(200, 50, 50) or Color3.fromRGB(150, 30, 30)
    else
        StatusText.Text = '● SYSTEM IDLE'
        StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
        ToggleBtn.Text = 'START'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(100, 50, 255) or Color3.fromRGB(60, 30, 150)
    end
end

ToggleBtn.MouseEnter:Connect(function() isHovering = true UpdateUI() end)
ToggleBtn.MouseLeave:Connect(function() isHovering = false UpdateUI() end)
ToggleBtn.MouseButton1Click:Connect(function()
    if isDebouncing then return end
    isDebouncing = true
    isActive = not isActive
    UpdateUI()
    if isActive then StartEngine() else StopEngine() end
    task.wait(0.3)
    isDebouncing = false
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.delay(1, function() if isActive then StartEngine() end end)
end)

