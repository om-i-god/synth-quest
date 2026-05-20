// Engine_SynthQuest.sc
// Synth Quest — JRPG with synth-based party
// v0.2 — adds per-voice extra_wet (left stick Y) and delay_amt (left stick X)

Engine_SynthQuest : CroneEngine {
	var <sq_mage, <sq_cleric, <sq_warrior, <sq_bard, <sq_drone, <sq_wraith;

	*new { arg context, doneCallback;
		^super.new(context, doneCallback);
	}

	alloc {
		// MAGE — 2-op FM bell
		SynthDef(\sq_mage, {
			arg out=0, freq=440, amp=0.28, amp_mul=1,
			    mod_index=2, mod_ratio=2,
			    cutoff=2200, resonance=0.3,
			    env_attack=0.005, env_release=0.55,
			    wet=0, extra_wet=0, delay_amt=0, delay_time=0.375,
			    room=0.88, damp=0.35,
			    t_trig=0;
			var env, mod, car, sig, dry, rev, extra_rev, del, rclip, dclip;
			env = EnvGen.kr(Env.perc(env_attack, env_release, 1, -4), t_trig);
			mod = SinOsc.ar(freq * mod_ratio) * mod_index * freq * env;
			car = SinOsc.ar(freq + mod);
			sig = car * env * amp * amp_mul;
			sig = RLPF.ar(sig, cutoff.clip(40, 18000), resonance.clip(0.05, 0.95));
			rclip = room.clip(0, 0.99);
			dclip = damp.clip(0, 1);
			dry = sig;
			rev = FreeVerb.ar(sig, 1, rclip, dclip);
			sig = (dry * (1 - wet)) + (rev * wet);
			extra_rev = FreeVerb.ar(sig, 1, (rclip + 0.04).clip(0, 0.99), (dclip + 0.05).clip(0, 1));
			sig = sig + (extra_rev * extra_wet * 1.6);
			del = CombC.ar(sig, 2.0, delay_time.clip(0.001, 2.0), 1.5);
			sig = sig + (del * delay_amt * 1.3);
			Out.ar(out, sig.dup);
		}).add;

		// CLERIC — triangle pad with chorus
		SynthDef(\sq_cleric, {
			arg out=0, freq=220, amp=0.22, amp_mul=1,
			    cutoff=1600, resonance=0.2,
			    env_attack=0.06, env_release=1.4,
			    detune=0.005, wet=0, extra_wet=0, delay_amt=0, delay_time=0.5,
			    room=0.92, damp=0.40,
			    t_trig=0;
			var env, sig, chorus, dry, rev, extra_rev, del, rclip, dclip;
			env = EnvGen.kr(Env.perc(env_attack, env_release, 1, -3), t_trig);
			sig = LFTri.ar(freq) + (LFTri.ar(freq * (1 + detune)) * 0.7);
			chorus = DelayC.ar(sig, 0.05,
				SinOsc.kr(0.3).range(0.005, 0.012));
			sig = (sig + chorus) * 0.4;
			sig = RLPF.ar(sig, cutoff.clip(40, 18000), resonance.clip(0.05, 0.95));
			sig = sig * env * amp * amp_mul;
			rclip = room.clip(0, 0.99);
			dclip = damp.clip(0, 1);
			dry = sig;
			rev = FreeVerb.ar(sig, 1, rclip, dclip);
			sig = (dry * (1 - wet)) + (rev * wet);
			extra_rev = FreeVerb.ar(sig, 1, (rclip + 0.02).clip(0, 0.99), (dclip + 0.05).clip(0, 1));
			sig = sig + (extra_rev * extra_wet * 1.6);
			del = CombC.ar(sig, 2.0, delay_time.clip(0.001, 2.0), 2.0);
			sig = sig + (del * delay_amt * 1.3);
			Out.ar(out, sig.dup);
		}).add;

		// WARRIOR — pulse + sub, punchy
		SynthDef(\sq_warrior, {
			arg out=0, freq=110, amp=0.3, amp_mul=1,
			    cutoff=1300, resonance=0.4,
			    env_attack=0.003, env_release=0.22,
			    wet=0, extra_wet=0, delay_amt=0, delay_time=0.375,
			    room=0.85, damp=0.50,
			    t_trig=0;
			var env, sig, sub, dry, rev, extra_rev, del, rclip, dclip;
			env = EnvGen.kr(Env.perc(env_attack, env_release, 1, -6), t_trig);
			sig = Pulse.ar(freq, 0.5);
			sub = SinOsc.ar(freq * 0.5) * 0.6;
			sig = (sig + sub) * 0.5;
			sig = RLPF.ar(sig, cutoff.clip(40, 18000), resonance.clip(0.05, 0.95));
			sig = sig * env * amp * amp_mul;
			rclip = room.clip(0, 0.99);
			dclip = damp.clip(0, 1);
			dry = sig;
			rev = FreeVerb.ar(sig, 1, rclip, dclip);
			sig = (dry * (1 - wet)) + (rev * wet);
			extra_rev = FreeVerb.ar(sig, 1, (rclip + 0.05).clip(0, 0.99), dclip);
			sig = sig + (extra_rev * extra_wet * 1.6);
			del = CombC.ar(sig, 2.0, delay_time.clip(0.001, 2.0), 1.0);
			sig = sig + (del * delay_amt * 1.3);
			Out.ar(out, sig.dup);
		}).add;

		// BARD — wavetable scan
		SynthDef(\sq_bard, {
			arg out=0, freq=330, amp=0.26, amp_mul=1,
			    wt_pos=0,
			    cutoff=2200, resonance=0.5,
			    env_attack=0.012, env_release=0.5,
			    wet=0, extra_wet=0, delay_amt=0, delay_time=0.375,
			    room=0.90, damp=0.40,
			    t_trig=0;
			var env, sig, sine, saw, dry, rev, extra_rev, del, rclip, dclip;
			env = EnvGen.kr(Env.perc(env_attack, env_release, 1, -4), t_trig);
			sine = SinOsc.ar(freq);
			saw = LFSaw.ar(freq) * 0.7;
			sig = XFade2.ar(sine, saw, wt_pos.clip(-1, 1));
			sig = RLPF.ar(sig, cutoff.clip(40, 18000), resonance.clip(0.05, 0.95));
			sig = sig * env * amp * amp_mul;
			rclip = room.clip(0, 0.99);
			dclip = damp.clip(0, 1);
			dry = sig;
			rev = FreeVerb.ar(sig, 1, rclip, dclip);
			sig = (dry * (1 - wet)) + (rev * wet);
			extra_rev = FreeVerb.ar(sig, 1, (rclip + 0.03).clip(0, 0.99), (dclip + 0.05).clip(0, 1));
			sig = sig + (extra_rev * extra_wet * 1.6);
			del = CombC.ar(sig, 2.0, delay_time.clip(0.001, 2.0), 1.5);
			sig = sig + (del * delay_amt * 1.3);
			Out.ar(out, sig.dup);
		}).add;

		// WRAITH — high-register sawtooth grain w/ CombC stutter trail.
		// Uses the same persistent-node + t_trig pattern as the other voices.
		// The grain envelope fires on t_trig; the overall perc envelope shapes
		// the full decay. BPF narrows to metallic high-register; BHiShelf
		// trims harsh top end. doneAction:0 keeps the node alive for per-voice
		// param control (cutoff/res/dly/room/damp) between triggers.
		SynthDef(\sq_wraith, {
			arg out=0, freq=440, vel=0.7, attack=0.005, release=2.5, wet=0.8,
			    cutoff=2400, resonance=0.15,
			    delay_amt=0, delay_time=0.07,
			    extra_wet=0, room=0.88, damp=0.35,
			    t_trig=0;
			var env, grain_env, saw, grain, filt, stutter, shelf, sig, dry, rev, extra_rev, rclip, dclip;
			// overall perc envelope — shapes the full stutter trail
			env = EnvGen.kr(Env.perc(attack, release, 1, -3), t_trig);
			// short grain burst (~60ms) seeding the CombC stutter
			grain_env = EnvGen.kr(Env.perc(0.001, 0.06), t_trig);
			saw   = Saw.ar(freq * 2.0);
			grain = saw * grain_env;
			// narrow bandpass for metallic high-register colour
			filt = BPF.ar(grain, (freq * 3.5).clip(40, 18000), resonance.clip(0.05, 0.95));
			// CombC stutter trail (~14 Hz stutter, ~1.2s decay)
			stutter = CombC.ar(filt, 0.3, delay_time.clip(0.001, 0.3), 1.2);
			sig = filt + (stutter * delay_amt.clip(0, 1));
			// high-shelf -3dB cut at 4kHz to tame harshness (BHiShelf per BEQSuite naming)
			shelf = BHiShelf.ar(sig, 4000, 1.0, -3);
			// apply overall envelope + velocity
			sig = shelf * env * vel;
			rclip = room.clip(0, 0.99);
			dclip = damp.clip(0, 1);
			dry = sig;
			sig = (dry * (1 - wet)) + (FreeVerb.ar(sig, 1, rclip, dclip) * wet);
			sig = sig + (FreeVerb.ar(sig, 1, (rclip + 0.04).clip(0, 0.99), (dclip + 0.05).clip(0, 1)) * extra_wet * 1.6);
			Out.ar(out, sig.dup);
		}).add;

		// DRONE — slow detuned saws + sub
		SynthDef(\sq_drone, {
			arg out=0, freq=110, amp=0,
			    cutoff=500, lfo_rate=0.08, lfo_depth=0.12;
			var sig, lfo;
			lfo = SinOsc.kr(lfo_rate).range(1 - lfo_depth, 1 + lfo_depth);
			sig = LFSaw.ar(freq * lfo) * 0.3;
			sig = sig + (LFSaw.ar(freq * 1.5 * lfo + 0.3) * 0.18);
			sig = sig + (SinOsc.ar(freq * 0.5) * 0.4);
			sig = sig + (SinOsc.ar(freq * 2.001) * 0.08);
			sig = LPF.ar(sig, cutoff);
			sig = LeakDC.ar(sig);
			sig = sig * Lag.kr(amp, 1.2);
			Out.ar(out, sig.dup);
		}).add;

		context.server.sync;

		sq_mage    = Synth.new(\sq_mage,    [\out, context.out_b], context.server);
		sq_cleric  = Synth.new(\sq_cleric,  [\out, context.out_b], context.server);
		sq_warrior = Synth.new(\sq_warrior, [\out, context.out_b], context.server);
		sq_bard    = Synth.new(\sq_bard,    [\out, context.out_b], context.server);
		sq_drone   = Synth.new(\sq_drone,   [\out, context.out_b], context.server);
		sq_wraith  = Synth.new(\sq_wraith,  [\out, context.out_b], context.server);

		// trigger commands: freq, vel, attack, release, wet
		this.addCommand("trig_mage", "fffff", { arg msg;
			sq_mage.set(\freq, msg[1], \amp_mul, msg[2],
				\env_attack, msg[3], \env_release, msg[4],
				\wet, msg[5], \t_trig, 1);
		});
		this.addCommand("trig_cleric", "fffff", { arg msg;
			sq_cleric.set(\freq, msg[1], \amp_mul, msg[2],
				\env_attack, msg[3], \env_release, msg[4],
				\wet, msg[5], \t_trig, 1);
		});
		this.addCommand("trig_warrior", "fffff", { arg msg;
			sq_warrior.set(\freq, msg[1], \amp_mul, msg[2],
				\env_attack, msg[3], \env_release, msg[4],
				\wet, msg[5], \t_trig, 1);
		});
		this.addCommand("trig_bard", "fffff", { arg msg;
			sq_bard.set(\freq, msg[1], \amp_mul, msg[2],
				\env_attack, msg[3], \env_release, msg[4],
				\wet, msg[5], \t_trig, 1);
		});
		this.addCommand("trig_wraith", "fffff", { arg msg;
			sq_wraith.set(\freq, msg[1], \vel, msg[2],
				\attack, msg[3], \release, msg[4],
				\wet, msg[5], \t_trig, 1);
		});

		// per-voice cutoff
		this.addCommand("mage_cutoff",    "f", { arg msg; sq_mage.set(\cutoff, msg[1]); });
		this.addCommand("cleric_cutoff",  "f", { arg msg; sq_cleric.set(\cutoff, msg[1]); });
		this.addCommand("warrior_cutoff", "f", { arg msg; sq_warrior.set(\cutoff, msg[1]); });
		this.addCommand("bard_cutoff",    "f", { arg msg; sq_bard.set(\cutoff, msg[1]); });
		this.addCommand("wraith_cutoff",  "f", { arg msg; sq_wraith.set(\cutoff, msg[1]); });

		// per-voice resonance
		this.addCommand("mage_res",    "f", { arg msg; sq_mage.set(\resonance, msg[1]); });
		this.addCommand("cleric_res",  "f", { arg msg; sq_cleric.set(\resonance, msg[1]); });
		this.addCommand("warrior_res", "f", { arg msg; sq_warrior.set(\resonance, msg[1]); });
		this.addCommand("bard_res",    "f", { arg msg; sq_bard.set(\resonance, msg[1]); });
		this.addCommand("wraith_res",  "f", { arg msg; sq_wraith.set(\resonance, msg[1]); });

		// per-voice extra reverb (left stick Y)
		this.addCommand("mage_xwet",    "f", { arg msg; sq_mage.set(\extra_wet, msg[1]); });
		this.addCommand("cleric_xwet",  "f", { arg msg; sq_cleric.set(\extra_wet, msg[1]); });
		this.addCommand("warrior_xwet", "f", { arg msg; sq_warrior.set(\extra_wet, msg[1]); });
		this.addCommand("bard_xwet",    "f", { arg msg; sq_bard.set(\extra_wet, msg[1]); });
		this.addCommand("wraith_xwet",  "f", { arg msg; sq_wraith.set(\extra_wet, msg[1]); });

		// per-voice delay mix (left stick X)
		this.addCommand("mage_dly",    "f", { arg msg; sq_mage.set(\delay_amt, msg[1]); });
		this.addCommand("cleric_dly",  "f", { arg msg; sq_cleric.set(\delay_amt, msg[1]); });
		this.addCommand("warrior_dly", "f", { arg msg; sq_warrior.set(\delay_amt, msg[1]); });
		this.addCommand("bard_dly",    "f", { arg msg; sq_bard.set(\delay_amt, msg[1]); });
		this.addCommand("wraith_dly",  "f", { arg msg; sq_wraith.set(\delay_amt, msg[1]); });

		// per-voice delay time (seconds; clamped to 2.0 in the SynthDef)
		this.addCommand("mage_dly_time",    "f", { arg msg; sq_mage.set(\delay_time, msg[1]); });
		this.addCommand("cleric_dly_time",  "f", { arg msg; sq_cleric.set(\delay_time, msg[1]); });
		this.addCommand("warrior_dly_time", "f", { arg msg; sq_warrior.set(\delay_time, msg[1]); });
		this.addCommand("bard_dly_time",    "f", { arg msg; sq_bard.set(\delay_time, msg[1]); });
		this.addCommand("wraith_dly_time",  "f", { arg msg; sq_wraith.set(\delay_time, msg[1]); });

		// per-voice reverb size (FreeVerb room) and damping
		this.addCommand("mage_room",    "f", { arg msg; sq_mage.set(\room, msg[1]); });
		this.addCommand("cleric_room",  "f", { arg msg; sq_cleric.set(\room, msg[1]); });
		this.addCommand("warrior_room", "f", { arg msg; sq_warrior.set(\room, msg[1]); });
		this.addCommand("bard_room",    "f", { arg msg; sq_bard.set(\room, msg[1]); });
		this.addCommand("wraith_room",  "f", { arg msg; sq_wraith.set(\room, msg[1]); });

		this.addCommand("mage_damp",    "f", { arg msg; sq_mage.set(\damp, msg[1]); });
		this.addCommand("cleric_damp",  "f", { arg msg; sq_cleric.set(\damp, msg[1]); });
		this.addCommand("warrior_damp", "f", { arg msg; sq_warrior.set(\damp, msg[1]); });
		this.addCommand("bard_damp",    "f", { arg msg; sq_bard.set(\damp, msg[1]); });
		this.addCommand("wraith_damp",  "f", { arg msg; sq_wraith.set(\damp, msg[1]); });

		// drone control
		this.addCommand("drone_amp",    "f", { arg msg; sq_drone.set(\amp, msg[1]); });
		this.addCommand("drone_freq",   "f", { arg msg; sq_drone.set(\freq, msg[1]); });
		this.addCommand("drone_cutoff", "f", { arg msg; sq_drone.set(\cutoff, msg[1]); });
	}

	free {
		sq_mage.free;
		sq_cleric.free;
		sq_warrior.free;
		sq_bard.free;
		sq_drone.free;
		sq_wraith.free;
	}
}
