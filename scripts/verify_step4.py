"""Run STEP 4 Verilog tests with XSim, without opening or modifying the XPR."""

import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from datetime import datetime


def main(stage=4):
    parser = argparse.ArgumentParser(description=f"Run STEP {stage} XSim tests without modifying the XPR.")
    parser.add_argument("--vivado-bin", type=Path, help="Vivado bin directory (or set VIVADO_BIN)")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    tool_dir = args.vivado_bin or (Path(os.environ["VIVADO_BIN"]) if os.environ.get("VIVADO_BIN") else None)
    suffix = ".bat" if os.name == "nt" else ""

    def tool(name):
        candidate = tool_dir / (name + suffix) if tool_dir else shutil.which(name + suffix)
        if not candidate or not Path(candidate).is_file():
            parser.error(f"{name} not found; pass --vivado-bin or set VIVADO_BIN")
        return str(candidate)

    executables = {name: tool(name) for name in ("xvlog", "xelab", "xsim")}
    # 실행마다 별도 디렉터리를 만들어 이전 결과와 섞이지 않게 한다.
    out = root / "build" / f"step{stage}" / datetime.now().strftime("%Y%m%d_%H%M%S_%f")
    out.mkdir(parents=True)
    rtl = sorted((root / "fpga-microwave-oven.srcs" / "sources_1" / "new").glob("*.v"))
    test_dir = root / "fpga-microwave-oven.srcs" / "sim_1" / "new"
    tests = ["tb_input_frontend", "tb_timebase"]
    if stage >= 5:
        tests += ["tb_microwave_controller", "tb_input_controller"]
    if stage >= 6:
        tests += ["tb_display_controller", "tb_controller_display"]
    if stage >= 7:
        tests += ["tb_sound_controller", "tb_display_sound"]
    if stage >= 8:
        tests += ["tb_servo_controller", "tb_door_controller", "tb_door_control"]
    if stage >= 9:
        tests += ["tb_motor_controller", "tb_motor_control"]
    sources = rtl + [test_dir / f"{name}.v" for name in tests]
    compile_args = [executables["xvlog"], *map(str, sources)]

    def run(label, command):
        print(f"[{label}]", flush=True)
        result = subprocess.run(command, cwd=out, capture_output=True, text=True,
                                encoding="utf-8", errors="replace", timeout=180)
        output = result.stdout + result.stderr
        (out / f"{label}.txt").write_text(output, encoding="utf-8")
        print(output, end="", flush=True)
        if result.returncode or re.search(r"(?im)^\s*(?:ERROR|FATAL|Fatal):", output):
            raise RuntimeError(f"{label} failed; logs: {out}")
        return output

    run("compile", compile_args)
    for name in tests:
        run(f"elaborate_{name}", [executables["xelab"], name, "-s", name, "-debug", "typical"])
        tcl = out / f"{name}.tcl"
        wave_command = "log_wave -r /"
        if name == "tb_servo_controller":
            # 기본 40 ms 검사는 고속 내부 카운터 대신 외부 펄스·제어 신호만 기록.
            signals = ["scenario", "reset", "enable", "target_open", "servo_pwm", "applied",
                       "default_reset", "default_target", "default_pwm", "default_applied"]
            wave_command = "log_wave " + " ".join(f"/{name}/{signal}" for signal in signals)
        tcl.write_text(wave_command + "\nrun all\nquit\n", encoding="utf-8")
        # XSim 생성 Tcl에서 Windows 역슬래시가 escape로 해석되지 않게 한다.
        output = run(f"simulate_{name}", [executables["xsim"], name, "-tclbatch", tcl.as_posix(),
                                         "-wdb", (out / f"{name}.wdb").as_posix()])
        if "PASS:" not in output:
            raise RuntimeError(f"{name}: PASS marker absent; logs: {out}")
    print(f"PASS: STEP {stage} tests completed. Logs and waveforms: {out}")


def entry(stage=4):
    try:
        main(stage)
    except (RuntimeError, subprocess.TimeoutExpired) as error:
        print(error, file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    entry()
