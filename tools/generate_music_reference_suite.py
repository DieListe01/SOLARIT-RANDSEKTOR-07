"""Render original, evolving SOLARIT reference music stems.

Requires NumPy, SciPy and FFmpeg with libvorbis. The score is authored here: faction
motifs, harmony, meter, section changes, percussion and timbral systems are
different by faction. These are original in-house demo/reference assets, not
licensed recordings or a substitute for final human composition/mix approval.
"""
from __future__ import annotations

import math
import shutil
import subprocess
from pathlib import Path

import numpy as np
from scipy.signal import lfilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "audio" / "music"
RATE = 48_000
SEED = 870711

SCORES = {
    "forge": {"bpm": 108, "eighths": 8, "root": 38, "motif": [0, 7, 3, 10, 12, 7, 5], "scale": [0, 3, 5, 7, 10], "sections": [0, 3, 5, 2, 0, 7], "bars": 48},
    "drift": {"bpm": 108, "eighths": 7, "root": 43, "motif": [0, 2, 7, 5, 10, 3, 12], "scale": [0, 2, 5, 7, 9, 10], "sections": [0, 5, 3, 7, 0, 10], "bars": 56},
    "lumen": {"bpm": 96, "eighths": 10, "root": 45, "motif": [0, 11, 4, 9, 2, 7, 14], "scale": [0, 2, 4, 7, 11], "sections": [0, 4, 11, 7, 2, 9], "bars": 48},
}


def add_tone(buf: np.ndarray, start: float, length: float, midi: float, gain: float,
             faction: str, kind: str, pan: float = 0.0, seed: int = 0) -> None:
    offset = int(start * RATE)
    count = min(int(length * RATE), len(buf) - offset)
    if count <= 0:
        return
    t = np.arange(count, dtype=np.float32) / RATE
    hz = 440.0 * 2.0 ** ((midi - 69.0) / 12.0)
    sweep = (0.0, -0.16, 0.25)[seed % 3] if kind in ("hit", "crystal") else 0.0
    phase_l = 2.0 * np.pi * (hz * t + sweep * hz * t * t / max(length, 0.001))
    phase_r = phase_l * (1.0 + (0.0015 if faction == "lumen" else 0.0005)) + 0.07
    env = np.minimum(1.0, t / max(0.002, min(0.12, length * 0.18)))
    env *= np.minimum(1.0, np.maximum(0.0, length - t) / max(0.015, min(0.32, length * 0.35)))
    if kind in ("hit", "crystal"):
        env *= np.exp(-t * (4.0 if kind == "hit" else 2.3))
    trem = 1.0 + (0.08 if faction == "drift" else 0.025) * np.sin(2.0 * np.pi * (3.1 + seed % 4) * t)
    if kind == "pad":
        # Detuned, inharmonic partials keep the sound from collapsing into a
        # single oscillator; the three factions use different spectral weights.
        ratios = {"forge": [1, 2, 3, 4, 5], "drift": [1, 1.997, 3.01, 4.03, 6.02], "lumen": [1, 2.756, 4.17, 6.91, 9.02]}[faction]
        weights = {"forge": [0.46, 0.22, 0.15, 0.11, 0.06], "drift": [0.34, 0.30, 0.20, 0.10, 0.06], "lumen": [0.36, 0.16, 0.22, 0.16, 0.10]}[faction]
        left = sum(w * np.sin(phase_l * r) for r, w in zip(ratios, weights))
        right = sum(w * np.sin(phase_r * r + i * 0.09) for i, (r, w) in enumerate(zip(ratios, weights)))
        swell = 0.82 + 0.18 * np.sin(2 * np.pi * t / max(length, .01))
        wave = np.column_stack((left, right)) * env[:, None] * swell[:, None]
    elif kind == "bass":
        wave = np.column_stack((np.sin(phase_l) + .27 * np.sin(phase_l * 2.01),
                                np.sin(phase_r) + .27 * np.sin(phase_r * 2.01))) * env[:, None]
    elif kind in ("hit", "crystal"):
        rng = np.random.default_rng(SEED + seed)
        noise = rng.standard_normal((count, 2), dtype=np.float32)
        noise = np.concatenate((noise[:1] * 0.0, np.diff(noise, axis=0)), axis=0)
        partials = np.sin(phase_l) + .52 * np.sin(phase_r * (2.41 if faction == "lumen" else 1.72))
        grit = 0.42 * noise[:, 0] + 0.34 * noise[:, 1]
        if faction == "forge":
            wave = np.column_stack((partials + grit, partials * .91 + np.roll(grit, 3)))
        elif faction == "drift":
            wave = np.column_stack((partials * .62 + grit, partials * .75 - grit * .67))
        else:
            ring = np.sin(phase_l * 2.756) + .55 * np.sin(phase_r * 4.17)
            wave = np.column_stack((partials * .32 + ring + grit * .2,
                                    partials * .22 + ring * .88 - grit * .17))
        wave *= env[:, None]
    elif kind == "noise":
        rng = np.random.default_rng(SEED + seed * 17)
        raw = rng.standard_normal((count, 2), dtype=np.float32)
        # A moving one-pole filter makes alarm textures sweep rather than buzz.
        alpha = .22 if faction == "drift" else .11
        low_a = np.column_stack((lfilter([.035],[1.0,-.965],raw[:,0]), lfilter([.035],[1.0,-.965],raw[:,1])))
        low_b = np.column_stack((lfilter([alpha],[1.0,-(1.0-alpha)],raw[:,0]), lfilter([alpha],[1.0,-(1.0-alpha)],raw[:,1])))
        blend=np.linspace(0.0,1.0,count,dtype=np.float32)[:,None]
        filt=low_a*(1.0-blend)+low_b*blend
        wave = filt * env[:, None]
    else:
        return
    left_gain = math.sqrt(max(0.0, 1.0 - (pan + 1.0) * 0.5))
    right_gain = math.sqrt(max(0.0, (pan + 1.0) * 0.5))
    buf[offset:offset + count, 0] += wave[:, 0] * gain * trem * left_gain
    buf[offset:offset + count, 1] += wave[:, 1] * gain * trem * right_gain


