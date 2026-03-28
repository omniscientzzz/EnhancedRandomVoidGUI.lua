local fenv = getfenv()
fenv.require = function() end

-- [[ VOID x AEGIS V20: ABSOLUTE DESYNC (絕對脫軌) ]] --
-- 終極防禦：本地遊玩，伺服器判定放逐高空，自體判定框徹底抹除，敵方判定框擴張 2048

local Players = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')
local RunService = game:GetService('RunService')

local LocalPlayer = Players.LocalPlayer
local toggleKey = Enum.KeyCode.P

-- ==========================================
-- [ 核心奇點參數 ]
-- ==========================================
local DESYNC_HEIGHT = 500000 -- 伺服器端假身高度 (50萬格高空)
local VOID_DEPTH = -99999 -- 自身判定框放逐深度
local FORCEFIELD_RADIUS = 100 -- 黑洞力場半徑

local isActive = false
local realCFrame = nil
local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Exclude

-- 連接池
local renderConnection = nil
local heartbeatConnection = nil
local hitboxConnection = nil

-- ==========================================
-- [ 異步 Hitbox 處理 (敵方 2048 擴張) ]
-- ==========================================
task.spawn(function()
    while true do
        task.wait(0.1) -- 提高刷新頻率以防遊戲重置 Hitbox
        if isActive then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character then
                    -- 【敵方：絕對路徑 2048 Hitbox 擴張】
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
ScreenGui.Name = 'VoidAbsoluteGUI'
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = game:GetService('CoreGui') end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new('Frame')
MainFrame.Name = 'MainFrame'
MainFrame.Size = UDim2.new(0, 310, 0, 290)
MainFrame.Position = UDim2.new(0.85, -50, 0.75, -90)
MainFrame.BackgroundColor3 = Color3.fromRGB(5, 0, 10) 
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true 
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new('UICorner', MainFrame)
MainCorner.CornerRadius = UDim.new(0, 8)

local MainStroke = Instance.new('UIStroke', MainFrame)
MainStroke.Color = Color3.fromRGB(255, 0, 100)
MainStroke.Thickness = 2

local TitleText = Instance.new('TextLabel', MainFrame)
TitleText.Size = UDim2.new(1, 0, 0, 30)
TitleText.BackgroundTransparency = 1
TitleText.Text = '🩸 V20 ABSOLUTE DESYNC'
TitleText.TextColor3 = Color3.fromRGB(255, 100, 150)
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
ToggleBtn.BackgroundColor3 = Color3.fromRGB(80, 0, 30)
ToggleBtn.Text = 'ENGAGE DESYNC [P]'
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 14
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = MainFrame
Instance.new('UICorner', ToggleBtn).CornerRadius = UDim.new(0, 4)

local StatsText = Instance.new('TextLabel', MainFrame)
StatsText.Size = UDim2.new(1, 0, 0, 160)
StatsText.Position = UDim2.new(0.1, 0, 0, 115)
StatsText.BackgroundTransparency = 1
StatsText.Text = '[✓] True Network Desync (500k)\n[✓] Self Hitbox Banished (-99k)\n[✓] Absolute Intangibility\n[✓] Blackhole Shield (100 Studs)\n[✓] Enemy 2048x HitboxHead'
StatsText.TextColor3 = Color3.fromRGB(255, 180, 200)
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

    -- [核心 1] Heartbeat：物理結算後，欺騙伺服器與抹除自身 Hitbox
    heartbeatConnection = RunService.Heartbeat:Connect(function()
        if not isActive then return end
        local currentHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not currentHrp then return end

        -- 1. 儲存你本地真實操作的正確位置
        realCFrame = currentHrp.CFrame
        
        -- 2. 真·網路脫軌：將你的實體拋到 50萬格高空 (伺服器和其他玩家會認為你在這)
        local voidOffset = Vector3.new(math.random(-100, 100), DESYNC_HEIGHT, math.random(-100, 100))
        currentHrp.CFrame = realCFrame + voidOffset
        
        -- 3. 抹除你自己的 Hitbox (防止遊戲使用獨立判定框)
        pcall(function()
            local myHitbox = workspace:FindFirstChild(LocalPlayer.Name) and workspace[LocalPlayer.Name]:FindFirstChild("HitboxHead")
            if myHitbox then
                -- 將自己的判定框放逐到地底極深處，尺寸歸零，並關閉一切物理探測
                myHitbox.CFrame = CFrame.new(0, VOID_DEPTH, 0)
                myHitbox.Size = Vector3.new(0, 0, 0)
                myHitbox.CanCollide = false
                myHitbox.CanQuery = false
                myHitbox.CanTouch = false
                myHitbox.Transparency = 1
            end
        end)

        -- 4. 本體無形化 (免疫 Raycast 光線追蹤)
        for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                pcall(function()
                    part.CanQuery = false 
                    part.CanTouch = false
                end)
            end
        end

        -- 5. 黑洞力場 (防禦近身或投擲物)
        local threats = workspace:GetPartBoundsInRadius(realCFrame.Position, FORCEFIELD_RADIUS, overlapParams)
        for _, threat in ipairs(threats) do
            if threat:IsA("BasePart") and threat.Size.Magnitude < 100 then
                pcall(function() threat.CanTouch = false threat.CanQuery = false end)
                if not threat.Anchored then
                    threat.AssemblyLinearVelocity = Vector3.new(math.huge, math.huge, math.huge)
                end
            end
        end
    end)

    -- [核心 2] RenderStepped：在畫面渲染前，把你拉回真實位置，讓你能正常玩
    renderConnection = RunService.RenderStepped:Connect(function()
        if not isActive then return end
        local currentHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if currentHrp and realCFrame then
            -- 覆蓋掉剛才 Heartbeat 的高空假座標，讓你的視角和操作完全正常
            currentHrp.CFrame = realCFrame
        end
    end)
end

local function StopApotheosis()
    if renderConnection then renderConnection:Disconnect() end
    if heartbeatConnection then heartbeatConnection:Disconnect() end
    if hitboxConnection then hitboxConnection:Disconnect() end
    
    local char = LocalPlayer.Character
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                pcall(function()
                    part.CanTouch = true
                    part.CanQuery = true
                end)
            end
        end

        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp and realCFrame then
            hrp.CFrame = realCFrame
        end
    end
end

-- ==========================================
-- [ UI 與控制邏輯 ]
-- ==========================================
local isHovering = false

local function UpdateUI()
    if isActive then
        StatusText.Text = 'STATUS: ABSOLUTE VOID'
        StatusText.TextColor3 = Color3.fromRGB(255, 0, 100)
        MainStroke.Color = Color3.fromRGB(255, 0, 100)
        ToggleBtn.Text = 'EXIT VOID [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(120, 0, 50) or Color3.fromRGB(100, 0, 40)
    else
        StatusText.Text = 'STATUS: VULNERABLE'
        StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
        MainStroke.Color = Color3.fromRGB(100, 100, 100)
        ToggleBtn.Text = 'ENGAGE DESYNC [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(100, 0, 40) or Color3.fromRGB(80, 0, 30)
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
