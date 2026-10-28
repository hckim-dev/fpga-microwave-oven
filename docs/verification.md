# STEP 4 검증 기록

## 완료 조건과 실제 결과

2026-10-28, Windows의 Vivado XSim **2026.1 / SW Build 6511674**에서
`scripts/verify_step4.py`로 xvlog 컴파일, xelab elaboration, XSim Simulation을 수행했습니다.

| 계획된 검증 | 실제 결과 |
| --- | --- |
| Reset 비동기 인가, 2클럭 동기 해제 | PASS |
| 외부 Reset 미인가 상태의 FPGA 구성 직후 초기화 | PASS |
| 기동 시 눌린 버튼과 엔코더 초기 위상의 가짜 이벤트 방지 | PASS |
| 버튼 7개: 잡음, 누름, 홀드, 떼기 바운스, 동시 입력 | PASS |
| EC11 KEY 극성 반전 | active-low 가정의 Simulation PASS, 실기 미확인 |
| CW/CCW, 부분 역회전과 왕복 전이 상쇄 | PASS |
| 2비트 잘못된 전이와 이후 복구 | PASS |
| Reset 중 부분 회전량 폐기 | PASS |
| tick/debounce 계수 1 및 클릭당 전이 2/4 | PASS |
| 기본 100 MHz·1 ms tick·10 ms debounce 정확한 경계 | 축소 없이 PASS |
| 실제 EC11·버튼·보드 동작 | 미실행 |

`tb_input_frontend`는 주기를 축소하여 약 10 us 동안 시나리오를 실행합니다.
관찰 신호: `scenario`, `ready`, `synced_reset`, `button_raw`, `button_down`,
`button_pulse`, `ab`, `cw`, `ccw`, `invalid`, `tick_1ms`.
기대값은 이벤트 횟수·1클럭 폭·상태 및 간격으로 자동 판정합니다.

`tb_timebase`는 기본 Parameter 그대로 약 10 ms를 실행합니다.
100,000클럭마다 tick이 나오고, 두 동기화 클럭 뒤 1,000,000클럭 연속 안정 시
버튼이 반영되는 경계를 검사합니다. 이는 Simulation 시간이며 실측 보드 시간이 아닙니다.

최종 실행 로그 및 원시 Waveform은 `build/step4/<실행시각>/`에 생성됩니다.
각 TB의 `simulate_*.txt`에 `PASS:`가 있으며 최종 실행의 컴파일/실행 로그에는 경고·오류가 없습니다.
WDB는 생성했지만 GUI에서 파형을 시각 검토한 결과는 아닙니다.
공개 저장소의 재현 근거는 TB와 실행 스크립트이며, 로컬 build 폴더는 추적하지 않습니다.

원본 XPR도 Vivado에서 읽기 전용으로 열어 RTL 5개, TB 2개와 Top 등록을 확인했습니다.
`scripts/create_project.tcl`로 별도 프로젝트 생성과 compile order 갱신도 완료했습니다.
이 작업은 합성 또는 Simulation 실행과 구분됩니다.

## 실행 중 발견한 문제

첫 실행에서는 XSim이 Windows 역슬래시 경로를 생성 Tcl의 escape로 해석하여
TB 실행 스크립트를 읽지 못했습니다. Simulator 종료 코드만으로는 이 실패가
성공처럼 보일 수 있었지만 PASS 마커 검사가 실패를 검출했습니다.
Tcl/WDB 인자는 슬래시 경로로 전달하도록 수정한 후 두 TB를 다시 실행하여 통과했습니다.

Verilog 모드에서 for 초기화문의 변수 선언 경고도 확인하여 모듈 범위 integer 선언으로
수정했습니다. SystemVerilog 모드로 전환하지 않았습니다.

원본 XPR의 보드 저장소 경로만으로 batch Vivado가 Basys3 BoardPart를 찾지 못하는
`Project 1-5713` 경고도 발견했습니다. 실제 설치된 `board.xml` 위치를 확인하고,
검사 프로세스의 `board.repoPaths`에 해당 저장소를 전달해 재검사했습니다.
검사 스크립트는 선택적인 `VIVADO_BOARD_REPO` 환경 변수를 지원합니다.
전역 설정과 원본 BoardPart 경로는 변경하지 않았습니다. 별도 재생성 프로젝트는
FPGA Part를 직접 지정하므로 BoardPart 설치 없이도 입력 Simulation을 재현할 수 있습니다.

## 이번 단계에서 하지 않은 검증

Synthesis, Implementation, Timing, Bitstream, 보드 다운로드는 수행하지 않았습니다.
입력 모듈은 최종 보드 Top이 아니며 XDC는 변경하지 않았습니다.
모터·서보 전원, 부저 직결, 실제 문 위치, 모터 RPM도 이 결과로 검증되지 않습니다.
실제 보드 입력 확인은 보드용 Top/XDC 준비 시점에 진행합니다.
