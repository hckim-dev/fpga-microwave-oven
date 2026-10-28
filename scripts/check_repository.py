"""소스 등록, 핀 배정, Python 문법과 로컬 문서 링크를 검사한다."""

import ast
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from urllib.parse import unquote, urlsplit


def require(condition, message):
    if not condition:
        raise ValueError(message)


def main():
    root = Path(__file__).resolve().parents[1]
    source_root = root / "fpga-microwave-oven.srcs"
    rtl = sorted((source_root / "sources_1/new").glob("*.v"))
    tests = sorted((source_root / "sim_1/new").glob("*.v"))
    for path in rtl + tests:
        modules = re.findall(r"(?m)^module\s+(\w+)", path.read_text(encoding="utf-8"))
        require(modules == [path.stem], f"File/module name mismatch: {path.name}")

    project = ET.parse(root / "fpga-microwave-oven.xpr")
    registered = {}
    for fileset in project.findall(".//FileSet"):
        paths = []
        for entry in fileset.findall("File"):
            name = entry.attrib["Path"].replace(
                "$PSRCDIR/", "fpga-microwave-oven.srcs/"
            )
            name = name.replace("$PPRDIR/", "")
            path = (root / name).resolve()
            require(path.is_file(), f"Missing XPR source: {name}")
            paths.append(path)
        require(len(paths) == len(set(paths)), "Duplicate XPR source")
        registered[fileset.attrib["Name"]] = set(paths)
    require(registered["sources_1"] == set(rtl), "RTL registration mismatch")
    require(registered["sim_1"] == set(tests), "Testbench registration mismatch")
    xdc = source_root / "constrs_1/new/microwave_basys3.xdc"
    require(registered["constrs_1"] == {xdc}, "Active XDC mismatch")
    for fileset, names in (("sources_1", rtl), ("sim_1", tests)):
        option = project.find(
            f'.//FileSet[@Name="{fileset}"]/Config/Option[@Name="TopModule"]'
        )
        require(
            option is not None and option.get("Val") in {p.stem for p in names},
            f"Invalid selected Top: {fileset}",
        )

    pins = re.findall(
        r"PACKAGE_PIN (\w+) IOSTANDARD LVCMOS33\}\s+\[get_ports \{([^}]+)\}\]",
        xdc.read_text(encoding="utf-8"),
    )
    require(len(pins) == len({pin for pin, _ in pins}), "Duplicate package pin")
    require(len(pins) == len({port for _, port in pins}), "Duplicate XDC port")
    top = (source_root / "sources_1/new/top_microwave_oven.v").read_text(
        encoding="utf-8"
    )
    ports = set()
    for high, low, name in re.findall(
        r"(?m)^\s*(?:input|output)\s+wire\s*(?:\[(\d+):(\d+)\])?\s+(\w+)", top
    ):
        if high:
            ports.update(f"{name}[{i}]" for i in range(int(low), int(high) + 1))
        else:
            ports.add(name)
    require({port for _, port in pins} == ports, "Top/XDC port coverage mismatch")
    master = (
        source_root / "constrs_1/imports/digilent-xdc-master/Basys-3-Master.xdc"
    ).read_text(encoding="utf-8")
    reference = {
        name: pin
        for pin, name in re.findall(
            r"PACKAGE_PIN (\w+)\s+IOSTANDARD LVCMOS33.*?\[get_ports (\{[^}]+\}|\w+)\]",
            master,
        )
    }
    aliases = {
        "seg[7]": "dp",
        "door_open": "{JXADC[0]}",
        "door_close": "{JXADC[1]}",
        "rotary_s1": "{JC[1]}",
        "rotary_s2": "{JC[2]}",
        "rotary_key": "{JC[3]}",
        "motor_pwm": "{JA[0]}",
        "motor_in1": "{JA[1]}",
        "motor_in2": "{JA[2]}",
        "servo_pwm": "{JB[0]}",
        "buzzer": "{JB[1]}",
    }
    for pin, port in pins:
        name = aliases.get(port, "{" + port + "}" if "[" in port else port)
        require(reference.get(name) == pin, f"Board pin mismatch: {port}")

    for script in (root / "scripts").glob("*.py"):
        ast.parse(script.read_text(encoding="utf-8"), filename=str(script))
    for document in [root / "README.md", *(root / "docs").rglob("*.md")]:
        for target in re.findall(
            r"\[[^\]]+\]\(([^)]+)\)", document.read_text(encoding="utf-8")
        ):
            target = target.strip("<>")
            if not urlsplit(target).scheme and not target.startswith("#"):
                path = document.parent / unquote(target.split("#")[0])
                require(path.exists(), f"Broken local link: {document.name}: {target}")

    tracked = subprocess.run(
        ["git", "ls-files", "-z"], cwd=root, check=True, capture_output=True
    ).stdout
    ignored = subprocess.run(
        ["git", "check-ignore", "--no-index", "-z", "--stdin"],
        cwd=root,
        input=tracked,
        capture_output=True,
    )
    require(ignored.returncode in (0, 1), "git check-ignore failed")
    require(not ignored.stdout, "Ignored generated/local files are tracked")
    print(
        f"PASS: {len(rtl)} RTL, {len(tests)} TB, XPR sources/Top, {len(pins)} pins, "
        "Python syntax, local links, Git exclusions"
    )


if __name__ == "__main__":
    try:
        main()
    except (
        ValueError,
        OSError,
        ET.ParseError,
        SyntaxError,
        subprocess.CalledProcessError,
    ) as error:
        print(error, file=sys.stderr)
        sys.exit(1)
