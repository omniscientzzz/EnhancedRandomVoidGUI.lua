local fenv = getfenv()
fenv.require = function() end

-- [[ VOID x AEGIS V33: SANCTUARY (神域・絕對零質量脫軌) ]] --
-- 終極對策：將所有肉體與 Hitbox 轉移至 50,000 單位外的虛空，
-- 並徹底剝奪其物理質量 (Massless) 與碰撞，完美解決「飛天」與「全圖秒殺」問題。
-- 防作弊 (RAC) 完全無法察覺，因為你的移動核心 (HRP) 依舊在原地合法行走。

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')

local LocalPlayer = Players.LocalPlayer
local toggleKey = Enum.KeyCode.P

local isActive = false
local originalC0 = nil
local rootJoint = nil
local originalProperties = {}

local ghostAura = nil

-- ==========================================
-- [ GUI 建構 (神域純白風格) ]
-- ==========================================
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'AegisV33GUI'
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = game:GetService('CoreGui') end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new('Frame')
MainFrame.Name = 'MainFrame'
MainFrame.Size = UDim2.new(0, 340, 0, 330)
MainFrame.Position = UDim2.new(0.85, -60, 0.75, -120)
MainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true 
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new('UICorner', MainFrame)
MainCorner.CornerRadius = UDim.new(0, 6)

local MainStroke = Instance.new('UIStroke', MainFrame)
MainStroke.Color = Color3.fromRGB(255, 255, 255)
MainStroke.Thickness = 3

local TitleText = Instance.new('TextLabel', MainFrame)
TitleText.Size = UDim2.new(1, 0, 0, 30)
TitleText.BackgroundTransparency = 1
TitleText.Text = '💠 V33 SANCTUARY'
TitleText.TextColor3 = Color3.fromRGB(220, 220, 255)
TitleText.TextSize = 18
TitleText.Font = Enum.Font.GothamBlack
TitleText.Parent = MainFrame

local StatusText = Instance.new('TextLabel', MainFrame)
StatusText.Size = UDim2.new(1, 0, 0, 20)
StatusText.Position = UDim2.new(0, 0, 0, 35)
StatusText.BackgroundTransparency = 1
StatusText.Text = 'DIMENSION: REALITY'
StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusText.TextSize = 12
StatusText.Font = Enum.Font.GothamBold
StatusText.Parent = MainFrame

local ToggleBtn = Instance.new('TextButton', MainFrame)
ToggleBtn.Size = UDim2.new(0.8, 0, 0, 40)
ToggleBtn.Position = UDim2.new(0.1, 0, 0, 65)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
ToggleBtn.Text = 'SHIFT DIMENSION [P]'
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 14
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = MainFrame
Instance.new('UICorner', ToggleBtn).CornerRadius = UDim.new(0, 4)

local StatsText = Instance.new('TextLabel', MainFrame)
StatsText.Size = UDim2.new(1, 0, 0, 200)
StatsText.Position = UDim2.new(0.1, 0, 0, 115)
StatsText.BackgroundTransparency = 1
StatsText.Text = '[✓] 50,000 Studs C0 Dislocation\n[✓] Zero-Mass Physics (Anti-Fling)\n[✓] Collision Matrix Erased\n[✓] RAC Anti-Cheat Compliant\n\nYour Hitbox is now 50,000 studs away.\nIt has no mass. It cannot be pushed.\nMap-wide AoE will explode on the battlefield,\nbut you are no longer there.'
StatsText.TextColor3 = Color3.fromRGB(200, 200, 220)
StatsText.TextSize = 11
StatsText.TextXAlignment = Enum.TextXAlignment.Left
StatsText.Font = Enum.Font.Code
StatsText.Parent = MainFrame

-- ==========================================
-- [ 核心：零質量神域脫軌機制 ]
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

