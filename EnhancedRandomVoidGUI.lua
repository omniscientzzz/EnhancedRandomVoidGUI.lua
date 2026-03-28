local fenv = getfenv()
fenv.require = function() end

-- [[ VOID x AEGIS V34: WRAITH (怨靈・破甲與無限領域) ]] --
-- 核心 1：Shield Breaker (破甲打擊) - 摧毀敵人所有護盾。
-- 核心 2：Hierarchy Shift (圖層剝離) - 移出 Workspace 規避 AoE。
-- 核心 3：Omnipresent Aegis (全知神盾) - 將 Hitbox 放大至引擎極限 (2048 Studs)。

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')

local LocalPlayer = Players.LocalPlayer
local toggleKey = Enum.KeyCode.P

local isActive = false
local connections = {}
local lastScanTime = 0

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
MainFrame.Size = UDim2.new(0, 330, 0, 340)
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
TitleText.Text = '👻 V34 WRAITH (OMNIPRESENT)'
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
StatsText.Size = UDim2.new(1, 0, 0, 210)
StatsText.Position = UDim2.new(0.1, 0, 0, 115)
StatsText.BackgroundTransparency = 1
StatsText.Text = '[✓] Enemy Shields Eradicated\n[✓] Workspace Hierarchy Shift\n[✓] Projectiles Nullified\n[✓] Infinite Hitbox (2048 Studs)\n\nYour Aegis barrier now covers the entire\nmap. Any unanchored projectile or raycast\nspawned anywhere will be instantly\nabsorbed by your limitless domain.'
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

            local ff = enemyChar:FindFirstChildOfClass("ForceField")
            if ff then ff:Destroy() end

            for _, obj in ipairs(enemyChar:GetDescendants()) do
                local name = obj.Name:lower()
                if name:match("shield") or name:match("armor") or name:match("protect") or name:match("barrier") then
                    if obj:IsA("BasePart") then
                        pcall(function()
                            obj.CanCollide = false
                            obj.CanTouch = false
                            obj.CanQuery = false 
                            obj.Transparency = 1
                            obj.Size = Vector3.new(0.01, 0.01, 0.01) 
                        end)
                    elseif obj:IsA("ValueBase") then
                        pcall(function() obj.Value = 0 end)
                    end
                end
            end

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
-- [ 核心 3：全知神盾 (Omnipresent Aegis) ]
-- ==========================================
local function EnsureAegisBarrier(char)
    if not char then return end
    
    -- 1. 官方防護罩 (抵禦基礎腳本傷害)
    if not char:FindFirstChild("WraithForceField") then
        local ff = Instance.new("ForceField")
        ff.Name = "WraithForceField"
        ff.Visible = false
        ff.Parent = char
    end

    -- 2. 極限體積結界 (引擎上限：2048x2048x2048)
    local root = char:FindFirstChild("HumanoidRootPart")
    if root and not char:FindFirstChild("AegisBarrier") then
        local barrier = Instance.new("Part")
        barrier.Name = "AegisBarrier"
        barrier.Shape = Enum.PartType.Ball
        
        -- 【關鍵修改】：將盾牌的 Hitbox 放大至 Roblox 引擎的物理極限
        barrier.Size = Vector3.new(2048, 2048, 2048) 
        
        barrier.Material = Enum.Material.ForceField
        barrier.Color = Color3.fromRGB(100, 0, 255)
        
        -- 因為體積過於巨大，必須將其完全隱形，否則會遮蔽整個遊戲畫面
        barrier.Transparency = 1 
        
        barrier.CanCollide = false 
        barrier.CanTouch = true    -- 觸發投擲物銷毀
        barrier.CanQuery = true    -- 吸收全地圖的射線 (Raycast)
        barrier.Massless = true
        barrier.Anchored = false
        barrier.CastShadow = false

        -- 將結界綁定在玩家身上
        local weld = Instance.new("WeldConstraint")
        weld.Part0 = barrier
        weld.Part1 = root
        weld.Parent = barrier

        barrier.CFrame = root.CFrame
        barrier.Parent = char

        -- [全圖投擲物抹除邏輯]
        barrier.Touched:Connect(function(hit)
            if hit and hit.Parent and not hit:IsDescendantOf(char) and not hit:IsDescendantOf(workspace.Terrain) then
                -- 攔截未錨定的物體 (過濾掉地圖建築)
                if not hit.Anchored and hit.Size.Magnitude < 100 then
                    pcall(function()
                        hit.CanTouch = false
                        hit.Velocity = Vector3.new(0, 0, 0)
                        hit:Destroy()
                    end)
                end
            end
        end)
    end
end

local function RemoveAegisBarrier(char)
    if not char then return end
    local ff = char:FindFirstChild("WraithForceField")
    if ff then ff:Destroy() end
    local barrier = char:FindFirstChild("AegisBarrier")
    if barrier then barrier:Destroy() end
end

-- ==========================================
-- [ 核心 2：圖層剝離 (Hierarchy Shift) ]
-- ==========================================
local function ShiftDimension(char)
    if not char then return end
    
    if char.Parent ~= workspace.CurrentCamera then
        pcall(function() char.Parent = workspace.CurrentCamera end)
    end
    
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "AegisBarrier" then
            pcall(function()
                part.CanQuery = false
                part.CanTouch = false
            end)
        end
    end
end

-- ==========================================
-- [ 系統生命週期控制 ]
-- ==========================================
local function StartWraith()
    local char = LocalPlayer.Character
    if not char then return end

    EnsureAegisBarrier(char)

    local loop = RunService.Heartbeat:Connect(function()
        if not isActive then return end
        
        local currentTime = tick()
        if currentTime - lastScanTime >= 0.5 then
            StripEnemyShields()
            lastScanTime = currentTime
        end
        
        local currentChar = LocalPlayer.Character
        if currentChar then
            ShiftDimension(currentChar)
            EnsureAegisBarrier(currentChar)
            -- 移除了旋轉特效，因為現在結界是全透明且覆蓋全圖的，旋轉會消耗多餘的效能
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
        pcall(function() char.Parent = workspace end)
        RemoveAegisBarrier(char)
        
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


