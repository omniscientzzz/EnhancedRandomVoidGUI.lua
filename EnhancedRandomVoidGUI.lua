local fenv = getfenv()
fenv.require = function() end

-- [[ VOID x AEGIS V25: OMNIPRESENCE (量子態瘋狂瞬移) ]] --
-- 物理與視覺的極致混亂：每秒 60 次廣域隨機瞬移
-- 攝影機強制穩定，殘影系統啟動

local Players = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService')

local LocalPlayer = Players.LocalPlayer
local toggleKey = Enum.KeyCode.P

local isActive = false
local lastOffset = Vector3.zero

-- ==========================================
-- [ 攝影機穩定錨點 ]
-- ==========================================
local CamAnchor = Instance.new("Part")
CamAnchor.Name = "AegisCamAnchor"
CamAnchor.Size = Vector3.new(1, 1, 1)
CamAnchor.Transparency = 1
CamAnchor.CanCollide = false
CamAnchor.Anchored = true
CamAnchor.Parent = workspace

local heartbeatConnection = nil
local ghostFolder = Instance.new("Folder")
ghostFolder.Name = "AegisGhosts"
ghostFolder.Parent = workspace

-- ==========================================
-- [ 視覺殘影生成 (Crazy TP 特效) ]
-- ==========================================
local function CreateAfterimage(cframe)
    -- 限制殘影生成頻率避免過度 Lag
    if math.random() > 0.4 then return end
    
    local ghost = Instance.new("Part")
    ghost.Size = Vector3.new(2, 5, 2)
    ghost.CFrame = cframe
    ghost.Anchored = true
    ghost.CanCollide = false
    ghost.Material = Enum.Material.ForceField
    ghost.Color = Color3.fromRGB(180, 0, 255) -- 量子紫
    ghost.Parent = ghostFolder
    
    -- 殘影消散動畫
    local tween = TweenService:Create(ghost, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Transparency = 1,
        Size = Vector3.new(0, 15, 0)
    })
    tween:Play()
    tween.Completed:Connect(function() ghost:Destroy() end)
end

-- ==========================================
-- [ GUI 建構 ]
-- ==========================================
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'AegisV25GUI'
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = game:GetService('CoreGui') end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new('Frame')
MainFrame.Name = 'MainFrame'
MainFrame.Size = UDim2.new(0, 310, 0, 320)
MainFrame.Position = UDim2.new(0.85, -50, 0.75, -110)
MainFrame.BackgroundColor3 = Color3.fromRGB(10, 0, 15)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true 
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new('UICorner', MainFrame)
MainCorner.CornerRadius = UDim.new(0, 8)

local MainStroke = Instance.new('UIStroke', MainFrame)
MainStroke.Color = Color3.fromRGB(150, 0, 255)
MainStroke.Thickness = 3

local TitleText = Instance.new('TextLabel', MainFrame)
TitleText.Size = UDim2.new(1, 0, 0, 30)
TitleText.BackgroundTransparency = 1
TitleText.Text = '🌀 V25 OMNIPRESENCE'
TitleText.TextColor3 = Color3.fromRGB(200, 100, 255)
TitleText.TextSize = 16
TitleText.Font = Enum.Font.GothamBlack
TitleText.Parent = MainFrame

local StatusText = Instance.new('TextLabel', MainFrame)
StatusText.Size = UDim2.new(1, 0, 0, 20)
StatusText.Position = UDim2.new(0, 0, 0, 35)
StatusText.BackgroundTransparency = 1
StatusText.Text = 'STATUS: STABLE'
StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusText.TextSize = 12
StatusText.Font = Enum.Font.GothamBold
StatusText.Parent = MainFrame

local ToggleBtn = Instance.new('TextButton', MainFrame)
ToggleBtn.Size = UDim2.new(0.8, 0, 0, 40)
ToggleBtn.Position = UDim2.new(0.1, 0, 0, 65)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 0, 50)
ToggleBtn.Text = 'INITIATE CRAZY TP [P]'
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 14
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = MainFrame
Instance.new('UICorner', ToggleBtn).CornerRadius = UDim.new(0, 4)

