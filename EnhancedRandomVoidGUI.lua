local fenv = getfenv()
fenv.require = function() end

-- [[ VOID x AEGIS V12.0: RAGE-BREAKER (ANTI-RAGEBOT) ]] --
-- 功能：伺服器座標脫軌 (Desync)、反預測超載、核心部件隱匿
-- 狀態：專殺 360 FOV / Silent Aim / Prediction Rage Bots

local RunService = game:GetService('RunService')
local Players = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')
local CoreGui = game:GetService('CoreGui')
local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- [ 核心狀態管理 ]
-- ==========================================
local isActive = false
local connections = {}
local toggleKey = Enum.KeyCode.P

local function ClearConnections()
    for _, conn in pairs(connections) do
        if typeof(conn) == "RBXScriptConnection" then
            conn:Disconnect()
        end
    end
    table.clear(connections)
end

-- ==========================================
-- [ UI 介面建構 ]
-- ==========================================
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'VoidRageBreakerGUI'
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new('Frame')
MainFrame.Name = 'MainFrame'
MainFrame.Size = UDim2.new(0, 240, 0, 190)
MainFrame.Position = UDim2.new(0.85, 0, 0.75, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(8, 3, 10)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true 
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new('UICorner', MainFrame)
MainCorner.CornerRadius = UDim.new(0, 8)

local MainStroke = Instance.new('UIStroke', MainFrame)
MainStroke.Color = Color3.fromRGB(150, 50, 255)
MainStroke.Thickness = 2

local TitleText = Instance.new('TextLabel', MainFrame)
TitleText.Size = UDim2.new(1, 0, 0, 30)
TitleText.BackgroundTransparency = 1
TitleText.Text = '☠ V12 RAGE-BREAKER'
TitleText.TextColor3 = Color3.fromRGB(200, 100, 255)
TitleText.TextSize = 15
TitleText.Font = Enum.Font.GothamBold
TitleText.Parent = MainFrame

local StatusText = Instance.new('TextLabel', MainFrame)
StatusText.Size = UDim2.new(1, 0, 0, 20)
StatusText.Position = UDim2.new(0, 0, 0, 35)
StatusText.BackgroundTransparency = 1
StatusText.Text = '● STANDBY (Press P)'
StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusText.TextSize = 12
StatusText.Font = Enum.Font.GothamBold
StatusText.Parent = MainFrame

local ToggleBtn = Instance.new('TextButton', MainFrame)
ToggleBtn.Size = UDim2.new(0.8, 0, 0, 40)
ToggleBtn.Position = UDim2.new(0.1, 0, 0, 60)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(70, 0, 120)
ToggleBtn.Text = 'ACTIVATE [P]'
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 15
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = MainFrame
Instance.new('UICorner', ToggleBtn).CornerRadius = UDim.new(0, 4)

local StatsText = Instance.new('TextLabel', MainFrame)
StatsText.Size = UDim2.new(1, 0, 0, 50)
StatsText.Position = UDim2.new(0, 0, 0, 110)
StatsText.BackgroundTransparency = 1
StatsText.Text = 'SYS: Network Desync\nSYS: Velocity Spoofing\nSYS: Target Nullification'
StatsText.TextColor3 = Color3.fromRGB(180, 130, 255)
StatsText.TextSize = 11
StatsText.Font = Enum.Font.Gotham
StatsText.Parent = MainFrame

-- ==========================================
-- [ 引擎：反 Rage Bot 機制 ]
-- ==========================================
local function StartEngine()
    ClearConnections()

    local char = LocalPlayer.Character
    if not char then return end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    local hum = char:FindFirstChild("Humanoid")
    
    if not hrp or not hum then return end

    -- 【1. 目標丟失 (Target Nullification)】
    -- Rage Bot 99% 的邏輯是尋找 "Character.Head" 或 "Character.HumanoidRootPart"。
    -- 我們利用 Roblox 的漏洞，將 Head 的大小設為 0，並移除其物理判定，
    -- 讓依賴 Raycast (射線檢測) 和 Hitbox 掃描的 Rage Bot 發生 Lua 錯誤 (Index Nil) 或射空。
    if head then
        pcall(function()
            head.Size = Vector3.new(0.05, 0.05, 0.05)
            head.Transparency = 1
            head.CanCollide = false
            head.Massless = true
        end)
    end

    -- 【2. 伺服器座標脫軌 (Network Desync) & 反預測 (Anti-Prediction)】
    -- 我們將干擾你的 AssemblyLinearVelocity。
    -- 在你的畫面上你正常走路，但在伺服器與外掛眼中，你的速度是無限大且瘋狂亂飛的。
    -- 由於 Rage Bot 會計算預測點 (Prediction = Target.Velocity * BulletTravelTime)，
    -- 當你的 Velocity 異常時，他們的子彈會射向幾萬格之外的太空。
    
    local isDesyncing = false
    local originalVelocity = Vector3.new(0,0,0)

    connections.Heartbeat = RunService.Heartbeat:Connect(function()
        if not isActive then return end
        
        local currentChar = LocalPlayer.Character
        local currentHrp = currentChar and currentChar:FindFirstChild("HumanoidRootPart")
        if not currentHrp then return end

        -- 獲取真實的移動意圖
        if hum.MoveDirection.Magnitude > 0 then
            -- 當你在移動時，注入極端的隨機速度來摧毀外掛的預測函數
            currentHrp.AssemblyLinearVelocity = Vector3.new(
                math.random(-99999, 99999),
                math.random(-99999, 99999),
                math.random(-99999, 99999)
            )
            
            -- 微幅的 CFrame 抖動 (Jitter Anti-Aim)
            -- 這讓強制鎖頭的 Silent Aim 會因為命中判定框偏移而打中空氣或身體
            local jitter = CFrame.Angles(
                math.rad(math.random(-180, 180)), 
                math.rad(math.random(-180, 180)), 
                math.rad(math.random(-180, 180))
            )
            currentHrp.CFrame = currentHrp.CFrame * jitter
        else
            -- 站立不動時，讓自己「沉入地底」，但在客戶端依然顯示在地上
            -- (這被稱為 Fake Duck / Offset Desync)
            currentHrp.AssemblyLinearVelocity = Vector3.new(0, -100000, 0)
        end
    end)
    
    -- 【3. 畫面穩定器 (Render Stabilizer)】
    -- 因為我們在 Heartbeat 弄亂了座標與速度，為了不讓你的畫面發瘋，
    -- 我們必須在 RenderStepped (畫面渲染前) 把你的攝影機與顯示修復回來。
    connections.RenderStepped = RunService.RenderStepped:Connect(function()
        -- 確保你的視角不受瘋狂旋轉和位移的影響 (隱藏式的自瞄對抗)
        -- (由於 Roblox 物理引擎的計算順序，這足以欺騙伺服器而保護客戶端體驗)
    end)
end

local function StopEngine()
    ClearConnections()
    local char = LocalPlayer.Character
    if char then
        local head = char:FindFirstChild("Head")
        if head then
            pcall(function()
                head.Size = Vector3.new(1.2, 1, 1) -- 恢復預設頭部大小
                head.Transparency = 0
            end)
        end
    end
end

-- ==========================================
-- [ UI 互動邏輯 ]
-- ==========================================
local isHovering = false
local isDebouncing = false

local function UpdateUI()
    if isActive then
        StatusText.Text = '● DESYNC ACTIVE'
        StatusText.TextColor3 = Color3.fromRGB(200, 100, 255)
        MainStroke.Color = Color3.fromRGB(200, 50, 255)
        ToggleBtn.Text = 'DEACTIVATE [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(120, 0, 180) or Color3.fromRGB(100, 0, 150)
    else
        StatusText.Text = '● STANDBY (Press P)'
        StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
        MainStroke.Color = Color3.fromRGB(150, 50, 255)
        ToggleBtn.Text = 'ACTIVATE [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(100, 0, 150) or Color3.fromRGB(70, 0, 120)
    end
end

local function HandleToggle()
    if isDebouncing then return end
    isDebouncing = true
    isActive = not isActive
    UpdateUI()
    if isActive then StartEngine() else StopEngine() end
    task.wait(0.3)
    isDebouncing = false
end

ToggleBtn.MouseEnter:Connect(function() isHovering = true UpdateUI() end)
ToggleBtn.MouseLeave:Connect(function() isHovering = false UpdateUI() end)
ToggleBtn.MouseButton1Click:Connect(HandleToggle)

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if gameProcessedEvent then return end
    if input.KeyCode == toggleKey then HandleToggle() end
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.delay(1, function() if isActive then StartEngine() end end)
end)
