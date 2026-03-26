local fenv = getfenv()
fenv.require = function() end

-- [ 初始化隨機數種子 ] --
math.randomseed(os.time())

-- [ 核心服務 ] --
local RunService = game:GetService('RunService')
local Players = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')
local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- [ 終極防呆機制：強力清除所有舊版 GUI ]
-- ==========================================
local function ForceCleanOldGUIs()
    local guiNamesToDelete = {'VoidGUI', 'UltimateVoidGUI', 'OblivionProtocolGUI'}
    
    for _, guiName in ipairs(guiNamesToDelete) do
        pcall(function()
            -- 清除 PlayerGui 中的殘留
            local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
            if playerGui and playerGui:FindFirstChild(guiName) then
                playerGui[guiName]:Destroy()
            end
            -- 清除 CoreGui 中的殘留 (部分執行器會放這裡)
            local coreGui = game:GetService("CoreGui")
            if coreGui and coreGui:FindFirstChild(guiName) then
                coreGui[guiName]:Destroy()
            end
        end)
    end
end
ForceCleanOldGUIs()

-- [ 狀態變數與連接池 ] --
local isMasterActive = false
local connections = {}
local originalPhysicalProperties = {}

-- [ 輔助函數 ] --
local function GetHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild('HumanoidRootPart')
end

local function GetHum()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild('Humanoid')
end

local function GetRandomVoidOffset()
    local randX = (math.random() - 0.5) * 20000000000
    local randY = (math.random() - 0.5) * 20000000000 
    local randZ = (math.random() - 0.5) * 20000000000
    return Vector3.new(randX, randY, randZ)
end

-- ==========================================
-- [ 極簡 UI 介面設計 - 一鍵啟動版 ]
-- ==========================================
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'OblivionProtocolGUI' -- 使用全新命名避免衝突
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999999 -- 確保在最上層，絕對不會被擋住點擊

local success, core = pcall(function() return game:GetService("CoreGui") end)
ScreenGui.Parent = success and core or LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new('Frame')
MainFrame.Name = 'MainFrame'
MainFrame.Size = UDim2.new(0, 200, 0, 90)
-- 這次預設放在畫面正中央，讓你一眼就能確認執行成功
MainFrame.Position = UDim2.new(0.5, -100, 0.5, -45)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new('UICorner')
UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = MainFrame

local UIStroke = Instance.new('UIStroke')
UIStroke.Color = Color3.fromRGB(120, 40, 255)
UIStroke.Thickness = 2
UIStroke.Parent = MainFrame

-- [ 頂部拖曳標題列 ]
local TopBar = Instance.new('Frame')
TopBar.Size = UDim2.new(1, 0, 0, 30)
TopBar.BackgroundColor3 = Color3.fromRGB(30, 20, 60)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame
Instance.new('UICorner', TopBar).CornerRadius = UDim.new(0, 10)

local TopBarFix = Instance.new('Frame')
TopBarFix.Size = UDim2.new(1, 0, 0, 10)
TopBarFix.Position = UDim2.new(0, 0, 1, -10)
TopBarFix.BackgroundColor3 = Color3.fromRGB(30, 20, 60)
TopBarFix.BorderSizePixel = 0
TopBarFix.Parent = TopBar

local Title = Instance.new('TextLabel')
Title.Size = UDim2.new(1, 0, 1, 0)
Title.BackgroundTransparency = 1
Title.Text = '⚡ OBLIVION PROTOCOL'
Title.TextColor3 = Color3.fromRGB(200, 180, 255)
Title.TextSize = 13
Title.Font = Enum.Font.GothamBold
Title.Parent = TopBar

-- [ 一鍵總開關按鈕 ]
local MasterButton = Instance.new('TextButton')
MasterButton.Size = UDim2.new(1, -20, 0, 40)
MasterButton.Position = UDim2.new(0, 10, 0, 40)
MasterButton.BackgroundColor3 = Color3.fromRGB(70, 40, 160)
MasterButton.BorderSizePixel = 0
MasterButton.Text = 'ACTIVATE ALL'
MasterButton.TextColor3 = Color3.fromRGB(255, 255, 255)
MasterButton.TextSize = 14
MasterButton.Font = Enum.Font.GothamBold
MasterButton.Parent = MainFrame
Instance.new('UICorner', MasterButton).CornerRadius = UDim.new(0, 6)

