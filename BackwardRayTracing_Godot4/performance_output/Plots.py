import pandas as pd
import plotly.graph_objects as go
import plotly.io as pio
import os

# === CONFIG ===
csv_path = r"C:\Users\pmell\Faculdade\UNIOESTE\ProjetoTCC\BackwardRayTracing_Godot4\performance_output\performance_data.csv"
output_dir = os.path.splitext(csv_path)[0] + "_interactive"
os.makedirs(output_dir, exist_ok=True)

# === LOAD CSV ===
df = pd.read_csv(csv_path, sep=";")
df["Time"] = df["Time"].astype(float)

# === PLOT FUNCTION ===
def plot_interactive(y_col, y_label, title, file_name):
    fig = go.Figure()
    fig.add_trace(go.Scatter(
        x=df["Time"],
        y=df[y_col],
        mode="lines+markers",
        name=y_label,
        line=dict(width=2)
    ))

    fig.update_layout(
        title=title,
        xaxis_title="Time (seconds)",
        yaxis_title=y_label,
        hovermode="x unified",
        template="plotly_dark",
        autosize=True,
        margin=dict(l=40, r=40, t=50, b=40)
    )

    output_file = os.path.join(output_dir, file_name)
    pio.write_html(fig, file=output_file, auto_open=False)
    print(f"Saved interactive graph: {output_file}")


# === GENERATE INTERACTIVE GRAPHS ===
plot_interactive("FPS", "Frames Per Second", "FPS Over Time", "fps.html")
plot_interactive("ProcessTime", "Process Time (s)", "Process Time Over Time", "process_time.html")
plot_interactive("PhysicsTime", "Physics Time (s)", "Physics Time Over Time", "physics_time.html")
plot_interactive("Memory(GiB)", "Memory Usage (GiB)", "Memory Usage Over Time", "memory.html")
plot_interactive("DrawCalls", "Draw Calls", "Draw Calls Over Time", "draw_calls.html")

# === Combined Interactive Graph ===
fig = go.Figure()
colors = {
    "FPS": "deepskyblue",
    "ProcessTime": "limegreen",
    "PhysicsTime": "orange",
    "Memory(GiB)": "mediumpurple",
    "DrawCalls": "crimson"
}

for col, color in colors.items():
    fig.add_trace(go.Scatter(
        x=df["Time"],
        y=df[col],
        mode="lines",
        name=col,
        line=dict(width=2, color=color)
    ))

fig.update_layout(
    title="Combined Performance Metrics Over Time",
    xaxis_title="Time (seconds)",
    hovermode="x unified",
    template="plotly_white"
)

combined_file = os.path.join(output_dir, "combined_metrics.html")
pio.write_html(fig, file=combined_file, auto_open=False)
print(f"Saved interactive combined graph: {combined_file}")
