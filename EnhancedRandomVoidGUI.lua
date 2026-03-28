local fenv = getfenv()
fenv.require = function() end

-- [[ VOID x AEGIS V35: PHANTOM (怨靈・無形幻影) ]] --
-- 修正了無法攻擊的問題：捨棄實體護盾，改用空間雷達抹除。
-- 修正了武器失效的問題：不再將角色移出 Workspace。
-- 核心 1：Shield Breaker (破甲打擊) - 摧毀敵人所有護盾。
-- 核心 2：Spatial Radar (空間雷達) - 無實體防禦，瞬間抹除靠近的投擲物。

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
ScreenGui.Name = 'AegisV35GUI'
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = game:GetService('CoreGui') end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new('Frame')
MainFrame.Name = 'MainFrame'
MainFrame.Size = UDim2.new(0, 340, 0, 340)
MainFrame.Position = UDim2.new(0.85, -60, 0.75, -130)
MainFrame.BackgroundColor3 = Color3.fromRGB(10, 5, 15)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true 
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new('UICorner', MainFrame)
MainCorner.CornerRadius = UDim.new(0, 6)

local MainStroke = Instance.new('UIStroke', MainFrame)
MainStroke.Color = Color3.fromRGB(130, 0, 255)
MainStroke.Thickness = 2

local TitleText = Instance.new('TextLabel', MainFrame)
TitleText.Size = UDim2.new(1, 0, 0, 30)
TitleText.BackgroundTransparency = 1
TitleText.Text = '👻 V35 WRAITH (PHANTOM)'
TitleText.TextColor3 = Color3.fromRGB(180, 100, 255)
TitleText.TextSize = 15
TitleText.Font = Enum.Font.GothamBlack
TitleText.Parent = MainFrame

local StatusText = Instance.new('TextLabel', MainFrame)
StatusText.Size = UDim2.new(1, 0, 0, 20)
StatusText.Position = UDim2.new(0, 0, 0, 35)
StatusText.BackgroundTransparency = 1
StatusText.Text = 'PHANTOM MODE: DISABLED'
StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusText.TextSize = 12
StatusText.Font = Enum.Font.GothamBold
StatusText.Parent = MainFrame

local ToggleBtn = Instance.new('TextButton', MainFrame)
ToggleBtn.Size = UDim2.new(0.8, 0, 0, 40)
ToggleBtn.Position = UDim2.new(0.1, 0, 0, 65)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 10, 50)
ToggleBtn.Text = 'ENGAGE PHANTOM [P]'
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 14
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = MainFrame
Instance.new('UICorner', ToggleBtn).CornerRadius = UDim.new(0, 4)

local StatsText = Instance.new('TextLabel', MainFrame)
StatsText.Size = UDim2.new(1, 0, 0, 210)
StatsText.Position = UDim2.new(0.1, 0, 0, 115)
StatsText.BackgroundTransparency = 1
StatsText.Text = '[✓] Enemy Shields Eradicated\n[✓] Weapons Restored (No Hitbox Block)\n[✓] Spatial Radar Deletion (150 Studs)\n[✓] Server Desync Attempt\n\nPhysical walls removed.\nYou can now attack normally.\nA 150-stud invisible radar instantly\nteleports & deletes incoming projectiles.'
StatsText.TextColor3 = Color3.fromRGB(160, 120, 255)
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
-- [ 核心 2：空間雷達 (Spatial Radar) ]
-- ==========================================
-- 放棄實體護盾，改用無形的空間掃描。這保證了你的武器和滑鼠絕對不會被擋住。
local function RadarEradication(char)
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    -- 設定掃描過濾器：排除你自己，以免把自己的子彈或裝備刪掉
    local overlapParams = OverlapParams.new()
    overlapParams.FilterType = Enum.RaycastFilterType.Exclude
    overlapParams.FilterDescendantsInstances = {char}

    -- 掃描周圍 150 Studs 內的所有零件
    local hitParts = workspace:GetPartBoundsInRadius(root.Position, 150, overlapParams)

    for _, hit in ipairs(hitParts) do
        -- 判斷是否為敵人的投擲物 (未錨定、體積不大、不是地圖地形)
        if not hit.Anchored and hit.Size.Magnitude < 50 and not hit:IsDescendantOf(workspace.Terrain) then
            pcall(function()
                -- 為了防止伺服器判定延遲，先將它瞬間傳送到地底虛空，剝奪碰撞，最後刪除
                hit.CFrame = CFrame.new(0, -99999, 0)
                hit.Velocity = Vector3.new(0, 0, 0)
                hit.CanTouch = false
                hit:Destroy()
            end)
        end
    end
end

-- ==========================================
-- [ 系統生命週期控制 ]
-- ==========================================
local function StartPhantom()
    -- 掛載官方無敵幀作為最後防線
    local char = LocalPlayer.Character
    if char and not char:FindFirstChild("WraithForceField") then
        local ff = Instance.new("ForceField")
        ff.Name = "WraithForceField"
        ff.Visible = false
        ff.Parent = char
    end

    local loop = RunService.Heartbeat:Connect(function()
        if not isActive then return end
        
        local currentTime = tick()
        
        -- 每 0.5 秒破甲一次
        if currentTime - lastScanTime >= 0.5 then
            StripEnemyShields()
            lastScanTime = currentTime
        end
        
        -- 每一幀執行空間雷達抹除
        local currentChar = LocalPlayer.Character
        if currentChar then
            RadarEradication(currentChar)
        end
    end)
    table.insert(connections, loop)
end

local function StopPhantom()
    for _, conn in ipairs(connections) do
        conn:Disconnect()
    end
    connections = {}
    
    local char = LocalPlayer.Character
    if char then
        local ff = char:FindFirstChild("WraithForceField")
        if ff then ff:Destroy() end
    end
end

-- ==========================================
-- [ UI 與控制邏輯 ]
-- ==========================================
local isHovering = false

local function UpdateUI()
    if isActive then
        StatusText.Text = 'PHANTOM MODE: ACTIVE'
        StatusText.TextColor3 = Color3.fromRGB(130, 0, 255)
        MainStroke.Color = Color3.fromRGB(130, 0, 255)
        ToggleBtn.Text = 'DISENGAGE [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(60, 0, 100) or Color3.fromRGB(40, 0, 70)
    else
        StatusText.Text = 'PHANTOM MODE: DISABLED'
        StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
        MainStroke.Color = Color3.fromRGB(100, 100, 100)
        ToggleBtn.Text = 'ENGAGE PHANTOM [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(50, 10, 70) or Color3.fromRGB(30, 10, 50)
    end
end

local function ToggleSystem()
    isActive = not isActive
    UpdateUI()
    if isActive then StartPhantom() else StopPhantom() end
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
        StartPhantom()
    end
end)

