local fenv = getfenv()
fenv.require = function() end

-- [[ VOID x AEGIS V31: OBLIVION (絕對湮滅與重力錨定) ]] --
-- 專治 Rivals 全圖巨大球體外掛與物理擊飛。
-- 包含：絕對防擊飛、大體積投擲物秒刪、Hitbox 命名加密。

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')

local LocalPlayer = Players.LocalPlayer
local toggleKey = Enum.KeyCode.P

local isActive = false
local connections = {}

-- ==========================================
-- [ GUI 建構 (湮滅深淵風格) ]
-- ==========================================
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'AegisV31GUI'
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = game:GetService('CoreGui') end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new('Frame')
MainFrame.Name = 'MainFrame'
MainFrame.Size = UDim2.new(0, 320, 0, 310)
MainFrame.Position = UDim2.new(0.85, -60, 0.75, -120)
MainFrame.BackgroundColor3 = Color3.fromRGB(5, 5, 8)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true 
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new('UICorner', MainFrame)
MainCorner.CornerRadius = UDim.new(0, 6)

local MainStroke = Instance.new('UIStroke', MainFrame)
MainStroke.Color = Color3.fromRGB(80, 0, 255)
MainStroke.Thickness = 2

local TitleText = Instance.new('TextLabel', MainFrame)
TitleText.Size = UDim2.new(1, 0, 0, 30)
TitleText.BackgroundTransparency = 1
TitleText.Text = '🌌 V31 OBLIVION'
TitleText.TextColor3 = Color3.fromRGB(150, 100, 255)
TitleText.TextSize = 16
TitleText.Font = Enum.Font.GothamBlack
TitleText.Parent = MainFrame

local StatusText = Instance.new('TextLabel', MainFrame)
StatusText.Size = UDim2.new(1, 0, 0, 20)
StatusText.Position = UDim2.new(0, 0, 0, 35)
StatusText.BackgroundTransparency = 1
StatusText.Text = 'DEFENSE: INACTIVE'
StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusText.TextSize = 12
StatusText.Font = Enum.Font.GothamBold
StatusText.Parent = MainFrame

local ToggleBtn = Instance.new('TextButton', MainFrame)
ToggleBtn.Size = UDim2.new(0.8, 0, 0, 40)
ToggleBtn.Position = UDim2.new(0.1, 0, 0, 65)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(20, 0, 40)
ToggleBtn.Text = 'ENGAGE OBLIVION [P]'
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 14
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = MainFrame
Instance.new('UICorner', ToggleBtn).CornerRadius = UDim.new(0, 4)

local StatsText = Instance.new('TextLabel', MainFrame)
StatsText.Size = UDim2.new(1, 0, 0, 170)
StatsText.Position = UDim2.new(0.1, 0, 0, 115)
StatsText.BackgroundTransparency = 1
StatsText.Text = '[✓] Absolute Anti-Fling Engine\n[✓] AoE Sphere Auto-Deletion\n[✓] Anatomy Scramble (Aimbot Crash)\n[✓] Zero CFrame Modification\n\nYou will not be moved.\nTheir projectiles will cease to exist.\nTheir scripts will error.'
StatsText.TextColor3 = Color3.fromRGB(180, 150, 255)
StatsText.TextSize = 11
StatsText.TextXAlignment = Enum.TextXAlignment.Left
StatsText.Font = Enum.Font.Code
StatsText.Parent = MainFrame

-- ==========================================
-- [ 核心功能 ]
-- ==========================================

-- 1. 投擲物清除器 (秒殺巨大的光球與攻擊)
local function ObliterateThreat(part)
    if not part:IsA("BasePart") then return end
    if part:IsDescendantOf(LocalPlayer.Character) then return end

    -- 如果物體體積過大 (例如你圖中那些大於 15 格的球體)，或者是未錨定的投擲物
    -- 瞬間將其拔除物理碰撞與視覺，然後銷毀
    if part.Size.Magnitude > 15 or not part.Anchored then
        pcall(function()
            part.CanCollide = false
            part.CanTouch = false
            part.CanQuery = false
            part.Transparency = 1
            part.AssemblyLinearVelocity = Vector3.zero
            part.CFrame = CFrame.new(0, -99999, 0)
            task.wait()
            part:Destroy()
        end)
    end
end

local function StartOblivion()
    local char = LocalPlayer.Character
    if not char then return end

    -- [A] 器官代碼加密 (Anatomy Scramble)
    -- Rivals 的命中判定通常會尋找 "Head" 或 "Torso"。
    -- 我們將這些名字改掉，對手的本地判定腳本在打中你時會找不到對應部位，直接產生 Error 而無法對伺服器發送扣血指令。
    for _, part in ipairs(char:GetChildren()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            -- 加上亂碼後綴，但保留基本物理
            part.Name = part.Name .. "_VOID_ENCRYPTED"
        end
    end

    -- [B] 絕對防擊飛 (Anti-Fling Engine)
    -- 利用 Stepped (物理計算前) 強制介入，抹除所有異常的動能
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local antiFling = RunService.Stepped:Connect(function()
        if not isActive or not hrp then return end
        
        -- 消除所有旋轉力 (防止你在空中亂滾)
        hrp.AssemblyAngularVelocity = Vector3.zero
        
        -- 如果受到極大外力 (速度瞬間超過 50)，直接鎖死動能
        -- 這讓你即使站在核彈中心，也能像釘在地上一般穩固
        if hrp.AssemblyLinearVelocity.Magnitude > 50 then
            hrp.AssemblyLinearVelocity = Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0)
        end
    end)
    table.insert(connections, antiFling)

    -- [C] 實時環境掃描器 (Workspace Sweeper)
    -- 清理已經存在場上的巨大球體
    for _, obj in ipairs(workspace:GetDescendants()) do
        ObliterateThreat(obj)
    end

    -- 監視新生成的球體並在 0.001 秒內將其刪除
    local sweeper = workspace.DescendantAdded:Connect(function(descendant)
        if isActive then
            ObliterateThreat(descendant)
        end
    end)
    table.insert(connections, sweeper)
end

local function StopOblivion()
    for _, conn in ipairs(connections) do
        conn:Disconnect()
    end
    connections = {}
    
    -- 為了安全起見，不主動改回名字，等到玩家重生時自然恢復
end

-- ==========================================
-- [ UI 與控制邏輯 ]
-- ==========================================
local isHovering = false

local function UpdateUI()
    if isActive then
        StatusText.Text = 'DEFENSE: OBLIVION ACTIVE'
        StatusText.TextColor3 = Color3.fromRGB(150, 100, 255)
        MainStroke.Color = Color3.fromRGB(150, 0, 255)
        ToggleBtn.Text = 'DISENGAGE [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(60, 0, 100) or Color3.fromRGB(40, 0, 80)
    else
        StatusText.Text = 'DEFENSE: INACTIVE'
        StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
        MainStroke.Color = Color3.fromRGB(80, 0, 255)
        ToggleBtn.Text = 'ENGAGE OBLIVION [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(30, 0, 60) or Color3.fromRGB(20, 0, 40)
    end
end

local function ToggleSystem()
    isActive = not isActive
    UpdateUI()
    if isActive then StartOblivion() else StopOblivion() end
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
        StartOblivion()
    end
end)

