local fenv = getfenv()
fenv.require = function() end

-- [[ VOID x AEGIS V21: FIREWALL (獨立協議攔截防禦) ]] --
-- 極致優化的 hookmetamethod，不影響幀數、不閃退
-- 專門防禦「客戶端強制回報死亡/扣血」以及「管理員遠端踢出/處罰」

local Players = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')
local LocalPlayer = Players.LocalPlayer
local toggleKey = Enum.KeyCode.P

local isActive = false
local blockedCount = 0

-- 效能優化：將常用函數快取到本地變數，減少 Global 尋址時間
local s_lower = string.lower
local s_find = string.find
local t_tostring = tostring
local t_typeof = typeof
local inst_IsA = game.IsA

-- ==========================================
-- [ GUI 建構 ]
-- ==========================================
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'AegisFirewallGUI'
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = game:GetService('CoreGui') end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new('Frame')
MainFrame.Name = 'MainFrame'
MainFrame.Size = UDim2.new(0, 260, 0, 150)
MainFrame.Position = UDim2.new(0.85, 0, 0.8, -100)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 20, 25)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true 
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new('UICorner', MainFrame)
MainCorner.CornerRadius = UDim.new(0, 6)

local MainStroke = Instance.new('UIStroke', MainFrame)
MainStroke.Color = Color3.fromRGB(0, 150, 255)
MainStroke.Thickness = 2

local TitleText = Instance.new('TextLabel', MainFrame)
TitleText.Size = UDim2.new(1, 0, 0, 30)
TitleText.BackgroundTransparency = 1
TitleText.Text = '🛡️ AEGIS FIREWALL'
TitleText.TextColor3 = Color3.fromRGB(100, 200, 255)
TitleText.TextSize = 16
TitleText.Font = Enum.Font.GothamBlack
TitleText.Parent = MainFrame

local StatusText = Instance.new('TextLabel', MainFrame)
StatusText.Size = UDim2.new(1, 0, 0, 20)
StatusText.Position = UDim2.new(0, 0, 0, 30)
StatusText.BackgroundTransparency = 1
StatusText.Text = 'FIREWALL: OFFLINE'
StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusText.TextSize = 12
StatusText.Font = Enum.Font.GothamBold
StatusText.Parent = MainFrame

local BlockCountText = Instance.new('TextLabel', MainFrame)
BlockCountText.Size = UDim2.new(1, 0, 0, 20)
BlockCountText.Position = UDim2.new(0, 0, 0, 50)
BlockCountText.BackgroundTransparency = 1
BlockCountText.Text = 'Blocked Packets: 0'
BlockCountText.TextColor3 = Color3.fromRGB(200, 200, 200)
BlockCountText.TextSize = 11
BlockCountText.Font = Enum.Font.Code
BlockCountText.Parent = MainFrame

local ToggleBtn = Instance.new('TextButton', MainFrame)
ToggleBtn.Size = UDim2.new(0.8, 0, 0, 35)
ToggleBtn.Position = UDim2.new(0.1, 0, 0, 85)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(20, 40, 60)
ToggleBtn.Text = 'ENABLE [P]'
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 14
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = MainFrame
Instance.new('UICorner', ToggleBtn).CornerRadius = UDim.new(0, 4)

-- ==========================================
-- [ 惡意關鍵字字典 ]
-- ==========================================
local blacklistWords = {
    "kill", "damage", "die", "dead", "hit", "punish", 
    "kick", "ban", "crash", "fling", "takedamage", "health"
}

local function IsMaliciousString(str)
    local lowerStr = s_lower(str)
    for i = 1, #blacklistWords do
        if s_find(lowerStr, blacklistWords[i]) then
            return true
        end
    end
    return false
end

-- ==========================================
-- [ 核心：極限效能 Hook ]
-- ==========================================
if not hookmetamethod then
    BlockCountText.Text = "ERROR: Executor doesn't support hookmetamethod"
    BlockCountText.TextColor3 = Color3.fromRGB(255, 50, 50)
else
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        if not isActive then return oldNamecall(self, ...) end

        local method = getnamecallmethod()
        
        -- [熱路徑優化] 1. 只有發送給伺服器的封包才檢查
        if method == "FireServer" or method == "InvokeServer" then
            
            -- [熱路徑優化] 2. 確保 self 是 Instance，防止底層 C++ 報錯
            if t_typeof(self) == "Instance" and (inst_IsA(self, "RemoteEvent") or inst_IsA(self, "RemoteFunction")) then
                
                -- 攔截 1：檢查 Remote 的名稱
                if IsMaliciousString(self.Name) then
                    blockedCount = blockedCount + 1
                    BlockCountText.Text = 'Blocked Packets: ' .. t_tostring(blockedCount)
                    return nil -- 吞噬封包
                end
                
                -- 攔截 2：深度掃描參數 (防止遊戲將擊殺指令藏在參數中)
                local args = {...}
                for i = 1, #args do
                    local argType = t_typeof(args[i])
                    
                    -- 檢查字串參數 (例如 FireServer("TakeDamage", 100))
                    if argType == "string" then
                        if IsMaliciousString(args[i]) then
                            blockedCount = blockedCount + 1
                            BlockCountText.Text = 'Blocked Packets: ' .. t_tostring(blockedCount)
                            return nil 
                        end
                    -- 檢查是否試圖傳送我們的 Humanoid (例如回報受擊對象)
                    elseif argType == "Instance" then
                        if args[i] == LocalPlayer or (LocalPlayer.Character and args[i]:IsDescendantOf(LocalPlayer.Character)) then
                            -- 如果封包裡包含了「我」或「我的身體部位」，極有可能是傷害判定回報
                            blockedCount = blockedCount + 1
                            BlockCountText.Text = 'Blocked Target Packets: ' .. t_tostring(blockedCount)
                            return nil
                        end
                    end
                end
            end
        end

        return oldNamecall(self, ...)
    end)
end

-- ==========================================
-- [ 控制邏輯 ]
-- ==========================================
local isHovering = false

local function UpdateUI()
    if isActive then
        StatusText.Text = 'FIREWALL: ONLINE (BLOCKING)'
        StatusText.TextColor3 = Color3.fromRGB(0, 200, 255)
        MainStroke.Color = Color3.fromRGB(0, 200, 255)
        ToggleBtn.Text = 'DISABLE [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(30, 80, 120) or Color3.fromRGB(20, 60, 100)
    else
        StatusText.Text = 'FIREWALL: OFFLINE'
        StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
        MainStroke.Color = Color3.fromRGB(100, 100, 100)
        ToggleBtn.Text = 'ENABLE [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(40, 60, 80) or Color3.fromRGB(20, 40, 60)
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
