AddCSLuaFile()

local author = 'YongLi'
local model = 'weapons/horizontalwallrun_YongLi.mdl'
local anim = 'horizontalwallrun_YongLi'
VManip:RegisterAnim(anim,
    {
        ['model']=model,
        ['lerp_peak']=0.45,
        ['lerp_speed_in']=2,
        ['lerp_speed_out']=0.5,
        ['lerp_curve']=0.8,
        ['speed']=1.2
    }
)

anim = nil
model = nil
author = nil
