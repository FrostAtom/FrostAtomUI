import argparse
import math
import os
import re
import subprocess
import sys
import time
import warnings
from pathlib import Path

ROOT = Path(__file__).resolve().parent
ADDON = ROOT.parent.parent / "FrostAtomUI"
DATA = ADDON / "Modules" / "SpellAlertData.lua"
VOICE_DIR = ADDON / "Media" / "Voice"
os.environ.setdefault("HF_HOME", str(ROOT / "models"))
os.environ.setdefault("HF_HUB_DISABLE_SYMLINKS_WARNING", "1")
warnings.filterwarnings("ignore", category=UserWarning)
warnings.filterwarnings("ignore", category=FutureWarning)

import numpy as np
import torch
from kokoro import KModel, KPipeline

REPO = "hexgrad/Kokoro-82M"
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"

RATE = 24000
OUT_RATE = 44100
TRIM_DB = -45
LEAD = 0.005
TAIL = 0.02
FADE_IN = 0.004
FADE_OUT = 0.008
TARGET_RMS_DB = -16
PEAK_DB = -1

ANNOUNCER_FX = ",".join([
    "highpass=f=120",
    "equalizer=f=250:t=q:w=1:g=1.5",
    "equalizer=f=3000:t=q:w=1.2:g=3",
    "deesser=i=0.4",
    "acompressor=threshold=-24dB:ratio=3:attack=3:release=60:makeup=3",
    "alimiter=limit=0.9",
])

ANNOUNCER = dict(range=1.4, pitch=-1, fx=True)

PRESETS = {
    "heart": dict(voice="af_heart", lang="a"),
    "heart_x": dict(voice="af_heart", lang="a", **ANNOUNCER),
    "bella_x": dict(voice="af_bella", lang="a", **ANNOUNCER),
    "warm_flame_x": dict(voice="af_heart*0.6+af_bella*0.4", lang="a", **ANNOUNCER),
    "bella_sarah_x": dict(voice="af_bella*0.5+af_sarah*0.5", lang="a", **ANNOUNCER),
    "nicole_x": dict(voice="af_nicole", lang="a", **ANNOUNCER),
    "emma_x": dict(voice="bf_emma", lang="b", **ANNOUNCER),
    "emma_heart_x": dict(voice="bf_emma*0.5+af_heart*0.5", lang="b", **ANNOUNCER),
    "uk_elegance_x": dict(voice="bf_emma*0.6+bm_fable*0.4", lang="b", **ANNOUNCER),
    "emma_bella_x": dict(voice="bf_emma", prosody="af_bella", lang="b", **ANNOUNCER),
    "warm_flame_x2": dict(voice="af_heart*0.6+af_bella*0.4", lang="a", range=1.8, pitch=-2, fx=True),
}

DEFAULT_PRESET = "warm_flame_x2"

TEXTS = {
    "freezingTrap": "Freezing Trap",
    "freezingArrow": "Freezing Arrow",
    "garroteSilence": "Garrote",
    "trinket": "Trinket",
    "drinking": "Drinking",
    "demonicCircleTeleport": "Demonic Circle",
}

EXTRA = {
    "interrupted": "Interrupted!",
}

SPELL_RE = re.compile(r'^\s*\{ key = "(\w+)",(.*)\},\s*--\s*([^,\n]+)')
CATEGORY_RE = re.compile(r"^\t(\w+) = \{$")
LENGTHS_RE = re.compile(r"Data\.LENGTHS = \{[^}]*\}")
CLASS_SOUNDS_RE = re.compile(r"Data\.CLASS_SOUNDS = \{([^}]*)\}")

_model = None
_g2p = {}
_packs = {}


def model():
    global _model
    if _model is None:
        _model = KModel(repo_id=REPO).to(DEVICE).eval()
        print(f"Kokoro on {DEVICE}" + (f" ({torch.cuda.get_device_name()})" if DEVICE == "cuda" else ""))
    return _model


def g2p(lang):
    if lang not in _g2p:
        _g2p[lang] = KPipeline(lang_code=lang, repo_id=REPO, model=False)
    return _g2p[lang]


def pack(voice):
    if voice not in _packs:
        blend = 0
        for part in voice.split("+"):
            name, _, weight = part.partition("*")
            blend = blend + g2p(name[0]).load_single_voice(name) * float(weight or 1)
        _packs[voice] = blend / sum(float(p.partition("*")[2] or 1) for p in voice.split("+"))
    return _packs[voice]


