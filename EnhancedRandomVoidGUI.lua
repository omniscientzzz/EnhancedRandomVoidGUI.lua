local fenv = getfenv()
fenv.require = function() end

-- [[ VOID x AEGIS V36: OBLIVION (虛無・伺服器錯位) ]] --
-- 終極對策：針對「伺服器端判定 (Server-Sided Hitreg)」的絕對防禦。
-- 核心 1：Shield Breaker (破甲打擊) - 摧毀敵人所有護盾。
-- 核心 2：Network Desync (網路錯位) - 欺騙伺服器物理引擎，使伺服器 Hitbox 光速位移。
-- 核心 3：Self Ghosting (本體虛化) - 關閉自身的所有觸碰判定，免疫本地地雷與陷阱。

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')

local LocalPlayer = Players.LocalPlayer
local toggleKey = Enum.KeyCode.P

local isActive = false
local connections = {}
local lastScanTime = 0

-- 用來儲存真實速度的緩存表
local realVelocities = {}

-- ==========================================
-- [ GUI 建構 (深淵血紅/幽紫風格) ]
-- ==========================================
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'AegisV36GUI'
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = game:GetService('CoreGui') end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new('Frame')
MainFrame.Name = 'MainFrame'
MainFrame.Size = UDim2.new(0, 340, 0, 350)
MainFrame.Position = UDim2.new(0.85, -60, 0.75, -130)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 5, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true 
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new('UICorner', MainFrame)
MainCorner.CornerRadius = UDim.new(0, 6)

local MainStroke = Instance.new('UIStroke', MainFrame)
MainStroke.Color = Color3.fromRGB(255, 0, 80)
MainStroke.Thickness = 2

local TitleText = Instance.new('TextLabel', MainFrame)
TitleText.Size = UDim2.new(1, 0, 0, 30)
TitleText.BackgroundTransparency = 1
TitleText.Text = '👻 V36 WRAITH (OBLIVION)'
TitleText.TextColor3 = Color3.fromRGB(255, 100, 150)
TitleText.TextSize = 15
TitleText.Font = Enum.Font.GothamBlack
TitleText.Parent = MainFrame

local StatusText = Instance.new('TextLabel', MainFrame)
StatusText.Size = UDim2.new(1, 0, 0, 20)
StatusText.Position = UDim2.new(0, 0, 0, 35)
StatusText.BackgroundTransparency = 1
StatusText.Text = 'DESYNC MODE: DISABLED'
StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusText.TextSize = 12
StatusText.Font = Enum.Font.GothamBold
StatusText.Parent = MainFrame

local ToggleBtn = Instance.new('TextButton', MainFrame)
ToggleBtn.Size = UDim2.new(0.8, 0, 0, 40)
ToggleBtn.Position = UDim2.new(0.1, 0, 0, 65)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 10, 30)
ToggleBtn.Text = 'ENGAGE DESYNC [P]'
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 14
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = MainFrame
Instance.new('UICorner', ToggleBtn).CornerRadius = UDim.new(0, 4)

local StatsText = Instance.new('TextLabel', MainFrame)
StatsText.Size = UDim2.new(1, 0, 0, 220)
StatsText.Position = UDim2.new(0.1, 0, 0, 115)
StatsText.BackgroundTransparency = 1
StatsText.Text = '[✓] Server Hitbox Desync (Active)\n[✓] Velocity Spoofing (Bypass Server)\n[✓] Self Ghosting (CanTouch=false)\n[✓] Weapons & Movement Normal\n\nYour true Hitbox is now invisible to the\nServer. The game engine thinks you are\nflying at Mach 10, causing all server\nattacks to miss your local body.'
StatsText.TextColor3 = Color3.fromRGB(255, 150, 180)
StatsText.TextSize = 11
StatsText.TextXAlignment = Enum.TextXAlignment.Left
StatsText.Font = Enum.Font.Code
StatsText.Parent = MainFrame

