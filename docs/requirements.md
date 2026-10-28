# 요구사항 추적

PDF의 기능 요구와 예시를 구분합니다. STEP 10은 기본 기능의 Top 통합 단계이며 실제 보드 검증 완료를 뜻하지 않습니다.

| ID | 요구사항 | 현재 구현 Source | Simulation/Testbench | 실제 Hardware | 발표 근거 |
| --- | --- | --- | --- | --- | --- |
| R01 | 로터리로 분·초 설정 | `input_frontend.v`, `rotary_decoder.v`, `microwave_controller.v` | 입력·제어·연계 TB PASS: 00:00~59:59 설정과 경계 | 미확인 | STEP 4/5 로그·WDB |
| R02 | 문 열기/닫기 효과음 | `door_controller.v`, `sound_controller.v`: 수락 이벤트를 리듬으로 재생 | 부저/도어 연계 TB PASS: 실제 도어 FSM 이벤트와 중복/이동 요청 필터링 | 미확인 | STEP 7/8 로그·WDB |
| R03 | 버튼마다 BEEP | `input_frontend.v`, `sound_controller.v` | 입력·부저 TB PASS: 동시/연속 요청 보존, ON/OFF 길이, 큐 초과 표시 | 미확인 | STEP 4/7 로그·WDB |
| R04 | 동작 종료 알림 | `microwave_controller.v`, `display_controller.v`, `sound_controller.v` | 연계 TB PASS: 0000 3회 점멸과 동일한 종료음 envelope, 3초 후 복귀 | 미확인 | STEP 5/6/7 로그·WDB |
| R05 | 동작 표시 | `display_controller.v`, `fnd_scanner.v` | 표시 TB PASS: 3,600개 시간 값, 선택 필드·일시정지·circle 교대·스캔 | 미확인 | STEP 6 로그·WDB |
| R06 | 취소 | 시간·표시·소리·도어 이동 취소, 서보/모터 출력 차단 | 제어·표시·부저·도어·모터 및 Top TB PASS: 실제 입력 경로 취소·동시 요청 우선순위·출력 차단 | 미확인 | STEP 5~9 로그·WDB |
| R07 | 서보로 문 개폐 | `door_controller.v`, `servo_controller.v` | 서보·도어·연계 TB PASS: 프레임/폭, 명령 적용, 대기/개폐 추정과 가열 차단 | 미확인 | STEP 8 로그·WDB, 실제 개폐는 미확보 |
| R08 | 모터 PWM 속도 제어 | `motor_controller.v`, 가열 제어 실행 허가 | 모터/연계 TB PASS: 1 kHz·30/50/70/90%, 경계 반영, 정지·재개·만료 우선 | 미확인 | STEP 9 로그·WDB, 실제 RPM/회전은 미확보 |
| R09 | 자체 아이디어 | 기본 기능 안정화 후 선정 | 미실행 | 미확인 | 미확보 |

STEP 10의 `top_microwave_oven.v`와 `tb_top_microwave_oven`이 R01~R08의 모듈을 연결합니다.
실제 버튼·로터리 입력부터 출력까지 시나리오를 검사하며 STEP 10 로그·WDB를 통합 근거로 사용합니다.
개별 수치·경계 조건은 각 단위 TB가 보완합니다.

공통 기반 `reset_synchronizer.v`, `tick_generator.v`, `btn_debouncer.v`는
`tb_input_frontend`와 `tb_timebase`로 검증했습니다. 전체 기능의 실제 검증 상태는
[검증 기록](verification.md)을 따릅니다.

종료 시 0의 3회 점멸과 circle/남은 시간 교대는 PDF의 예시이며 STEP 3 설계에 채택했습니다.
STEP 6/7에서 표시와 종료음을 구현하고 Simulation으로 검증했습니다. 실제 표시·청취 확인은 남아 있습니다.

최종 제출은 개요, 구현, Architecture, FSM, 주요 Source, Testbench 결과,
중요 동작 자막을 넣은 실제 영상, Troubleshooting, 구현 후기와 결론을 포함한 PPT입니다.
발표자료 및 실기 사진/영상은 아직 작성·확보하지 않았습니다.
