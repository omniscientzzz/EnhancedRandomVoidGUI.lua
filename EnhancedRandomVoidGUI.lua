local fenv = getfenv()
fenv.require = function() end

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')
local CoreGui = game:GetService('CoreGui')
local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- [ 清理舊版 UI ]
-- ==========================================
local function ForceCleanOldGUIs()
    local guiNames = {'VoidGUI', 'UltimateVoidGUI', 'AegisShieldGUI', 'V8GodModeGUI', 'V8OmnipotentGUI'}
    for _, guiName in ipairs(guiNames) do
        pcall(function()
            local pg = LocalPlayer:FindFirstChild("PlayerGui")
            if pg and pg:FindFirstChild(guiName) then pg[guiName]:Destroy() end
            if CoreGui:FindFirstChild(guiName) then CoreGui[guiName]:Destroy() end
        end)
    end
end
ForceCleanOldGUIs()

-- ==========================================
-- [ 全域狀態變數 ]
-- ==========================================
local Flags = {
    V8Defense = false,
    GodMode = false,
    AntiExplosion = false,
    AntiRemote = false,
    AntiFling = false,
    AntiState = false,
    Hitbox = false,
    ESP = false
}

local connections = {}
local espHighlights = {}

-- ==========================================
-- [ 模組 1: V8 欺騙防禦 (CFrame 亂數擾亂) ]
-- ==========================================
local function ToggleV8Defense(state)
    Flags.V8Defense = state
    if connections.V8Spoof then connections.V8Spoof:Disconnect() end
    if connections.V8Render then connections.V8Render:Disconnect() end

    if state then
        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:WaitForChild("HumanoidRootPart", 3)
        if not hrp then return end

        local realCFrame = hrp.CFrame
        connections.V8Spoof = RunService.Heartbeat:Connect(function()
            if not hrp or not hrp.Parent then return end
            realCFrame = hrp.CFrame
            hrp.CFrame = hrp.CFrame + Vector3.new(math.random(-250, 250), math.random(50, 300), math.random(-250, 250))
            hrp.AssemblyLinearVelocity = Vector3.new(math.random(-9999, 9999), math.random(-9999, 9999), math.random(-9999, 9999))
        end)
        connections.V8Render = RunService.RenderStepped:Connect(function()
            if not hrp or not hrp.Parent then return end
            hrp.CFrame = realCFrame
        end)
    end
end

-- ==========================================
-- [ 模組 2: V8 絕對無敵 (十萬米高空解同步) ]
-- ==========================================
local function ToggleGodMode(state)
    Flags.GodMode = state
    if connections.GodSpoof then connections.GodSpoof:Disconnect() end
    if connections.GodRender then connections.GodRender:Disconnect() end

    if state then
        if Flags.V8Defense then ToggleV8Defense(false) end
        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:WaitForChild("HumanoidRootPart", 3)
        local hum = char:WaitForChild("Humanoid", 3)
        if not hrp or not hum then return end

        pcall(function()
            hum.BreakJointsOnDeath = false
            hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
        end)

        local originalCFrame = hrp.CFrame
        connections.GodSpoof = RunService.Heartbeat:Connect(function()
            if not hrp or not hrp.Parent then return end
            originalCFrame = hrp.CFrame
            hrp.CFrame = CFrame.new(0, 999999, 0)
            hrp.AssemblyLinearVelocity = Vector3.zero
        end)
        connections.GodRender = RunService.RenderStepped:Connect(function()
            if not hrp or not hrp.Parent then return end
            hrp.CFrame = originalCFrame
        end)
    else
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("Humanoid") then
            char.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
        end
        if Flags.V8Defense then ToggleV8Defense(true) end
    end
end

-- ==========================================
-- [ 模組 3: 防爆裝甲 (Anti-Explosion) ]
-- ==========================================
-- 攔截並無效化所有生成的爆炸物件
workspace.DescendantAdded:Connect(function(desc)
    if Flags.AntiExplosion and desc:IsA("Explosion") then
        pcall(function()
            desc.BlastPressure = 0
            desc.BlastRadius = 0
            desc.DestroyJointRadiusPercent = 0
            desc.ExplosionType = Enum.ExplosionType.NoCraters
            task.defer(function() desc:Destroy() end)
        end)
    end
end)