-- [ 自訂拖曳功能 (綁定於 TopBar) ] --
local dragging, dragInput, dragStart, startPos

TopBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)

TopBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- ==========================================
-- [ 核心邏輯：一鍵切換所有狀態 ]
-- ==========================================
local function ToggleAll()
    isMasterActive = not isMasterActive
    local state = isMasterActive

    -- 介面視覺更新
    if state then
        MasterButton.Text = 'DEACTIVATE ALL'
        MasterButton.BackgroundColor3 = Color3.fromRGB(180, 40, 60)
        UIStroke.Color = Color3.fromRGB(255, 60, 80)
        TopBar.BackgroundColor3 = Color3.fromRGB(60, 20, 30)
        TopBarFix.BackgroundColor3 = Color3.fromRGB(60, 20, 30)
    else
        MasterButton.Text = 'ACTIVATE ALL'
        MasterButton.BackgroundColor3 = Color3.fromRGB(70, 40, 160)
        UIStroke.Color = Color3.fromRGB(120, 40, 255)
        TopBar.BackgroundColor3 = Color3.fromRGB(30, 20, 60)
        TopBarFix.BackgroundColor3 = Color3.fromRGB(30, 20, 60)
    end

    -- 斷開所有舊的連接以防重複疊加
    for key, conn in pairs(connections) do
        if conn then conn:Disconnect() end
    end
    connections = {}

    if state then
        -- [ 1. 啟動 Void TP ]
        connections.VoidTP = RunService.Heartbeat:Connect(function()
            local hrp = GetHRP()
            if hrp then
                local randomOffset = GetRandomVoidOffset()
                hrp.CFrame = CFrame.new(hrp.Position.X + randomOffset.X, hrp.Position.Y + randomOffset.Y, hrp.Position.Z + randomOffset.Z)
            end
        end)

        -- [ 2. 啟動 Absolute Mass (絕對質量) & [ 6. 啟動 Noclip (穿牆) ] & [ 3. 啟動 Untouchable (虛無化) ]
        connections.Physics = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            if char then
                local hum = GetHum()
                if hum then
                    hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
                    hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
                end
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        -- 記錄原始屬性以便關閉時還原
                        if not originalPhysicalProperties[part] then
                            originalPhysicalProperties[part] = part.CustomPhysicalProperties
                        end
                        part.CustomPhysicalProperties = PhysicalProperties.new(100, 100, 0, 100, 100)
                        part.CanTouch = false
                        part.CanCollide = false
                    end
                end
            end
        end)

        -- [ 4. 啟動 Anti-Bring (反綁架) ]
        local lastPos = nil
        connections.AntiBring = RunService.Heartbeat:Connect(function()
            local hrp = GetHRP()
            if hrp then
                lastPos = hrp.Position 
            end
        end)

        -- [ 5. 啟動 Velocity Wiper (動能抹除) ]
        connections.AntiFling = RunService.Stepped:Connect(function()
            local hrp = GetHRP()
            if hrp then
                for _, v in ipairs(hrp:GetChildren()) do
                    if v:IsA("BodyMover") or v:IsA("BodyVelocity") or v:IsA("BodyGyro") or v:IsA("AngularVelocity") then
                        v:Destroy()
                    end
                end
                if hrp.RotVelocity.Magnitude > 30 or hrp.Velocity.Magnitude > 200 then
                    hrp.RotVelocity = Vector3.new(0, 0, 0)
                    hrp.Velocity = Vector3.new(0, 0, 0)
                end
            end
        end)

    else
        -- [ 關閉狀態：還原屬性 ]
        local char = LocalPlayer.Character
        if char then
            for part, props in pairs(originalPhysicalProperties) do
                if part and part.Parent then
                    part.CustomPhysicalProperties = props
                end
            end
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanTouch = true
                end
            end
        end
        originalPhysicalProperties = {}
    end
end

-- ==========================================
-- [ 事件綁定 ]
-- ==========================================
MasterButton.MouseButton1Click:Connect(ToggleAll)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed then
        if input.KeyCode == Enum.KeyCode.P then
            ToggleAll()
        elseif input.KeyCode == Enum.KeyCode.RightShift then
            MainFrame.Visible = not MainFrame.Visible
        end
    end
end)
