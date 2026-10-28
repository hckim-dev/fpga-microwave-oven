"""XSim VCD에서 잠금 해제 경계를 잘라 실제 Simulation 파형을 그린다."""

import argparse
import hashlib
import json
import re
from bisect import bisect_right
from collections import defaultdict
from pathlib import Path


def read_vcd(path):
    text = path.read_text(encoding="utf-8")
    header, marker, body = text.partition("$enddefinitions $end")
    if not marker:
        raise ValueError("VCD header missing")
    scale = re.search(r"\$timescale\s+(\d+)\s*(fs|ps|ns|us|ms|s)\s+\$end", header)
    if not scale:
        raise ValueError("VCD timescale missing")
    ns_per_tick = (
        int(scale[1])
        * {"fs": 1e-6, "ps": 1e-3, "ns": 1, "us": 1e3, "ms": 1e6, "s": 1e9}[scale[2]]
    )
    scope, signals, widths = [], {}, {}
    for line in header.splitlines():
        parts = line.split()
        if not parts:
            continue
        if parts[0] == "$scope":
            scope.append(parts[2])
        elif parts[0] == "$upscope":
            scope.pop()
        elif parts[0] == "$var":
            code = parts[3]
            signals["/".join([*scope, parts[4]])] = code
            widths[code] = int(parts[2])
    events, now = defaultdict(list), 0
    for line in body.splitlines():
        line = line.strip()
        if not line or line.startswith("$"):
            continue
        if line.startswith("#"):
            now = int(line[1:])
            continue
        if line[0] in "bB":
            value, code = line[1:].split()
        elif line[0] in "01xXzZ":
            value, code = line[0], line[1:]
        else:
            raise ValueError(f"Unsupported VCD value: {line}")
        number = None if re.search("[xXzZ]", value) else int(value, 2)
        # 같은 Simulation 시각의 델타 갱신은 마지막 값으로 관찰한다.
        if events[code] and events[code][-1][0] == now:
            events[code][-1] = (now, number)
        else:
            events[code].append((now, number))
    return header + marker, signals, widths, events, ns_per_tick


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("vcd", type=Path)
    parser.add_argument("--output-dir", type=Path, default=Path("docs/evidence"))
    args = parser.parse_args()
    if args.vcd.resolve() == (args.output_dir / "control_lock_boundary.vcd").resolve():
        raise ValueError("Use another --output-dir to preserve the input VCD")
    header, signals, widths, events, scale = read_vcd(args.vcd)
    base = "tb_top_control_lock"
    tracks = [
        ("clk", f"{base}/clk", None),
        ("SW0 raw", f"{base}/lock_switch", None),
        ("KEY raw (pressed)", f"{base}/buttons", 6),
        ("locked", f"{base}/dut/locked", None),
        ("previous locked", f"{base}/dut/u_lock/r_was_locked", None),
        ("KEY pulse", f"{base}/dut/button_pulse", 6),
        ("KEY to controller", f"{base}/dut/control_buttons", 6),
        ("cook state", f"{base}/dut/cook_state", None),
        ("motor PWM", f"{base}/motor_pwm", None),
    ]
    if any(path not in signals for _, path, _ in tracks):
        raise ValueError("Required signals missing; use export_lock_waveform.tcl")
    times = {code: [t for t, _ in values] for code, values in events.items()}

    def value_at(path, tick, bit=None):
        code = signals[path]
        index = bisect_right(times[code], tick) - 1
        value = events[code][index][1] if index >= 0 else None
        if value is None:
            raise ValueError(f"Unknown VCD value at {tick}: {path}")
        return (value >> bit) & 1 if bit is not None else value

    switch, buttons = f"{base}/lock_switch", f"{base}/buttons"
    candidates = [
        t
        for t, value in events[signals[switch]]
        if t > 0
        and value == 0
        and value_at(switch, t - 1) == 1
        and value_at(buttons, t, 6) == 1
        and value_at(buttons, t - 1, 6) == 0
    ]
    if not candidates:
        raise ValueError("Simultaneous SW0 release / KEY press not found")
    trigger = candidates[0]
    start, end = max(0, trigger - round(20 / scale)), trigger + round(100 / scale)
    points = sorted(
        {start, end}
        | {t for values in events.values() for t, _ in values if start < t < end}
    )
    values = [[value_at(path, t, bit) for t in points] for _, path, bit in tracks]
    if not any(values[5]) or any(values[6]) or any(values[7]) or any(values[8]):
        raise ValueError(
            "Expected protected IDLE boundary is not present in this trace"
        )

    args.output_dir.mkdir(parents=True, exist_ok=True)
    crop = args.output_dir / "control_lock_boundary.vcd"
    lines = [header, f"#{start}", "$dumpvars"]

    def encode(code, value):
        return (
            f"{value}{code}"
            if widths[code] == 1
            else f"b{value:0{widths[code]}b} {code}"
        )

    for code in sorted(widths):
        path = next(path for path, key in signals.items() if key == code)
        lines.append(encode(code, value_at(path, start)))
    lines.append("$end")
    changes = defaultdict(list)
    for code, data in events.items():
        for t, value in data:
            if start < t <= end:
                changes[t].append(encode(code, value))
    for t in sorted(changes):
        lines.extend([f"#{t}", *changes[t]])
    crop.write_text("\n".join(lines) + "\n", encoding="utf-8")

    # Matplotlib은 문서 이미지 재생성에만 필요하며 RTL 검증의 의존성은 아니다.
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    plt.rcParams.update({
        "font.family": "DejaVu Sans", "svg.fonttype": "none",
        "svg.hashsalt": "fpga-microwave-oven-control-lock",
    })
    fig, axes = plt.subplots(len(tracks), 1, figsize=(13, 8), sharex=True)
    x = [(t - trigger) * scale for t in points]
    pulse_start = next(t for t in points if value_at(tracks[5][1], t, 6))
    pulse_end = next(
        t for t in points if t > pulse_start and not value_at(tracks[5][1], t, 6)
    )
    for index, (axis, (label, _, _), y) in enumerate(zip(axes, tracks, values)):
        axis.step(
            x,
            y,
            where="post",
            color="#136f63" if index >= 6 else "#245ca6",
            linewidth=1.8,
        )
        axis.axvspan(
            (pulse_start - trigger) * scale,
            (pulse_end - trigger) * scale,
            color="#f1b44c",
            alpha=0.22,
        )
        axis.axvline(0, color="#9aa4b2", linewidth=0.8, linestyle="--")
        axis.set(ylim=(-0.25, 1.25), yticks=[0, 1])
        axis.set_ylabel(
            label, rotation=0, ha="right", va="center", labelpad=25, fontsize=10
        )
        axis.grid(axis="x", color="#e6eaf0", linewidth=0.7)
        axis.spines[["top", "right"]].set_visible(False)
    axes[7].set_yticks([0], labels=["IDLE"])
    axes[-1].set(xlim=(-20, 100), xlabel="Time from simultaneous raw transition (ns)")
    fig.suptitle(
        "Control-lock release boundary — actual XSim trace", fontsize=16, x=0.54, y=0.98
    )
    fig.text(
        0.54,
        0.935,
        "100 MHz clock / scaled debounce: 3 cycles / shaded: KEY pulse blocked by release guard",
        ha="center",
        fontsize=10,
        color="#4b5563",
    )
    fig.subplots_adjust(left=0.22, right=0.98, top=0.90, bottom=0.08, hspace=0.23)
    fig.savefig(args.output_dir / "control_lock_boundary.png", dpi=160)
    svg = args.output_dir / "control_lock_boundary.svg"
    fig.savefig(svg, metadata={"Date": None})
    svg.write_text(
        "\n".join(line.rstrip() for line in svg.read_text(encoding="utf-8").splitlines()) + "\n",
        encoding="utf-8",
    )
    plt.close(fig)
    manifest = {
        "source_vcd": args.vcd.name,
        "source_sha256": hashlib.sha256(args.vcd.read_bytes()).hexdigest(),
        "crop_sha256": hashlib.sha256(crop.read_bytes()).hexdigest(),
        "timescale_ns_per_tick": scale,
        "trigger_ns": trigger * scale,
        "window_ns": [start * scale, end * scale],
        "key_pulse_ns": [pulse_start * scale, pulse_end * scale],
        "matplotlib_version": matplotlib.__version__,
        "note": "Actual XSim data, scaled debounce, not a hardware measurement.",
    }
    (args.output_dir / "control_lock_boundary.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    print(f"PASS: actual VCD cropped and rendered: {args.output_dir}")


if __name__ == "__main__":
    main()
