import sys, json, argparse
import numpy as np, librosa


def build(wav, fall_time, keep, min_gap, lanes_mode):
    y, sr = librosa.load(wav, sr=None)

    # onset strength envelope + detected onsets (every musical hit)
    env = librosa.onset.onset_strength(y=y, sr=sr)
    onsets = librosa.onset.onset_detect(y=y, sr=sr, onset_envelope=env, backtrack=True)
    times = librosa.frames_to_time(onsets, sr=sr)
    strength = env[onsets]

    # keep only the strongest hits -> accents, so timing varies with the song
    if len(strength):
        mask = strength >= np.quantile(strength, 1 - keep)
        times = times[mask]

    # lane by brightness at each hit (bass -> Left, treble -> Right)
    cent = librosa.feature.spectral_centroid(y=y, sr=sr)[0]
    ct = librosa.times_like(cent, sr=sr)
    b = np.interp(times, ct, cent)
    if lanes_mode == "lr":
        lane_of = np.where(b < np.median(b), 0, 3)
    else:
        lane_of = np.digitize(b, np.quantile(b, [0.25, 0.5, 0.75]))  # 0..3

    lanes, last = [[], [], [], []], [-9.0] * 4
    for t, ln in sorted(zip(times.tolist(), lane_of.tolist())):
        spawn = round(float(t) - fall_time, 4)
        if spawn < 0 or spawn - last[ln] < min_gap:
            continue
        lanes[ln].append(spawn)
        last[ln] = spawn
    return lanes


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="Turn a wav into a game chart (fk_times).")
    ap.add_argument("wav")
    ap.add_argument("--fall-time", type=float, default=2.2)
    ap.add_argument("--keep", type=float, default=0.35,
                    help="fraction of strongest onsets to keep (0.25=sparse, 0.8=busy)")
    ap.add_argument("--min-gap", type=float, default=0.13,
                    help="min seconds between notes in one lane")
    ap.add_argument("--lanes", choices=["lr", "quad"], default="lr")
    a = ap.parse_args()

    lanes = build(a.wav, a.fall_time, a.keep, a.min_gap, a.lanes)
    print("per lane [L,D,U,R]:", [len(x) for x in lanes], file=sys.stderr)
    print(json.dumps(lanes, separators=(", ", ": ")))
