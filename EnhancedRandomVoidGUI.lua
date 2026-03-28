local fenv = getfenv()
fenv.require = function() end

-- [[ VOID x AEGIS V32: REFLECTOR (絕對鏡像) ]] --
-- 修復了 V31 導致引擎秒殺的致命錯誤 (不再重新命名 Head)。
-- 導入 Y軸動能欺騙 (Y-Axis Velocity Spoof) 與 奈米化清理 (Nano-Shrink)。
-- 完全兼容 Rivals 的高強度防作弊系統 (RAC)。

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')

local LocalPlayer = Players.LocalPlayer
local toggleKey = Enum.KeyCode.P

local isActive = false
local connections = {}
local savedVelocity = Vector3.zero

-- ==========================================
-- [ GUI 建構 (鏡像冷光風格) ]
-- ==========================================
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'AegisV32GUI'
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = game:GetService('CoreGui') end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new('Frame')
MainFrame.Name = 'MainFrame'
MainFrame.Size = UDim2.new(0, 320, 0, 310)
MainFrame.Position = UDim2.new(0.85, -60, 0.75, -120)
MainFrame.BackgroundColor3 = Color3.fromRGB(5, 15, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true 
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new('UICorner', MainFrame)
MainCorner.CornerRadius = UDim.new(0, 6)

local MainStroke = Instance.new('UIStroke', MainFrame)
MainStroke.Color = Color3.fromRGB(0, 200, 255)
MainStroke.Thickness = 2

local TitleText = Instance.new('TextLabel', MainFrame)
TitleText.Size = UDim2.new(1, 0, 0, 30)
TitleText.BackgroundTransparency = 1
TitleText.Text = '🪞 V32 REFLECTOR'
TitleText.TextColor3 = Color3.fromRGB(150, 220, 255)
TitleText.TextSize = 16
TitleText.Font = Enum.Font.GothamBlack
TitleText.Parent = MainFrame

local StatusText = Instance.new('TextLabel', MainFrame)
StatusText.Size = UDim2.new(1, 0, 0, 20)
StatusText.Position = UDim2.new(0, 0, 0, 35)
StatusText.BackgroundTransparency = 1
StatusText.Text = 'SYSTEM: STABLE'
StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusText.TextSize = 12
StatusText.Font = Enum.Font.GothamBold
StatusText.Parent = MainFrame

local ToggleBtn = Instance.new('TextButton', MainFrame)
ToggleBtn.Size = UDim2.new(0.8, 0, 0, 40)
ToggleBtn.Position = UDim2.new(0.1, 0, 0, 65)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(0, 40, 60)
ToggleBtn.Text = 'ACTIVATE REFLECTION [P]'
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 14
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = MainFrame
Instance.new('UICorner', ToggleBtn).CornerRadius = UDim.new(0, 4)

local StatsText = Instance.new('TextLabel', MainFrame)
StatsText.Size = UDim2.new(1, 0, 0, 170)
StatsText.Position = UDim2.new(0.1, 0, 0, 115)
StatsText.BackgroundTransparency = 1
StatsText.Text = '[✓] Anatomy Core Preserved (No Death)\n[✓] Y-Axis Velocity Spoof (-25000)\n[✓] AoE Nano-Shrink Protocol\n[✓] Kinetic Dampener (Anti-Fling)\n\nAimbots will shoot at the floor.\nGiant spheres will become dust.\nYou remain untouched.'
StatsText.TextColor3 = Color3.fromRGB(150, 200, 255)
StatsText.TextSize = 11
StatsText.TextXAlignment = Enum.TextXAlignment.Left
StatsText.Font = Enum.Font.Code
StatsText.Parent = MainFrame

-- ==========================================
-- [ 核心功能 ]
-- ==========================================

-- 1. 奈米縮小協議 (取代 Destroy，防止敵方腳本報錯與排斥力)
local function NeutralizeThreat(part)
    if not part:IsA("BasePart") then return end
    if part:IsDescendantOf(LocalPlayer.Character) then return end
    if part:IsDescendantOf(workspace.Terrain) then return end

    -- 偵測：體積大於 12 格的物體，或是帶有攻擊性的未錨定投擲物
    if part.Size.Magnitude > 12 or (not part.Anchored and part.Name ~= "Handle") then
        pcall(function()
            -- 不使用 Destroy()，因為 Rivals 的某些武器代碼找不到 Part 會引發全局 Lag
            -- 我們直接把它的碰撞關閉，並且將體積縮小到 0.01 (肉眼不可見，且無判定)
            part.CanCollide = false
            part.CanTouch = false
            part.CanQuery = false
            part.Transparency = 1
            part.Size = Vector3.new(0.01, 0.01, 0.01)
            -- 取消它的動能，讓它在原地停擺
            part.AssemblyLinearVelocity = Vector3.zero
        end)
    end
end

local function StartReflector()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- [A] 動能採樣與 Y軸自瞄欺騙 (Aimbot Breaker)
    -- 我們在 Heartbeat (伺服器發送前) 將你的下降速度改為極端值。
    -- 大多數防作弊 (RAC) 只會嚴格檢查 X 與 Z 軸的高速移動，因為 Y軸的高速下降可能只是玩家掉出地圖。
    -- 但自瞄外掛 (Resolver) 會把這個 Y 軸速度算進預判裡，導致他們全部往地板開槍。
    local heartbeat = RunService.Heartbeat:Connect(function()
        if not isActive or not hrp then return end
        -- 記住你真實的移動速度
        savedVelocity = hrp.AssemblyLinearVelocity
        
        -- 發送極端墜落假數據給伺服器與敵人的自瞄
        hrp.AssemblyLinearVelocity = Vector3.new(savedVelocity.X, -25000, savedVelocity.Z)
    end)
    table.insert(connections, heartbeat)

    -- [B] 客戶端還原 (Smooth Movement)
    -- 在畫面渲染前，把真實速度還給你，這樣你在自己畫面上完全不會感覺到卡頓或下墜
    local render = RunService.RenderStepped:Connect(function()
        if not isActive or not hrp then return end
        hrp.AssemblyLinearVelocity = savedVelocity
    end)
    table.insert(connections, render)

    -- [C] 防擊飛阻尼器 (Kinetic Dampener)
    -- 防止你被巨大的 Hitbox 或爆炸產生的物理排斥力彈飛
    local stepped = RunService.Stepped:Connect(function()
        if not isActive or not hrp then return end
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)
    table.insert(connections, stepped)

    -- [D] 全圖範圍攻擊清理 (AoE Nano-Shrink)
    -- 清理場上現有的巨大球體
    for _, obj in ipairs(workspace:GetDescendants()) do
        NeutralizeThreat(obj)
    end

    -- 監視新生成的攻擊並瞬間將其奈米化
    local sweeper = workspace.DescendantAdded:Connect(function(descendant)
        if isActive then
            NeutralizeThreat(descendant)
        end
    end)
    table.insert(connections, sweeper)
end

local function StopReflector()
    for _, conn in ipairs(connections) do
        conn:Disconnect()
    end
    connections = {}
    
    local char = LocalPlayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.AssemblyLinearVelocity = savedVelocity
        end
    end
end

-- ==========================================
-- [ UI 與控制邏輯 ]
-- ==========================================
local isHovering = false

local function UpdateUI()
    if isActive then
        StatusText.Text = 'SYSTEM: REFLECTING'
        StatusText.TextColor3 = Color3.fromRGB(0, 255, 255)
        MainStroke.Color = Color3.fromRGB(0, 255, 255)
        ToggleBtn.Text = 'DEACTIVATE [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(0, 80, 120) or Color3.fromRGB(0, 60, 100)
    else
        StatusText.Text = 'SYSTEM: STABLE'
        StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
        MainStroke.Color = Color3.fromRGB(0, 200, 255)
        ToggleBtn.Text = 'ACTIVATE REFLECTION [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(0, 50, 80) or Color3.fromRGB(0, 40, 60)
    end
end

local function ToggleSystem()
    isActive = not isActive
    UpdateUI()
    if isActive then StartReflector() else StopReflector() end
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
        task.wait(1)
        StartReflector()
    end
end)

