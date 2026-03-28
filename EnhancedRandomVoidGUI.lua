local fenv = getfenv()
fenv.require = function() end

-- [[ VOID x AEGIS V21: AEGIS OVERRIDE (神盾覆寫) ]] --
-- 終極反外掛投擲物：動能欺騙、觸碰抹除、本地端投擲物強制湮滅

local Players = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')
local RunService = game:GetService('RunService')

local LocalPlayer = Players.LocalPlayer
local toggleKey = Enum.KeyCode.P

-- ==========================================
-- [ 核心奇點參數 ]
-- ==========================================
local DESYNC_HEIGHT = 500000 -- 伺服器端假身高度
local VOID_DEPTH = 500000 -- 放逐深度 (改為正數高空，避免觸發跌落死亡機制)
local FORCEFIELD_RADIUS = 150 -- 黑洞力場擴大至 150 格

local isActive = false
local realCFrame = nil
local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Exclude

-- 連接池
local renderConnection = nil
local heartbeatConnection = nil

-- ==========================================
-- [ 異步 Hitbox 處理 (敵方 2048 擴張) ]
-- ==========================================
task.spawn(function()
    while true do
        task.wait(0.1)
        if isActive then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character then
                    pcall(function()
                        local enemyHitbox = workspace:FindFirstChild(plr.Name) and workspace[plr.Name]:FindFirstChild("HitboxHead")
                        if enemyHitbox then
                            enemyHitbox.Size = Vector3.new(2048, 2048, 2048)
                            enemyHitbox.Transparency = 0.85
                            enemyHitbox.CanCollide = false
                            enemyHitbox.Massless = true
                        end
                    end)
                end
            end
        end
    end
end)

-- ==========================================
-- [ GUI 建構 ]
-- ==========================================
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'AegisV21GUI'
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = game:GetService('CoreGui') end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new('Frame')
MainFrame.Name = 'MainFrame'
MainFrame.Size = UDim2.new(0, 310, 0, 310)
MainFrame.Position = UDim2.new(0.85, -50, 0.75, -110)
MainFrame.BackgroundColor3 = Color3.fromRGB(5, 5, 15) 
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true 
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new('UICorner', MainFrame)
MainCorner.CornerRadius = UDim.new(0, 8)

local MainStroke = Instance.new('UIStroke', MainFrame)
MainStroke.Color = Color3.fromRGB(0, 200, 255)
MainStroke.Thickness = 2

local TitleText = Instance.new('TextLabel', MainFrame)
TitleText.Size = UDim2.new(1, 0, 0, 30)
TitleText.BackgroundTransparency = 1
TitleText.Text = '🛡️ V21 AEGIS OVERRIDE'
TitleText.TextColor3 = Color3.fromRGB(100, 220, 255)
TitleText.TextSize = 16
TitleText.Font = Enum.Font.GothamBlack
TitleText.Parent = MainFrame

local StatusText = Instance.new('TextLabel', MainFrame)
StatusText.Size = UDim2.new(1, 0, 0, 20)
StatusText.Position = UDim2.new(0, 0, 0, 35)
StatusText.BackgroundTransparency = 1
StatusText.Text = 'STATUS: VULNERABLE'
StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusText.TextSize = 12
StatusText.Font = Enum.Font.GothamBold
StatusText.Parent = MainFrame

local ToggleBtn = Instance.new('TextButton', MainFrame)
ToggleBtn.Size = UDim2.new(0.8, 0, 0, 40)
ToggleBtn.Position = UDim2.new(0.1, 0, 0, 65)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(0, 40, 80)
ToggleBtn.Text = 'ENGAGE AEGIS [P]'
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 14
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = MainFrame
Instance.new('UICorner', ToggleBtn).CornerRadius = UDim.new(0, 4)

local StatsText = Instance.new('TextLabel', MainFrame)
StatsText.Size = UDim2.new(1, 0, 0, 180)
StatsText.Position = UDim2.new(0.1, 0, 0, 115)
StatsText.BackgroundTransparency = 1
StatsText.Text = '[✓] Velocity Spoof (Anti-Aimbot)\n[✓] TouchInterest Erasure\n[✓] True Network Desync\n[✓] Local Projectile Annihilation\n[✓] Absolute Intangibility'
StatsText.TextColor3 = Color3.fromRGB(180, 230, 255)
StatsText.TextSize = 12
StatsText.TextXAlignment = Enum.TextXAlignment.Left
StatsText.Font = Enum.Font.Code
StatsText.Parent = MainFrame

