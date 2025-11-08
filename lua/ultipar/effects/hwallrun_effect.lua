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

local actionName = 'HWallRun'

local rolloffset = 0
if CLIENT then
    hook.Add('InputMouseApply', 'hwallrun.ang.effect', function(cmd, x, y, ang)
        if not rolloffset then return end

        local origin = cmd:GetViewAngles()
    
        if math.abs(origin.roll - rolloffset) < 0.1 then
            origin.roll = rolloffset
            cmd:SetViewAngles(origin)
            rolloffset = nil
        else

            origin.roll = Lerp(FrameTime() * 5, origin.roll, rolloffset)
            cmd:SetViewAngles(origin)
        end

    end)
end

local function effectstart_default(self, ply, isright)
    if SERVER then
        ply:EmitSound(self.sound)
        timer.Create('wallrunhfoot', 0.205, 30, function() ply:EmitSound(self.sound) end)
    elseif CLIENT then
        isright = isright or 1
        local offset = isright * self.rolloffset
        if offset ~= math.huge and offset ~= -math.huge then
            rolloffset = offset
        end

        VManip:PlayAnim(self.handanim)
        UltiPar.SetVecPunchVel(self.vecpunch)
    end
end

local function effectclear_default(self, ply, endtype)
    if CLIENT then 
        rolloffset = 0
        print('fuck')
        if not endtype and VManip:GetCurrentAnim() == self.handanim and IsValid(VManip:GetVMGesture()) then
            VManip:Remove()
        end

        if endtype == 'jump' then 
            UltiPar.SetVecPunchVel(self.vecpunchjump)
        end
    elseif SERVER then
        timer.Remove('wallrunhfoot')
        if endtype == 'jump' then 
            -- 跳跃结束时播放音效
            ply:EmitSound(self.soundclean)
        end
    end
end

local effect, _ = UltiPar.RegisterEffect(
    actionName, 
    'default',
    {
        handanim = 'horizontalwallrun_YongLi',
        label = '#default',
        sound = 'wallrun.footstep.cuda',
        soundclean = 'wallrun.cleanfootstep.cuda',
        vecpunch = Vector(0, 0, 25),
        rolloffset = 10,
        vecpunchjump = Vector(50, 0, 25)
    }
)
effect.start = effectstart_default
effect.clear = effectclear_default

UltiPar.RegisterEffectEasy(
    actionName, 
    'SP-VManip-cuda',
    {
        handanim = 'horizontalwallrun_YongLi',
        label = '#wr.SP_VManip_YongLi',
        start = effectstart_default,
        clear = effectclear_default
    }
)

effectstart_default = nil
effectclear_default = nil
actionName = nil