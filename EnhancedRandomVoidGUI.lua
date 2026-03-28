local fenv = getfenv()
fenv.require = function() end

-- [[ VOID x AEGIS V34: WRAITH (怨靈・破甲與圖層剝離) ]] --
-- 核心 1：Shield Breaker (破甲打擊) - 本地端摧毀敵人所有護盾實體與數值。
-- 核心 2：Hierarchy Shift (圖層剝離) - 將你的角色移出 Workspace，徹底無效化敵方的全圖 AoE 鎖定。

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')

local LocalPlayer = Players.LocalPlayer
local toggleKey = Enum.KeyCode.P

local isActive = false
local connections = {}

-- ==========================================
-- [ GUI 建構 (怨靈幽紫風格) ]
-- ==========================================
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'AegisV34GUI'
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = game:GetService('CoreGui') end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new('Frame')
MainFrame.Name = 'MainFrame'
MainFrame.Size = UDim2.new(0, 330, 0, 320)
MainFrame.Position = UDim2.new(0.85, -60, 0.75, -130)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 5, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true 
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new('UICorner', MainFrame)
MainCorner.CornerRadius = UDim.new(0, 6)

local MainStroke = Instance.new('UIStroke', MainFrame)
MainStroke.Color = Color3.fromRGB(180, 0, 255)
MainStroke.Thickness = 2

local TitleText = Instance.new('TextLabel', MainFrame)
TitleText.Size = UDim2.new(1, 0, 0, 30)
TitleText.BackgroundTransparency = 1
TitleText.Text = '👻 V34 WRAITH (ARMOR PIERCER)'
TitleText.TextColor3 = Color3.fromRGB(200, 100, 255)
TitleText.TextSize = 15
TitleText.Font = Enum.Font.GothamBlack
TitleText.Parent = MainFrame

local StatusText = Instance.new('TextLabel', MainFrame)
StatusText.Size = UDim2.new(1, 0, 0, 20)
StatusText.Position = UDim2.new(0, 0, 0, 35)
StatusText.BackgroundTransparency = 1
StatusText.Text = 'WRAITH MODE: DISABLED'
StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusText.TextSize = 12
StatusText.Font = Enum.Font.GothamBold
StatusText.Parent = MainFrame

local ToggleBtn = Instance.new('TextButton', MainFrame)
ToggleBtn.Size = UDim2.new(0.8, 0, 0, 40)
ToggleBtn.Position = UDim2.new(0.1, 0, 0, 65)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(40, 10, 60)
ToggleBtn.Text = 'ENGAGE WRAITH [P]'
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 14
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = MainFrame
Instance.new('UICorner', ToggleBtn).CornerRadius = UDim.new(0, 4)

local StatsText = Instance.new('TextLabel', MainFrame)
StatsText.Size = UDim2.new(1, 0, 0, 190)
StatsText.Position = UDim2.new(0.1, 0, 0, 115)
StatsText.BackgroundTransparency = 1
StatsText.Text = '[✓] Enemy Shields Eradicated (Local)\n[✓] Projectiles Ignore Armor\n[✓] Workspace Hierarchy Shift\n[✓] AoE & Raycast Invisibility\n\nYour attacks now pierce all shields.\nYour body no longer exists in Workspace.\nEnemy scripts cannot target you.'
StatsText.TextColor3 = Color3.fromRGB(180, 120, 255)
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

            -- 1. 摧毀官方 ForceField
            local ff = enemyChar:FindFirstChildOfClass("ForceField")
            if ff then ff:Destroy() end

            -- 2. 徹底無效化所有客製化盾牌部件與屬性
            for _, obj in ipairs(enemyChar:GetDescendants()) do
                local name = obj.Name:lower()
                
                -- 如果發現名字包含 shield (盾), armor (甲), protect (保護) 的東西
                if name:match("shield") or name:match("armor") or name:match("protect") or name:match("barrier") then
                    if obj:IsA("BasePart") then
                        -- 不直接刪除(怕破壞他們骨架)，但剝奪所有物理與判定
                        pcall(function()
                            obj.CanCollide = false
                            obj.CanTouch = false
                            obj.CanQuery = false -- 你的射線/投擲物將直接穿透它！
                            obj.Transparency = 1
                            obj.Size = Vector3.new(0.01, 0.01, 0.01)
                        end)
                    elseif obj:IsA("ValueBase") then
                        -- 如果是數值類型的護盾(例如 Health.Shield.Value = 100)，強制作廢
                        pcall(function() obj.Value = 0 end)
                    end
                end
            end

            -- 3. 駭入 Attributes (有些遊戲把護盾寫在屬性裡)
            pcall(function()
                if enemyChar:GetAttribute("Shield") or enemyChar:GetAttribute("Armor") then
                    enemyChar:SetAttribute("Shield", 0)
                    enemyChar:SetAttribute("Armor", 0)
                end
            end)
        end
    end
end

-- ==========================================
-- [ 核心 2：圖層剝離 (Hierarchy Shift) ]
-- ==========================================
local function ShiftDimension(char)
    if not char then return end
    
    -- 【神級防禦技巧】：將你的角色從 Workspace 移到 Camera
    -- 對手的範圍爆破(AoE)外掛通常會寫：`for _, v in pairs(workspace:GetChildren())`
    -- 當你躲在 Camera 裡時，他們的外掛腳本「在物理圖層上」根本找不到你，直接報錯失效。
    if char.Parent ~= workspace.CurrentCamera then
        pcall(function()
            char.Parent = workspace.CurrentCamera
        end)
    end
    
    -- 雙重保險：關閉所有部位的射線判定
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function()
                part.CanQuery = false
                part.CanTouch = false
            end)
        end
    end
end

local function StartWraith()
    local char = LocalPlayer.Character
    if not char then return end

    -- 啟動高頻掃描，確保敵人的盾牌一長出來就瞬間破壞，且確保你一直藏在 Camera 中
    local loop = RunService.Heartbeat:Connect(function()
        if not isActive then return end
        
        -- 進攻：破甲
        StripEnemyShields()
        
        -- 防守：躲避掃描
        local currentChar = LocalPlayer.Character
        if currentChar then
            ShiftDimension(currentChar)
        end
    end)
    table.insert(connections, loop)
end

local function StopWraith()
    for _, conn in ipairs(connections) do
        conn:Disconnect()
    end
    connections = {}
    
    local char = LocalPlayer.Character
    if char then
        -- 將角色放回 Workspace，恢復正常狀態
        pcall(function() char.Parent = workspace end)
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                pcall(function()
                    part.CanQuery = true
                    part.CanTouch = true
                end)
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
        StatusText.Text = 'WRAITH MODE: ACTIVE'
        StatusText.TextColor3 = Color3.fromRGB(180, 0, 255)
        MainStroke.Color = Color3.fromRGB(180, 0, 255)
        ToggleBtn.Text = 'DISENGAGE [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(80, 0, 120) or Color3.fromRGB(60, 0, 90)
    else
        StatusText.Text = 'WRAITH MODE: DISABLED'
        StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
        MainStroke.Color = Color3.fromRGB(100, 100, 100)
        ToggleBtn.Text = 'ENGAGE WRAITH [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(60, 10, 80) or Color3.fromRGB(40, 10, 60)
    end
end

local function ToggleSystem()
    isActive = not isActive
    UpdateUI()
    if isActive then StartWraith() else StopWraith() end
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
        StartWraith()
    end
end)

