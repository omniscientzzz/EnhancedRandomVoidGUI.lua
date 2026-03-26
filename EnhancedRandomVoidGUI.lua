local fenv = getfenv()
fenv.require = function() end

math.randomseed(os.time())

local RunService = game:GetService('RunService')
local Players = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')
local Workspace = game:GetService('Workspace')
local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- [ 清除舊版 GUI ]
-- ==========================================
local function ForceCleanOldGUIs()
    local guiNamesToDelete = {'VoidGUI', 'UltimateVoidGUI', 'OblivionProtocolGUI'}
    for _, guiName in ipairs(guiNamesToDelete) do
        pcall(function()
            local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
            if playerGui and playerGui:FindFirstChild(guiName) then
                playerGui[guiName]:Destroy()
            end
            local coreGui = game:GetService("CoreGui")
            if coreGui and coreGui:FindFirstChild(guiName) then
                coreGui[guiName]:Destroy()
            end
        end)
    end
end
ForceCleanOldGUIs()

local isMasterActive = false
local connections = {}
local originalStates = {}

local function GetHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild('HumanoidRootPart')
end

local function GetHum()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild('Humanoid')
end

-- ==========================================
-- [ ★ 修復版：安全 Metatable 攔截 ★ ]
-- ==========================================
local OldNamecall
local OldNewIndex
local OldIndex

if hookmetamethod then
    -- 攔截 Namecall (防止客戶端被踢或被強殺)
    OldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        if isMasterActive and typeof(self) == "Instance" then
            if method == "Kick" or method == "kick" then
                if self == LocalPlayer then return nil end
            elseif method == "TakeDamage" or method == "BreakJoints" then
                local char = LocalPlayer.Character
                if char and (self == char or self:IsDescendantOf(char)) then return nil end
            end
        end
        return OldNamecall(self, ...)
    end)

    -- 攔截 NewIndex (鎖死血量修改)
    OldNewIndex = hookmetamethod(game, "__newindex", function(self, key, value)
        if isMasterActive and not checkcaller() and typeof(self) == "Instance" then
            if key == "Health" and self:IsA("Humanoid") then
                local char = LocalPlayer.Character
                if char and self:IsDescendantOf(char) then
                    -- 拒絕寫入，維持 0 血量狀態
                    return 
                end
            end
        end
        return OldNewIndex(self, key, value)
    end)

    -- 攔截 Index (修復無限遞迴卡死問題)
    OldIndex = hookmetamethod(game, "__index", function(self, key)
        if isMasterActive and not checkcaller() and typeof(self) == "Instance" then
            if self:IsA("Humanoid") then
                local char = LocalPlayer.Character
                if char and self:IsDescendantOf(char) then
                    -- 使用 OldIndex 獲取 MaxHealth，避免 self.MaxHealth 再次觸發 __index 造成當機
                    if key == "Health" then return OldIndex(self, "MaxHealth") end
                    if key == "Dead" then return false end
                end
            end
        end
        return OldIndex(self, key)
    end)
end

-- ==========================================
-- [ 啟動喪屍無敵機制 (Zombie Desync) ]
-- ==========================================
local function ApplyOneTimeSetups(char)
    if not char then return end
    local hum = char:WaitForChild("Humanoid", 3)
    
    if not isMasterActive then return end

    if hum then
        -- 1. 徹底關閉致死機制
        hum.BreakJointsOnDeath = false 
        hum.RequiresNeck = false       
        
        local badStates = {
            Enum.HumanoidStateType.Dead, Enum.HumanoidStateType.Ragdoll,
            Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Physics
        }
        for _, s in ipairs(badStates) do
            if originalStates[s] == nil then originalStates[s] = hum:GetStateEnabled(s) end
            hum:SetStateEnabled(s, false)
        end

        -- 2. 觸發伺服器欺騙 (同步 0 血量給伺服器)
        hum.Health = 0 
    end
end

LocalPlayer.CharacterAdded:Connect(function(char)
    if isMasterActive then
        task.spawn(function()
            task.wait(0.5) -- 等待角色完全載入
            ApplyOneTimeSetups(char)
        end)
    end
end)

-- ==========================================
-- [ UI 介面 ]
-- ==========================================
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'OblivionProtocolGUI'
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999999