def phonemize(text, lang):
    return " ".join(r.phonemes for r in g2p(lang)(text))


def shape_f0(f0, range_, pitch):
    voiced = f0 > 40
    if not voiced.any():
        return f0
    log = torch.log(f0.clamp(min=1))
    mean = log[voiced].mean()
    shaped = torch.exp(mean + range_ * (log - mean) + pitch * math.log(2) / 12)
    return torch.where(voiced, shaped, f0)


@torch.no_grad()
def infer(ps, ref_s, speed, range_, pitch):
    m = model()
    ids = [m.vocab[p] for p in ps if p in m.vocab]
    input_ids = torch.LongTensor([[0, *ids, 0]]).to(DEVICE)
    lengths = torch.full((1,), input_ids.shape[-1], device=DEVICE, dtype=torch.long)
    text_mask = torch.zeros_like(input_ids, dtype=torch.bool)
    ref_s = ref_s.to(DEVICE)
    s = ref_s[:, 128:]
    d = m.predictor.text_encoder(m.bert_encoder(m.bert(input_ids, attention_mask=(~text_mask).int())).transpose(-1, -2), s, lengths, text_mask)
    x, _ = m.predictor.lstm(d)
    duration = torch.sigmoid(m.predictor.duration_proj(x)).sum(axis=-1) / speed
    pred_dur = torch.round(duration).clamp(min=1).long().squeeze()
    indices = torch.repeat_interleave(torch.arange(input_ids.shape[1], device=DEVICE), pred_dur)
    aln = torch.zeros((input_ids.shape[1], indices.shape[0]), device=DEVICE)
    aln[indices, torch.arange(indices.shape[0])] = 1
    aln = aln.unsqueeze(0)
    f0, n = m.predictor.F0Ntrain(d.transpose(-1, -2) @ aln, s)
    f0 = shape_f0(f0, range_, pitch)
    asr = m.text_encoder(input_ids, lengths, text_mask) @ aln
    return m.decoder(asr, f0, n, ref_s[:, :128]).squeeze().cpu().numpy()


def synth(text, voice, lang="a", prosody=None, speed=1.1, range=1.0, pitch=0, style=None, fx=False):
    ps = phonemize(text, lang)
    index = min(style or len(ps) - 1, 509)
    timbre = pack(voice)[index]
    ref_s = torch.cat([timbre[:, :128], pack(prosody or voice)[index][:, 128:]], dim=1)
    audio = infer(ps, ref_s, speed, range, pitch)
    if fx:
        audio = ffmpeg_filter(audio, ANNOUNCER_FX)
    return normalize(trim(audio))


def ffmpeg_filter(audio, chain):
    out = subprocess.run(
        ["ffmpeg", "-loglevel", "error", "-f", "f32le", "-ar", str(RATE), "-ac", "1", "-i", "-",
         "-af", chain, "-f", "f32le", "-ar", str(RATE), "-ac", "1", "-"],
        input=audio.astype("<f4").tobytes(),
        capture_output=True,
        check=True,
    )
    return np.frombuffer(out.stdout, dtype="<f4").copy()


def trim(audio):
    level = 10 ** (TRIM_DB / 20) * np.abs(audio).max()
    loud = np.flatnonzero(np.abs(audio) > level)
    audio = audio[max(loud[0] - int(LEAD * RATE), 0) : loud[-1] + int(TAIL * RATE)].copy()
    fade_in, fade_out = int(FADE_IN * RATE), int(FADE_OUT * RATE)
    audio[:fade_in] *= np.linspace(0, 1, fade_in)
    audio[-fade_out:] *= np.linspace(1, 0, fade_out)
    return audio


def normalize(audio):
    voiced = audio[np.abs(audio) > 0.02 * np.abs(audio).max()]
    rms = np.sqrt(np.mean(voiced**2))
    audio = audio * (10 ** (TARGET_RMS_DB / 20) / rms)
    peak = np.abs(audio).max()
    limit = 10 ** (PEAK_DB / 20)
    if peak > limit:
        audio *= limit / peak
    return audio


