import csv
import math
import os

# -------- Files --------
INPUT_CSV = "ble_decoded.csv"     # root
SETS_FOLDER = "sets"
OUTPUT_CSV = os.path.join(SETS_FOLDER, "ble_decoded_analysis.csv")

# -------- Rep detection params --------
THRESHOLD_START = 12.0    # deg/s  (start rep when above this)
THRESHOLD_STOP  = 6.0     # deg/s  (end rep when below this)
MIN_REP_DURATION = 0.8    # seconds (filter tiny false reps)


def ensure_sets_folder():
    os.makedirs(SETS_FOLDER, exist_ok=True)


def load_data(path):
    rows = []
    with open(path, newline="") as f:
        reader = csv.DictReader(f)
        for r in reader:
            rows.append({
                "t": float(r["t_s"]),
                "gx": float(r["gx"]),
                "gy": float(r["gy"]),
                "gz": float(r["gz"]),
            })
    return rows


def detect_reps(data):
    """
    Uses hysteresis:
      - start when gmag > THRESHOLD_START
      - stop  when gmag < THRESHOLD_STOP
    """
    reps = []
    in_rep = False
    rep_start = None

    for row in data:
        t = row["t"]
        gmag = math.sqrt(row["gx"]**2 + row["gy"]**2 + row["gz"]**2)

        if not in_rep and gmag > THRESHOLD_START:
            in_rep = True
            rep_start = t

        elif in_rep and gmag < THRESHOLD_STOP:
            rep_end = t
            dur = rep_end - rep_start
            if dur >= MIN_REP_DURATION:
                reps.append((rep_start, rep_end, dur))
            in_rep = False

    return reps


def save_analysis(path, reps):
    with open(path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["rep_number", "start_time", "end_time", "duration_sec"])
        for i, (start, end, dur) in enumerate(reps, 1):
            w.writerow([i, f"{start:.6f}", f"{end:.6f}", f"{dur:.3f}"])


if __name__ == "__main__":
    ensure_sets_folder()

    data = load_data(INPUT_CSV)
    reps = detect_reps(data)

    print(f"Detected {len(reps)} reps from {INPUT_CSV}")
    for i, (s, e, d) in enumerate(reps, 1):
        print(f"Rep {i}: start={s:.3f} end={e:.3f} dur={d:.2f}s")

    save_analysis(OUTPUT_CSV, reps)
    print(f"Saved analysis to: {OUTPUT_CSV}")