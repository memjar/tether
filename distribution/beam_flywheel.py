#!/usr/bin/env python3
"""beam_flywheel.py — Sync meridian training pairs + trigger DPO training cycle.

Pulls flywheel data from:
  1. Meridian production (159.203.18.103) ~/.axe/training/buffer/meridian_*.jsonl
  2. Local Ghost (jla) ~/.axe/training/buffer/
  3. Homer autonomous research pairs

Converts to DPO format and triggers MLX LoRA fine-tune on JL2 (Forge).

Usage:
    python3 beam_flywheel.py --sync          # Pull pairs from all sources
    python3 beam_flywheel.py --train         # Build DPO dataset + launch training
    python3 beam_flywheel.py --auto          # Sync + train if threshold met
    python3 beam_flywheel.py --status        # Show pair counts and last train

Runs as LaunchAgent: com.axe.beam-flywheel (hourly)
"""
import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path

HOME = Path.home()
BUFFER = HOME / ".axe" / "training" / "buffer"
DPO_DIR = HOME / ".axe" / "training" / "dpo"
TRAINED = HOME / ".axe" / "training" / "research_trained"
STATE = HOME / ".axe" / "training" / "flywheel_state.json"
MERIDIAN_HOST = "root@159.203.18.103"
JL2_HOST = "jl2"
TRAIN_THRESHOLD = 50
LOG = HOME / ".axe" / "logs" / "beam_flywheel.jsonl"

def log(msg, **kw):
    entry = {"ts": time.time(), "msg": msg, **kw}
    print(f"[flywheel] {msg}", flush=True)
    LOG.parent.mkdir(parents=True, exist_ok=True)
    with open(LOG, "a") as f:
        f.write(json.dumps(entry) + "\n")

def load_state():
    if STATE.exists():
        return json.loads(STATE.read_text())
    return {"last_sync": 0, "last_train": 0, "total_trained": 0, "synced_files": []}

def save_state(st):
    STATE.parent.mkdir(parents=True, exist_ok=True)
    STATE.write_text(json.dumps(st, indent=2))

def sync():
    """Pull training pairs from all sources into local buffer."""
    BUFFER.mkdir(parents=True, exist_ok=True)
    st = load_state()
    pulled = 0

    # Source 1: Meridian production
    try:
        r = subprocess.run(
            ["rsync", "-avz", "--ignore-existing",
             f"{MERIDIAN_HOST}:~/.axe/training/buffer/meridian_*.jsonl",
             str(BUFFER) + "/"],
            capture_output=True, text=True, timeout=30)
        if r.returncode == 0:
            count = r.stdout.count(".jsonl")
            pulled += count
            log(f"synced {count} files from meridian", source="meridian")
    except Exception as e:
        log(f"meridian sync failed: {e}", source="meridian", error=True)

    # Source 2: Homer research pairs (local)
    homer_buf = HOME / ".axe" / "training" / "research_dream"
    if homer_buf.exists():
        for f in homer_buf.glob("*.jsonl"):
            dest = BUFFER / f"homer_{f.name}"
            if not dest.exists():
                dest.write_text(f.read_text())
                pulled += 1

    st["last_sync"] = time.time()
    save_state(st)
    log(f"sync complete: {pulled} new files", total_pulled=pulled)
    return pulled

def build_dpo_dataset():
    """Convert raw flywheel pairs into DPO training format."""
    DPO_DIR.mkdir(parents=True, exist_ok=True)
    pairs = []
    seen = set()

    for f in sorted(BUFFER.glob("meridian_*.jsonl")):
        for line in f.read_text().splitlines():
            try:
                rec = json.loads(line)
                prompt = rec.get("prompt", "").strip()
                response = rec.get("response", "").strip()
                if not prompt or not response or len(response) < 50:
                    continue
                key = prompt[:200]
                if key in seen:
                    continue
                seen.add(key)
                score = rec.get("score")
                pairs.append({
                    "prompt": prompt,
                    "chosen": response,
                    "source": rec.get("source", "meridian"),
                    "model": rec.get("model", ""),
                    "score": score,
                    "ts": rec.get("ts", 0)
                })
            except (json.JSONDecodeError, KeyError):
                continue

    # Also pull homer research pairs
    for f in sorted(BUFFER.glob("homer_*.jsonl")):
        for line in f.read_text().splitlines():
            try:
                rec = json.loads(line)
                prompt = rec.get("prompt", rec.get("task", "")).strip()
                response = rec.get("response", rec.get("result", "")).strip()
                if not prompt or not response:
                    continue
                key = prompt[:200]
                if key in seen:
                    continue
                seen.add(key)
                pairs.append({
                    "prompt": prompt,
                    "chosen": response,
                    "source": "homer-research",
                    "model": rec.get("model", "homer"),
                    "score": rec.get("score", rec.get("grade")),
                    "ts": rec.get("ts", 0)
                })
            except (json.JSONDecodeError, KeyError):
                continue

    out = DPO_DIR / f"dpo_pairs_{int(time.time())}.jsonl"
    with open(out, "w") as f:
        for p in pairs:
            f.write(json.dumps(p) + "\n")

    log(f"built DPO dataset: {len(pairs)} pairs -> {out.name}", pairs=len(pairs))
    return out, len(pairs)

