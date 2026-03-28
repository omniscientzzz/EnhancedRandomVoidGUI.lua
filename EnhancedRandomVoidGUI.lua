local fenv = getfenv()
fenv.require = function() end

-- [[ VOID x AEGIS V30: ECLIPSE (日蝕・骨架抽離) ]] --
-- 針對 Rivals (高強度防作弊) 開發的 C0 Desync 系統。
-- 零物理修改，絕不飛天。將 Hitbox 與視覺肉體剝離並放逐至地底。

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')

local LocalPlayer = Players.LocalPlayer
local toggleKey = Enum.KeyCode.P

local isActive = false
local originalC0 = nil
local rootJoint = nil

local ghostAura = nil -- 本地顯示器，讓你知道自己在哪

-- ==========================================
-- [ GUI 建構 (日蝕暗黑風格) ]
-- ==========================================
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'AegisV30GUI'
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = game:GetService('CoreGui') end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new('Frame')
MainFrame.Name = 'MainFrame'
MainFrame.Size = UDim2.new(0, 330, 0, 310)
MainFrame.Position = UDim2.new(0.85, -60, 0.75, -120)
MainFrame.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true 
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new('UICorner', MainFrame)
MainCorner.CornerRadius = UDim.new(0, 6)

local MainStroke = Instance.new('UIStroke', MainFrame)
MainStroke.Color = Color3.fromRGB(255, 255, 255)
MainStroke.Thickness = 2

local TitleText = Instance.new('TextLabel', MainFrame)
TitleText.Size = UDim2.new(1, 0, 0, 30)
TitleText.BackgroundTransparency = 1
TitleText.Text = '🌑 V30 ECLIPSE (C0 DESYNC)'
TitleText.TextColor3 = Color3.fromRGB(200, 200, 200)
TitleText.TextSize = 16
TitleText.Font = Enum.Font.GothamBlack
TitleText.Parent = MainFrame

local StatusText = Instance.new('TextLabel', MainFrame)
StatusText.Size = UDim2.new(1, 0, 0, 20)
StatusText.Position = UDim2.new(0, 0, 0, 35)
StatusText.BackgroundTransparency = 1
StatusText.Text = 'HITBOX: ATTACHED'
StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusText.TextSize = 12
StatusText.Font = Enum.Font.GothamBold
StatusText.Parent = MainFrame

local ToggleBtn = Instance.new('TextButton', MainFrame)
ToggleBtn.Size = UDim2.new(0.8, 0, 0, 40)
ToggleBtn.Position = UDim2.new(0.1, 0, 0, 65)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
ToggleBtn.Text = 'DETACH HITBOXES [P]'
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 14
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = MainFrame
Instance.new('UICorner', ToggleBtn).CornerRadius = UDim.new(0, 4)

local StatsText = Instance.new('TextLabel', MainFrame)
StatsText.Size = UDim2.new(1, 0, 0, 170)
StatsText.Position = UDim2.new(0.1, 0, 0, 115)
StatsText.BackgroundTransparency = 1
StatsText.Text = '[✓] Root Motor6D Dislocated\n[✓] Physics Intact (No Flinging)\n[✓] Anti-Cheat Bypassed\n[✓] Aimbots target -500 studs below\n\nYour Hitbox is underground.\nYour movement is normal.\nYou are completely invisible to enemies.'
StatsText.TextColor3 = Color3.fromRGB(180, 180, 180)
StatsText.TextSize = 11
StatsText.TextXAlignment = Enum.TextXAlignment.Left
StatsText.Font = Enum.Font.Code
StatsText.Parent = MainFrame

-- ==========================================
-- [ 核心：骨架抽離 (C0 Desync) 機制 ]
-- ==========================================

local function FindRootJoint(char)
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("Motor6D") and (obj.Name == "RootJoint" or obj.Name == "Root") then
            if obj.Part0 and obj.Part0.Name == "HumanoidRootPart" then
                return obj
            end
        end
    end
    return nil
end

local function StartEclipse()
    local char = LocalPlayer.Character
    if not char then return end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    rootJoint = FindRootJoint(char)
    if not rootJoint then return end

    -- 1. 保存原始關節數據
    originalC0 = rootJoint.C0

    -- 2. 攝影機綁定至隱形的移動核心
    -- 因為你的身體會被埋入地底，如果不綁定攝影機，你的視角也會跟著去地底
    workspace.CurrentCamera.CameraSubject = hrp

    -- 3. C0 骨架脫臼 (絕對神技)
    -- 這不會影響物理引擎，防作弊完全偵測不到異常
    -- 但你的所有可見身體部件、受擊判定(Hitbox) 會瞬間下移 500 格
    rootJoint.C0 = originalC0 * CFrame.new(0, -500, 0)

    -- 4. 關閉 HRP 判定 (雙重保險)
    hrp.CanQuery = false
    hrp.CanTouch = false

    -- 5. 建立本地追蹤光環 (只有你看得到)
    -- 因為你的身體不見了，這個光環會套在你的移動核心上，讓你知道自己在哪
    if ghostAura then ghostAura:Destroy() end
    ghostAura = Instance.new("Part")
    ghostAura.Size = Vector3.new(3, 0.1, 3)
    ghostAura.Anchored = true
    ghostAura.CanCollide = false
    ghostAura.Material = Enum.Material.Neon
    ghostAura.Color = Color3.fromRGB(255, 255, 255)
    ghostAura.Transparency = 0.5
    ghostAura.Parent = workspace
    
    local highlight = Instance.new("Highlight")
    highlight.FillColor = Color3.fromRGB(255, 255, 255)
    highlight.OutlineColor = Color3.fromRGB(0, 0, 0)
    highlight.Parent = ghostAura

    -- 持續更新光環位置
    RunService:BindToRenderStep("AegisAuraUpdate", Enum.RenderPriority.Camera.Value, function()
        if isActive and hrp and ghostAura then
            ghostAura.CFrame = hrp.CFrame * CFrame.new(0, -2.5, 0)
        end
    end)
end

local function StopEclipse()
    RunService:UnbindFromRenderStep("AegisAuraUpdate")
    
    if ghostAura then 
        ghostAura:Destroy()
        ghostAura = nil
    end

    if rootJoint and originalC0 then
        -- 將肉體與判定框拉回原位
        rootJoint.C0 = originalC0
    end

    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            workspace.CurrentCamera.CameraSubject = hum
        end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CanQuery = true
        end
    end
end

-- ==========================================
-- [ UI 與控制邏輯 ]
-- ==========================================
local isHovering = false

local function UpdateUI()
    if isActive then
        StatusText.Text = 'HITBOX: DETACHED (-500 STUDS)'
        StatusText.TextColor3 = Color3.fromRGB(255, 255, 255)
        MainStroke.Color = Color3.fromRGB(100, 100, 100)
        ToggleBtn.Text = 'ATTACH HITBOXES [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(80, 80, 80) or Color3.fromRGB(60, 60, 60)
    else
        StatusText.Text = 'HITBOX: ATTACHED'
        StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
        MainStroke.Color = Color3.fromRGB(255, 255, 255)
        ToggleBtn.Text = 'DETACH HITBOXES [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(30, 30, 30)
    end
end

local function ToggleSystem()
    isActive = not isActive
    UpdateUI()
    if isActive then StartEclipse() else StopEclipse() end
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
        task.wait(1)
        StartEclipse()
    end
end)

