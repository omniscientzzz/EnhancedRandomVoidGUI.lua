local fenv = getfenv()
fenv.require = function() end

-- [[ VOID x AEGIS V35: DEUS (神之領域・底層協議駭入) ]] --
-- 拋棄物理防禦，直接攔截與竄改 Roblox 底層 Metatable 封包。
-- 包含：網路傷害封包銷毀、護盾判定強制重定向 (真傷穿甲)、血量記憶體鎖死。

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')

local LocalPlayer = Players.LocalPlayer
local toggleKey = Enum.KeyCode.P

local isActive = false
local connections = {}

-- ==========================================
-- [ GUI 建構 (神之領域・暗金代碼風格) ]
-- ==========================================
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'AegisV35GUI'
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = game:GetService('CoreGui') end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new('Frame')
MainFrame.Name = 'MainFrame'
MainFrame.Size = UDim2.new(0, 340, 0, 340)
MainFrame.Position = UDim2.new(0.85, -60, 0.75, -140)
MainFrame.BackgroundColor3 = Color3.fromRGB(10, 5, 5)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true 
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new('UICorner', MainFrame)
MainCorner.CornerRadius = UDim.new(0, 6)

local MainStroke = Instance.new('UIStroke', MainFrame)
MainStroke.Color = Color3.fromRGB(255, 180, 0)
MainStroke.Thickness = 2

local TitleText = Instance.new('TextLabel', MainFrame)
TitleText.Size = UDim2.new(1, 0, 0, 30)
TitleText.BackgroundTransparency = 1
TitleText.Text = '👑 V35 DEUS (PROTOCOL HOOK)'
TitleText.TextColor3 = Color3.fromRGB(255, 215, 0)
TitleText.TextSize = 16
TitleText.Font = Enum.Font.GothamBlack
TitleText.Parent = MainFrame

local StatusText = Instance.new('TextLabel', MainFrame)
StatusText.Size = UDim2.new(1, 0, 0, 20)
StatusText.Position = UDim2.new(0, 0, 0, 35)
StatusText.BackgroundTransparency = 1
StatusText.Text = 'METATABLE: SECURE'
StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusText.TextSize = 12
StatusText.Font = Enum.Font.GothamBold
StatusText.Parent = MainFrame

local ToggleBtn = Instance.new('TextButton', MainFrame)
ToggleBtn.Size = UDim2.new(0.8, 0, 0, 40)
ToggleBtn.Position = UDim2.new(0.1, 0, 0, 65)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(40, 20, 0)
ToggleBtn.Text = 'OVERRIDE PROTOCOLS [P]'
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 14
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = MainFrame
Instance.new('UICorner', ToggleBtn).CornerRadius = UDim.new(0, 4)

local StatsText = Instance.new('TextLabel', MainFrame)
StatsText.Size = UDim2.new(1, 0, 0, 210)
StatsText.Position = UDim2.new(0.1, 0, 0, 115)
StatsText.BackgroundTransparency = 1
StatsText.Text = '[✓] __namecall Hooked (Packet Intercept)\n[✓] Outgoing Hits Rerouted to Head\n[✓] Shield Raycast Query Bypassed\n[✓] Incoming Damage Packets Dropped\n[✓] __newindex Health Locked\n\nPhysics evasion abandoned.\nWe are now hacking the network traffic.\nYour attacks pierce all shields.\nYou cannot be killed by code.'
StatsText.TextColor3 = Color3.fromRGB(255, 200, 100)
StatsText.TextSize = 11
StatsText.TextXAlignment = Enum.TextXAlignment.Left
StatsText.Font = Enum.Font.Code
StatsText.Parent = MainFrame

-- ==========================================
-- [ 核心 1：記憶體與網路協議駭入 (Metatable Hooking) ]
-- ==========================================
-- 這是 Roblox 漏洞利用的最高境界，直接接管遊戲的底層函數。

local mt = getrawmetatable(game)
local oldNamecall = mt.__namecall
local oldNewindex = mt.__newindex
setreadonly(mt, false)

