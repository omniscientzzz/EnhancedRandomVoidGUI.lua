-- [[ 絕對防禦 V6 (幻影疊加版)：全網Anti-Aim整合 + 反預判速度欺騙 + 終極解同步 ]] --
-- 維護者：專屬腳本架構師
-- 承諾：自動繼承所有穩定功能，極限化生存率，拒絕卡頓。

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
local Flags = { AbsoluteDefense = false }
local connections = {}
local realCFrame = nil
local realVelocity = Vector3.new(0, 0, 0)
local LIMIT_COORD = 9e8 -- Lua 物理引擎極限數值 (稍微調低避免伺服器踢出)

local function ClearConnections()
    for key, conn in pairs(connections) do
        if typeof(conn) == "RBXScriptConnection" then
            conn:Disconnect()
        end
    end
    table.clear(connections)
end

local OriginalSizes = {}
local OriginalC0s = {}

-- ==========================================
-- [ 核心引擎：V6 終極防禦機制 ]
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
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false) -- 防止被外力物理擊飛
        end)
    end

    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                OriginalSizes[part] = part.Size
            elseif part:IsA("Motor6D") then
                OriginalC0s[part] = part.C0
            end
        end
    end

    -- 【防撞擊與物理抹除】
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

    -- 【V6 核心：Anti-Aim, Velocity Spoofing, Jitter, Singularity】
    connections.Heartbeat = RunService.Heartbeat:Connect(function()
        if not Flags.AbsoluteDefense then return end
        local char = LocalPlayer.Character
        if not char then return end
        
        -- (繼承) 自我奇異點 - 體積無限小 + 隱藏頭部
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Size = Vector3.new(0.01, 0.01, 0.01)
                part.Massless = true
                if part.Name == "Head" then
                    part.Transparency = 1 
                end
            elseif part:IsA("Motor6D") then
                part.C0 = CFrame.new(0, 0, 0) * CFrame.Angles(
                    math.rad(math.random(-36000, 36000)), 
                    math.rad(math.random(-36000, 36000)), 
                    math.rad(math.random(-36000, 36000))
                )
            end
        end

        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            -- 儲存真實位置供客戶端畫面使用
            realCFrame = hrp.CFrame 
            realVelocity = hrp.AssemblyLinearVelocity
            
            -- (繼承) 反投擲物操控
            local overlapParams = OverlapParams.new()
            overlapParams.FilterDescendantsInstances = {char}
            overlapParams.FilterType = Enum.RaycastFilterType.Exclude
            local incomingThreats = workspace:GetPartBoundsInRadius(realCFrame.Position, 25, overlapParams)
            for _, threat in ipairs(incomingThreats) do
                if threat:IsA("BasePart") and not threat.Anchored and threat.Size.Magnitude < 15 then
                    pcall(function()
                        threat.CanTouch = false 
                        threat.CanCollide = false
                        threat.CFrame = CFrame.new(0, -50000, 0)
                    end)
                end
            end

            -- 【V6 新增 1：Velocity Spoofing (反預判)】
            -- 讓所有依賴預判(Prediction)的自瞄外掛完全失效
            hrp.AssemblyLinearVelocity = Vector3.new(
                math.random(-99999, 99999), 
                math.random(-99999, 99999), 
                math.random(-99999, 99999)
            )
            hrp.AssemblyAngularVelocity = Vector3.new(math.random(-99999, 99999), math.random(-99999, 99999), math.random(-99999, 99999))

            -- 【V6 新增 2：CFrame Jitter + Inverted Stance (伺服器震盪與上下顛倒)】
            -- 在極限座標周圍加入隨機的劇烈震盪，並且將角色上下顛倒 (埋藏頭部Hitbox)
            local limitX = (math.random() > 0.5 and 1 or -1) * LIMIT_COORD
            local limitZ = (math.random() > 0.5 and 1 or -1) * LIMIT_COORD
            local jitterX = math.random(-50, 50)
            local jitterY = math.random(-50, 50)
            local jitterZ = math.random(-50, 50)
            
            -- CFrame.Angles(math.rad(180)...) 讓角色倒立
            hrp.CFrame = CFrame.new(limitX + jitterX, (LIMIT_COORD / 10) + jitterY, limitZ + jitterZ) 
                         * CFrame.Angles(math.rad(180), math.rad(math.random(0, 360)), math.rad(math.random(-90, 90)))
        end

        -- (繼承) 無限放大敵人 Hitbox
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

    -- 【客戶端視角完美還原】
    -- 確保你的畫面不會因為上述的極端操作而瘋狂亂抖
    connections.Render = RunService.RenderStepped:Connect(function()
        if not Flags.AbsoluteDefense then return end
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") and realCFrame then
            char.HumanoidRootPart.CFrame = realCFrame
            -- 將你本地的物理速度還原，保證你能正常走路跳躍
            char.HumanoidRootPart.AssemblyLinearVelocity = realVelocity
            char.HumanoidRootPart.AssemblyAngularVelocity = Vector3.new(0,0,0)
        end
    end)
    
    -- (繼承) 防爆系統
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
-- [ 微型化 UI 介面 (V6 幻影版) ]
-- ==========================================
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'AegisV6GUI'
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new('Frame')
MainFrame.Size = UDim2.new(0, 160, 0, 45) 
MainFrame.Position = UDim2.new(0.5, -80, 0.85, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui
Instance.new('UICorner', MainFrame).CornerRadius = UDim.new(0, 8)

local UIStroke = Instance.new('UIStroke')
UIStroke.Color = Color3.fromRGB(120, 50, 200) -- V6專屬幻影紫
UIStroke.Thickness = 2
UIStroke.Parent = MainFrame

local ToggleBtn = Instance.new('TextButton')
ToggleBtn.Size = UDim2.new(1, -8, 1, -8)
ToggleBtn.Position = UDim2.new(0, 4, 0, 4)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(20, 15, 25)
ToggleBtn.Text = 'Phantom V6 [ OFF ]'
ToggleBtn.TextColor3 = Color3.fromRGB(180, 130, 255)
ToggleBtn.Font = Enum.Font.GothamBlack
ToggleBtn.TextSize = 12 
ToggleBtn.Parent = MainFrame
Instance.new('UICorner', ToggleBtn).CornerRadius = UDim.new(0, 6)

ToggleBtn.MouseButton1Click:Connect(function()
    Flags.AbsoluteDefense = not Flags.AbsoluteDefense
    
    if Flags.AbsoluteDefense then
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 10, 40)
        ToggleBtn.TextColor3 = Color3.fromRGB(220, 100, 255)
        ToggleBtn.Text = 'Phantom V6 [ ON ]'
        UIStroke.Color = Color3.fromRGB(200, 50, 255)
        ActivateLimitEngine()
    else
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(20, 15, 25)
        ToggleBtn.TextColor3 = Color3.fromRGB(180, 130, 255)
        ToggleBtn.Text = 'Phantom V6 [ OFF ]'
        UIStroke.Color = Color3.fromRGB(120, 50, 200)
        DeactivateLimitEngine()
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

LocalPlayer.CharacterAdded:Connect(function()
    task.delay(0.5, function()
        if Flags.AbsoluteDefense then ActivateLimitEngine() end
    end)
end)
