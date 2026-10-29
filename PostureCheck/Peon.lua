local _, ns = ...

-- The Lazy Peon from Durotar, rendered with the game's own 3D model. As
-- posture gets worse he goes from working, to standing around, to sitting,
-- to asleep, and finally he is replaced by a sack.

local PEON_DISPLAY_ID = 10038   -- Lazy Peon (NPC 10556)
local SACK_FILE_ID = 199745     -- world/generic/passivedoodads/furniture/containers/sack01.m2
local WIDTH, HEIGHT = 80, 96
local FACING = 0.6              -- radians; a three-quarter view
local SACK_FACING = 0.4

-- Stages from best to worst posture. Each lists animation IDs to try in
-- order, since not every model has every animation.
local STAGES = {
    { upTo = 0.35, anims = { 136, 0 } },   -- EmoteWorkNoSheathe, Stand
    { upTo = 0.6,  anims = { 0 } },        -- Stand
    { upTo = 0.75, anims = { 97, 0 } },    -- SitGround
    { upTo = 0.9,  anims = { 100, 97 } },  -- Sleep, SitGround
}
local SACK_STAGE = #STAGES + 1

local function PickAnimation(model, anims)
    for _, id in ipairs(anims) do
        if not model.HasAnimation or model:HasAnimation(id) then
            return id
        end
    end
    return 0
end

function ns.CreatePeon(parent)
    local model = CreateFrame("PlayerModel", nil, parent)
    model:SetSize(WIDTH, HEIGHT)

    local peon = { frame = model }

    local function Apply()
        local stage = STAGES[peon.stage]
        if stage then
            model:SetFacing(FACING)
            model:SetAnimation(PickAnimation(model, stage.anims))
        else
            model:SetFacing(SACK_FACING)
        end
    end

    local function Load()
        if not peon.stage then return end
        model:ClearModel()
        if peon.stage == SACK_STAGE then
            model:SetModel(SACK_FILE_ID)
        else
            model:SetDisplayInfo(PEON_DISPLAY_ID)
        end
        Apply()
    end

    -- Models lose their animation when hidden, and HasAnimation only answers
    -- once the model has loaded, so re-apply at both points.
    if model:HasScript("OnModelLoaded") then
        model:SetScript("OnModelLoaded", Apply)
    end
    model:SetScript("OnShow", Load)

    function peon:SetHunch(amount)
        local stage = SACK_STAGE
        for i, s in ipairs(STAGES) do
            if amount < s.upTo then
                stage = i
                break
            end
        end
        if stage == self.stage then return end

        local swapModel = not self.stage or (self.stage == SACK_STAGE) ~= (stage == SACK_STAGE)
        self.stage = stage
        if swapModel then Load() else Apply() end
    end

    return peon
end
