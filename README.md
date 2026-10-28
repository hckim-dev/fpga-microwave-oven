# FPGA Microwave Oven

Basys3 전자레인지 과제의 Verilog 프로젝트입니다.
현재 STEP 4의 Reset·시간 기준·버튼·로터리 입력 처리와 Simulation 검증까지 완료했습니다.
전체 전자레인지 기능과 실제 보드 동작은 아직 구현·검증하지 않았습니다.

- 대상: Basys3 / xc7a35tcpg236-1, 100 MHz
- Simulator: Vivado XSim 2026.1
- RTL 5개, 자동 판정 Testbench 2개
- [입력 Interface](docs/input_interface.md)
- [검증 기록](docs/verification.md)
- [요구사항 추적](docs/requirements.md)

## 실행

Python 3과 Vivado XSim이 필요합니다. 저장소 루트에서 실행합니다.

    python scripts/verify_step4.py --vivado-bin "C:/AMDDesignTools/2026.1/Vivado/bin"

경로는 실제 설치 위치로 바꾸세요. VIVADO_BIN 환경 변수 또는 PATH도 지원합니다.
결과 로그와 Waveform은 build/step4/ 아래에 분리 저장합니다.
두 TB의 PASS와 오류 검사를 모두 통과해야 성공입니다.

## Vivado

기존 XPR에서 tb_input_frontend와 tb_timebase를 각각 Simulation Top으로 선택하여 실행합니다.
Design Top input_frontend는 입력 처리 단위이며 보드용 최종 Top이 아닙니다.
XDC의 기능 핀·클럭 제약은 아직 활성화하지 않았습니다.

별도 프로젝트는 Vivado Tcl Console에서 다음 명령으로 생성합니다.
작업 디렉터리가 다르면 스크립트의 절대 경로를 사용하세요.

    source scripts/create_project.tcl

build/vivado_step4에 프로젝트를 생성하며 기존 XPR을 덮어쓰지 않습니다.
보드 파일 없이 FPGA Part를 직접 지정해 Simulation을 재현합니다.

합성·Implementation·Timing·Bitstream·보드 검증은 이 단계에서 수행하지 않았습니다.
기존 교육자료 원본과 자동 생성물은 구현 소스에 포함하지 않습니다.
