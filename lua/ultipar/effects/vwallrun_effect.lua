sound.Add({
	name = 'wallrun.footstep.cuda',
	channel = CHAN_AUTO,
	volume = 1.0,
	level = 80,
	pitch = {95, 110},
	sound = {
        'cuda/mirrorsedge/me_footstep_concretewallrun1.wav',
        'cuda/mirrorsedge/me_footstep_concretewallrun2.wav',
        'cuda/mirrorsedge/me_footstep_concretewallrun3.wav',
        'cuda/mirrorsedge/me_footstep_concretewallrun4.wav',
        'cuda/mirrorsedge/me_footstep_concretewallrun5.wav',
        'cuda/mirrorsedge/me_footstep_concretewallrun6.wav'
    }
})

sound.Add({
	name = 'wallrun.cleanfootstep.cuda',
	channel = CHAN_AUTO,
	volume = 1.0,
	level = 80,
	pitch = {95, 110},
	sound = {
        'cuda/mirrorsedge/me_footsteps_congrete_clean_wallrun_slow_faith2.wav',
        'cuda/mirrorsedge/me_footsteps_congrete_clean_wallrun_slow_faith2.wav',
        'cuda/mirrorsedge/me_footsteps_congrete_clean_wallrun_slow_faith2.wav',
        'cuda/mirrorsedge/me_footsteps_congrete_clean_wallrun_slow_faith2.wav',
        'cuda/mirrorsedge/me_footsteps_congrete_clean_wallrun_slow_faith2.wav',
        'cuda/mirrorsedge/me_footsteps_congrete_clean_wallrun_slow_faith2.wav'
    }
})

local actionName = 'VWallRun'

local function effectstart_default(self, ply)
    if SERVER then
        ply:EmitSound(self.sound)
        timer.Create('wallrunhfoot', 0.205, 30, function() ply:EmitSound(self.sound) end)
    elseif CLIENT then
        VManip:PlayAnim(self.handanim)
    
        if VManip:GetCurrentAnim() == 'verticalwallrun' and IsValid(VManip:GetVMGesture()) then
            -- 这个动作是给全身设计的，所以原点在脚上，必须特殊处理
            VManip:GetVMGesture().RenderOverride = function(self)
                self:SetPos(EyePos() - ply:EyeAngles():Up() * 64)
                self:SetAngles(ply:EyeAngles())
            end    
        end

        UltiPar.SetVecPunchVel(self.vecpunch)
    end
end

local function effectclear_default(self, ply, _, enddata)
    if CLIENT then 
        if VManip:GetCurrentAnim() == self.handanim and IsValid(VManip:GetVMGesture()) then
            VManip:Remove()
        end

        if enddata and enddata.type == 'jump' then 
            UltiPar.SetVecPunchVel(self.vecpunchjump)
        end
    elseif SERVER then
        timer.Remove('wallrunhfoot')
        if enddata and enddata.type == 'jump' then 
            -- 跳跃结束时播放音效
            ply:EmitSound(self.soundclean)
        end
    end
end

local effect, _ = UltiPar.RegisterEffect(
    actionName, 
    'default',
    {
        handanim = 'verticalwallrun',
        label = '#default',
        sound = 'wallrun.footstep.cuda',
        soundclean = 'wallrun.cleanfootstep.cuda',
        vecpunch = Vector(0, 0, 25),
        vecpunchjump = Vector(50, 0, 25)
    }
)
effect.start = effectstart_default
effect.clear = effectclear_default

UltiPar.RegisterEffectEasy(
    actionName, 
    'SP-VManip-cuda',
    {
        handanim = 'verticalwallrun',
        label = '#vwr.SP_VManip_cuda',
        start = effectstart_default,
        clear = effectclear_default
    }
)

effectstart_default = nil
effectclear_default = nil
actionName = nil