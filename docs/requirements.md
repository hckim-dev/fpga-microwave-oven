# 요구사항 추적

PDF의 기능 요구와 예시를 구분합니다. STEP 6 완료는 전체 기능 및 실제 보드 검증 완료를 뜻하지 않습니다.

| ID | 요구사항 | 현재 구현 Source | Simulation/Testbench | 실제 Hardware | 발표 근거 |
| --- | --- | --- | --- | --- | --- |
| R01 | 로터리로 분·초 설정 | `input_frontend.v`, `rotary_decoder.v`, `microwave_controller.v` | 입력·제어·연계 TB PASS: 00:00~59:59 설정과 경계 | 미확인 | STEP 4/5 로그·WDB |
| R02 | 문 열기/닫기 효과음 | 버튼 입력 이벤트만 | `tb_input_frontend`: 열기/닫기 입력 PASS. 소리 미구현 | 미확인 | 미확보 |
| R03 | 버튼마다 BEEP | 7개 버튼 이벤트만 | `tb_input_frontend`: 바운스·홀드·동시 입력 PASS. BEEP 미구현 | 미확인 | STEP 4 입력 검증 기록 |
| R04 | 동작 종료 알림 | `microwave_controller.v`, `display_controller.v`: 만료와 0000 3회 점멸 | 표시·제어 연계 TB PASS: 3,000 tick 뒤 대기 복귀, 완료 통지 재시도. 소리 미구현 | 미확인 | STEP 5/6 로그·WDB |
| R05 | 동작 표시 | `display_controller.v`, `fnd_scanner.v` | 표시 TB PASS: 3,600개 시간 값, 선택 필드·일시정지·circle 교대·스캔 | 미확인 | STEP 6 로그·WDB |
| R06 | 취소 | `microwave_controller.v`: 전 상태 시간 초기화·IDLE·실행 허가 차단 | 제어·연계 TB PASS. 실제 모터·서보·소리 취소는 이후 통합 필요 | 미확인 | STEP 5 로그·WDB |
| R07 | 서보로 문 개폐 | 입력 이벤트·가열 시작 차단/중단만 | 제어·연계 TB PASS: 논리적 닫힘 조건과 수동 재개. 서보 미구현 | 미확인 | STEP 5 로그·WDB, 실제 개폐는 미확보 |
| R08 | 모터 PWM 속도 제어 | 속도 +/- 이벤트만 | `tb_input_frontend`: 입력 PASS. PWM 미구현 | 미확인 | 미확보 |
| R09 | 자체 아이디어 | 기본 기능 안정화 후 선정 | 미실행 | 미확인 | 미확보 |

공통 기반 `reset_synchronizer.v`, `tick_generator.v`, `btn_debouncer.v`는
`tb_input_frontend`와 `tb_timebase`로 검증했습니다. 전체 기능의 실제 검증 상태는
[검증 기록](verification.md)을 따릅니다.

종료 시 0의 3회 점멸과 circle/남은 시간 교대는 PDF의 예시이며 STEP 3 설계에 채택했습니다.
STEP 6에서 표시를 구현하고 Simulation으로 검증했습니다. 종료음과 실제 보드 확인은 남아 있습니다.

최종 제출은 개요, 구현, Architecture, FSM, 주요 Source, Testbench 결과,
중요 동작 자막을 넣은 실제 영상, Troubleshooting, 구현 후기와 결론을 포함한 PPT입니다.
발표자료 및 실기 사진/영상은 아직 작성·확보하지 않았습니다.