-- ==========================================
-- [ 模組 4: 防遠程擊殺與防踢 (Anti-Remote/Kick) ]
-- ==========================================
-- 使用 metatable 攔截危險的 RemoteEvents 和 Client Kick
pcall(function()
    local gm = getrawmetatable(game)
    if gm then
        setreadonly(gm, false)
        local oldNamecall = gm.__namecall
        gm.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            local args = {...}
            if Flags.AntiRemote then
                -- 攔截本地防作弊 Kick
                if method == "Kick" or method == "kick" then
                    return
                end
                -- 攔截伺服器濫用的擊殺/封禁 Remote
                if (method == "FireServer" or method == "InvokeServer") and self.Name then
                    local name = string.lower(self.Name)
                    if name:find("kill") or name:find("ban") or name:find("kick") or name:find("crash") or name:find("punish") then
                        return -- 靜默攔截
                    end
                end
            end
            return oldNamecall(self, unpack(args))
        end)
        setreadonly(gm, true)
    end
end)

-- ==========================================
-- [ 模組 5: 物理防禦 (Anti-Fling & 碰撞免疫) ]
-- ==========================================
RunService.Stepped:Connect(function()
    if Flags.AntiFling then
        -- 關閉與其他玩家的碰撞，防止被推擠或 Fling 飛天
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                for _, part in ipairs(player.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end
        -- 限制自身異常速度，防止被伺服器物理引擎彈飛
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local hrp = char.HumanoidRootPart
            if hrp.AssemblyLinearVelocity.Magnitude > 300 or hrp.AssemblyAngularVelocity.Magnitude > 300 then
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end
        end
    end
end)

-- ==========================================
-- [ 模組 6: 狀態免疫 (Anti-Void & Anti-Sit) ]
-- ==========================================
RunService.Heartbeat:Connect(function()
    if Flags.AntiState then
        local char = LocalPlayer.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChild("Humanoid")
            
            -- 防墜落死亡 (自動彈回地面)
            if hrp and hrp.Position.Y < (workspace.FallenPartsDestroyHeight + 50) then
                hrp.CFrame = hrp.CFrame + Vector3.new(0, 500, 0)
                hrp.AssemblyLinearVelocity = Vector3.zero
            end
            
            -- 防止被強制坐下、摔倒或布娃娃狀態
            if hum then
                if hum.Sit then hum.Sit = false end
                if hum.PlatformStand then hum.PlatformStand = false end
                hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
                hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
                hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
            end
        end
    end
end)

-- ==========================================
-- [ 模組 7: 致命打擊 (Hitbox) ]
-- ==========================================
task.spawn(function()
    while task.wait(0.5) do
        if Flags.Hitbox then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    if player.Team ~= LocalPlayer.Team or player.Team == nil then
                        local enemyHrp = player.Character.HumanoidRootPart
                        pcall(function()
                            enemyHrp.Size = Vector3.new(25, 25, 25)
                            enemyHrp.Transparency = 0.7
                            enemyHrp.BrickColor = BrickColor.new("Really red")
                            enemyHrp.Material = Enum.Material.ForceField
                            enemyHrp.CanCollide = false
                        end)
                    end
                end
            end
        else
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    local enemyHrp = player.Character.HumanoidRootPart
                    if enemyHrp.Size.X > 5 then
                        pcall(function()
                            enemyHrp.Size = Vector3.new(2, 2, 1)
                            enemyHrp.Transparency = 1
                        end)
                    end
                end
            end
        end
    end
end)

-- ==========================================
-- [ 模組 8: 戰術透視 (ESP) ]
-- ==========================================
local function UpdateESP()
    for _, hl in pairs(espHighlights) do if hl then hl:Destroy() end end
    table.clear(espHighlights)
    if Flags.ESP then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                if player.Team ~= LocalPlayer.Team or player.Team == nil then
                    local hl = Instance.new("Highlight")
                    hl.Adornee = player.Character
                    hl.FillColor = Color3.fromRGB(255, 0, 50)
                    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                    hl.FillTransparency = 0.5
                    hl.OutlineTransparency = 0.1
                    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    hl.Parent = CoreGui
                    table.insert(espHighlights, hl)
                end
            end
        end
    end
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function() task.wait(1); if Flags.ESP then UpdateESP() end end)
end)
for _, player in ipairs(Players:GetPlayers()) do
    player.CharacterAdded:Connect(function() task.wait(1); if Flags.ESP then UpdateESP() end end)
end

-- ==========================================
-- [ 全新滾動式 UI 介面設計 (V8 OMNIPOTENT) ]
-- ==========================================
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'V8OmnipotentGUI'
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new('Frame')
MainFrame.Size = UDim2.new(0, 280, 0, 320)
MainFrame.Position = UDim2.new(0.5, -140, 0.5, -160)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui
Instance.new('UICorner', MainFrame).CornerRadius = UDim.new(0, 8)

