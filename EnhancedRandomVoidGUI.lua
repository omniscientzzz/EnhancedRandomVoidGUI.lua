-- [[ 絕對防禦 V5 (累積整合版)：奇異點自轉 + 敵人Hitbox無限膨脹 + 微型UI ]] --
-- 維護者：專屬腳本架構師
-- 承諾：自動繼承所有穩定功能，拒絕卡頓，持續疊加防禦機制。

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')
local CoreGui = game:GetService('CoreGui')
local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- [ 清理舊版 UI ]
-- ==========================================
pcall(function()
    local oldGUI = CoreGui:FindFirstChild("AegisV5GUI") or LocalPlayer:FindFirstChild("PlayerGui"):FindFirstChild("AegisV5GUI")
    if oldGUI then oldGUI:Destroy() end
end)

-- ==========================================
-- [ 全域狀態與變數 ]
-- ==========================================
local Flags = { AbsoluteDefense = false }
local connections = {}
local realCFrame = nil
local LIMIT_COORD = 9e9 -- Lua 物理引擎極限數值

-- 安全清理所有監聽事件
local function ClearConnections()
    for key, conn in pairs(connections) do
        if typeof(conn) == "RBXScriptConnection" then
            conn:Disconnect()
        end
    end
    table.clear(connections)
end

-- 儲存原始尺寸與關節數據 (供關閉時還原)
local OriginalSizes = {}
local OriginalC0s = {}