-- ==========================================
-- [ 引擎：絕對脫軌防禦機制啟動 ]
-- ==========================================
local function StartApotheosis()
    local char = LocalPlayer.Character
    if not char then return end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    realCFrame = hrp.CFrame
    overlapParams.FilterDescendantsInstances = {char}

    heartbeatConnection = RunService.Heartbeat:Connect(function()
        if not isActive then return end
        local currentHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not currentHrp then return end

        realCFrame = currentHrp.CFrame
        
        -- 1. 真·網路脫軌 (CFrame Desync)
        local voidOffset = Vector3.new(math.random(-10, 10), DESYNC_HEIGHT, math.random(-10, 10))
        currentHrp.CFrame = realCFrame + voidOffset
        
        -- 2. 動能欺騙 (Velocity Spoofing) - 徹底癱瘓敵方預判自瞄外掛
        currentHrp.AssemblyLinearVelocity = Vector3.new(math.huge, math.huge, math.huge)
        currentHrp.AssemblyAngularVelocity = Vector3.new(math.huge, math.huge, math.huge)
        
        -- 3. 自體 Hitbox 與觸碰抹除
        pcall(function()
            local myHitbox = workspace:FindFirstChild(LocalPlayer.Name) and workspace[LocalPlayer.Name]:FindFirstChild("HitboxHead")
            if myHitbox then
                myHitbox.CFrame = CFrame.new(0, VOID_DEPTH, 0)
                myHitbox.Size = Vector3.new(0, 0, 0)
                myHitbox.CanCollide = false
                myHitbox.CanQuery = false
                myHitbox.CanTouch = false
            end
        end)

        for _, obj in ipairs(LocalPlayer.Character:GetDescendants()) do
            -- 【絕對防禦】：強制刪除觸碰感應器，讓帶有傷害的投擲物無法觸發
            if obj:IsA("TouchTransmitter") then
                obj:Destroy()
            elseif obj:IsA("BasePart") then
                pcall(function()
                    obj.CanQuery = false 
                    obj.CanTouch = false
                end)
            end
        end

        -- 4. 絕對湮滅力場 (Local Projectile Eradication)
        local threats = workspace:GetPartBoundsInRadius(realCFrame.Position, FORCEFIELD_RADIUS, overlapParams)
        for _, threat in ipairs(threats) do
            if threat:IsA("BasePart") and threat.Size.Magnitude < 150 and not threat.Anchored then
                pcall(function()
                    -- 不只是彈開，而是直接在本地端將威脅物放逐到虛空並剝奪判定
                    threat.CFrame = CFrame.new(math.huge, math.huge, math.huge)
                    threat.AssemblyLinearVelocity = Vector3.zero
                    threat.CanTouch = false
                    threat.CanQuery = false
                    threat.Transparency = 1
                end)
            end
        end
    end)

    renderConnection = RunService.RenderStepped:Connect(function()
        if not isActive then return end
        local currentHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if currentHrp and realCFrame then
            -- 視覺回歸：讓你本地畫面看起來完全正常
            currentHrp.CFrame = realCFrame
            -- 將本地速度歸零，避免你自己控制時飛出去
            currentHrp.AssemblyLinearVelocity = Vector3.zero
            currentHrp.AssemblyAngularVelocity = Vector3.zero
        end
    end)
end

local function StopApotheosis()
    if renderConnection then renderConnection:Disconnect() end
    if heartbeatConnection then heartbeatConnection:Disconnect() end
    
    local char = LocalPlayer.Character
    if char then
        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("BasePart") then
                pcall(function()
                    obj.CanTouch = true
                    obj.CanQuery = true
                end)
            end
        end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp and realCFrame then
            hrp.CFrame = realCFrame
            hrp.AssemblyLinearVelocity = Vector3.zero
        end
    end
end

-- ==========================================
-- [ UI 與控制邏輯 ]
-- ==========================================
local isHovering = false

local function UpdateUI()
    if isActive then
        StatusText.Text = 'STATUS: AEGIS ACTIVE'
        StatusText.TextColor3 = Color3.fromRGB(0, 200, 255)
        MainStroke.Color = Color3.fromRGB(0, 200, 255)
        ToggleBtn.Text = 'EXIT AEGIS [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(0, 80, 150) or Color3.fromRGB(0, 60, 120)
    else
        StatusText.Text = 'STATUS: VULNERABLE'
        StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
        MainStroke.Color = Color3.fromRGB(100, 100, 100)
        ToggleBtn.Text = 'ENGAGE AEGIS [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(0, 60, 120) or Color3.fromRGB(0, 40, 80)
    end
end

local function ToggleSystem()
    isActive = not isActive
    UpdateUI()
    if isActive then StartApotheosis() else StopApotheosis() end
end

ToggleBtn.MouseEnter:Connect(function() isHovering = true UpdateUI() end)
ToggleBtn.MouseLeave:Connect(function() isHovering = false UpdateUI() end)
ToggleBtn.MouseButton1Click:Connect(ToggleSystem)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == toggleKey then
        ToggleSystem()
    end
end)

LocalPlayer.CharacterAdded:Connect(function(newChar)
    if isActive then
        task.wait(0.5)
        overlapParams.FilterDescendantsInstances = {newChar}
        StartApotheosis()
    end
end)