-- ==========================================
-- [ 核心 1：破甲打擊 (Armor Piercing) ]
-- ==========================================
local function StripEnemyShields()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local enemyChar = player.Character
            local ff = enemyChar:FindFirstChildOfClass("ForceField")
            if ff then ff:Destroy() end

            for _, obj in ipairs(enemyChar:GetDescendants()) do
                local name = obj.Name:lower()
                if name:match("shield") or name:match("armor") or name:match("protect") or name:match("barrier") then
                    if obj:IsA("BasePart") then
                        pcall(function()
                            obj.CanCollide = false
                            obj.Transparency = 1
                            obj.Size = Vector3.new(0.01, 0.01, 0.01) 
                        end)
                    elseif obj:IsA("ValueBase") then
                        pcall(function() obj.Value = 0 end)
                    end
                end
            end
        end
    end
end

-- ==========================================
-- [ 核心 3：本體虛化 (Self Ghosting) ]
-- ==========================================
local function GhostSelf(char)
    -- 關閉自身的所有觸碰判定，防止地上的陷阱或本地碰觸判定傷害你
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function() part.CanTouch = false end)
        end
    end
end

-- ==========================================
-- [ 系統生命週期控制 (The Desync Engine) ]
-- ==========================================
local function StartDesync()
    local char = LocalPlayer.Character
    if not char then return end

    -- [引擎欺騙 - 步驟 1]：在本地物理運算前 (Stepped)，恢復你原本的真實速度，讓你不會在螢幕上亂飛。
    local steppedConn = RunService.Stepped:Connect(function()
        if not isActive then return end
        local currentChar = LocalPlayer.Character
        local root = currentChar and currentChar:FindFirstChild("HumanoidRootPart")
        if root and realVelocities[root] then
            root.Velocity = realVelocities[root]
        end
    end)
    table.insert(connections, steppedConn)

    -- [引擎欺騙 - 步驟 2]：在物理運算後、數據傳給伺服器前 (Heartbeat)，把你的速度改為天文數字。
    local heartbeatConn = RunService.Heartbeat:Connect(function()
        if not isActive then return end
        
        local currentTime = tick()
        if currentTime - lastScanTime >= 0.5 then
            StripEnemyShields()
            lastScanTime = currentTime
        end

        local currentChar = LocalPlayer.Character
        if currentChar then
            GhostSelf(currentChar) -- 維持本體虛化
            
            local root = currentChar:FindFirstChild("HumanoidRootPart")
            if root then
                -- 記錄你當下的真實速度
                realVelocities[root] = root.Velocity
                -- 欺騙伺服器：發送極端向量，使伺服器 Hitbox 直接錯位、預判系統崩潰
                root.Velocity = Vector3.new(15000, -15000, 15000) 
            end
        end
    end)
    table.insert(connections, heartbeatConn)
end

local function StopDesync()
    for _, conn in ipairs(connections) do
        conn:Disconnect()
    end
    connections = {}
    realVelocities = {}
    
    local char = LocalPlayer.Character
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                pcall(function() part.CanTouch = true end)
            end
        end
    end
end

-- ==========================================
-- [ UI 與控制邏輯 ]
-- ==========================================
local isHovering = false

local function UpdateUI()
    if isActive then
        StatusText.Text = 'DESYNC MODE: ACTIVE (SERVER SPOOFED)'
        StatusText.TextColor3 = Color3.fromRGB(255, 0, 80)
        MainStroke.Color = Color3.fromRGB(255, 0, 80)
        ToggleBtn.Text = 'DISENGAGE [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(100, 0, 40) or Color3.fromRGB(80, 0, 30)
    else
        StatusText.Text = 'DESYNC MODE: DISABLED'
        StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
        MainStroke.Color = Color3.fromRGB(100, 100, 100)
        ToggleBtn.Text = 'ENGAGE DESYNC [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(70, 10, 30) or Color3.fromRGB(50, 10, 30)
    end
end

local function ToggleSystem()
    isActive = not isActive
    UpdateUI()
    if isActive then StartDesync() else StopDesync() end
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
        StartDesync()
    end
end)

