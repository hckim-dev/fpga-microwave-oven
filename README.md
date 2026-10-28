# FPGA Microwave Oven

Basys3에서 시간 설정, 도어 서보, 모터 PWM, 표시와 효과음을 구현하는 Verilog 프로젝트입니다.
현재 **STEP 11: 조작 잠금(R09) 추가 및 16개 Simulation PASS** 상태입니다.
합성·배치배선·Bitstream 생성과 100 MHz 내부 Timing 검사를 통과했습니다.
사용자는 기본 동작이 정상이라고 보고했고 SG90 떨림은 자연스러운 동작으로 수용해 종결했습니다.
새 조작 잠금은 실기 확인 전이며, 항목별 실기 기록과 발표자료가 남아 있습니다.

- 대상: Basys3 / `xc7a35tcpg236-1`, 100 MHz
- 확인한 Simulator: Vivado XSim 2026.1
- HDL: Verilog `.v`, 단일 클럭과 clock enable 방식
- 구현 범위: 입력, 시간 제어, FND, 부저, 서보/도어, 모터 속도 설정과 PWM, SW0 조작 잠금

## 구성과 진행 상태

| 경로 | 내용 |
| --- | --- |
| `fpga-microwave-oven.srcs/sources_1/new/` | RTL 14개: 보드 Top과 입력·시간·표시·부저·도어·모터·잠금 |
| `fpga-microwave-oven.srcs/sim_1/new/` | 자동 판정 Testbench 16개 |
| `scripts/verify_step11.py` | 현재 16개 TB 실행 및 로그·Waveform 저장 |
| `scripts/verify_step10.py` | 이전 14개 TB 실행 |
| `scripts/check_repository.py` | FPGA Part·보드 Top·활성 핀/클럭·파일·문서·Git 검사 |
| `scripts/test_repository_checks.py` | 정상 설정과 잘못된 설정의 회귀 검사 9개 |
| `scripts/build_board.tcl` | 합성·배치배선·내부 Timing 검사·Bitstream 생성 |
| `scripts/verify_step9.py` | 이전 13개 TB 실행 |
| `scripts/verify_step8.py` | 이전 입력·시간·표시·부저·도어 11개 TB 실행 |
| `scripts/verify_step7.py` | 이전 입력·시간·표시·부저 8개 TB 실행 |
| `scripts/verify_step6.py` | 이전 입력·시간·표시 6개 TB 실행 |
| `scripts/verify_step5.py` | 이전 입력·시간 제어 4개 TB 실행 |
| `scripts/verify_step4.py` | 공통 XSim 실행 코드와 이전 2개 TB 실행 |
| `scripts/create_project.tcl` | 상대 경로로 STEP 11 보드 프로젝트 재생성 |
| `scripts/check_step4_project.tcl` | 원본 XPR의 Source/Top 읽기 전용 검사 |
| [전체 통합과 보드 연결](docs/integration.md) | 모듈 연결, 핀, LED와 실기 확인 순서 |
| [입력 Interface](docs/input_interface.md) | 극성, 이벤트와 Parameter 계약 |
| [시간·가열 제어 Interface](docs/controller_interface.md) | FSM, 시간과 우선순위 계약 |
| [FND 표시 Interface](docs/display_interface.md) | 스캔·화면·Timing·완료 통지 |
| [부저 Interface](docs/sound_interface.md) | 리듬·우선순위·입력 보존·출력 모드 |
| [서보·도어 Interface](docs/door_interface.md) | 펄스·도어 FSM·이동 대기·추정 상태 |
| [모터 Interface](docs/motor_interface.md) | 속도 단계·PWM 주기·정지 조건 |
| [조작 잠금](docs/control_lock.md) | SW0·LD14, 잠금 중 허용 조작과 검증 |
| [하드웨어 확인](docs/hardware_test.md) | 조작·실기 체크리스트·남은 관찰 |
| [전체 검토](docs/review.md) | 검토 기준·정리 내용·검증 결과 |
| [검증 기록](docs/verification.md) | 완료 조건, 시나리오와 실제 실행 결과 |
| [요구사항 추적](docs/requirements.md) | 구현·Simulation·실기·발표 근거 구분 |

## 검증 실행

Python 3과 Vivado XSim이 필요합니다. 저장소 루트에서 실행합니다.

```powershell
python scripts/check_repository.py
python scripts/test_repository_checks.py
python scripts/verify_step11.py --vivado-bin "C:/AMDDesignTools/2026.1/Vivado/bin"
```

