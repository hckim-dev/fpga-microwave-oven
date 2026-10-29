# FPGA Microwave Oven

**시간 설정부터 문 개폐·모터 구동·종료 알림까지, Basys3에서 구현한 전자레인지 제어 모형입니다.**

`Verilog` · `Basys3 / Artix-7` · `Vivado 2026.1` · `100 MHz`

**Testbench 16개 PASS · 100 MHz 내부 Timing 통과 · 실제 보드 정상 동작 확인**

https://github.com/user-attachments/assets/339a04de-37d3-44b4-93c6-2343d36fdcb4

## 주요 기능

| 기능 | 동작 |
| --- | --- |
| 시간 설정 | 로터리로 분·초 설정, 00:00~59:59 |
| 실행 제어 | 시작·일시정지·재개·취소 |
| 문 개폐 | SG90 서보 제어, 열기 요청 시 구동 차단·닫은 뒤 수동 재개 |
| 모터 제어 | 1 kHz PWM, 듀티 30/50/70/90% |
| 표시·소리 | 남은 시간/회전 패턴 교대, 버튼음·개폐 효과음·종료 알림 3회 |
| 조작 잠금 | SW0로 설정·시작·재개 차단, 정지·취소·개폐 허용 |

## 설계에서 해결한 문제

| 문제 | 구현 |
| --- | --- |
| 접점 잡음과 기동 중 오입력 | 2단 동기화·디바운싱·초기 누름 억제 |
| 여러 입력과 시간 만료가 겹치는 상황 | 정지 우선순위와 공통 실행 허가로 출력 제어 |
| 동작 중 PWM 설정 변경 | 주기 시작에서 새 설정 적용, 진행 중 펄스 보존 |
| 잠금 해제와 KEY 동시 입력 | 이전 잠금 상태를 보존해 의도하지 않은 시작 차단 |

RTL 14개를 단일 클럭으로 연결했습니다. [구조·FSM](docs/design.md) · [문제 해결 사례](docs/troubleshooting.md)

## 검증 결과

| Simulation | 보드 빌드 | 100 MHz 내부 Timing | 자원 사용 |
| --- | --- | --- | --- |
| Testbench 16개 PASS | Bitstream 생성·DRC 위반 0 | Setup +0.222 ns / Hold +0.122 ns | LUT 3.96% / FF 1.10% |

실제 보드의 기본 기능과 SW0 잠금은 정상 동작 확인을 받았습니다.
문 위치는 서보 명령·시간으로 추정하며, 실제 가열 장치와 위치 센서는 사용하지 않습니다.
[검증 결과](docs/verification.md)에서 Simulation·Timing·실기 확인 범위를 구분했습니다.

## 자세히 보기

| 문서 | 내용 |
| --- | --- |
| [설계](docs/design.md) | 모듈 구조·FSM·타이밍 정책 |
| [하드웨어](docs/hardware.md) | 부품·핀 연결·조작·확인 순서 |
| [검증](docs/verification.md) | 테스트 범위·합성/Timing 수치·실제 XSim 파형 |
| [문제 해결](docs/troubleshooting.md) | 실패 재현·원인·수정 결과 |
| [실행 방법](docs/reproduction.md) | Simulation·프로젝트 생성·Bitstream 빌드 |