-- 攔截所有網路封包與方法調用
mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    local remoteName = string.lower(self.Name)

    if isActive then
        -- [防禦] 攔截「承受傷害」的網路封包
        if method == "FireServer" or method == "InvokeServer" then
            if remoteName:match("damage") or remoteName:match("hit") or remoteName:match("hurt") or remoteName:match("take") then
                -- 檢查這個封包是不是要對「我們」造成傷害
                for _, arg in pairs(args) do
                    if arg == LocalPlayer or arg == LocalPlayer.Character or (typeof(arg) == "Instance" and arg:IsDescendantOf(LocalPlayer.Character)) then
                        -- 發現扣血指令！直接吃掉這個封包，伺服器將永遠收不到你受傷的訊息。
                        return 
                    end
                end
            end
        end

        -- [進攻] 護盾穿透與強制爆頭 (Packet Reroute)
        -- 當你打中敵人的盾牌，你的客戶端會發送「我打中盾牌了」給伺服器。
        -- 我們在這裡攔截它，把封包裡的「盾牌」強行改成「敵人的頭」。
        if method == "FireServer" or method == "InvokeServer" then
            if remoteName:match("hit") or remoteName:match("damage") or remoteName:match("shoot") or remoteName:match("projectile") then
                for i, arg in pairs(args) do
                    if typeof(arg) == "Instance" and arg:IsA("BasePart") then
                        local argName = string.lower(arg.Name)
                        -- 偵測到打中的是護盾/裝甲
                        if argName:match("shield") or argName:match("armor") or argName:match("barrier") or argName:match("forcefield") then
                            local enemyChar = arg.Parent
                            if enemyChar and enemyChar:FindFirstChild("Head") then
                                -- 竄改封包：將命中的目標替換為敵人的頭部！
                                args[i] = enemyChar.Head
                            end
                        end
                    end
                end
                -- 放行已經被我們竄改過的封包
                return oldNamecall(self, unpack(args))
            end
        end

        -- [防禦] 封鎖本地的強制扣血指令
        if method == "TakeDamage" and typeof(self) == "Instance" and self:IsDescendantOf(LocalPlayer.Character) then
            return -- 拒絕執行 TakeDamage
        end
    end

    return oldNamecall(self, ...)
end)

-- 記憶體鎖死：無論遊戲怎麼嘗試修改你的血量，強制鎖回滿血
mt.__newindex = newcclosure(function(t, k, v)
    if isActive and typeof(t) == "Instance" and t:IsA("Humanoid") and t:IsDescendantOf(LocalPlayer.Character) then
        if k == "Health" then
            -- 拒絕扣血，永遠返回 MaxHealth
            return oldNewindex(t, k, t.MaxHealth)
        end
    end
    return oldNewindex(t, k, v)
end)

setreadonly(mt, true)

-- ==========================================
-- [ 核心 2：物理層面護盾穿透與 AoE 清理 ]
-- ==========================================
local function PhysicalOverrides()
    -- 1. 讓你的子彈/射線直接穿過敵人的盾牌 (CanQuery = false)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            for _, obj in ipairs(player.Character:GetDescendants()) do
                if obj:IsA("BasePart") then
                    local name = obj.Name:lower()
                    if name:match("shield") or name:match("armor") or name:match("barrier") then
                        pcall(function()
                            obj.CanCollide = false
                            obj.CanQuery = false -- 你的射線/投擲物判定會直接穿透它
                            obj.CanTouch = false
                            obj.Transparency = 1
                        end)
                    end
                end
            end
        end
    end

    -- 2. 清理全圖巨大的光球，防止干擾視線與產生錯誤排斥力
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Size.Magnitude > 15 and not obj:IsDescendantOf(LocalPlayer.Character) and not obj:IsDescendantOf(workspace.Terrain) then
            pcall(function()
                obj.CanCollide = false
                obj.CanQuery = false
                obj.CanTouch = false
                obj.Transparency = 1
                obj.Size = Vector3.new(0.01, 0.01, 0.01)
                obj.AssemblyLinearVelocity = Vector3.zero
            end)
        end
    end
end

local function StartDeus()
    -- 啟動物理覆寫迴圈
    local loop = RunService.Heartbeat:Connect(function()
        if not isActive then return end
        PhysicalOverrides()
        
        -- 強制解除死亡狀態 (Zombie Mode)
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                if hum:GetState() == Enum.HumanoidStateType.Dead then
                    hum:ChangeState(Enum.HumanoidStateType.Running)
                end
                hum.Health = hum.MaxHealth
            end
        end
    end)
    table.insert(connections, loop)
end

local function StopDeus()
    for _, conn in ipairs(connections) do
        conn:Disconnect()
    end
    connections = {}
end

-- ==========================================
-- [ UI 與控制邏輯 ]
-- ==========================================
local isHovering = false

local function UpdateUI()
    if isActive then
        StatusText.Text = 'PROTOCOLS: OVERRIDDEN'
        StatusText.TextColor3 = Color3.fromRGB(255, 215, 0)
        MainStroke.Color = Color3.fromRGB(255, 215, 0)
        ToggleBtn.Text = 'RESTORE PROTOCOLS [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(120, 80, 0) or Color3.fromRGB(80, 50, 0)
    else
        StatusText.Text = 'METATABLE: SECURE'
        StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
        MainStroke.Color = Color3.fromRGB(255, 180, 0)
        ToggleBtn.Text = 'OVERRIDE PROTOCOLS [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(60, 30, 0) or Color3.fromRGB(40, 20, 0)
    end
end

local function ToggleSystem()
    isActive = not isActive
    UpdateUI()
    if isActive then StartDeus() else StopDeus() end
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
        task.wait(0.5)
        StartDeus()
    end
end)

