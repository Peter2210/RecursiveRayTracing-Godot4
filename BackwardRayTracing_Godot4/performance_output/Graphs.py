import pandas as pd
import matplotlib.pyplot as plt
import os

# === CONFIG ===
csv_path = r"C:\Users\pmell\Faculdade\UNIOESTE\ProjetoTCC\BackwardRayTracing_Godot4\performance_output\performance_data.csv"
output_dir = os.path.splitext(csv_path)[0] + "_graphs"
os.makedirs(output_dir, exist_ok=True)

# === LOAD CSV ===
df = pd.read_csv(csv_path, sep=';')

# Convert Time to float in case it's a string
df["Time"] = df["Time"].astype(float)

# === AVAILABLE COLUMNS ===
# Time, FPS, ProcessTime, PhysicsTime, Memory(GiB), DrawCalls

# === PLOT SETTINGS ===
plt.style.use("ggplot")
font = {"size": 12}
plt.rc("font", **font)

def plot_metric(y_col, ylabel, title, color="blue", save_name=None):
    plt.figure(figsize=(10, 5))
    plt.plot(df["Time"], df[y_col], label=y_col, color=color)
    plt.xlabel("Time (s)")
    plt.ylabel(ylabel)
    plt.title(title)
    plt.grid(True)
    plt.legend()
    if save_name:
        path = os.path.join(output_dir, save_name)
        plt.savefig(path)
        print(f"Saved: {path}")
    plt.close()


# === GENERATE GRAPHS ===
plot_metric("FPS", "Frames Per Second", "FPS Over Time", "dodgerblue", "fps.png")
plot_metric("ProcessTime", "Process Time (s)", "Process Time Over Time", "green", "process_time.png")
plot_metric("PhysicsTime", "Physics Time (s)", "Physics Time Over Time", "orange", "physics_time.png")
plot_metric("Memory(GiB)", "Memory Usage (GiB)", "Memory Usage Over Time", "purple", "memory.png")
plot_metric("DrawCalls", "Draw Calls", "Draw Calls Over Time", "crimson", "draw_calls.png")

# === Combined view (optional) ===
plt.figure(figsize=(12, 6))
for col, color in [("FPS", "dodgerblue"), ("DrawCalls", "crimson"), ("Memory(GiB)", "purple")]:
    plt.plot(df["Time"], df[col], label=col, alpha=0.8)
plt.xlabel("Time (s)")
plt.title("Combined Metrics Over Time")
plt.legend()
plt.grid(True)
plt.savefig(os.path.join(output_dir, "combined_metrics.png"))
plt.close()
print("Saved combined graph.")
