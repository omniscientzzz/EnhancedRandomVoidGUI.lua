local fenv = getfenv()
fenv.require = function() end

-- [[ VOID x AEGIS V27: NULLIFIER (絕對抵消者) ]] --
-- 不進行任何玩家位移 (No TP)。
-- 純粹的本地端投擲物刪除、TouchInterest 抹除與射線無效化 (CanQuery = false)。

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')

local LocalPlayer = Players.LocalPlayer
local toggleKey = Enum.KeyCode.P

local isActive = false
local ERASURE_RADIUS = 60 -- 湮滅半徑 60 格 (足以在超高速投擲物擊中前將其攔截)

-- 碰撞檢測參數配置
local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Exclude

local protectionConnection = nil
local intangibilityConnection = nil

-- ==========================================
-- [ GUI 建構 (極簡防護盾風格) ]
-- ==========================================
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'AegisV27GUI'
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = game:GetService('CoreGui') end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new('Frame')
MainFrame.Name = 'MainFrame'
MainFrame.Size = UDim2.new(0, 320, 0, 300)
MainFrame.Position = UDim2.new(0.85, -60, 0.75, -120)
MainFrame.BackgroundColor3 = Color3.fromRGB(10, 15, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true 
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new('UICorner', MainFrame)
MainCorner.CornerRadius = UDim.new(0, 6)

local MainStroke = Instance.new('UIStroke', MainFrame)
MainStroke.Color = Color3.fromRGB(0, 255, 150)
MainStroke.Thickness = 2

local TitleText = Instance.new('TextLabel', MainFrame)
TitleText.Size = UDim2.new(1, 0, 0, 30)
TitleText.BackgroundTransparency = 1
TitleText.Text = '🛡️ V27 NULLIFIER'
TitleText.TextColor3 = Color3.fromRGB(50, 255, 180)
TitleText.TextSize = 18
TitleText.Font = Enum.Font.GothamBlack
TitleText.Parent = MainFrame

local StatusText = Instance.new('TextLabel', MainFrame)
StatusText.Size = UDim2.new(1, 0, 0, 20)
StatusText.Position = UDim2.new(0, 0, 0, 35)
StatusText.BackgroundTransparency = 1
StatusText.Text = 'AURA: DISABLED'
StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusText.TextSize = 12
StatusText.Font = Enum.Font.GothamBold
StatusText.Parent = MainFrame

local ToggleBtn = Instance.new('TextButton', MainFrame)
ToggleBtn.Size = UDim2.new(0.8, 0, 0, 40)
ToggleBtn.Position = UDim2.new(0.1, 0, 0, 65)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(0, 40, 30)
ToggleBtn.Text = 'ACTIVATE SHIELD [P]'
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 14
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = MainFrame
Instance.new('UICorner', ToggleBtn).CornerRadius = UDim.new(0, 4)

local StatsText = Instance.new('TextLabel', MainFrame)
StatsText.Size = UDim2.new(1, 0, 0, 160)
StatsText.Position = UDim2.new(0.1, 0, 0, 115)
StatsText.BackgroundTransparency = 1
StatsText.Text = '[✓] 0% Player Movement/TP\n[✓] Absolute Intangibility (CanQuery)\n[✓] TouchTransmitter Purged\n[✓] Projectile Erasure Aura (60 Studs)\n\nIncoming attacks will be neutralized\nbefore they can touch you.'
StatsText.TextColor3 = Color3.fromRGB(150, 255, 200)
StatsText.TextSize = 11
StatsText.TextXAlignment = Enum.TextXAlignment.Left
StatsText.Font = Enum.Font.Code
StatsText.Parent = MainFrame

-- ==========================================
-- [ 核心：絕對防禦機制 ]
-- ==========================================

local function StartNullifier()
    local char = LocalPlayer.Character
    if not char then return end
    
    -- 將玩家自身加入忽略名單，防止刪除自己
    overlapParams.FilterDescendantsInstances = {char}

    -- 1. 絕對虛無化 (Stepped：在物理計算前執行)
    -- 這會讓你免疫所有射線檢測 (Raycast) 與觸碰判定 (Touched)
    intangibilityConnection = RunService.Stepped:Connect(function()
        if not isActive then return end
        local currentChar = LocalPlayer.Character
        if currentChar then
            for _, obj in ipairs(currentChar:GetDescendants()) do
                if obj:IsA("BasePart") then
                    pcall(function()
                        obj.CanTouch = false
                        obj.CanQuery = false -- 關鍵：免疫射線與範圍鎖定外掛
                        -- 保留 CanCollide 讓你可以正常走路
                    end)
                elseif obj:IsA("TouchTransmitter") then
                    obj:Destroy() -- 徹底摧毀觸碰感應器
                end
            end
        end
    end)

    -- 2. 湮滅力場 (Heartbeat：主動掃描並刪除威脅)
    protectionConnection = RunService.Heartbeat:Connect(function()
        if not isActive then return end
        local currentChar = LocalPlayer.Character
        if not currentChar then return end
        
        local hrp = currentChar:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        -- 掃描周圍 60 格內的所有物體
        local nearbyParts = workspace:GetPartBoundsInRadius(hrp.Position, ERASURE_RADIUS, overlapParams)
        
        for _, part in ipairs(nearbyParts) do
            if part:IsA("BasePart") then
                -- 智能過濾：我們不想刪除地板或巨大的建築 (通常大小超過 100)
                -- 投擲物通常小於 50，且大部分是 unanchored (未錨定) 或帶有特效
                if part.Size.Magnitude < 100 then
                    pcall(function()
                        -- 第一步：剝奪它的傷害能力
                        part.CanTouch = false
                        part.CanQuery = false
                        
                        -- 第二步：阻止它的動能
                        part.AssemblyLinearVelocity = Vector3.zero
                        part.AssemblyAngularVelocity = Vector3.zero
                        
                        -- 第三步：在本地端將其流放並銷毀 (徹底消失)
                        -- 把它傳送到極遠處可以避免刪除延遲造成的瞬間傷害
                        part.CFrame = CFrame.new(0, -99999, 0)
                        part.LocalTransparencyModifier = 1 -- 瞬間視覺隱形
                        
                        -- 如果它不是被錨定的(通常是飛行中的投擲物)，直接 Destroy
                        if not part.Anchored then
                            part:Destroy()
                        end
                    end)
                end
            end
        end
    end)
end

local function StopNullifier()
    if intangibilityConnection then intangibilityConnection:Disconnect() end
    if protectionConnection then protectionConnection:Disconnect() end
    
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
    end
end

-- ==========================================
-- [ UI 與控制邏輯 ]
-- ==========================================
local isHovering = false

local function UpdateUI()
    if isActive then
        StatusText.Text = 'AURA: ACTIVE (SAFE)'
        StatusText.TextColor3 = Color3.fromRGB(0, 255, 150)
        MainStroke.Color = Color3.fromRGB(0, 255, 150)
        ToggleBtn.Text = 'DEACTIVATE [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(0, 100, 60) or Color3.fromRGB(0, 80, 50)
    else
        StatusText.Text = 'AURA: DISABLED'
        StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
        MainStroke.Color = Color3.fromRGB(100, 100, 100)
        ToggleBtn.Text = 'ACTIVATE SHIELD [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(0, 60, 40) or Color3.fromRGB(0, 40, 30)
    end
end

local function ToggleSystem()
    isActive = not isActive
    UpdateUI()
    if isActive then StartNullifier() else StopNullifier() end
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
        StartNullifier()
    end
end)

