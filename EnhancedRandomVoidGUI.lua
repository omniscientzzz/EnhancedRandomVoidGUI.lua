local fenv = getfenv()
fenv.require = function() end

-- [[ VOID x AEGIS V22: ABSOLUTE NULLIFIER (絕對無效化 Hook) ]] --
-- 防崩潰優化：加入 checkcaller() 隔離，並進行嚴格的 Type Checking
-- 新增防禦：攔截屬性賦值 (Humanoid.Health = 0) 與原生處決 (BreakJoints/TakeDamage)

local Players = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')
local LocalPlayer = Players.LocalPlayer
local toggleKey = Enum.KeyCode.P

local isActive = false
local blockedDamage = 0

-- 效能優化快取
local t_tostring = tostring
local t_typeof = typeof
local inst_IsA = game.IsA
local inst_IsDescendantOf = game.IsDescendantOf

-- ==========================================
-- [ GUI 建構 ]
-- ==========================================
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'AegisNullifierGUI'
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = game:GetService('CoreGui') end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new('Frame')
MainFrame.Name = 'MainFrame'
MainFrame.Size = UDim2.new(0, 260, 0, 150)
MainFrame.Position = UDim2.new(0.85, 0, 0.8, -100)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true 
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new('UICorner', MainFrame)
MainCorner.CornerRadius = UDim.new(0, 6)

local MainStroke = Instance.new('UIStroke', MainFrame)
MainStroke.Color = Color3.fromRGB(255, 50, 50)
MainStroke.Thickness = 2

local TitleText = Instance.new('TextLabel', MainFrame)
TitleText.Size = UDim2.new(1, 0, 0, 30)
TitleText.BackgroundTransparency = 1
TitleText.Text = '🛡️ V22 ABSOLUTE'
TitleText.TextColor3 = Color3.fromRGB(255, 100, 100)
TitleText.TextSize = 16
TitleText.Font = Enum.Font.GothamBlack
TitleText.Parent = MainFrame

local StatusText = Instance.new('TextLabel', MainFrame)
StatusText.Size = UDim2.new(1, 0, 0, 20)
StatusText.Position = UDim2.new(0, 0, 0, 30)
StatusText.BackgroundTransparency = 1
StatusText.Text = 'DEFENSE: OFFLINE'
StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusText.TextSize = 12
StatusText.Font = Enum.Font.GothamBold
StatusText.Parent = MainFrame

local BlockCountText = Instance.new('TextLabel', MainFrame)
BlockCountText.Size = UDim2.new(1, 0, 0, 20)
BlockCountText.Position = UDim2.new(0, 0, 0, 50)
BlockCountText.BackgroundTransparency = 1
BlockCountText.Text = 'Hits Nullified: 0'
BlockCountText.TextColor3 = Color3.fromRGB(200, 200, 200)
BlockCountText.TextSize = 11
BlockCountText.Font = Enum.Font.Code
BlockCountText.Parent = MainFrame

local ToggleBtn = Instance.new('TextButton', MainFrame)
ToggleBtn.Size = UDim2.new(0.8, 0, 0, 35)
ToggleBtn.Position = UDim2.new(0.1, 0, 0, 85)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(60, 20, 20)
ToggleBtn.Text = 'ENABLE [P]'
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 14
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = MainFrame
Instance.new('UICorner', ToggleBtn).CornerRadius = UDim.new(0, 4)

-- ==========================================
-- [ 輔助函數：確認是否為玩家角色組件 ]
-- ==========================================
local function IsLocalCharacter(obj)
    local char = LocalPlayer.Character
    if not char then return false end
    if obj == char then return true end
    return inst_IsDescendantOf(obj, char)
end

-- ==========================================
-- [ 核心：雙重極限防禦 Hook ]
-- ==========================================
if not hookmetamethod then
    BlockCountText.Text = "ERROR: Executor not supported"
else
    -- 🛡️ 第一層：攔截函數呼叫 (__namecall)
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        if isActive and not checkcaller() then
            local method = getnamecallmethod()
            
            -- [防禦 1] 攔截本地端的直接致死函數 (TakeDamage, BreakJoints, Destroy)
            if method == "TakeDamage" or method == "BreakJoints" then
                if t_typeof(self) == "Instance" and IsLocalCharacter(self) then
                    blockedDamage = blockedDamage + 1
                    BlockCountText.Text = 'Hits Nullified: ' .. t_tostring(blockedDamage)
                    return nil -- 吞噬致死/扣血指令，讓它完全不執行
                end
            end
            
            -- [防禦 2] 攔截試圖將你的角色當作參數傳送出去的封包 (向伺服器回報受擊)
            if method == "FireServer" or method == "InvokeServer" then
                local args = {...}
                for i = 1, #args do
                    if t_typeof(args[i]) == "Instance" and IsLocalCharacter(args[i]) then
                        blockedDamage = blockedDamage + 1
                        BlockCountText.Text = 'Hits Nullified: ' .. t_tostring(blockedDamage)
                        return nil -- 拒絕向伺服器發送包含你身體的封包
                    end
                end
            end
        end
        return oldNamecall(self, ...)
    end)

    -- 🛡️ 第二層：攔截屬性修改 (__newindex) -> 最強的防扣血手段
    local oldNewIndex
    oldNewIndex = hookmetamethod(game, "__newindex", function(self, index, value)
        if isActive and not checkcaller() then
            -- [防禦 3] 攔截遊戲腳本直接強制修改你的血量 (例如: Humanoid.Health = 0)
            if index == "Health" then
                if t_typeof(self) == "Instance" and inst_IsA(self, "Humanoid") and IsLocalCharacter(self) then
                    -- 檢查如果企圖把血量改低，就直接拒絕這次賦值
                    if t_typeof(value) == "number" and value < self.Health then
                        blockedDamage = blockedDamage + 1
                        BlockCountText.Text = 'Hits Nullified: ' .. t_tostring(blockedDamage)
                        return nil -- 吞噬賦值動作，血量鎖定
                    end
                end
            end
        end
        return oldNewIndex(self, index, value)
    end)
end

-- ==========================================
-- [ 控制邏輯 ]
-- ==========================================
local isHovering = false

local function UpdateUI()
    if isActive then
        StatusText.Text = 'DEFENSE: ONLINE (GOD)'
        StatusText.TextColor3 = Color3.fromRGB(255, 50, 50)
        MainStroke.Color = Color3.fromRGB(255, 50, 50)
        ToggleBtn.Text = 'DISABLE [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(120, 30, 30) or Color3.fromRGB(100, 20, 20)
    else
        StatusText.Text = 'DEFENSE: OFFLINE'
        StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
        MainStroke.Color = Color3.fromRGB(100, 100, 100)
        ToggleBtn.Text = 'ENABLE [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(80, 40, 40) or Color3.fromRGB(60, 20, 20)
    end
end

ToggleBtn.MouseEnter:Connect(function() isHovering = true UpdateUI() end)
ToggleBtn.MouseLeave:Connect(function() isHovering = false UpdateUI() end)
ToggleBtn.MouseButton1Click:Connect(function()
    isActive = not isActive
    UpdateUI()
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == toggleKey then
        isActive = not isActive
        UpdateUI()
    end
end)