local function StartSanctuary()
    local char = LocalPlayer.Character
    if not char then return end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    rootJoint = FindRootJoint(char)
    if not rootJoint then return end

    -- 1. 保存原始狀態
    originalC0 = rootJoint.C0
    originalProperties = {}

    -- 2. 攝影機綁定至移動核心
    workspace.CurrentCamera.CameraSubject = hrp

    -- 3. 抽乾物理質量與碰撞 (這是防止「飛天/Fling」的絕對關鍵)
    -- 我們將除了 HRP 以外的所有身體部件，設定為無質量、無碰撞、無摩擦力
    local zeroFriction = PhysicalProperties.new(0, 0, 0, 0, 0)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            originalProperties[part] = {
                Massless = part.Massless,
                CanCollide = part.CanCollide,
                CustomPhysicalProperties = part.CustomPhysicalProperties
            }
            part.Massless = true
            part.CanCollide = false
            part.CustomPhysicalProperties = zeroFriction
        end
    end

    -- 4. 絕對放逐 (50,000 格外的虛空)
    -- 這足以避開任何「全圖範圍秒殺」外掛的攻擊半徑
    local voidOffset = CFrame.new(50000, -50000, 50000)
    rootJoint.C0 = originalC0 * voidOffset

    -- 5. 建立本地追蹤光環 (讓你能在戰場上精準走位)
    if ghostAura then ghostAura:Destroy() end
    ghostAura = Instance.new("Part")
    ghostAura.Size = Vector3.new(3, 0.1, 3)
    ghostAura.Anchored = true
    ghostAura.CanCollide = false
    ghostAura.Material = Enum.Material.ForceField
    ghostAura.Color = Color3.fromRGB(200, 220, 255)
    ghostAura.Parent = workspace
    
    local highlight = Instance.new("Highlight")
    highlight.FillColor = Color3.fromRGB(200, 220, 255)
    highlight.OutlineColor = Color3.fromRGB(0, 50, 150)
    highlight.Parent = ghostAura

    RunService:BindToRenderStep("AegisSanctuaryUpdate", Enum.RenderPriority.Camera.Value, function()
        if isActive and hrp and ghostAura then
            -- 光環會緊緊跟隨你真正的移動核心
            ghostAura.CFrame = hrp.CFrame * CFrame.new(0, -2.5, 0)
        end
    end)
end

local function StopSanctuary()
    RunService:UnbindFromRenderStep("AegisSanctuaryUpdate")
    
    if ghostAura then 
        ghostAura:Destroy()
        ghostAura = nil
    end

    if rootJoint and originalC0 then
        rootJoint.C0 = originalC0
    end

    -- 恢復物理屬性
    for part, props in pairs(originalProperties) do
        if part and part.Parent then
            part.Massless = props.Massless
            part.CanCollide = props.CanCollide
            part.CustomPhysicalProperties = props.CustomPhysicalProperties
        end
    end
    originalProperties = {}

    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then workspace.CurrentCamera.CameraSubject = hum end
    end
end

-- ==========================================
-- [ UI 與控制邏輯 ]
-- ==========================================
local isHovering = false

local function UpdateUI()
    if isActive then
        StatusText.Text = 'DIMENSION: VOID (50k STUDS)'
        StatusText.TextColor3 = Color3.fromRGB(255, 255, 255)
        MainStroke.Color = Color3.fromRGB(150, 150, 255)
        ToggleBtn.Text = 'RETURN TO REALITY [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(80, 80, 120) or Color3.fromRGB(60, 60, 100)
    else
        StatusText.Text = 'DIMENSION: REALITY'
        StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
        MainStroke.Color = Color3.fromRGB(255, 255, 255)
        ToggleBtn.Text = 'SHIFT DIMENSION [P]'
        ToggleBtn.BackgroundColor3 = isHovering and Color3.fromRGB(60, 60, 70) or Color3.fromRGB(40, 40, 50)
    end
end

local function ToggleSystem()
    isActive = not isActive
    UpdateUI()
    if isActive then StartSanctuary() else StopSanctuary() end
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
        StartSanctuary()
    end
end)

