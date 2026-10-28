# FPGA Microwave Oven

Basys3에서 전자레인지의 시간 설정·동작·문 개폐·종료 알림을 재현한 Verilog 제어 시스템입니다.
EC11 입력을 안정화한 뒤 가열·도어 상태를 관리하고, SG90 서보·모터 PWM·FND·부저를 제어합니다.
추가 기능으로 SW0 조작 잠금을 구현했습니다.

**핵심 구현:** 단일 100 MHz 클럭 · 정지 우선순위 · 주기 경계 PWM 갱신 · 잠금 해제 경계 보호

| 확인 범위 | 결과 |
| --- | --- |
| 기능 구현 | 필수 기능 R01~R08 + 자체 아이디어 R09 |
| 자동 검증 | RTL Testbench 16개 PASS, 설정 회귀 9개 OK |
| 보드 빌드 | 합성·배치배선·Bitstream 생성, DRC 위반 0 |
| 100 MHz 내부 Timing | setup +0.222 ns / hold +0.122 ns |
| 자원 사용 | LUT 824/20,800 (3.96%), FF 459/41,600 (1.10%) |
| 실제 보드 | 기본 기능·SW0 잠금 정상 동작 확인 보고, 항목별 결과·영상 정리 중 |

수치는 Vivado 2026.1의 검증 시점 결과입니다. [공유용 검증 근거](docs/evidence/README.md)와
[전체 검증 이력](docs/verification.md)에 Simulation·합성·Timing·실기 확인을 구분했습니다.

## 기능과 조작

| 기능 | 조작·동작 |
| --- | --- |
| 시간 설정 | EC11 회전으로 선택 필드 ±1, btnL로 분/초 전환, 00:00~59:59 |
| 시작·일시정지·재개 | EC11 KEY, 닫힘 추정 상태와 0이 아닌 시간에서 시작 |
| 문 개폐 | J3 열기 / L3 닫기, 실행 중 열면 중단, 닫은 뒤 KEY로 수동 재개 |
| 모터 제어 | btnU/D, 1 kHz PWM 듀티 30/50/70/90%, 기본 50% |
| 취소·Reset | btnR은 시간 초기화·속도 유지, btnC는 전체 초기화·속도 50% |
| 표시 | 설정 필드 점멸, 실행 중 시간/circle 교대, 일시정지 시 구분점 점멸 |
| 소리·종료 | 버튼 BEEP·개폐 효과음, 만료 시 0000과 종료음 3회 후 대기 복귀 |
| 조작 잠금 | SW0=1·LD14 켜짐, 설정·시작·재개 차단, 정지·취소·개폐는 유지 |

외부 배선과 상태 LED는 [보드 연결](docs/integration.md), 실기 순서는
[하드웨어 확인](docs/hardware_test.md), 잠금 정책은 [조작 잠금](docs/control_lock.md)을 따릅니다.
문 닫힘은 센서 없이 서보 명령·대기 시간으로 추정하며, PWM 듀티는 실측 RPM 비율이 아닙니다.

## 구조

```mermaid
flowchart LR
  INPUT[입력 안정화·이벤트] --> LOCK[조작 잠금]
  LOCK --> COOK[시간·가열 FSM]
  INPUT --> DOOR[도어 FSM·서보]
  DOOR -->|닫힘 추정| COOK
  COOK --> OUTPUT[표시·소리·모터]
```

제어 흐름 요약입니다. 상세 신호·실제 FSM·설계 선택은 [설계 설명](docs/design.md)에 정리했습니다.
전체 RTL은 14개 모듈이며 외부 입력을 제외한 로직은 하나의 클럭과 clock enable을 사용합니다.

## 대표 검증: 잠금 해제와 KEY 동시 입력

![조작 잠금 해제 경계의 실제 XSim 파형](docs/evidence/control_lock_boundary.png)

SW0 해제와 KEY 입력이 함께 들어와도, 이전 잠금 상태가 해당 KEY 펄스를 차단해 IDLE을 유지합니다.
**필터 계수를 축소한 실제 Simulation 파형이며 하드웨어 실측이 아닙니다.**
[VCD·SVG·재생성 절차](docs/evidence/README.md)와 [문제 해결 과정](docs/troubleshooting.md)을 제공합니다.

## 검증 실행

대상은 Basys3 `xc7a35tcpg236-1`, 확인한 도구는 Vivado/XSim 2026.1입니다.
저장소 루트에서 Python 3과 본인의 Vivado 설치 경로로 실행합니다.

```powershell
python scripts/check_repository.py
python scripts/test_repository_checks.py
python scripts/verify_step11.py --vivado-bin "C:/AMDDesignTools/2026.1/Vivado/bin"
```

각 명령이 오류 없이 끝나야 합니다. 실행 결과와 파형은 Git에서 제외하는 `build/`에 저장됩니다.
원본 XPR을 수정하지 않고 16개 TB를 실행합니다. 새 프로젝트 생성·GUI Simulation·보드 빌드는
[재현 절차](docs/reproduction.md)를 참고하세요.

## 소스와 문서

| 경로 | 내용 |
| --- | --- |
| `fpga-microwave-oven.srcs/sources_1/new/` | RTL 14개, 보드 Top `top_microwave_oven` |
| `fpga-microwave-oven.srcs/sim_1/new/` | 자동 판정 TB 16개 |
| `fpga-microwave-oven.srcs/constrs_1/new/microwave_basys3.xdc` | 활성 보드 핀·클럭 제약 |
| `scripts/` | 저장소 검사·Simulation·프로젝트 재생성·보드 빌드·문서 파형 생성 |
| [문서 안내](docs/README.md) | 설계·모듈 계약·검증·검토 이력 |
| [요구사항 추적](docs/requirements.md) | R01~R09와 구현·검증·실기 근거 연결 |
| [시연 촬영 계획](docs/demo_plan.md) | 촬영 순서·확인 대상·자막안 |

기능 개발과 코드 검토는 마무리했습니다. 현재는 실기 증거와 발표자료를 정리하는 단계입니다.
실제 사진·영상은 제공받은 자료만 사용하며, 보드의 전기적 조건과 모형의 기구 보정 범위는
[하드웨어 기록](docs/hardware_test.md)에 별도로 남깁니다.
