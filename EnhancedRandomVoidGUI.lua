local fenv = getfenv()
fenv.require = function() end

-- [[ VOID x AEGIS V24: TERMINUS (終焉極限) ]] --
-- 座標突破 1e30 (Roblox Float32 極限邊緣)
-- 徹底摧毀全圖範圍爆破與 math.huge 鎖定

local Players = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')
local RunService = game:GetService('RunService')

local LocalPlayer = Players.LocalPlayer
local toggleKey = Enum.KeyCode.P

-- ==========================================
-- [ 核心極限參數 (Float32 極限邊緣) ]
-- ==========================================
-- 1e30 = 1,000,000,000,000,000,000,000,000,000,000
-- 這是 Roblox 不會判定為 NaN 或 Infinity 的極限安全值
-- 每次跳躍間距超過 2e30
local TERMINUS_BASE = 1e30 
local FORCEFIELD_RADIUS = 200 

local isActive = false
local realCFrame = nil
local togglePhase = 0 
local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Exclude

-- 連接池
local renderConnection = nil
local heartbeatConnection = nil

-- ==========================================
-- [ 敵方 hitbox 崩壞處理 ]
-- ==========================================
task.spawn(function()
    while true do
        task.wait(0.1)
        if isActive then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character then
                    pcall(function()
                        local enemyHitbox = workspace:FindFirstChild(plr.Name) and workspace[plr.Name]:FindFirstChild("HitboxHead")
                        if enemyHitbox then
                            -- 強制將敵方 Hitbox 放逐到反向極限
                            enemyHitbox.CFrame = CFrame.new(-TERMINUS_BASE, -TERMINUS_BASE, -TERMINUS_BASE)
                            enemyHitbox.Size = Vector3.new(0, 0, 0)
                            enemyHitbox.CanCollide = false
                            enemyHitbox.CanTouch = false
                            enemyHitbox.CanQuery = false
                        end
                    end)
                end
            end
        end
    end
end)

-- ==========================================
-- [ GUI 建構 ]
-- ==========================================
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'AegisV24GUI'
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = game:GetService('CoreGui') end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new('Frame')
MainFrame.Name = 'MainFrame'
MainFrame.Size = UDim2.new(0, 310, 0, 310)
MainFrame.Position = UDim2.new(0.85, -50, 0.75, -110)
MainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0) -- 絕對純黑
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true 
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new('UICorner', MainFrame)
MainCorner.CornerRadius = UDim.new(0, 8)

local MainStroke = Instance.new('UIStroke', MainFrame)
MainStroke.Color = Color3.fromRGB(255, 0, 0) -- 終焉紅
MainStroke.Thickness = 3

local TitleText = Instance.new('TextLabel', MainFrame)
TitleText.Size = UDim2.new(1, 0, 0, 30)
TitleText.BackgroundTransparency = 1
TitleText.Text = '⚠ V24 TERMINUS LIMIT'
TitleText.TextColor3 = Color3.fromRGB(255, 50, 50)
TitleText.TextSize = 16
TitleText.Font = Enum.Font.GothamBlack
TitleText.Parent = MainFrame

local StatusText = Instance.new('TextLabel', MainFrame)
StatusText.Size = UDim2.new(1, 0, 0, 20)
StatusText.Position = UDim2.new(0, 0, 0, 35)
StatusText.BackgroundTransparency = 1
StatusText.Text = 'STATUS: NORMAL'
StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusText.TextSize = 12
StatusText.Font = Enum.Font.GothamBold
StatusText.Parent = MainFrame

local ToggleBtn = Instance.new('TextButton', MainFrame)
ToggleBtn.Size = UDim2.new(0.8, 0, 0, 40)
ToggleBtn.Position = UDim2.new(0.1, 0, 0, 65)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(40, 0, 0)
ToggleBtn.Text = 'ACTIVATE TERMINUS [P]'
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 14
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = MainFrame
Instance.new('UICorner', ToggleBtn).CornerRadius = UDim.new(0, 4)

local StatsText = Instance.new('TextLabel', MainFrame)
StatsText.Size = UDim2.new(1, 0, 0, 180)
StatsText.Position = UDim2.new(0.1, 0, 0, 115)
StatsText.BackgroundTransparency = 1
StatsText.Text = '[⚠] COORD LIMIT: +/- 1e30 (MAX)\n[⚠] INTERVAL: > 2e30 PER TICK\n[⚠] TOUCH INTEREST: PURGED\n[⚠] INTANGIBILITY: ABSOLUTE\n[⚠] ENGINE BREAK BYPASS: ON\n\nFloat32 limits engaged.'
StatsText.TextColor3 = Color3.fromRGB(255, 100, 100)
StatsText.TextSize = 11
StatsText.TextXAlignment = Enum.TextXAlignment.Left
StatsText.Font = Enum.Font.Code
StatsText.Parent = MainFrame

