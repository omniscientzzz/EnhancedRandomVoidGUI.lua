-- [[ 絕對防禦 V6.5 (血幻影版)：Anti-Aim + Rage Bot 完美兼容修復版 ]] --
-- 維護者：專屬腳本架構師
-- 特色：新增 Rage Sync 模式，解決自瞄運算崩潰、FOV判定失效等問題。

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')
local CoreGui = game:GetService('CoreGui')
local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- [ 清理舊版 UI ]
-- ==========================================
pcall(function()
    local oldGUI = CoreGui:FindFirstChild("AegisV6GUI") or LocalPlayer:FindFirstChild("PlayerGui"):FindFirstChild("AegisV6GUI")
    if oldGUI then oldGUI:Destroy() end
end)

-- ==========================================
-- [ 全域狀態與變數 ]
-- ==========================================
local Flags = { 
    AbsoluteDefense = false,
    RageSync = false -- 預設關閉，開啟後完美兼容 Rage Bot
}
local connections = {}
local realCFrame = nil
local realVelocity = Vector3.new(0, 0, 0)
local LIMIT_COORD = 9e8 

local OriginalSizes = {}
local OriginalC0s = {}

local function ClearConnections()
    for key, conn in pairs(connections) do
        if typeof(conn) == "RBXScriptConnection" then
            conn:Disconnect()
        end
    end
    table.clear(connections)
    pcall(function() RunService:UnbindFromRenderStep("AegisRestore") end)
end

-- ==========================================
-- [ 核心引擎：V6.5 狂暴同步防禦機制 ]
-- ==========================================
local function ActivateLimitEngine()
    ClearConnections()
    pcall(function() workspace.FallenPartsDestroyHeight = -math.huge end)

    local char = LocalPlayer.Character
    if char and char:FindFirstChild("Humanoid") then
        local hum = char.Humanoid
        pcall(function()
            hum.MaxHealth = math.huge
            hum.Health = math.huge
            hum.BreakJointsOnDeath = false
            hum.RequiresNeck = false
            hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
        end)
    end

    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then OriginalSizes[part] = part.Size
            elseif part:IsA("Motor6D") then OriginalC0s[part] = part.C0 end
        end
    end

    -- 【階段 1：捕獲真實狀態 (確保你本地的移動與輸入不受干擾)】
    connections.Stepped = RunService.Stepped:Connect(function()
        if not Flags.AbsoluteDefense then return end
        local currentChar = LocalPlayer.Character
        if currentChar then
            local hrp = currentChar:FindFirstChild("HumanoidRootPart")
            if hrp then
                realCFrame = hrp.CFrame
                realVelocity = hrp.AssemblyLinearVelocity
            end
            
            -- 防撞擊與物理抹除
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    for _, part in ipairs(player.Character:GetChildren()) do
                        if part:IsA("BasePart") then part.CanCollide = false end
                    end
                end
            end
        end
    end)

    -- 【階段 2：伺服器欺騙 (製造幻影與干擾敵人)】
    connections.Heartbeat = RunService.Heartbeat:Connect(function()
        if not Flags.AbsoluteDefense then return end
        local char = LocalPlayer.Character
        if not char then return end
        
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp and realCFrame then
            if Flags.RageSync then
                -- [ Rage Bot 兼容模式 ]
                -- 震盪範圍縮小至 35 內，確保敵人在 Rage Bot 的 FOV 內
                -- 速度箝制在 ±600，防止 Rage Bot 的預判數學公式回傳 NaN
                local jitterX = math.random(-35, 35)
                local jitterY = math.random(-15, 15)
                local jitterZ = math.random(-35, 35)
                
                hrp.CFrame = CFrame.new(realCFrame.Position + Vector3.new(jitterX, jitterY, jitterZ)) 
                             * CFrame.Angles(math.rad(180), math.rad(math.random(0, 360)), 0)
                
                hrp.AssemblyLinearVelocity = Vector3.new(math.random(-600, 600), math.random(-600, 600), math.random(-600, 600))
            else
                -- [ 純粹幻影模式 (不開 Rage Bot 時最無敵) ]
                local limitX = (math.random() > 0.5 and 1 or -1) * LIMIT_COORD
                local limitZ = (math.random() > 0.5 and 1 or -1) * LIMIT_COORD
                hrp.CFrame = CFrame.new(limitX + math.random(-50,50), (LIMIT_COORD / 10), limitZ + math.random(-50,50)) 
                             * CFrame.Angles(math.rad(180), math.rad(math.random(0, 360)), math.rad(math.random(-90, 90)))
                             
                hrp.AssemblyLinearVelocity = Vector3.new(math.random(-99999, 99999), math.random(-99999, 99999), math.random(-99999, 99999))
            end
            hrp.AssemblyAngularVelocity = Vector3.new(math.random(-9999, 9999), math.random(-9999, 9999), math.random(-9999, 9999))
            
            -- 自我奇異點
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Size = Vector3.new(0.01, 0.01, 0.01)
                    part.Massless = true
                    if part.Name == "Head" then part.Transparency = 1 end
                end
            end
        end
        
        -- 無限放大敵人 Hitbox (輔助你的 Rage Bot)
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local enemyHRP = player.Character:FindFirstChild("HumanoidRootPart") or player.Character:FindFirstChild("Torso")
                if enemyHRP then
                    enemyHRP.Size = Vector3.new(60, 60, 60)
                    enemyHRP.Transparency = 0.7 
                    enemyHRP.BrickColor = BrickColor.new("Bright red")
                    enemyHRP.Material = Enum.Material.ForceField
                    enemyHRP.CanCollide = false 
                end
            end
        end
    end)

    -- 【階段 3：本地端完美還原 (覆寫管線優先級)】
    -- 使用 RenderPriority.Camera - 10 確保在你的 Rage Bot 運作前，先把你的座標還原！
    RunService:BindToRenderStep("AegisRestore", Enum.RenderPriority.Camera.Value - 10, function()
        if not Flags.AbsoluteDefense then return end
        local char = LocalPlayer.Character
        if char and realCFrame then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.CFrame = realCFrame
                hrp.AssemblyLinearVelocity = realVelocity
                hrp.AssemblyAngularVelocity = Vector3.new(0,0,0)
            end
        end
    end)
    
    -- 防爆系統
    connections.Explosion = workspace.DescendantAdded:Connect(function(desc)
        if Flags.AbsoluteDefense and desc.ClassName == "Explosion" then
            desc.BlastPressure = 0
            desc.BlastRadius = 0
            task.defer(function() pcall(function() desc:Destroy() end) end)
        end
    end)