def compose(faction: str, state: str) -> tuple[np.ndarray, dict]:
    score = SCORES[faction]
    bpm, eighths, bars = score["bpm"], score["eighths"], score["bars"]
    step = 60.0 / bpm / 2.0
    bar_sec = step * eighths
    samples = int(round(bar_sec * bars * RATE))
    out = np.zeros((samples, 2), dtype=np.float32)
    rng = np.random.default_rng(SEED + sum(map(ord, faction + state)))
    motif, scale = score["motif"], score["scale"]
    root = score["root"]
    for bar in range(bars):
        section = (bar // 8) % len(score["sections"])
        chord = score["sections"][section]
        section_level = [0.56, 0.72, 0.84, 0.70, 0.95, 0.76][section]
        bar_start = bar * bar_sec
        # Calm foundation: slow evolving chord voicings and a weighted low pulse.
        if state == "calm":
            voicing = [0, scale[(section + 2) % len(scale)], 12, 19 if faction != "lumen" else 23]
            for voice, interval in enumerate(voicing):
                add_tone(out, bar_start, bar_sec * 0.96, root + 24 + chord + interval,
                         0.080 * section_level / (1.0 + voice * .38), faction, "pad",
                         (-.7 + voice * .46), bar * 11 + voice)
            if bar % (2 if faction == "drift" else 3) == 0:
                add_tone(out, bar_start, bar_sec * .72, root + chord, .13 * section_level,
                         faction, "bass", -.16 if bar % 2 else .16, bar)
            if bar % 4 == 3:
                add_tone(out, bar_start + bar_sec * .72, bar_sec * .23, root + 48 + motif[bar % len(motif)],
                         .045, faction, "crystal" if faction == "lumen" else "hit", .4, bar + 301)
        # Contact brings the signature motif and a faction-specific ticking pulse.
        elif state == "contact":
            if bar % 2 == 0 or faction == "drift":
                for idx, interval in enumerate(motif):
                    if faction == "drift" and idx in (2, 5) and bar % 3 == 0:
                        continue
                    at = bar_start + idx * step
                    add_tone(out, at, step * (1.6 if faction == "lumen" else .82),
                             root + 36 + chord + interval, .105 * section_level,
                             faction, "crystal" if faction == "lumen" else "hit",
                             (-.72 + (idx % 5) * .36), bar * 13 + idx + 401)
            if faction == "drift":
                for pos in [0, 3, 6]:
                    add_tone(out, bar_start + pos * step, step * .34, root + 30, .11,
                             faction, "bass", .25 if pos == 3 else -.25, bar * 9 + pos + 501)
        # Battle is the main dramatic lift: measured low impacts plus a developing lead.
        elif state == "battle":
            beat_positions = [0, 4] if faction == "drift" else ([0, 5] if faction == "lumen" else [0, 4])
            for pos in beat_positions:
                add_tone(out, bar_start + pos * step, step * 1.8, root + chord - 12,
                         .17 * section_level, faction, "bass", 0, bar * 5 + pos + 601)
            if bar % 8 in (4, 5, 6, 7):
                note = motif[(bar + section) % len(motif)] + (12 if section in (2, 4) else 0)
                add_tone(out, bar_start + step * (2 if faction != "drift" else 1),
                         step * (3.3 if faction == "lumen" else 2.1), root + 48 + chord + note,
                         .10 * section_level, faction, "pad" if faction == "lumen" else "hit",
                         .28 if bar % 2 else -.28, bar + 701)
            hit_positions = range(eighths) if faction == "drift" else [0, 2, 4, 6]
            for pos in hit_positions:
                if rng.random() < (.88 if faction == "drift" else .68):
                    kind = "crystal" if faction == "lumen" else "hit"
                    duration = step * (.52 if faction == "drift" else 1.05)
                    add_tone(out, bar_start + pos * step, duration,
                             root + (24 if faction == "forge" else 30) + (chord if pos % 4 == 0 else 0),
                             .075 * section_level, faction, kind,
                             float(rng.uniform(-.8, .8)), bar * 19 + pos + 801)
        # Alarm adds a tense high register pulse; it remains a separate, duckable stem.
        elif state == "alarm":
            alarm_steps = [0, 2, 4, 6] if faction != "drift" else [0, 1, 3, 4, 6]
            for n, pos in enumerate(alarm_steps):
                interval = [0, 1, 7, 6, 10, 5][(n + section) % 6]
                add_tone(out, bar_start + pos * step, step * 1.35, root + 54 + interval,
                         .082 * section_level, faction, "crystal" if faction == "lumen" else "hit",
                         -.55 if n % 2 == 0 else .55, bar * 17 + pos + 901)
            if bar % 4 == 0:
                add_tone(out, bar_start, bar_sec * .82, root + 60 + (1 if faction == "lumen" else 6),
                         .022, faction, "noise", 0, bar + 1001)
        else:
            raise ValueError(state)
    # Soft non-zero room/tape bed ties spectral material together without a loop click.
    if state in ("calm", "alarm"):
        rng = np.random.default_rng(SEED + 73 + sum(map(ord, faction + state)))
        bed = rng.standard_normal(out.shape, dtype=np.float32)
        # Low-rate, smoothed stochastic energy; fade the opening/loop seam.
        decimated = bed[::240].copy()
        decimated *= np.linspace(.25, .08, len(decimated), dtype=np.float32)[:, None]
        bed = np.repeat(decimated, 240, axis=0)[:len(out)]
        out += bed * (.0025 if state == "calm" else .0018)
    # Cosine fades make the authored loop's boundary safe; reverb is deliberately
    # kept short so the musical downbeat stays legible.
    fade_n = int(RATE * min(1.2, bar_sec * .48))
    fade = np.linspace(0.0, 1.0, fade_n, dtype=np.float32)
    out[:fade_n] *= fade[:, None]
    out[-fade_n:] *= fade[::-1, None]
    peak = float(np.max(np.abs(out)))
    if peak > .88:
        out *= .88 / peak
    return out, {"bpm": bpm, "beats_per_bar": eighths, "beat_unit": 8, "bars": bars,
                 "duration_seconds": samples / RATE, "peak": float(np.max(np.abs(out)))}


def title_score() -> tuple[np.ndarray, dict]:
    bpm, bars, beats = 96, 64, 4
    bar_sec = 60 / bpm * beats
    out = np.zeros((int(round(bar_sec * bars * RATE)), 2), dtype=np.float32)
    motif = [0, 7, 3, 10, 14, 12, 7]
    harmony = [0, 3, 10, 5, 0, 7, 2, 9]
    for bar in range(bars):
        section = bar // 8
        root = 38 + harmony[section % len(harmony)]
        start = bar * bar_sec
        level = [0.28, .42, .6, .82, .92, .68, .84, .45][section]
        for i, interval in enumerate([0, 7, 12, 19]):
            add_tone(out, start, bar_sec * .97, root + 24 + interval,
                     .046 * level / (1 + i*.4), "lumen", "pad", -.65+i*.43, bar*23+i+1201)
        if section >= 1 and bar % 2 == 0:
            add_tone(out, start, bar_sec * .7, root, .10 * level, "forge", "bass", 0, bar+1301)
        if section >= 2:
            for beat in ([0, 2] if section % 2 else [1, 3]):
                add_tone(out, start + beat * (60/bpm), .55, root + 48 + motif[(bar+beat)%len(motif)],
                         .045*level, "lumen", "crystal", -.4 if beat % 2 else .4, bar*4+beat+1401)
        if section >= 3 and bar % (2 if section < 6 else 4) == 0:
            add_tone(out, start, .82, root-12, .11*level, "forge", "hit", 0, bar+1501)
    fade_n=int(RATE*2.0)
    fade=np.linspace(0,1,fade_n,dtype=np.float32)
    out[:fade_n]*=fade[:,None]; out[-fade_n:]*=fade[::-1,None]
    peak=float(np.max(np.abs(out)))
    if peak>.88: out*=.88/peak
    return out, {"bpm":bpm,"beats_per_bar":beats,"bars":bars,"duration_seconds":len(out)/RATE,"peak":float(np.max(np.abs(out)))}


def encode(name: str, samples: np.ndarray, folder: Path = OUT, target_lufs: int = -20) -> None:
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        raise RuntimeError("FFmpeg is required to encode Ogg Vorbis music assets")
    folder.mkdir(parents=True, exist_ok=True)
    output = folder / f"{name}.ogg"
    cmd = [ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-f", "f32le",
           "-ar", str(RATE), "-ac", "2", "-i", "pipe:0", "-c:a", "libvorbis",
           "-q:a", "6", "-af", f"loudnorm=I={target_lufs}:TP=-1.5:LRA=12", "-ar", str(RATE), str(output)]
    result = subprocess.run(cmd, input=np.asarray(samples, dtype="<f4").tobytes(),
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode:
        raise RuntimeError(result.stderr.decode("utf-8", "replace"))
    print(f"{output.relative_to(ROOT)}: {len(samples)/RATE:.1f}s stereo 48kHz Vorbis")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    if not shutil.which("ffmpeg"):
        raise SystemExit("FFmpeg not found; install FFmpeg with libvorbis")
    for faction in SCORES:
        for state in ("calm", "contact", "battle", "alarm"):
            audio, meta = compose(faction, state)
            encode(f"{faction}_{state}_demo", audio)
            print(f"  tempo={meta['bpm']} meter={meta['beats_per_bar']}/{meta['beat_unit']} bars={meta['bars']} peak={meta['peak']:.3f}")
    title, meta = title_score()
    encode("first_signal_demo", title)
    print(f"  title={meta['duration_seconds']:.1f}s peak={meta['peak']:.3f}")
    render_harvester_sfx()


def render_harvester_sfx() -> None:
    folder=ROOT/"assets"/"audio"/"sfx"
    start=np.zeros((int(.90*RATE),2),dtype=np.float32)
    add_tone(start,.0,.82,34,.19,"forge","bass",0,1990)
    add_tone(start,.05,.64,46,.12,"forge","hit",-.2,1991)
    add_tone(start,.27,.48,72,.13,"lumen","crystal",.35,1992)
    encode("harvest_start_demo",start,folder,-17)

    collect=np.zeros((int(1.15*RATE),2),dtype=np.float32)
    for i,at in enumerate([.02,.19,.39,.62,.88]):
        add_tone(collect,at,.29,67+[0,7,12,19,24][i],.22,"lumen","crystal",-.7+i*.34,2001+i)
    add_tone(collect,.06,.82,43,.10,"drift","noise",0,2050)
    fade=min(int(.06*RATE),len(collect)//4)
    collect[:fade]*=np.linspace(0,1,fade,dtype=np.float32)[:,None]
    collect[-fade:]*=np.linspace(1,0,fade,dtype=np.float32)[:,None]
    encode("harvest_collect_demo",collect,folder,-17)

    unload=np.zeros((int(1.65*RATE),2),dtype=np.float32)
    add_tone(unload,.0,.92,38,.25,"forge","hit",0,2101)
    for i,at in enumerate([.13,.32,.53,.77,1.04,1.29]):
        add_tone(unload,at,.31,58+[0,7,12,5,19,24][i],.19,"lumen","crystal",.65-i*.25,2110+i)
    add_tone(unload,.26,1.05,50,.06,"drift","noise",0,2190)
    unload[:fade]*=np.linspace(0,1,fade,dtype=np.float32)[:,None]
    unload[-fade:]*=np.linspace(1,0,fade,dtype=np.float32)[:,None]
    encode("harvest_unload_demo",unload,folder,-17)

    step=.24
    work=np.zeros((int(step*16*RATE),2),dtype=np.float32)
    for i in range(16):
        at=i*step
        add_tone(work,at,.33,34+(i%4==2)*5,.12,"forge","bass",-.12 if i%2==0 else .12,2200+i)
        if i%2==0:
            add_tone(work,at,.20,52+(i%4)*2,.07,"forge","hit",.28 if i%4 else -.28,2240+i)
        add_tone(work,at,.30,70,.025,"lumen","pad",0,2260+i)
    # Match the motor loop's endpoint to its opening to avoid clicks.
    fade=int(.08*RATE)
    blend=np.linspace(0,1,fade,dtype=np.float32)[:,None]
    seam=work[-fade:]*(1.0-blend)+work[:fade]*blend
    work[:fade]=seam;work[-fade:]=seam
    encode("harvester_work_demo",work,folder,-19)


if __name__ == "__main__":
    main()