local success, core = pcall(function() return game:GetService("CoreGui") end)
ScreenGui.Parent = success and core or LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new('Frame')
MainFrame.Name = 'MainFrame'
MainFrame.Size = UDim2.new(0, 260, 0, 100)
MainFrame.Position = UDim2.new(0.5, -130, 0.5, -50)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 10, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new('UICorner')
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

local UIStroke = Instance.new('UIStroke')
UIStroke.Color = Color3.fromRGB(0, 255, 170)
UIStroke.Thickness = 2
UIStroke.Parent = MainFrame

local TopBar = Instance.new('Frame')
TopBar.Size = UDim2.new(1, 0, 0, 30)
TopBar.BackgroundColor3 = Color3.fromRGB(20, 60, 40)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame
Instance.new('UICorner', TopBar).CornerRadius = UDim.new(0, 8)

local TopBarFix = Instance.new('Frame')
TopBarFix.Size = UDim2.new(1, 0, 0, 10)
TopBarFix.Position = UDim2.new(0, 0, 1, -10)
TopBarFix.BackgroundColor3 = Color3.fromRGB(20, 60, 40)
TopBarFix.BorderSizePixel = 0
TopBarFix.Parent = TopBar

local Title = Instance.new('TextLabel')
Title.Size = UDim2.new(1, 0, 1, 0)
Title.BackgroundTransparency = 1
Title.Text = '🛡️ ZERO-HEALTH SYNC (FIXED)'
Title.TextColor3 = Color3.fromRGB(180, 255, 220)
Title.TextSize = 13
Title.Font = Enum.Font.GothamBold
Title.Parent = TopBar

local MasterButton = Instance.new('TextButton')
MasterButton.Size = UDim2.new(1, -20, 0, 45)
MasterButton.Position = UDim2.new(0, 10, 0, 42)
MasterButton.BackgroundColor3 = Color3.fromRGB(0, 180, 120)
MasterButton.BorderSizePixel = 0
MasterButton.Text = 'ACTIVATE DESYNC'
MasterButton.TextColor3 = Color3.fromRGB(255, 255, 255)
MasterButton.TextSize = 13
MasterButton.Font = Enum.Font.GothamBold
MasterButton.Parent = MainFrame
Instance.new('UICorner', MasterButton).CornerRadius = UDim.new(0, 6)

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
-- [ 狀態切換與極簡維持迴圈 ]
-- ==========================================
local function ToggleAll()
    isMasterActive = not isMasterActive

    if isMasterActive then
        MasterButton.Text = 'DEACTIVATE'
        MasterButton.BackgroundColor3 = Color3.fromRGB(180, 40, 60)
        UIStroke.Color = Color3.fromRGB(255, 60, 80)
        TopBar.BackgroundColor3 = Color3.fromRGB(60, 20, 30)
        TopBarFix.BackgroundColor3 = Color3.fromRGB(60, 20, 30)
        Title.TextColor3 = Color3.fromRGB(255, 180, 180)
    else
        MasterButton.Text = 'ACTIVATE DESYNC'
        MasterButton.BackgroundColor3 = Color3.fromRGB(0, 180, 120)
        UIStroke.Color = Color3.fromRGB(0, 255, 170)
        TopBar.BackgroundColor3 = Color3.fromRGB(20, 60, 40)
        TopBarFix.BackgroundColor3 = Color3.fromRGB(20, 60, 40)
        Title.TextColor3 = Color3.fromRGB(180, 255, 220)
    end

    for key, conn in pairs(connections) do
        if conn then conn:Disconnect() end
    end
    connections = {}

    if isMasterActive then
        ApplyOneTimeSetups(LocalPlayer.Character)

        -- 極輕量化的監聽：只負責維持自己的 0 血量，不做其他多餘運算
        connections.MaintainZombie = RunService.Heartbeat:Connect(function()
            local hum = GetHum()
            if hum and hum.Health > 0 then
                hum.Health = 0
            end
        end)

    else
        local hum = GetHum()
        
        if hum then
            hum.RequiresNeck = true
            hum.BreakJointsOnDeath = true
            for stateType, isEnabled in pairs(originalStates) do
                hum:SetStateEnabled(stateType, isEnabled)
            end
            hum.Health = hum.MaxHealth -- 恢復滿血
        end
        originalStates = {}
    end
end

MasterButton.MouseButton1Click:Connect(ToggleAll)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed then
        if input.KeyCode == Enum.KeyCode.RightShift then
            MainFrame.Visible = not MainFrame.Visible
        end
    end
end)