end

local function DeactivateLimitEngine()
    ClearConnections()
    pcall(function() workspace.FallenPartsDestroyHeight = -500 end)
    
    local char = LocalPlayer.Character
    if char then
        for part, size in pairs(OriginalSizes) do
            if part and part.Parent then part.Size = size end
        end
        for motor, c0 in pairs(OriginalC0s) do
            if motor and motor.Parent then motor.C0 = c0 end
        end
        if char:FindFirstChild("Head") then char.Head.Transparency = 0 end

        if char:FindFirstChild("Humanoid") then
            pcall(function()
                char.Humanoid.MaxHealth = 100
                char.Humanoid.Health = 100
                char.Humanoid.RequiresNeck = true
                char.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
                char.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
            end)
        end
    end
end

-- ==========================================
-- [ 雙按鈕 UI 介面 (V6.5 血幻影版) ]
-- ==========================================
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'AegisV6GUI'
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new('Frame')
MainFrame.Size = UDim2.new(0, 160, 0, 80) -- 擴大以容納第二個按鈕
MainFrame.Position = UDim2.new(0.5, -80, 0.85, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 10, 15)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui
Instance.new('UICorner', MainFrame).CornerRadius = UDim.new(0, 8)

local UIStroke = Instance.new('UIStroke')
UIStroke.Color = Color3.fromRGB(200, 30, 60) -- V6.5專屬血幻影紅
UIStroke.Thickness = 2
UIStroke.Parent = MainFrame

-- 按鈕 1：主開關
local ToggleBtn = Instance.new('TextButton')
ToggleBtn.Size = UDim2.new(1, -12, 0, 30)
ToggleBtn.Position = UDim2.new(0, 6, 0, 6)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(25, 15, 20)
ToggleBtn.Text = 'Phantom [ OFF ]'
ToggleBtn.TextColor3 = Color3.fromRGB(255, 100, 120)
ToggleBtn.Font = Enum.Font.GothamBlack
ToggleBtn.TextSize = 12 
ToggleBtn.Parent = MainFrame
Instance.new('UICorner', ToggleBtn).CornerRadius = UDim.new(0, 6)

-- 按鈕 2：Rage Bot 同步開關
local SyncBtn = Instance.new('TextButton')
SyncBtn.Size = UDim2.new(1, -12, 0, 30)
SyncBtn.Position = UDim2.new(0, 6, 0, 42)
SyncBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
SyncBtn.Text = 'Rage Sync: OFF'
SyncBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
SyncBtn.Font = Enum.Font.GothamBold
SyncBtn.TextSize = 11 
SyncBtn.Parent = MainFrame
Instance.new('UICorner', SyncBtn).CornerRadius = UDim.new(0, 6)

ToggleBtn.MouseButton1Click:Connect(function()
    Flags.AbsoluteDefense = not Flags.AbsoluteDefense
    if Flags.AbsoluteDefense then
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 10, 20)
        ToggleBtn.TextColor3 = Color3.fromRGB(255, 50, 80)
        ToggleBtn.Text = 'Phantom [ ON ]'
        ActivateLimitEngine()
    else
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(25, 15, 20)
        ToggleBtn.TextColor3 = Color3.fromRGB(255, 100, 120)
        ToggleBtn.Text = 'Phantom [ OFF ]'
        DeactivateLimitEngine()
    end
end)

SyncBtn.MouseButton1Click:Connect(function()
    Flags.RageSync = not Flags.RageSync
    if Flags.RageSync then
        SyncBtn.BackgroundColor3 = Color3.fromRGB(150, 100, 20)
        SyncBtn.TextColor3 = Color3.fromRGB(255, 200, 50)
        SyncBtn.Text = 'Rage Sync: ON (Safe)'
    else
        SyncBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        SyncBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
        SyncBtn.Text = 'Rage Sync: OFF'
    end
end)

-- 滑順拖曳邏輯
local dragging, dragInput, dragStart, startPos
MainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
MainFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.delay(0.5, function() if Flags.AbsoluteDefense then ActivateLimitEngine() end end)
end)
