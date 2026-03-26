-- [[ 絕對防禦 V7 (量子撕裂版)：極致 100 億高頻 TP ]] --
-- 維護者：專屬腳本架構師
-- 特色：三軸 ±100 億極限隨機座標，保證每幀位移 > 7 億，徹底摧毀敵方自瞄運算

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')
local CoreGui = game:GetService('CoreGui')
local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- [ 清理舊版 UI ]
-- ==========================================
pcall(function()
    local oldGUI = CoreGui:FindFirstChild("AegisV7GUI") or LocalPlayer:FindFirstChild("PlayerGui"):FindFirstChild("AegisV7GUI")
    if oldGUI then oldGUI:Destroy() end
end)

-- ==========================================
-- [ 全域狀態與變數 ]
-- ==========================================
local Flags = { AbsoluteDefense = false }
local connections = {}
local realCFrame = nil
local realVelocity = Vector3.new(0, 0, 0)
local lastFakePos = Vector3.new(0, 0, 0)

-- 極限參數設定
local MAX_COORD = 10000000000 -- 100 億 (±1e10)
local MIN_JUMP = 700000000    -- 7 億 (7e8)

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
-- [ 核心引擎：V7 極限躍遷機制 ]
-- ==========================================
local function ActivateLimitEngine()
    ClearConnections()
    -- 關閉掉落死亡限制，否則在 -100 億的 Y 軸會瞬間死亡
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

    -- 【階段 1：捕獲真實狀態 (保障本機端控制權)】
    connections.Stepped = RunService.Stepped:Connect(function()
        if not Flags.AbsoluteDefense then return end
        local currentChar = LocalPlayer.Character
        if currentChar then
            local hrp = currentChar:FindFirstChild("HumanoidRootPart")
            if hrp then
                realCFrame = hrp.CFrame
                realVelocity = hrp.AssemblyLinearVelocity
            end
            
            -- 關閉敵人碰撞，防止物理拉扯
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    for _, part in ipairs(player.Character:GetChildren()) do
                        if part:IsA("BasePart") then part.CanCollide = false end
                    end
                end
            end
        end
    end)

    -- 【階段 2：伺服器極限欺騙 (100億高頻 TP)】
    connections.Heartbeat = RunService.Heartbeat:Connect(function()
        if not Flags.AbsoluteDefense then return end
        local char = LocalPlayer.Character
        if not char then return end
        
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp and realCFrame then
            local newFakePos
            
            -- 演算法：生成新的 100 億範圍座標，並強制檢測與上次的距離是否大於 7 億
            repeat
                newFakePos = Vector3.new(
                    (math.random() * 2 - 1) * MAX_COORD, -- X 軸: -100億 ~ 100億
                    (math.random() * 2 - 1) * MAX_COORD, -- Y 軸: -100億 ~ 100億
                    (math.random() * 2 - 1) * MAX_COORD  -- Z 軸: -100億 ~ 100億
                )
            until (newFakePos - lastFakePos).Magnitude >= MIN_JUMP
            
            lastFakePos = newFakePos
            
            -- 寫入伺服器座標與極端旋轉/速度
            hrp.CFrame = CFrame.new(newFakePos) * CFrame.Angles(
                math.rad(math.random(-180, 180)), 
                math.rad(math.random(-180, 180)), 
                math.rad(math.random(-180, 180))
            )
            hrp.AssemblyLinearVelocity = Vector3.new(math.random(-99999, 99999), math.random(-99999, 99999), math.random(-99999, 99999))
            hrp.AssemblyAngularVelocity = Vector3.new(math.random(-9999, 9999), math.random(-9999, 9999), math.random(-9999, 9999))
            
            -- 自我奇異點 (微縮身軀)
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Size = Vector3.new(0.01, 0.01, 0.01)
                    part.Massless = true
                    if part.Name == "Head" then part.Transparency = 1 end
                end
            end
        end
    end)

    -- 【階段 3：本地端完美還原】
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
    
    -- 爆炸免疫系統
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
-- [ 極簡單鍵 UI 介面 (V7 量子版) ]
-- ==========================================
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'AegisV7GUI'
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new('Frame')
MainFrame.Size = UDim2.new(0, 160, 0, 42) -- 恢復單一按鈕大小
MainFrame.Position = UDim2.new(0.5, -80, 0.85, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(10, 5, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui
Instance.new('UICorner', MainFrame).CornerRadius = UDim.new(0, 8)

local UIStroke = Instance.new('UIStroke')
UIStroke.Color = Color3.fromRGB(150, 50, 255) -- V7 專屬量子紫
UIStroke.Thickness = 2
UIStroke.Parent = MainFrame

-- 按鈕 1：主開關
local ToggleBtn = Instance.new('TextButton')
ToggleBtn.Size = UDim2.new(1, -12, 1, -12)
ToggleBtn.Position = UDim2.new(0, 6, 0, 6)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(20, 15, 30)
ToggleBtn.Text = 'Quantum [ OFF ]'
ToggleBtn.TextColor3 = Color3.fromRGB(180, 100, 255)
ToggleBtn.Font = Enum.Font.GothamBlack
ToggleBtn.TextSize = 13 
ToggleBtn.Parent = MainFrame
Instance.new('UICorner', ToggleBtn).CornerRadius = UDim.new(0, 6)

ToggleBtn.MouseButton1Click:Connect(function()
    Flags.AbsoluteDefense = not Flags.AbsoluteDefense
    if Flags.AbsoluteDefense then
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(40, 10, 60)
        ToggleBtn.TextColor3 = Color3.fromRGB(200, 150, 255)
        ToggleBtn.Text = 'Quantum [ ON ]'
        ActivateLimitEngine()
    else
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(20, 15, 30)
        ToggleBtn.TextColor3 = Color3.fromRGB(180, 100, 255)
        ToggleBtn.Text = 'Quantum [ OFF ]'
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