-- ==========================================
-- [ 核心引擎：累積防禦機制 ]
-- ==========================================
local function ActivateLimitEngine()
    ClearConnections()
    
    -- 【累積 1】：防虛空死亡
    pcall(function() workspace.FallenPartsDestroyHeight = -math.huge end)

    -- 【累積 2】：防遠端秒殺基礎設置 (狀態免疫)
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
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        end)
    end

    -- 記錄原始數據 (用於還原)
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                OriginalSizes[part] = part.Size
            elseif part:IsA("Motor6D") then
                OriginalC0s[part] = part.C0
            end
        end
    end

    -- 【累積 3】：物理抹除 (零卡頓 Anti-Fling)
    connections.Stepped = RunService.Stepped:Connect(function()
        if not Flags.AbsoluteDefense then return end
        
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

    -- 【累積 4 & 8 & 9 & 10】：綜合極限運算 (Heartbeat)
    connections.Heartbeat = RunService.Heartbeat:Connect(function()
        if not Flags.AbsoluteDefense then return end
        local char = LocalPlayer.Character
        if not char then return end
        
        -- 【累積 9 (NEW)】：自我奇異點 - 體積無限小 + 瘋狂向內自轉 + 隱藏頭部
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                -- 將自己的 Hitbox 縮小至引擎極限
                part.Size = Vector3.new(0.01, 0.01, 0.01)
                part.Massless = true
                if part.Name == "Head" then
                    part.Transparency = 1 -- 讓頭部完全隱形
                end
            elseif part:IsA("Motor6D") then
                -- 讓所有關節向內無限摺疊並瘋狂自轉 (完全隱藏原本的人形結構)
                part.C0 = CFrame.new(0, 0, 0) * CFrame.Angles(
                    math.rad(math.random(-36000, 36000)), 
                    math.rad(math.random(-36000, 36000)), 
                    math.rad(math.random(-36000, 36000))
                )
            end
        end

        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            realCFrame = hrp.CFrame
            
            -- 【累積 8】：反投擲物操控 (半徑 20 單位抹除)
            local overlapParams = OverlapParams.new()
            overlapParams.FilterDescendantsInstances = {char}
            overlapParams.FilterType = Enum.RaycastFilterType.Exclude
            local incomingThreats = workspace:GetPartBoundsInRadius(realCFrame.Position, 20, overlapParams)
            for _, threat in ipairs(incomingThreats) do
                if threat:IsA("BasePart") and not threat.Anchored and threat.Size.Magnitude < 15 then
                    pcall(function()
                        threat.CanTouch = false 
                        threat.CanCollide = false
                        threat.CFrame = CFrame.new(0, -50000, 0)
                    end)
                end
            end

            -- 【累積 4】：極限解同步 (防指向攻擊)
            local limitX = (math.random() > 0.5 and 1 or -1) * LIMIT_COORD
            local limitZ = (math.random() > 0.5 and 1 or -1) * LIMIT_COORD
            hrp.CFrame = CFrame.new(limitX, LIMIT_COORD / 10, limitZ)
            
            -- 本體超高速自轉，干擾任何嘗試瞄準的 Aimbot
            hrp.RotVelocity = Vector3.new(0, 9e9, 0)
        end

        -- 【累積 10 (NEW)】：無限放大敵人 Hitbox
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local enemyHRP = player.Character:FindFirstChild("HumanoidRootPart") or player.Character:FindFirstChild("Torso")
                if enemyHRP then
                    -- 將敵人的 Hitbox 放大到極度誇張的大小 (長寬高各50)
                    enemyHRP.Size = Vector3.new(50, 50, 50)
                    enemyHRP.Transparency = 0.6 -- 半透明顯示，防止擋住視線
                    enemyHRP.BrickColor = BrickColor.new("Bright red")
                    enemyHRP.Material = Enum.Material.ForceField
                    enemyHRP.CanCollide = false -- 避免你自己卡在他們巨大的 Hitbox 上
                end
            end
        end
    end)

    -- 【累積 5】：客戶端視角還原 (保證你能正常遊玩)
    connections.Render = RunService.RenderStepped:Connect(function()
        if not Flags.AbsoluteDefense then return end
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") and realCFrame then
            char.HumanoidRootPart.CFrame = realCFrame
        end
    end)
    
    -- 【累積 6】：防爆系統 (Anti-Explosion)
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
        -- 還原自己尺寸與關節
        for part, size in pairs(OriginalSizes) do
            if part and part.Parent then part.Size = size end
        end
        for motor, c0 in pairs(OriginalC0s) do
            if motor and motor.Parent then motor.C0 = c0 end
        end
        if char:FindFirstChild("Head") then
            char.Head.Transparency = 0
        end

        if char:FindFirstChild("Humanoid") then
            pcall(function()
                char.Humanoid.MaxHealth = 100
                char.Humanoid.Health = 100
                char.Humanoid.RequiresNeck = true
                char.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
            end)
        end
    end
end

-- ==========================================
-- [ 微型化 UI 介面構建 (可移動) ]
-- ==========================================
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'AegisV5GUI'
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- 縮小版的背景框
local MainFrame = Instance.new('Frame')
MainFrame.Size = UDim2.new(0, 150, 0, 50) -- 體積縮小
MainFrame.Position = UDim2.new(0.5, -75, 0.85, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui
Instance.new('UICorner', MainFrame).CornerRadius = UDim.new(0, 6)

local UIStroke = Instance.new('UIStroke')
UIStroke.Color = Color3.fromRGB(80, 80, 200)
UIStroke.Thickness = 1.5
UIStroke.Parent = MainFrame

-- 微型開關按鈕
local ToggleBtn = Instance.new('TextButton')
ToggleBtn.Size = UDim2.new(1, -10, 1, -10)
ToggleBtn.Position = UDim2.new(0, 5, 0, 5)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
ToggleBtn.Text = 'Aegis V5 [ OFF ]'
ToggleBtn.TextColor3 = Color3.fromRGB(150, 150, 255)
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.TextSize = 13 -- 字體縮小
ToggleBtn.Parent = MainFrame
Instance.new('UICorner', ToggleBtn).CornerRadius = UDim.new(0, 4)

ToggleBtn.MouseButton1Click:Connect(function()
    Flags.AbsoluteDefense = not Flags.AbsoluteDefense
    
    if Flags.AbsoluteDefense then
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(20, 40, 20)
        ToggleBtn.TextColor3 = Color3.fromRGB(100, 255, 100)
        ToggleBtn.Text = 'Aegis V5 [ ON ]'
        UIStroke.Color = Color3.fromRGB(50, 255, 100)
        ActivateLimitEngine()
    else
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
        ToggleBtn.TextColor3 = Color3.fromRGB(150, 150, 255)
        ToggleBtn.Text = 'Aegis V5 [ OFF ]'
        UIStroke.Color = Color3.fromRGB(80, 80, 200)
        DeactivateLimitEngine()
    end
end)

-- 極度滑順的拖曳邏輯 (讓微型 UI 可隨意移動)
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

-- 【累積功能 7】：死亡/重生自動掛載
LocalPlayer.CharacterAdded:Connect(function()
    task.delay(0.5, function()
        if Flags.AbsoluteDefense then ActivateLimitEngine() end
    end)
end)