-- ==========================================
-- [ 引擎：32位元終極崩潰迴避脫軌 ]
-- ==========================================
local function StartTerminus()
    local char = LocalPlayer.Character
    if not char then return end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    realCFrame = hrp.CFrame
    overlapParams.FilterDescendantsInstances = {char}

    heartbeatConnection = RunService.Heartbeat:Connect(function()
        if not isActive then return end
        local currentHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not currentHrp then return end

        realCFrame = currentHrp.CFrame
        
        -- 四象限絕對跳躍 (確保每一幀的位移量達到最大極限 2e30)
        togglePhase = (togglePhase + 1) % 4
        
        local targetX, targetY, targetZ
        if togglePhase == 0 then
            targetX, targetY, targetZ = TERMINUS_BASE, TERMINUS_BASE, TERMINUS_BASE
        elseif togglePhase == 1 then
            targetX, targetY, targetZ = -TERMINUS_BASE, TERMINUS_BASE * 1.5, -TERMINUS_BASE
        elseif togglePhase == 2 then
            targetX, targetY, targetZ = TERMINUS_BASE, TERMINUS_BASE * 2, -TERMINUS_BASE
        else
            targetX, targetY, targetZ = -TERMINUS_BASE, TERMINUS_BASE * 2.5, TERMINUS_BASE
        end

        local terminusOffset = Vector3.new(targetX, targetY, targetZ)
        
        -- 瞬間放逐
        currentHrp.CFrame = CFrame.new(realCFrame.Position + terminusOffset)
        
        -- 徹底無效化 Touch (防止對手用 math.huge 範圍觸碰)
        for _, obj in ipairs(LocalPlayer.Character:GetDescendants()) do
            if obj:IsA("TouchTransmitter") then
                obj:Destroy() -- 毀滅觸發器
            elseif obj:IsA("BasePart") then
                pcall(function()
                    obj.CanTouch = false
                    obj.CanQuery = false
                end)
            end
        end

        -- 清除 HitboxHead
        pcall(function()
            local myHitbox = workspace:FindFirstChild(LocalPlayer.Name) and workspace[LocalPlayer.Name]:FindFirstChild("HitboxHead")
            if myHitbox then
                myHitbox.CFrame = CFrame.new(TERMINUS_BASE, TERMINUS_BASE, TERMINUS_BASE)
                myHitbox.Size = Vector3.zero
                myHitbox.CanTouch = false
                myHitbox.CanQuery = false
                local touch = myHitbox:FindFirstChildOfClass("TouchTransmitter")
                if touch then touch:Destroy() end
            end
        end)
    end)

    renderConnection = RunService.RenderStepped:Connect(function()
        if not isActive then return end
        local currentHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if currentHrp and realCFrame then
            -- 渲染時拉回真實座標
            currentHrp.CFrame = realCFrame
            currentHrp.AssemblyLinearVelocity = Vector3.zero
            currentHrp.AssemblyAngularVelocity = Vector3.zero
        end
    end)
end

local function StopTerminus()
    if renderConnection then renderConnection:Disconnect() end
    if heartbeatConnection then heartbeatConnection:Disconnect() end
    
    local char = LocalPlayer.Character
    if char then
        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("BasePart") then
                pcall(function()
                    obj.CanTouch = true
                    obj.CanQuery = true
                end)
            end
        end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp and realCFrame then
            hrp.CFrame = realCFrame
            hrp.AssemblyLinearVelocity = Vector3.zero
        end
    end
end

-- ==========================================
-- [ UI 與控制邏輯 ]
-- ==========================================
local isHovering = false

local function UpdateUI()
    if isActive then
        StatusText.Text = 'STATUS: TERMINUS ACTIVE'
        StatusText.TextColor3 = Color3.fromRGB(255, 50, 50)
        MainStroke.Color = Color3.fromRGB(255, 50, 50)
        ToggleBtn.Text = 'DEACTIVATE [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(150, 0, 0) or Color3.fromRGB(120, 0, 0)
    else
        StatusText.Text = 'STATUS: NORMAL'
        StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
        MainStroke.Color = Color3.fromRGB(100, 100, 100)
        ToggleBtn.Text = 'ACTIVATE TERMINUS [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(60, 0, 0) or Color3.fromRGB(40, 0, 0)
    end
end

local function ToggleSystem()
    isActive = not isActive
    UpdateUI()
    if isActive then StartTerminus() else StopTerminus() end
end

ToggleBtn.MouseEnter:Connect(function() isHovering = true UpdateUI() end)
ToggleBtn.MouseLeave:Connect(function() isHovering = false UpdateUI() end)
ToggleBtn.MouseButton1Click:Connect(ToggleSystem)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == toggleKey then
        ToggleSystem()
    end
end)

LocalPlayer.CharacterAdded:Connect(function(newChar)
    if isActive then
        task.wait(0.5)
        overlapParams.FilterDescendantsInstances = {newChar}
        StartTerminus()
    end
end)