local UIStroke = Instance.new('UIStroke')
UIStroke.Color = Color3.fromRGB(100, 50, 255)
UIStroke.Thickness = 2
UIStroke.Parent = MainFrame

local Title = Instance.new('TextLabel')
Title.Size = UDim2.new(1, 0, 0, 35)
Title.BackgroundTransparency = 1
Title.Text = '⚡ V8 OMNIPOTENT 終極防禦 ⚡'
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 14
Title.Font = Enum.Font.GothamBold
Title.Parent = MainFrame

local ScrollFrame = Instance.new('ScrollingFrame')
ScrollFrame.Size = UDim2.new(1, -10, 1, -65)
ScrollFrame.Position = UDim2.new(0, 5, 0, 35)
ScrollFrame.BackgroundTransparency = 1
ScrollFrame.ScrollBarThickness = 4
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 355)
ScrollFrame.Parent = MainFrame

local ListLayout = Instance.new('UIListLayout', ScrollFrame)
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Padding = UDim.new(0, 8)
ListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local function CreateToggleButton(text, layoutOrder, flagKey, activeColor)
    local btn = Instance.new('TextButton')
    btn.Size = UDim2.new(1, -15, 0, 36)
    btn.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 12
    btn.LayoutOrder = layoutOrder
    btn.Parent = ScrollFrame
    Instance.new('UICorner', btn).CornerRadius = UDim.new(0, 6)
    
    local stroke = Instance.new('UIStroke', btn)
    stroke.Color = Color3.fromRGB(40, 40, 50)
    
    btn.MouseButton1Click:Connect(function()
        Flags[flagKey] = not Flags[flagKey]
        if Flags[flagKey] then
            btn.BackgroundColor3 = activeColor
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            stroke.Color = activeColor
        else
            btn.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
            btn.TextColor3 = Color3.fromRGB(200, 200, 200)
            stroke.Color = Color3.fromRGB(40, 40, 50)
        end

        if flagKey == "V8Defense" and not Flags.GodMode then ToggleV8Defense(Flags.V8Defense)
        elseif flagKey == "GodMode" then ToggleGodMode(Flags.GodMode)
        elseif flagKey == "ESP" then UpdateESP() end
    end)
end

-- ==========================================
-- [ 建立按鈕清單 ]
-- ==========================================
CreateToggleButton('🛡️ V8 欺騙防禦 (CFrame亂數防預判)', 1, "V8Defense", Color3.fromRGB(0, 150, 255))
CreateToggleButton('👼 V8 絕對無敵 (十萬米高空解同步)', 2, "GodMode", Color3.fromRGB(255, 215, 0))
CreateToggleButton('💣 防爆裝甲 (無效化爆炸範圍/傷害)', 3, "AntiExplosion", Color3.fromRGB(255, 100, 0))
CreateToggleButton('🚫 防遠程擊殺/踢出 (攔截底層代碼)', 4, "AntiRemote", Color3.fromRGB(200, 0, 50))
CreateToggleButton('🧱 物理防禦 (免疫推擠與Fling飛天)', 5, "AntiFling", Color3.fromRGB(0, 200, 150))
CreateToggleButton('🛑 狀態免疫 (防墜落死/防坐下倒地)', 6, "AntiState", Color3.fromRGB(50, 150, 150))
CreateToggleButton('⚔️ 致命打擊 (無延遲大判定)', 7, "Hitbox", Color3.fromRGB(220, 20, 60))
CreateToggleButton('👁️ 戰術透視 (順暢原生ESP)', 8, "ESP", Color3.fromRGB(150, 50, 255))

local Tip = Instance.new('TextLabel')
Tip.Size = UDim2.new(1, 0, 0, 20)
Tip.Position = UDim2.new(0, 0, 1, -25)
Tip.BackgroundTransparency = 1
Tip.Text = '[Right Shift] 隱藏/顯示選單'
Tip.TextColor3 = Color3.fromRGB(120, 120, 120)
Tip.TextSize = 10
Tip.Font = Enum.Font.Gotham
Tip.Parent = MainFrame

-- UI 拖曳功能
local dragging, dragInput, dragStart, startPos
Title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true; dragStart = input.Position; startPos = MainFrame.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
    end
end)
Title.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.RightShift then
        MainFrame.Visible = not MainFrame.Visible
    end
end)

-- 角色重生時自動恢復部分狀態防禦
LocalPlayer.CharacterAdded:Connect(function()
    task.delay(1, function()
        if Flags.GodMode then ToggleGodMode(true)
        elseif Flags.V8Defense then ToggleV8Defense(true) end
    end)
end)
