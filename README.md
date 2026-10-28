# FPGA Microwave Oven

Basys3에서 시간 설정, 도어 서보, 모터 PWM, 표시와 효과음을 구현하는 Verilog 프로젝트입니다.
현재 **STEP 6: 입력·시간 제어·FND 표시의 RTL 및 Simulation 검증 완료** 상태이며,
전자레인지 전체 기능과 실제 보드 동작은 아직 구현·검증하지 않았습니다.

- 대상: Basys3 / `xc7a35tcpg236-1`, 100 MHz
- 확인한 Simulator: Vivado XSim 2026.1
- HDL: Verilog `.v`, 단일 클럭과 clock enable 방식
- 구현 범위: 입력, 시간 설정·countdown·시작/정지/취소, FND 화면·circle·종료 점멸

## 구성과 진행 상태

| 경로 | 내용 |
| --- | --- |
| `fpga-microwave-oven.srcs/sources_1/new/` | RTL 8개: 입력·시간 제어·표시 |
| `fpga-microwave-oven.srcs/sim_1/new/` | 자동 판정 Testbench 6개 |
| `scripts/verify_step6.py` | 현재 6개 TB 실행 및 로그·Waveform 저장 |
| `scripts/verify_step5.py` | 이전 입력·시간 제어 4개 TB 실행 |
| `scripts/verify_step4.py` | 공통 XSim 실행 코드와 이전 2개 TB 실행 |
| `scripts/create_project.tcl` | 상대 경로로 STEP 6 프로젝트 재생성 |
| `scripts/check_step4_project.tcl` | 원본 XPR의 Source/Top 읽기 전용 검사 |
| [입력 Interface](docs/input_interface.md) | 극성, 이벤트와 Parameter 계약 |
| [시간·가열 제어 Interface](docs/controller_interface.md) | FSM, 시간과 우선순위 계약 |
| [FND 표시 Interface](docs/display_interface.md) | 스캔·화면·Timing·완료 통지 |
| [검증 기록](docs/verification.md) | 완료 조건, 시나리오와 실제 실행 결과 |
| [요구사항 추적](docs/requirements.md) | 구현·Simulation·실기·발표 근거 구분 |

## 검증 실행

Python 3과 Vivado XSim이 필요합니다. 저장소 루트에서 실행합니다.

```powershell
python scripts/verify_step6.py --vivado-bin "C:/AMDDesignTools/2026.1/Vivado/bin"
```

경로는 본인의 설치 위치로 바꾸세요. `VIVADO_BIN` 환경 변수 또는 PATH도 지원합니다.
실행은 XPR을 열거나 변경하지 않으며 결과는 `build/step6/<실행시각>/`에 저장됩니다.
여섯 Simulation의 `PASS:` 확인과 오류 검출을 모두 통과해야 성공으로 판정합니다.
`build/`는 Git 추적 대상에서 제외합니다.

## Vivado에서 열기

기존 `fpga-microwave-oven.xpr`에는 이번 단계의 RTL과 TB가 등록되어 있습니다.
열려 있던 Vivado에서는 디스크 변경을 반영하도록 프로젝트를 다시 여세요.
현재 Design Top `input_frontend`는 입력 처리 단위이며 보드용 최종 Top이 아닙니다.
기존 프로젝트의 사용자 선택 Top은 유지합니다. 새 기능은 Simulation Sources에서
`tb_display_controller`, `tb_controller_display`를 각각 Set as Top으로 선택한 뒤
Run Behavioral Simulation을 실행하고 PASS를 확인하세요. 필요하면 Run All을 누릅니다.
XDC의 기능 핀과 클럭 제약은 아직 활성화하지 않았으므로 현재 프로젝트로 보드용
Bitstream을 생성하지 않습니다.

새 경로에서 Simulation 프로젝트를 재현하려면 Vivado Tcl Console에서 실행합니다.

```tcl
source scripts/create_project.tcl
```

Tcl Console의 작업 디렉터리가 다르면 스크립트의 절대 경로를 사용하세요.
`build/vivado_step6/`에 별도 프로젝트를 만들며 원본 XPR을 덮어쓰지 않습니다.
별도 프로젝트의 Design Top은 `display_controller`, Simulation Top은
`tb_display_controller`입니다. 모두 단위 검증용이며 보드 결선을 포함하지 않습니다.

## Git 관리 범위

RTL·Testbench·XDC, `.xpr`, 재현/검증 스크립트와 문서를 추적합니다.
Vivado의 `.cache`, `.hw`, `.ip_user_files`, `.runs`, `.sim`, `.gen`, `.tmp`,
`.Xil`과 로컬 `build/`, 루트에 생성되는 로그·파형·Bitstream 등은 제외합니다.
파형 표시 설정인 `.wcfg`와 소스 데이터인 `.mem`, `.coe`는 일괄 제외하지 않습니다.
발표용으로 선별한 Report·이미지·파형 등은 `docs/` 아래에서 명시적으로 관리할 수 있습니다.
자동 생성물의 추적 해제는 로컬 파일을 삭제하지 않으며 과거 커밋 이력도 변경하지 않습니다.

## 확인 범위

본 단계에서는 합성·Implementation·Timing·Bitstream·보드 검증을 실행하지 않았습니다.
기존에 생성된 Vivado 산출물은 보존하며 현재 RTL의 검증 근거로 사용하지 않습니다.
외부 부품의 전원 조건과 부저 직결의 전기적 적합성도 검증 완료로 간주하지 않습니다.
센서 없이 사용하는 도어 상태는 이후 서보 명령 기반 추정값으로 구현할 계획입니다.
기존 교육자료 원본은 이 저장소의 구현·검증 근거로 대체하거나 복제하지 않습니다.
