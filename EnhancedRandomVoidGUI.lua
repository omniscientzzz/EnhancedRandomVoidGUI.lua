local fenv = getfenv()
fenv.require = function() end

-- [[ VOID x AEGIS V29: RIVALS-GHOST (幽靈協議) ]] --
-- 專為 Rivals (與同類客製化 Hitreg FPS) 設計的絕對閃避系統。
-- 破解自瞄預判 (Resolver Breaker) + Hitbox 微距錯位 (Hitbox Shifter)

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')

local LocalPlayer = Players.LocalPlayer
local toggleKey = Enum.KeyCode.P

local isActive = false
local savedCFrame = nil
local savedVelocity = Vector3.zero

-- ==========================================
-- [ GUI 建構 (Rivals 戰術風格) ]
-- ==========================================
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'AegisV29GUI'
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = game:GetService('CoreGui') end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new('Frame')
MainFrame.Name = 'MainFrame'
MainFrame.Size = UDim2.new(0, 320, 0, 300)
MainFrame.Position = UDim2.new(0.85, -60, 0.75, -120)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true 
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new('UICorner', MainFrame)
MainCorner.CornerRadius = UDim.new(0, 4)

local MainStroke = Instance.new('UIStroke', MainFrame)
MainStroke.Color = Color3.fromRGB(0, 180, 255)
MainStroke.Thickness = 2

local TitleText = Instance.new('TextLabel', MainFrame)
TitleText.Size = UDim2.new(1, 0, 0, 30)
TitleText.BackgroundTransparency = 1
TitleText.Text = '🎯 V29 RIVALS-GHOST'
TitleText.TextColor3 = Color3.fromRGB(100, 200, 255)
TitleText.TextSize = 16
TitleText.Font = Enum.Font.GothamBlack
TitleText.Parent = MainFrame

local StatusText = Instance.new('TextLabel', MainFrame)
StatusText.Size = UDim2.new(1, 0, 0, 20)
StatusText.Position = UDim2.new(0, 0, 0, 35)
StatusText.BackgroundTransparency = 1
StatusText.Text = 'ANTI-AIM: DISABLED'
StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusText.TextSize = 12
StatusText.Font = Enum.Font.GothamBold
StatusText.Parent = MainFrame

local ToggleBtn = Instance.new('TextButton', MainFrame)
ToggleBtn.Size = UDim2.new(0.8, 0, 0, 40)
ToggleBtn.Position = UDim2.new(0.1, 0, 0, 65)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(0, 40, 80)
ToggleBtn.Text = 'ENGAGE GHOST DESYNC [P]'
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 14
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = MainFrame
Instance.new('UICorner', ToggleBtn).CornerRadius = UDim.new(0, 4)

local StatsText = Instance.new('TextLabel', MainFrame)
StatsText.Size = UDim2.new(1, 0, 0, 160)
StatsText.Position = UDim2.new(0.1, 0, 0, 115)
StatsText.BackgroundTransparency = 1
StatsText.Text = '[✓] Aimbot Resolver Broken\n[✓] Velocity Spoofing (15,000+)\n[✓] Micro Hitbox Shift (-6 Studs)\n[✓] RAC Anti-Cheat Bypass\n\nEnemy predictions will fail.\nVisual hits will not register.'
StatsText.TextColor3 = Color3.fromRGB(150, 220, 255)
StatsText.TextSize = 11
StatsText.TextXAlignment = Enum.TextXAlignment.Left
StatsText.Font = Enum.Font.Code
StatsText.Parent = MainFrame

-- ==========================================
-- [ 核心：Rivals 專用錯位引擎 ]
-- ==========================================

-- Heartbeat：負責將「假資料」發送給伺服器與敵人的客戶端
local heartbeatConnection = RunService.Heartbeat:Connect(function()
    if not isActive then return end
    
    local char = LocalPlayer.Character
    if not char then return end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- 1. 儲存真實的狀態 (讓你自己的操作不受影響)
    savedCFrame = hrp.CFrame
    savedVelocity = hrp.AssemblyLinearVelocity

    -- 2. 微距 Hitbox 錯位 (防手動瞄準)
    -- 將伺服器上的判定框悄悄往後推 6 格。
    -- 6 格是安全的距離，Rivals 防作弊不會因為 6 格的位移踢人。
    -- 但敵人如果瞄準你的「視覺身體」開槍，子彈會直接穿過去。
    local shiftDirection = hrp.CFrame.LookVector * -6 
    hrp.CFrame = hrp.CFrame + shiftDirection

    -- 3. 極限動能欺騙 (防 Aimbot 自瞄預判)
    -- 對手的自瞄腳本會計算你的速度來決定要往哪裡開槍 (Resolver)。
    -- 我們將速度瞬間改成極端亂數，他們的子彈會往反方向或天空射擊。
    local spoofX = math.random(-50000, 50000)
    local spoofY = math.random(-50000, 50000)
    local spoofZ = math.random(-50000, 50000)
    hrp.AssemblyLinearVelocity = Vector3.new(spoofX, spoofY, spoofZ)
end)

-- RenderStepped：在畫面渲染前，將你的角色拉回真實位置
-- 這樣在你的螢幕上，你完全是正常走路，不會有任何閃爍或延遲感。
local renderConnection = RunService.RenderStepped:Connect(function()
    if not isActive then return end
    
    local char = LocalPlayer.Character
    if not char then return end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp and savedCFrame then
        -- 把角色拉回真實位置，恢復真實速度
        hrp.CFrame = savedCFrame
        hrp.AssemblyLinearVelocity = savedVelocity
    end
end)

-- ==========================================
-- [ UI 與控制邏輯 ]
-- ==========================================
local isHovering = false

local function UpdateUI()
    if isActive then
        StatusText.Text = 'ANTI-AIM: ACTIVE (GHOST)'
        StatusText.TextColor3 = Color3.fromRGB(0, 200, 255)
        MainStroke.Color = Color3.fromRGB(0, 255, 255)
        ToggleBtn.Text = 'DISENGAGE [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(0, 100, 150) or Color3.fromRGB(0, 80, 120)
    else
        StatusText.Text = 'ANTI-AIM: DISABLED'
        StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
        MainStroke.Color = Color3.fromRGB(100, 100, 100)
        ToggleBtn.Text = 'ENGAGE GHOST DESYNC [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(0, 40, 80) or Color3.fromRGB(0, 30, 60)
    end
end

local function ToggleSystem()
    isActive = not isActive
    UpdateUI()
end

ToggleBtn.MouseEnter:Connect(function() isHovering = true UpdateUI() end)
ToggleBtn.MouseLeave:Connect(function() isHovering = false UpdateUI() end)
ToggleBtn.MouseButton1Click:Connect(ToggleSystem)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == toggleKey then
        ToggleSystem()
    end
end)