경로는 본인의 설치 위치로 바꾸세요. `VIVADO_BIN` 환경 변수 또는 PATH도 지원합니다.
실행은 XPR을 열거나 변경하지 않으며 결과는 `build/step11/<실행시각>/`에 저장됩니다.
저장소 검사 PASS, Python 회귀 검사 9개 OK, 열여섯 Simulation PASS를 각각 확인합니다.
각 명령이 오류 없이 끝나야 전체 검증 성공으로 판정합니다.
기본 서보 Timing 검사만 약 40 ms의 Simulation 시간을 실행하며, 해당 WDB는 고속 내부
카운터 대신 외부 펄스·제어 신호를 기록합니다.
`build/`는 Git 추적 대상에서 제외합니다.

## Vivado에서 열기

기존 `fpga-microwave-oven.xpr`의 Design Top은 `top_microwave_oven`입니다.
조작 잠금 검사는 Simulation Sources에서 `tb_top_control_lock`을 Set as Top으로 선택하고
Run Behavioral Simulation → Run All → `PASS:`를 확인합니다.
외부에서 XPR이 갱신된 경우 RTL/TB 편집 내용은 먼저 저장하되, 열려 있던 프로젝트 설정으로
디스크의 XPR을 덮어쓰지 말고 프로젝트를 닫았다 다시 열어 소스 등록을 반영하세요.
보드 Design Top은 `top_microwave_oven`으로 유지하고 Simulation Top만 단위 TB로 바꿀 수 있습니다.
Top 테스트는 실제 버튼·로터리 포트를 구동하며 내부 이벤트를 강제 주입하지 않습니다.

새 경로에서 프로젝트를 재현하려면 Vivado Tcl Console에서 실행합니다.

```tcl
source scripts/create_project.tcl
```

`build/vivado_step11/`에 별도 프로젝트를 만들며 기존 생성 프로젝트를 덮어쓰지 않습니다.
Tcl Console의 작업 디렉터리가 다르면 스크립트의 절대 경로를 사용하세요.
보드 핀은 [통합 문서](docs/integration.md)의 표와 활성 `microwave_basys3.xdc`를 따릅니다.

합성부터 Bitstream까지 별도로 빌드하려면 저장소 루트에서 실행합니다.

```powershell
& "C:/AMDDesignTools/2026.1/Vivado/bin/vivado.bat" -mode batch -source scripts/build_board.tcl -log build/board.log -journal build/board.jou
```

`build/`가 없다면 먼저 `New-Item -ItemType Directory -Force build`로 만드세요.
결과는 `build/board/<실행시각>_<프로세스ID>/`에 저장되며 원본 XPR이나 보드에 기록하지 않습니다.
`summary.txt`, `timing_summary.rpt`, `drc.rpt`, `cdc.rpt`, `methodology.rpt`를 함께 확인합니다.
스크립트는 내부 setup/hold, 클럭 펄스 폭과 내부 제약 누락을 검사하며 위반 시 실패합니다. 외부 출력의 동기 Timing 규격은
미정의이며 내부 Timing 통과와 구분합니다. 실제 실행 근거는 [검증 기록](docs/verification.md)에 남깁니다.

## Git 관리 범위

RTL·Testbench·XDC, `.xpr`, 재현/검증 스크립트와 문서를 추적합니다.
Vivado의 `.cache`, `.hw`, `.ip_user_files`, `.runs`, `.sim`, `.gen`, `.tmp`,
`.Xil`과 로컬 `build/`, 루트에 생성되는 로그·파형·Bitstream 등은 제외합니다.
파형 표시 설정인 `.wcfg`와 소스 데이터인 `.mem`, `.coe`는 일괄 제외하지 않습니다.
발표용으로 선별한 Report·이미지·파형 등은 `docs/` 아래에서 명시적으로 관리할 수 있습니다.
자동 생성물의 추적 해제는 로컬 파일을 삭제하지 않으며 과거 커밋 이력도 변경하지 않습니다.

## 확인 범위

Simulation과 보드 빌드의 실제 결과·제약·경고는 [검증 기록](docs/verification.md)을 따릅니다.
자동화 과정에서 보드를 프로그래밍하지 않았습니다. 사용자 동작 보고와 측정·영상 근거는 구분합니다.
자체 아이디어(R09)는 SW0 조작 잠금으로 구현했습니다. 실기 항목별 기록과 최종 발표자료는 남아 있습니다.
외부 부품의 전원 조건과 부저 직결의 전기적 적합성도 검증 완료로 간주하지 않습니다.
센서 없이 사용하는 도어 상태는 서보 명령·시간 경과 기반 추정값입니다.
서보 펄스 폭과 이동 대기 기본값은 기구와 부하에서 보정하기 전의 값이며 실제 각도·도착을 보장하지 않습니다.
기존 교육자료 원본은 이 저장소의 구현·검증 근거로 대체하거나 복제하지 않습니다.