def encode(audio, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = (np.clip(audio, -1, 1) * 32767).astype("<i2").tobytes()
    if path.suffix == ".wav":
        codec = ["-c:a", "pcm_s16le", "-map_metadata", "-1", "-fflags", "+bitexact"]
    else:
        codec = ["-ar", str(OUT_RATE), "-c:a", "libmp3lame", "-q:a", "2"]
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", str(RATE), "-ac", "1", "-i", "-", *codec, str(path)],
        input=pcm,
        check=True,
    )


def generate(phrases, preset, out, ext="wav"):
    lengths = {}
    for key, text in phrases.items():
        audio = synth(text, **preset)
        encode(audio, out / f"{key}.{ext}")
        lengths[key] = round(len(audio) / RATE, 2)
        print(f"{key:24} {lengths[key]:5.2f}s  {text}")
    return lengths


def spell_phrases():
    source = DATA.read_text(encoding="utf-8")
    classes = re.findall(r'"(\w+)"', CLASS_SOUNDS_RE.search(source).group(1))
    phrases = dict(EXTRA)
    category = None
    for line in source.splitlines():
        match = CATEGORY_RE.match(line)
        if match:
            category = match.group(1)
            continue
        match = SPELL_RE.match(line)
        if not match:
            continue
        key, fields, name = match.groups()
        name = TEXTS.get(key, name.strip())
        phrases[key] = f"{name}!"
        if category in ("cast", "control") and "area = true" not in fields:
            phrases[key + "You"] = f"{name} on you!"
        if "down = true" in fields:
            phrases[key + "Down"] = f"{name} down!"
        if "class = true" in fields:
            for suffix in classes:
                phrases[key + suffix] = f"{re.sub(r'(?<=[a-z])(?=[A-Z])', ' ', suffix)} {name.lower()}!"
    return phrases


def check_phonemes(phrases, lang):
    for key, text in phrases.items():
        _, tokens = g2p(lang).g2p(text)
        missing = [t.text for t in tokens if t.text.strip(" !'") and not t.phonemes]
        if missing:
            print(f"warning: {key}: no phonemes for {missing}")


def write_lengths(lengths):
    body = "".join(f"\t{key} = {lengths[key]},\n" for key in sorted(lengths))
    source = DATA.read_text(encoding="utf-8")
    DATA.write_text(LENGTHS_RE.sub(lambda _: "Data.LENGTHS = {\n" + body + "}", source, count=1), encoding="utf-8", newline="\n")


def generate_all(preset):
    phrases = spell_phrases()
    check_phonemes(phrases, preset["lang"])
    for old in VOICE_DIR.iterdir():
        if old.suffix != ".wav" or old.stem not in phrases:
            old.unlink()
    write_lengths(generate(phrases, preset, VOICE_DIR))
    print(f"{len(phrases)} sounds")


def preview(phrases, presets, out, gap=0.6):
    silence = np.zeros(int(gap * RATE))
    for name in presets:
        parts = []
        for text in phrases.values():
            parts += [synth(text, **PRESETS[name]), silence]
        encode(np.concatenate(parts), out / f"{name}.mp3")
        print(name)


def parse_phrases(items):
    phrases = {}
    for item in items:
        key, _, text = item.partition("=")
        phrases[key] = text or key
    return phrases


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="mode", required=True)

    gen = sub.add_parser("gen")
    gen.add_argument("phrases", nargs="+", help='key="Text"')
    gen.add_argument("--preset", default=DEFAULT_PRESET, choices=PRESETS)
    gen.add_argument("--out", type=Path, default=ROOT / "out")

    every = sub.add_parser("all")
    every.add_argument("--preset", default=DEFAULT_PRESET, choices=PRESETS)

    ab = sub.add_parser("preview")
    ab.add_argument("phrases", nargs="+", help='key="Text"')
    ab.add_argument("--presets", default=",".join(PRESETS))
    ab.add_argument("--out", type=Path, default=ROOT / "out" / "preview")

    args = parser.parse_args()
    start = time.perf_counter()
    if args.mode == "all":
        generate_all(PRESETS[args.preset])
    elif args.mode == "gen":
        phrases = parse_phrases(args.phrases)
        generate(phrases, PRESETS[args.preset], args.out)
    else:
        preview(parse_phrases(args.phrases), args.presets.split(","), args.out)
    print(f"done in {time.perf_counter() - start:.1f}s")


if __name__ == "__main__":
    sys.exit(main())