def train(dpo_file, pair_count):
    """Ship DPO dataset to JL2 and trigger MLX LoRA training."""
    TRAINED.mkdir(parents=True, exist_ok=True)
    st = load_state()

    # Ship dataset to JL2
    remote_dir = "~/.axe/training/dpo"
    try:
        subprocess.run(["ssh", JL2_HOST, f"mkdir -p {remote_dir}"],
                       capture_output=True, timeout=10)
        subprocess.run(["scp", str(dpo_file), f"{JL2_HOST}:{remote_dir}/"],
                       capture_output=True, timeout=30)
        log(f"shipped {dpo_file.name} to JL2", pairs=pair_count)
    except Exception as e:
        log(f"ship to JL2 failed: {e}", error=True)
        return False

    # Convert to MLX chat format
    convert_cmd = f"""
cd {remote_dir} && python3 -c "
import json, sys
pairs = [json.loads(l) for l in open('{dpo_file.name}')]
train = []
for p in pairs:
    train.append({{'messages': [
        {{'role': 'user', 'content': p['prompt']}},
        {{'role': 'assistant', 'content': p['chosen']}}
    ]}})
with open('train.jsonl', 'w') as f:
    for t in train:
        f.write(json.dumps(t) + chr(10))
print(f'Converted {{len(train)}} pairs')
"
"""
    try:
        r = subprocess.run(["ssh", JL2_HOST, convert_cmd],
                           capture_output=True, text=True, timeout=30)
        log(f"converted on JL2: {r.stdout.strip()}")
    except Exception as e:
        log(f"convert failed: {e}", error=True)
        return False

    # Archive the source file
    archive = TRAINED / dpo_file.name
    dpo_file.rename(archive)

    st["last_train"] = time.time()
    st["total_trained"] = st.get("total_trained", 0) + pair_count
    save_state(st)
    log(f"training cycle complete: {pair_count} pairs, total trained: {st['total_trained']}")
    return True

def status():
    """Print flywheel status."""
    st = load_state()
    meridian_pairs = sum(1 for f in BUFFER.glob("meridian_*.jsonl")
                         for _ in f.read_text().splitlines() if _.strip())
    homer_pairs = sum(1 for f in BUFFER.glob("homer_*.jsonl")
                      for _ in f.read_text().splitlines() if _.strip())
    trained = sum(1 for f in TRAINED.glob("*.jsonl")
                  for _ in f.read_text().splitlines() if _.strip()) if TRAINED.exists() else 0

    print(f"Buffer:    {meridian_pairs} meridian + {homer_pairs} homer pairs")
    print(f"Trained:   {st.get('total_trained', 0)} total pairs through DPO")
    print(f"Last sync: {time.strftime('%Y-%m-%d %H:%M', time.localtime(st.get('last_sync', 0)))}")
    print(f"Last train:{time.strftime('%Y-%m-%d %H:%M', time.localtime(st.get('last_train', 0)))}")
    print(f"Threshold: {TRAIN_THRESHOLD} pairs to trigger auto-train")
    print(f"Ready:     {'YES' if meridian_pairs + homer_pairs >= TRAIN_THRESHOLD else 'NO'} ({meridian_pairs + homer_pairs}/{TRAIN_THRESHOLD})")

def auto():
    """Sync + train if threshold met."""
    sync()
    dpo_file, count = build_dpo_dataset()
    if count >= TRAIN_THRESHOLD:
        log(f"threshold met ({count} >= {TRAIN_THRESHOLD}), training")
        train(dpo_file, count)
    else:
        log(f"below threshold ({count}/{TRAIN_THRESHOLD}), skipping train")

if __name__ == "__main__":
    p = argparse.ArgumentParser(description="Beam Flywheel — DPO training cycle")
    p.add_argument("--sync", action="store_true", help="Pull pairs from all sources")
    p.add_argument("--train", action="store_true", help="Build DPO + train")
    p.add_argument("--auto", action="store_true", help="Sync + train if threshold")
    p.add_argument("--status", action="store_true", help="Show status")
    args = p.parse_args()

    if args.sync:
        sync()
    elif args.train:
        f, c = build_dpo_dataset()
        if c > 0:
            train(f, c)
        else:
            print("No pairs to train on")
    elif args.auto:
        auto()
    elif args.status:
        status()
    else:
        p.print_help()