local StatsText = Instance.new('TextLabel', MainFrame)
StatsText.Size = UDim2.new(1, 0, 0, 190)
StatsText.Position = UDim2.new(0.1, 0, 0, 115)
StatsText.BackgroundTransparency = 1
StatsText.Text = '[⚡] FREQUENCY: 60 TP/sec\n[⚡] RADIUS: 200 - 800 Studs\n[⚡] CAMERA: Detached & Stabilized\n[⚡] AFTERIMAGE: Active\n[⚠] BREAKS ENEMY AIMBOT & DISTANCE CHECKS\n\nYour physical body is no longer bound to one location.'
StatsText.TextColor3 = Color3.fromRGB(180, 150, 255)
StatsText.TextSize = 11
StatsText.TextXAlignment = Enum.TextXAlignment.Left
StatsText.Font = Enum.Font.Code
StatsText.Parent = MainFrame

-- ==========================================
-- [ 核心：量子態瞬移迴圈 ]
-- ==========================================
local function StartOmnipresence()
    local char = LocalPlayer.Character
    if not char then return end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- 清除所有觸發器 (虛無化)
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("TouchTransmitter") then obj:Destroy() end
    end

    heartbeatConnection = RunService.Heartbeat:Connect(function()
        if not isActive then return end
        local currentHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not currentHrp then return end

        -- 1. 將角色拉回「真實位置」（讓你可以正常WASD走路）
        currentHrp.CFrame = currentHrp.CFrame - lastOffset
        
        -- 2. 將穩定錨點同步到真實位置，並綁定攝影機
        CamAnchor.CFrame = currentHrp.CFrame
        workspace.CurrentCamera.CameraSubject = CamAnchor
        
        -- 3. 計算新的「瘋狂隨機偏移量」 (半徑 200~800 的天空球體)
        local angleX = math.random() * math.pi * 2
        local angleZ = math.random() * math.pi * 2
        local radius = math.random(200, 800)
        local yOffset = math.random(300, 1000) -- 往天上飛避免卡牆
        
        lastOffset = Vector3.new(math.cos(angleX) * radius, yOffset, math.sin(angleZ) * radius)
        
        -- 4. 瞬間將肉體傳送出去
        currentHrp.CFrame = currentHrp.CFrame + lastOffset
        
        -- 5. 產生視覺殘影
        CreateAfterimage(currentHrp.CFrame)
    end)
end

local function StopOmnipresence()
    if heartbeatConnection then heartbeatConnection:Disconnect() end
    
    local char = LocalPlayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            -- 復原座標
            hrp.CFrame = hrp.CFrame - lastOffset
            lastOffset = Vector3.zero
        end
        
        local hum = char:FindFirstChild("Humanoid")
        if hum then
            -- 攝影機還原
            workspace.CurrentCamera.CameraSubject = hum
        end
    end
    ghostFolder:ClearAllChildren()
end

-- ==========================================
-- [ UI 與控制邏輯 ]
-- ==========================================
local isHovering = false

local function UpdateUI()
    if isActive then
        StatusText.Text = 'STATUS: FRENZY TP ACTIVE'
        StatusText.TextColor3 = Color3.fromRGB(200, 50, 255)
        MainStroke.Color = Color3.fromRGB(255, 0, 255)
        ToggleBtn.Text = 'DEACTIVATE [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(80, 0, 120) or Color3.fromRGB(60, 0, 100)
    else
        StatusText.Text = 'STATUS: STABLE'
        StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
        MainStroke.Color = Color3.fromRGB(150, 0, 255)
        ToggleBtn.Text = 'INITIATE CRAZY TP [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(50, 0, 80) or Color3.fromRGB(30, 0, 50)
    end
end

local function ToggleSystem()
    isActive = not isActive
    UpdateUI()
    if isActive then StartOmnipresence() else StopOmnipresence() end
end

ToggleBtn.MouseEnter:Connect(function() isHovering = true UpdateUI() end)
ToggleBtn.MouseLeave:Connect(function() isHovering = false UpdateUI() end)
ToggleBtn.MouseButton1Click:Connect(ToggleSystem)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == toggleKey then
        ToggleSystem()
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    if isActive then
        task.wait(0.5)
        StartOmnipresence()
    end
end)
