local fenv = getfenv()
fenv.require = function() end

-- [[ VOID x AEGIS V26: KAMUI (神威 - 絕對空間脫軌) ]] --
-- 利用 Stepped 與 Heartbeat 的渲染時間差，達成完美的伺服器與客戶端物理脫軌。
-- 在伺服器眼中，你永遠在 50000 studs 之外；在你自己眼中，你一切正常。

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')
local Lighting = game:GetService('Lighting')
local TweenService = game:GetService('TweenService')

local LocalPlayer = Players.LocalPlayer
local toggleKey = Enum.KeyCode.P

local isDesynced = false
local currentlyOffset = false
local offsetDistance = Vector3.new(50000, 0, 50000) -- 放逐到極遠的 X/Z 座標
local savedVelocity = Vector3.zero

-- ==========================================
-- [ 虛空立足點 (防止掉出地圖) ]
-- ==========================================
-- 當你被傳送到虛空時，物理引擎會計算重力。
-- 我們必須在虛空中即時生成地板托住你，否則你的客戶端會不斷往下掉。
local voidFloor = Instance.new("Part")
voidFloor.Name = "AegisKamuiFloor"
voidFloor.Size = Vector3.new(100, 5, 100)
voidFloor.Anchored = true
voidFloor.CanCollide = true
voidFloor.Transparency = 1
voidFloor.Color = Color3.fromRGB(255, 0, 0)
voidFloor.Parent = workspace

-- 視覺特效：神威濾鏡
local kamuiCC = Instance.new("ColorCorrectionEffect")
kamuiCC.Name = "AegisKamuiVision"
kamuiCC.TintColor = Color3.fromRGB(255, 230, 230)
kamuiCC.Saturation = -0.6
kamuiCC.Contrast = 0.2
kamuiCC.Enabled = false
kamuiCC.Parent = Lighting

-- ==========================================
-- [ GUI 建構 (深淵血紅風格) ]
-- ==========================================
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'AegisV26GUI'
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = game:GetService('CoreGui') end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new('Frame')
MainFrame.Name = 'MainFrame'
MainFrame.Size = UDim2.new(0, 320, 0, 330)
MainFrame.Position = UDim2.new(0.85, -60, 0.75, -120)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 0, 0)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true 
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new('UICorner', MainFrame)
MainCorner.CornerRadius = UDim.new(0, 6)

local MainStroke = Instance.new('UIStroke', MainFrame)
MainStroke.Color = Color3.fromRGB(180, 0, 0)
MainStroke.Thickness = 2

local TitleText = Instance.new('TextLabel', MainFrame)
TitleText.Size = UDim2.new(1, 0, 0, 30)
TitleText.BackgroundTransparency = 1
TitleText.Text = '👁️ V26 KAMUI (神威)'
TitleText.TextColor3 = Color3.fromRGB(255, 50, 50)
TitleText.TextSize = 18
TitleText.Font = Enum.Font.GothamBlack
TitleText.Parent = MainFrame

local StatusText = Instance.new('TextLabel', MainFrame)
StatusText.Size = UDim2.new(1, 0, 0, 20)
StatusText.Position = UDim2.new(0, 0, 0, 35)
StatusText.BackgroundTransparency = 1
StatusText.Text = 'REALITY: ATTACHED'
StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusText.TextSize = 12
StatusText.Font = Enum.Font.GothamBold
StatusText.Parent = MainFrame

local ToggleBtn = Instance.new('TextButton', MainFrame)
ToggleBtn.Size = UDim2.new(0.8, 0, 0, 40)
ToggleBtn.Position = UDim2.new(0.1, 0, 0, 65)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(40, 0, 0)
ToggleBtn.Text = 'ACTIVATE KAMUI [P]'
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 14
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = MainFrame
Instance.new('UICorner', ToggleBtn).CornerRadius = UDim.new(0, 4)

local StatsText = Instance.new('TextLabel', MainFrame)
StatsText.Size = UDim2.new(1, 0, 0, 200)
StatsText.Position = UDim2.new(0.1, 0, 0, 115)
StatsText.BackgroundTransparency = 1
StatsText.Text = '[⚠] FAILURE ANALYSIS:\nEnemy uses Server Interpolation.\n\n[⚡] V26 SOLUTION:\nPre-Physics Spatial Desync.\n\n[⚙] MECHANISM:\nDuring rendering, you are here.\nDuring physics, you are 50,000 studs away.\nServer reads physics. You are untouched.\nGravity stabilized via Void Floor.'
StatsText.TextColor3 = Color3.fromRGB(255, 150, 150)
StatsText.TextSize = 11
StatsText.TextXAlignment = Enum.TextXAlignment.Left
StatsText.Font = Enum.Font.Code
StatsText.Parent = MainFrame

-- ==========================================
-- [ 核心：神威引擎 (Pre-Physics Desync) ]
-- ==========================================

-- 1. 在物理引擎計算「碰撞與傷害」前，將本體放逐到虛空
RunService.Stepped:Connect(function()
    if isDesynced and not currentlyOffset then
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local hrp = char.HumanoidRootPart
            
            -- 保存真實速度
            savedVelocity = hrp.AssemblyLinearVelocity
            
            -- 將本體瞬間移至 50000 studs 外
            hrp.CFrame = hrp.CFrame + offsetDistance
            
            -- 將虛空立足點移動到腳下，防止伺服器判定你墜落
            voidFloor.Position = hrp.Position - Vector3.new(0, 3, 0)
            
            -- 打亂預判軌跡的物理速度
            hrp.AssemblyLinearVelocity = Vector3.new(math.random(-500,500), 0, math.random(-500,500))
            
            currentlyOffset = true
        end
    end
end)

-- 2. 在物理引擎計算完畢後 (客戶端渲染畫面前)，將本體拉回原位
RunService.Heartbeat:Connect(function()
    if currentlyOffset then
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local hrp = char.HumanoidRootPart
            
            -- 將本體拉回現實 (讓你能在畫面上正常看到自己並移動)
            hrp.CFrame = hrp.CFrame - offsetDistance
            
            -- 恢復真實速度，確保你的跳躍與行走順暢
            hrp.AssemblyLinearVelocity = savedVelocity
        end
        currentlyOffset = false
    end
end)

-- ==========================================
-- [ UI 與控制邏輯 ]
-- ==========================================
local isHovering = false

local function UpdateUI()
    if isDesynced then
        StatusText.Text = 'REALITY: DETACHED (VOID)'
        StatusText.TextColor3 = Color3.fromRGB(255, 0, 0)
        MainStroke.Color = Color3.fromRGB(255, 50, 50)
        ToggleBtn.Text = 'DEACTIVATE [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(100, 0, 0) or Color3.fromRGB(80, 0, 0)
        kamuiCC.Enabled = true
    else
        StatusText.Text = 'REALITY: ATTACHED'
        StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
        MainStroke.Color = Color3.fromRGB(180, 0, 0)
        ToggleBtn.Text = 'ACTIVATE KAMUI [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(60, 0, 0) or Color3.fromRGB(40, 0, 0)
        kamuiCC.Enabled = false
    end
end

local function ToggleKamui()
    isDesynced = not isDesynced
    UpdateUI()
end

ToggleBtn.MouseEnter:Connect(function() isHovering = true UpdateUI() end)
ToggleBtn.MouseLeave:Connect(function() isHovering = false UpdateUI() end)
ToggleBtn.MouseButton1Click:Connect(ToggleKamui)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == toggleKey then
        ToggleKamui()
    end
end)
