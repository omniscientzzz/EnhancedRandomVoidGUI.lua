-- [[ 絕對防禦 V2：極限物理突破 + 防爆 + 防遠端秒殺 (無Hook版) ]] --
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')
local CoreGui = game:GetService('CoreGui')
local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- [ 清理舊版 UI ]
-- ==========================================
pcall(function()
    local oldGUI = CoreGui:FindFirstChild("V8SingularityGUI") or LocalPlayer:FindFirstChild("PlayerGui"):FindFirstChild("V8SingularityGUI")
    if oldGUI then oldGUI:Destroy() end
end)

-- ==========================================
-- [ 全域狀態與變數 ]
-- ==========================================
local Flags = { AbsoluteDefense = false }
local connections = {}
local realCFrame = nil
local LIMIT_COORD = 9e9 -- Lua 物理引擎極限數值 (90億)

-- ==========================================
-- [ 核心引擎：極限解同步 & 物理防禦 ]
-- ==========================================
local function ActivateLimitEngine()
    for _, c in pairs(connections) do c:Disconnect() end
    
    -- 1. 突破世界掉落極限 (掉進虛空也不會死)
    pcall(function() workspace.FallenPartsDestroyHeight = -math.huge end)

    -- [ Anti-Remote Kill (防遠端秒殺基礎設置) ]
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("Humanoid") then
        local hum = char.Humanoid
        pcall(function()
            hum.MaxHealth = math.huge
            hum.Health = math.huge
            hum.BreakJointsOnDeath = false
            hum.RequiresNeck = false -- 防止「斬首」類型的遠端秒殺
            
            -- 徹底關閉死亡狀態，即使血量歸零也不會死
            hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        end)
    end

    -- [ Stepped: 物理抹除 (Anti-Fling / Anti-Touch) ]
    connections.Stepped = RunService.Stepped:Connect(function()
        if not Flags.AbsoluteDefense then return end
        
        -- 讓其他玩家完全無法觸碰或用射線偵測你 (防禦近戰、子彈)
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                for _, part in ipairs(player.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                        part.CanTouch = false
                        part.CanQuery = false
                    end
                end
            end
        end

        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local hrp = char.HumanoidRootPart
            -- 鎖死速度，免疫任何黑洞、彈飛技能
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end
    end)

    -- [ Heartbeat: 伺服器座標發送 & Anti-Remote Kill 狀態鎖 ]
    connections.Heartbeat = RunService.Heartbeat:Connect(function()
        if not Flags.AbsoluteDefense then return end
        local char = LocalPlayer.Character
        if not char then return end
        
        -- [ 狀態鎖：強制鎖血 (應對伺服器強制扣血 Remote) ]
        local hum = char:FindFirstChild("Humanoid")
        if hum then
            if hum.Health < hum.MaxHealth then
                hum.Health = hum.MaxHealth
            end
            -- 清除所有可能觸發即死判定的 TouchInterest (防秒殺磚塊)
            for _, v in ipairs(char:GetDescendants()) do
                if v:IsA("TouchTransmitter") or v.Name == "TouchInterest" then
                    v:Destroy()
                end
            end
        end

        -- [ 極限解同步：9e9 空間轉移 ]
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            realCFrame = hrp.CFrame
            -- 將伺服器座標傳送至 Lua 物理極限 (90億)，迴避所有地圖砲與指向性 Remote
            local limitX = (math.random() > 0.5 and 1 or -1) * LIMIT_COORD
            local limitZ = (math.random() > 0.5 and 1 or -1) * LIMIT_COORD
            local limitY = LIMIT_COORD / 10 
            
            hrp.CFrame = CFrame.new(limitX, limitY, limitZ)
            hrp.Velocity = Vector3.new(0,0,0)
            hrp.RotVelocity = Vector3.new(0,0,0)
        end
    end)

    -- [ RenderStepped: 客戶端視角還原 ]
    connections.Render = RunService.RenderStepped:Connect(function()
        if not Flags.AbsoluteDefense then return end
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") and realCFrame then
            char.HumanoidRootPart.CFrame = realCFrame
        end
    end)
    
    -- [ Anti-Explosion (防爆系統) ]
    -- 監聽全域爆炸生成，瞬間將其威力與範圍歸零
    connections.Explosion = workspace.DescendantAdded:Connect(function(desc)
        if Flags.AbsoluteDefense and desc:IsA("Explosion") then
            desc.BlastPressure = 0
            desc.BlastRadius = 0
            desc.DestroyJointRadiusPercent = 0
            desc.ExplosionType = Enum.ExplosionType.NoCraters
            -- 延遲銷毀以防止引擎報錯
            task.defer(function() 
                pcall(function() desc:Destroy() end) 
            end)
        end
    end)

    -- 清理場上現有的爆炸物
    for _, desc in ipairs(workspace:GetDescendants()) do
        if desc:IsA("Explosion") then
            desc.BlastPressure = 0
            desc.BlastRadius = 0
            task.defer(function() pcall(function() desc:Destroy() end) end)
        end
    end
end

local function DeactivateLimitEngine()
    for _, c in pairs(connections) do c:Disconnect() end
    pcall(function() workspace.FallenPartsDestroyHeight = -500 end)
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("Humanoid") then
        pcall(function()
            char.Humanoid.MaxHealth = 100
            char.Humanoid.Health = 100
            char.Humanoid.RequiresNeck = true
            char.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
            char.Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
            char.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
        end)
    end
end

-- ==========================================
-- [ UI 介面構建 ]
-- ==========================================
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'V8SingularityGUI'
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new('Frame')
MainFrame.Size = UDim2.new(0, 260, 0, 100)
MainFrame.Position = UDim2.new(0.5, -130, 0.8, -50)
MainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui
Instance.new('UICorner', MainFrame).CornerRadius = UDim.new(0, 12)

local UIStroke = Instance.new('UIStroke')
UIStroke.Color = Color3.fromRGB(255, 50, 50)
UIStroke.Thickness = 2
UIStroke.Parent = MainFrame

local ToggleBtn = Instance.new('TextButton')
ToggleBtn.Size = UDim2.new(1, -20, 1, -20)
ToggleBtn.Position = UDim2.new(0, 10, 0, 10)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 5, 5)
ToggleBtn.Text = 'V2極限防禦 [ 關閉 ]\n(防爆+防秒殺)'
ToggleBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
ToggleBtn.Font = Enum.Font.GothamBlack
ToggleBtn.TextSize = 16
ToggleBtn.Parent = MainFrame
Instance.new('UICorner', ToggleBtn).CornerRadius = UDim.new(0, 8)

