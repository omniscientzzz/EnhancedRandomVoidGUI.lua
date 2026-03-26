local fenv = getfenv()
fenv.require = function() end

-- [ 初始化隨機數種子 ] --
math.randomseed(os.time())

-- [ 核心服務 ] --
local RunService = game:GetService('RunService')
local Players = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')
local LocalPlayer = Players.LocalPlayer

-- [ 狀態變數 ] --
local isActive = false
local teleportCount = 0
local teleportConnection = nil

-- [ 增強功能：隨機極端座標生成器 ] --
-- 產生極度遙遠且不可預測的座標偏移量
local function GetRandomVoidOffset()
    -- 產生 -100億 到 100億 之間的隨機數 (極大化距離)
    local randX = (math.random() - 0.5) * 20000000000
    local randY = (math.random() - 0.5) * 20000000000 -- 原腳本 Y 軸是 0，現在加入高度亂數
    local randZ = (math.random() - 0.5) * 20000000000
    return Vector3.new(randX, randY, randZ)
end

-- [ GUI 創建 ] --
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'VoidGUI'
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new('Frame')
MainFrame.Name = 'MainFrame'
MainFrame.Size = UDim2.new(0, 220, 0, 180)
MainFrame.Position = UDim2.new(1, -240, 1, -200)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new('UICorner')
UICorner.CornerRadius = UDim.new(0, 16)
UICorner.Parent = MainFrame

local UIStroke = Instance.new('UIStroke')
UIStroke.Color = Color3.fromRGB(80, 60, 180)
UIStroke.Thickness = 1.5
UIStroke.Parent = MainFrame

local TopBar = Instance.new('Frame')
TopBar.Size = UDim2.new(1, 0, 0, 44)
TopBar.Position = UDim2.new(0, 0, 0, 0)
TopBar.BackgroundColor3 = Color3.fromRGB(30, 20, 60)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

local TopBarCorner = Instance.new('UICorner')
TopBarCorner.CornerRadius = UDim.new(0, 16)
TopBarCorner.Parent = TopBar

local TopBarFix = Instance.new('Frame')
TopBarFix.Size = UDim2.new(1, 0, 0, 16)
TopBarFix.Position = UDim2.new(0, 0, 1, -16)
TopBarFix.BackgroundColor3 = Color3.fromRGB(30, 20, 60)
TopBarFix.BorderSizePixel = 0
TopBarFix.Parent = TopBar

local Title = Instance.new('TextLabel')
Title.Size = UDim2.new(1, -16, 1, 0)
Title.Position = UDim2.new(0, 14, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = '⚡ VOID'
Title.TextColor3 = Color3.fromRGB(200, 180, 255)
Title.TextSize = 15
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar

local StatusLabel = Instance.new('TextLabel')
StatusLabel.Size = UDim2.new(1, -20, 0, 28)
StatusLabel.Position = UDim2.new(0, 10, 0, 52)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = '● IDLE'
StatusLabel.TextColor3 = Color3.fromRGB(120, 120, 140)
StatusLabel.TextSize = 13
StatusLabel.Font = Enum.Font.GothamBold
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Parent = MainFrame

local ToggleButton = Instance.new('TextButton')
ToggleButton.Size = UDim2.new(1, -20, 0, 54)
ToggleButton.Position = UDim2.new(0, 10, 0, 88)
ToggleButton.BackgroundColor3 = Color3.fromRGB(70, 40, 160)
ToggleButton.BorderSizePixel = 0
ToggleButton.Text = 'START'
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.TextSize = 17
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.Parent = MainFrame

local BtnCorner = Instance.new('UICorner')
BtnCorner.CornerRadius = UDim.new(0, 12)
BtnCorner.Parent = ToggleButton

local CountLabel = Instance.new('TextLabel')
CountLabel.Size = UDim2.new(1, -20, 0, 22)
CountLabel.Position = UDim2.new(0, 10, 0, 150)
CountLabel.BackgroundTransparency = 1
CountLabel.Text = 'Teleports: 0'
CountLabel.TextColor3 = Color3.fromRGB(80, 80, 100)
CountLabel.TextSize = 11
CountLabel.Font = Enum.Font.Gotham
CountLabel.TextXAlignment = Enum.TextXAlignment.Left
CountLabel.Parent = MainFrame

-- [ 核心邏輯函數 ] --
local function UpdateUI()
    if isActive then
        StatusLabel.Text = '● ACTIVE'
        StatusLabel.TextColor3 = Color3.fromRGB(120, 255, 160)
        ToggleButton.Text = 'STOP'
        ToggleButton.BackgroundColor3 = Color3.fromRGB(160, 40, 60)
    else
        StatusLabel.Text = '● IDLE'
        StatusLabel.TextColor3 = Color3.fromRGB(120, 120, 140)
        ToggleButton.Text = 'START'
        ToggleButton.BackgroundColor3 = Color3.fromRGB(70, 40, 160)
    end
    CountLabel.Text = 'Teleports: ' .. teleportCount
end

local function ToggleVoid()
    isActive = not isActive
    
    if isActive then
        teleportCount = teleportCount + 1
        UpdateUI()
        
        if teleportConnection then
            teleportConnection:Disconnect()
        end
        
        -- 啟動增強版隨機傳送循環
        teleportConnection = RunService.Heartbeat:Connect(function()
            local char = LocalPlayer.Character
            if char and char:FindFirstChild('HumanoidRootPart') then
                local hrp = char.HumanoidRootPart
                local pos = hrp.Position
                
                -- 每幀取得全新的百億級極端亂數
                local randomOffset = GetRandomVoidOffset()
                
                -- 瞬間移動到隨機的極端深空
                hrp.CFrame = CFrame.new(pos.X + randomOffset.X, pos.Y + randomOffset.Y, pos.Z + randomOffset.Z)
            end
        end)
    else
        UpdateUI()
        if teleportConnection then
            teleportConnection:Disconnect()
            teleportConnection = nil
        end
    end
end

-- [ 事件綁定 ] --
ToggleButton.MouseEnter:Connect(function()
    if isActive then
        ToggleButton.BackgroundColor3 = Color3.fromRGB(180, 60, 80)
    else
        ToggleButton.BackgroundColor3 = Color3.fromRGB(100, 60, 200)
    end
end)

ToggleButton.MouseLeave:Connect(function()
    UpdateUI()
end)

ToggleButton.Activated:Connect(ToggleVoid)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.P then
        ToggleVoid()
    end
end)

-- 角色重生處理
LocalPlayer.CharacterAdded:Connect(function()
    if isActive then
        teleportCount = teleportCount + 1
        UpdateUI()
    end
end)
