import pandas as pd
import numpy as np
from io import StringIO
import matplotlib.pyplot as plt

csv_path = "../ble_decoded.csv"
df = pd.read_csv(csv_path)

df = df.sort_values("t_s").reset_index(drop=True)
df["dt"] = df["t_s"].diff().fillna(0)

g_baseline = df["az"].median()
df["az_dyn"] = df["az"] - g_baseline

# do same for x/y if needed
df["ax_dyn"] = df["ax"] - df["ax"].median()
df["ay_dyn"] = df["ay"] - df["ay"].median()

df["vx"] = (df["ax_dyn"] * df["dt"]).cumsum()
df["vz"] = (df["az_dyn"] * df["dt"]).cumsum()
df["vx"] -= df["vx"].mean()
df["vz"] -= df["vz"].mean()


df["px"] = (df["vx"] * df["dt"]).cumsum()
df["pz"] = (df["vz"] * df["dt"]).cumsum()

plt.figure(figsize=(6,8))

plt.plot(df["px"], df["pz"])
plt.xlabel("X Position")
plt.ylabel("Z Position (Vertical)")
plt.title("Bar Path (2D)")
plt.grid(True)
plt.axis("equal")

plt.show()