local BtnStroke = Instance.new('UIStroke', ToggleBtn)
BtnStroke.Color = Color3.fromRGB(255, 50, 50)

ToggleBtn.MouseButton1Click:Connect(function()
    Flags.AbsoluteDefense = not Flags.AbsoluteDefense
    
    if Flags.AbsoluteDefense then
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(5, 40, 15)
        ToggleBtn.TextColor3 = Color3.fromRGB(100, 255, 100)
        ToggleBtn.Text = 'V2極限防禦中 [ 啟用 ]\n(免疫爆破/處決)'
        UIStroke.Color = Color3.fromRGB(50, 255, 100)
        BtnStroke.Color = Color3.fromRGB(50, 255, 100)
        ActivateLimitEngine()
    else
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 5, 5)
        ToggleBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
        ToggleBtn.Text = 'V2極限防禦 [ 關閉 ]\n(防爆+防秒殺)'
        UIStroke.Color = Color3.fromRGB(255, 50, 50)
        BtnStroke.Color = Color3.fromRGB(255, 50, 50)
        DeactivateLimitEngine()
    end
end)

-- 拖曳邏輯
local dragging, dragInput, dragStart, startPos
MainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true; dragStart = input.Position; startPos = MainFrame.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
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

-- 死亡/重生自動掛載
LocalPlayer.CharacterAdded:Connect(function()
    task.delay(1, function()
        if Flags.AbsoluteDefense then ActivateLimitEngine() end
    end)
end)
