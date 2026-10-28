# 프로젝트 재현

확인 환경은 Windows, Python 3.14.6, Vivado/XSim 2026.1입니다.
다른 Vivado 버전에서의 실행 결과는 확인하지 않았습니다. 도구 설치 경로는 환경에 맞게 바꿉니다.

## 저장소·설정 검사

```powershell
python scripts/check_repository.py
python scripts/test_repository_checks.py
```

Part·보드 Top·활성 핀 45개·100 MHz 클럭·소스 등록·로컬 문서 링크·Git 제외 규칙을 검사합니다.
설정 회귀 9개는 실제 파일을 바꾸지 않고 잘못된 설정의 거부 여부를 확인합니다.

## 전체 Simulation

```powershell
python scripts/verify_step11.py --vivado-bin "C:/AMDDesignTools/2026.1/Vivado/bin"
```

`VIVADO_BIN` 환경 변수와 PATH도 지원합니다. `build/step11/<실행시각>/`에 compile·elaboration·
Simulation 로그와 WDB를 저장하며, 16개 TB 모두 PASS가 있어야 성공입니다.
기본 서보 Timing TB는 40 ms를 Simulation하고 외부 신호 위주로 WDB를 기록합니다.

## 새 Vivado 프로젝트

Vivado Tcl Console의 작업 디렉터리를 저장소 루트로 두고 실행합니다.

```tcl
source scripts/create_project.tcl
```

`build/vivado_step11/microwave_step11.xpr`을 만듭니다. Part를 직접 지정하므로 별도의
Basys3 board repository 설정에 의존하지 않습니다. 기존 생성 프로젝트가 있으면 덮어쓰지 않습니다.
Design Top은 `top_microwave_oven`, 기본 Simulation Top은 `tb_top_control_lock`입니다.
RTL 14개·TB 16개·활성 XDC 하나를 등록합니다.

원본 `fpga-microwave-oven.xpr`도 사용할 수 있습니다. 외부에서 XPR이 갱신된 경우 RTL/TB
편집 내용은 먼저 저장하되, 열려 있던 프로젝트 설정으로 디스크의 XPR을 덮어쓰지 말고
프로젝트를 닫았다 다시 열어 등록을 반영합니다. 단위 TB를 검사할 때는 Simulation Sources에서
해당 TB를 Set as Top으로 선택하고 Run Behavioral Simulation → Run All을 실행합니다.
보드 Design Top은 변경하지 않습니다.

## 합성·배치배선·Bitstream

```powershell
New-Item -ItemType Directory -Force build
& "C:/AMDDesignTools/2026.1/Vivado/bin/vivado.bat" -mode batch -source scripts/build_board.tcl -log build/board.log -journal build/board.jou
```

결과는 `build/board/<실행시각>_<프로세스ID>/`에 저장합니다. 원본 XPR을 수정하거나 보드를
자동 프로그래밍하지 않습니다. 내부 setup/hold, 클럭 펄스 폭과 내부 제약 누락을 검사합니다.
`summary.txt`, `timing_summary.rpt`, `check_timing.rpt`, `pulse_width.rpt`, `drc.rpt`,
`cdc.rpt`, `methodology.rpt`를 함께 확인합니다. 외부 출력의 동기 Timing 요구 미정의 경고는
내부 Timing 검사와 구분하며 [검증 결과](verification.md)에 기록했습니다.

## Git 범위

RTL·TB·XDC·XPR·스크립트·문서를 관리합니다. 생성 프로젝트·캐시·실행 결과·대용량 WDB·
Bitstream은 `build/` 등에 보존하고 추적하지 않습니다. 선별한 문서용 PNG·SVG·짧은 VCD·
수치 요약은 `docs/evidence/`에서 관리합니다. `.wcfg`, `.mem`, `.coe`는 일괄 제외하지 않습니다.

## 파형 재생성

먼저 전체 Simulation을 실행합니다. 아래 `$simDir`는 실행 결과 경로로 바꿉니다.

```powershell
$repoRoot = (Get-Location).Path
$vivadoBin = "C:/AMDDesignTools/2026.1/Vivado/bin"
$simDir = "$repoRoot/build/step11/<실행시각>"
$env:LOCK_VCD_PATH = "$repoRoot/build/control_lock_full.vcd"
Push-Location $simDir
& "$vivadoBin/xsim.bat" tb_top_control_lock -tclbatch "$repoRoot/scripts/export_lock_waveform.tcl" -wdb "$repoRoot/build/control_lock_export.wdb"
Pop-Location
python scripts/render_lock_waveform.py build/control_lock_full.vcd --output-dir docs/evidence
```

XSim의 PASS와 오류 여부를 확인한 뒤 이미지를 생성합니다. 이미지 생성에는 Matplotlib이
필요하며 확인한 버전은 3.11.1입니다. 이 패키지는 RTL 검증의 의존성이 아닙니다.
전체 VCD는 build에 보존하고 선택 구간·PNG·SVG·해시만 docs에 저장합니다.
기록된 120 ns VCD만으로 다시 그릴 때는 원본 덮어쓰기를 피하도록 다른 출력 폴더를 사용합니다.

```powershell
python scripts/render_lock_waveform.py docs/evidence/control_lock_boundary.vcd --output-dir build/waveform_preview
```
