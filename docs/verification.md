# 검증 기록

## STEP 11 — 조작 잠금(R09)

2026-10-28, Vivado/XSim 2026.1에서 SW0 조작 잠금을 구현하고 검증했습니다.
SG90 떨림은 사용자가 자연스러운 동작으로 수용해 이슈를 종결했습니다.
서보 구동 정책·펄스 폭·결선은 변경하지 않았으며 별도의 전기·기구 측정을 추가한 것은 아닙니다.

| 확인 항목 | 실제 결과 |
| --- | --- |
| 기존 14개 + 신규 2개 TB | 16개 모두 PASS, 컴파일/elaboration/Simulation 경고·오류 없음 |
| 잠금 조합 | 네 상태별 128개 버튼 조합·CW/CCW 허용 규칙 PASS |
| SW0 입력 | 2단 동기화, 잡음, 잠금/해제 경계, 최소 계수 PASS |
| 기동·Reset | 입력 준비 전 차단, SW0=1 기동·Reset 유지 PASS |
| IDLE/PAUSED | 시간·필드·속도·시작/재개 차단 PASS |
| RUN | 잠금 후에도 계수·구동 유지, KEY 일시정지 허용 PASS |
| 해제 경계 | 누른 채인 KEY·해제와 동시 KEY 모두 시작 차단, 새 누름 필요 PASS |
| 정지·개폐 | 잠금 중 취소·문 개폐·이동 취소 및 UNKNOWN 복구 PASS |
| DONE | 잠금 중 만료·KEY 확인·3초 알림 후 자동 복귀 PASS |
| 부저 | 차단된 실제 버튼 누름의 BEEP 유지 PASS |
| Python 설정 회귀 | 9개 OK, Part·Top·45개 핀·100 MHz 검사 PASS |
| 합성·배치배선·Bitstream | 완료, DRC 위반·routing error 0 |
| 내부 Timing | 100 MHz, setup +0.222 ns / hold +0.122 ns / pulse +4.500 ns |
| 내부 제약 | no_clock·미제약 내부 endpoint·loops 등 자동 검사 모두 0 |
| CDC | CDC-3 Info 10개 + CDC-9 Info 1개, 경고 없음 |
| 자원 | LUT 824/20,800 (3.96%), FF 459/41,600 (1.10%), IOB 45, BUFG 1 |
| 새 기능 실기 확인 | 미실행 |

Simulation 근거는 `build/step11/20261028_152115_169069/`의 16개 PASS 로그와 WDB입니다.
`tb_control_lock`은 마스크와 필터 경계를 검사하고 `tb_top_control_lock`은 실제 Top의
버튼·로터리·SW0 포트만 구동합니다. 기존 Top TB는 SW0=0으로 고정해 이전 전체 기능을 확인합니다.
신규 RTL/TB는 포맷 정리 후 최종 전체 Simulation과 보드 빌드를 다시 실행했습니다.
가열·시간·표시·부저·도어·서보·모터의 기존 모듈 본체는 그대로입니다.

보드 빌드 근거는 `build/board/20261028_152128_18104/`의 `summary.txt`, Timing·CDC·DRC·
Methodology·자원·route 보고서와 `microwave.bit`입니다. 보드 프로그래밍은 실행하지 않았습니다.
기존 두 합성 경고 유형(Synth 8-6014, 8-7129)은 이전과 같고, 외부 출력 Timing 미정의에 따른
TIMING-18 경고 32개도 남습니다. 내부 Timing 통과와 실제 I/O·부품 동작은 구분합니다.

재생성 Tcl은 `build/vivado_step11/` 프로젝트 생성과 compile order를 통과했습니다.
원본 XPR에 RTL 14개·TB 16개를 등록하고 보드 Top과 활성 XDC를 검사합니다.
동작·새 핀·LED 변경 및 실기 순서는 [조작 잠금](control_lock.md)을 따릅니다.

### 잠금 해제·KEY 동시 입력 회귀

추가한 raw 입력 검사에서 SW0 해제와 KEY 누름의 필터 결과가 같은 클럭에 바뀌면
초기 구현이 시작을 허용하는 것을 재현했습니다. 수정 전 근거는
`build/step11_unlock_boundary_before_fix/simulate.txt`의
`simultaneous unlock and KEY must not start` 실패입니다.

해제 직후 한 클럭 동안 설정 허가를 보류하는 레지스터를 추가했습니다.
시작·재개·설정에는 이 경계 보호를 적용하고, 일시정지·취소·개폐·종료 확인은 유지합니다.
같은 raw 입력 회귀와 잠금 단위 경계 검사 모두 최종 16개 PASS에 포함됩니다.
최종 근거는 위의 `20261028_152115_169069` Simulation과
`20261028_152128_18104` 보드 빌드이며 초기 빌드와 구분합니다.

## STEP 10 최종 재검토

기준 커밋 `7b13034` 이후 저장소 검사기의 Part·보드 Top·비활성 XDC 오판을 보완했습니다.
Python 설정 회귀 9개가 OK이고 기존 RTL TB 14개가
`build/step10/20261028_144554_446843/`에서 모두 PASS입니다.
원본 XPR 읽기 검사와 소스만 복사한 경로에서의 프로젝트 재생성도 통과했습니다.
해당 검토 당시 RTL/TB의 토큰과 활성 XDC는 이전 검증본과 같아 합성·Timing을 재실행하지 않았습니다.
세부 결과와 종결 보류 사유는 [전체 검토](review.md)의 최종 재검토 절을 따릅니다.

## 전체 검토 후 재검증

2026-10-28, 코드 형식·주석 정리와 검증 도구 보완 후 기존 14개 TB를 모두 다시 실행해 PASS를 확인했습니다.
최종 근거는 `build/step10/20261028_143034_003952/`이며 로그에 경고·오류가 없습니다.
`build/board/20261028_143047_20084/`에서 합성·배치배선·Bitstream을 다시 생성했습니다.
LUT 785개, FF 436개, setup +0.283 ns, hold +0.122 ns로 이전 결과와 같습니다.
보완한 내부 제약 누락 검사와 pulse width 검사(+4.500 ns)도 통과했습니다.
DRC 위반 0이며 외부 출력 Timing 미정의 경고 32개와 기존 합성 경고는 이전과 같습니다.
코드 변경 근거, 주석 전수 조사와 부정 검사 결과는 [전체 검토](review.md)를 따릅니다.
사용자 기본 동작 정상 보고 및 SG90 떨림은 [하드웨어 확인](hardware_test.md)에 별도로 기록했습니다.

## STEP 10 - 보드 Top 통합과 빌드

2026-10-28, Vivado/XSim 2026.1 build 6511674에서 실행했습니다.

| 확인 항목 | 실제 결과 |
| --- | --- |
| 기존 13개 + Top 통합 TB | 14개 모두 PASS, 컴파일/elaboration/Simulation 경고·오류 없음 |
| Top raw 입력 | 기동 중 KEY 억제, 짧은 bounce, CW/CCW·분초 선택, 속도 변경 PASS |
| 전체 동작 경로 | UNKNOWN 시작 차단, 닫기 후 수동 시작, 정지/재개, 개폐 중단, 취소 PASS |
| 완료 연계 | 만료 시 모터 정지, timeout 1회, DONE 3,000 tick, 표시/소리 envelope 일치 PASS |
| 동시 요청 | 취소 > 열기 > 닫기/KEY, 이동 중 취소와 Reset 출력 차단 PASS |
| 합성·배치배선·Bitstream | 완료, routing error 0, DRC 위반 0 |
| 100 MHz 내부 Timing | WNS +0.283 ns, WHS +0.122 ns, TNS/THS 0 |
| Pulse width slack | +4.500 ns, 실패 endpoint 0 |
| 내부 제약 누락 | no_clock 0, unconstrained_internal_endpoints 0 |
| CDC | CDC-3 Info 9개 + CDC-9 Info 1개, Warning/Critical 없음 |
| 자원 사용량 | LUT 785/20,800 (3.77%), FF 436/41,600 (1.05%), IOB 44, BUFG 1 |
| 프로젝트 재생성·원본 XPR 읽기 검사 | RTL 13개·TB 14개 등록 PASS, 보드 Top과 활성 XDC 확인 |
| 보드 프로그래밍·실제 개폐/회전/청취 | 미실행 |

최종 Simulation 근거는 `build/step10/20261028_135954_842384/`입니다.
Top TB는 raw 포트만 조작하며 내부 상태·event를 force하지 않습니다.
분수 초의 정지 보존은 1,500 tick 동안 확인했고, 완료 3,000 tick도 축소하지 않았습니다.
Parameter를 축소한 통합 테스트와 기본 100 MHz Timing을 검사하는 기존 단위 TB를 구분합니다.
파형은 WDB로 저장했으며 GUI 파형의 육안 검토를 완료했다는 의미는 아닙니다.

최종 보드 빌드 근거는 `build/board/20261028_140007_14780/`의
`summary.txt`, `timing_summary.rpt`, `utilization.rpt`, `route_status.rpt`,
`cdc.rpt`, `drc.rpt`, `methodology.rpt`, `exceptions.rpt`, `microwave.bit`입니다.
콘솔 기록은 `build/step10_board_final_console.txt`입니다.
기존 XPR·보드에 기록하지 않는 `scripts/build_board.tcl`로 새로 생성했습니다.
실행마다 산출물을 분리하며 Git에는 생성 프로젝트·Bitstream·대용량 파형을 포함하지 않습니다.

### 경고 조사와 수정

첫 빌드 `build/board/20261028_135732_12936/`에서는 LUTAR-1 Warning 1개가 발생했습니다.
기동 대기의 `synced_reset || !ready` 조합식이 로터리 decoder의 비동기 CLR을 구동했습니다.
해당 구조는 조합 glitch가 의도치 않은 Reset으로 작용할 가능성이 있어 그대로 두지 않았습니다.
`rotary_decoder.enable`을 추가하고 `ready`를 동기식 기동 대기 입력으로 연결했습니다.
비동기 Reset은 `synced_reset`만 연결하며 enable 해제 시 누적량·seed·이벤트를 초기화합니다.
기존 2전이 단위 인스턴스도 enable을 명시했습니다. 전체 회귀와 재빌드 후 LUTAR-1은 0개입니다.

최종 합성의 Synth 8-6014는 `PassiveBuzzer=0`에서 사용하지 않는 톤 카운터/FF 제거입니다.
Synth 8-7129는 모터의 필드 선택 비트와 가열 제어의 속도 비트를 사용하지 않는다는 경고입니다.
버튼은 Top에서 각 소비 모듈로 연결되며, 모터가 속도 비트를 처리하는 것을 통합 TB로 확인했습니다.
이 경고를 숨기기 위한 설정이나 불필요한 dummy 로직은 추가하지 않았습니다.

최종 Methodology에는 TIMING-18 Warning 32개가 남습니다. LED/FND/서보/부저/모터 출력에
외부 동기 수신기의 output delay 요구를 정의하지 않았기 때문입니다. 상수 LOW인 IN2는 제외됩니다.
비동기 보드 입력 10개는 input arrival false path로 보고되며, CDC 보고서에서 9개의 2단 입력
동기화기와 1개의 Reset 동기화기에만 도달하는 것을 확인했습니다. FF 간 경로는 검사합니다.
외부 Timing 요구를 임의로 만들거나 경고를 억제하지 않았습니다.
따라서 위 slack은 **설정한 내부 Timing 제약의 결과**이며 모든 외부 I/O Timing이나
실제 모터·서보·부저 동작 검증을 뜻하지 않습니다.

`clockInfo.txt`가 Vivado의 부수 산출물임을 확인해 루트 제외 규칙을 추가했습니다.
이후 빌드는 출력 디렉터리에서 수행해 같은 파일도 build 안에 남깁니다.
보드 핀·상태 LED·실기 확인 순서는 [전체 통합](integration.md)을 따릅니다.

## STEP 9 - 모터 PWM과 가열/도어 연계

2026-10-28, XSim 2026.1에서 `scripts/verify_step9.py`로 기존 11개와 신규 2개 TB를
실행하여 모두 PASS를 확인했습니다. 최종 근거는
`build/step9/20261028_134733_933724/`의 열세 PASS 로그와 WDB입니다.

| 완료 조건 | 실제 결과 |
| --- | --- |
| 기본 100 MHz·100,000클럭 주기·1 kHz PWM | 네 듀티 모두 축소 없이 PASS |
| 30/50/70/90%의 정확한 HIGH 길이 | 각각 30,000/50,000/70,000/90,000클럭 PASS |
| 기본 50%, 상하한 포화, 증가/감소 동시 입력 유지 | PASS |
| HIGH 중 감소와 LOW 중 증가가 현재 펄스에 영향 없음 | PASS |
| 주기 마지막 클럭의 요청이 다음 주기에 반영 | PASS |
| IDLE/RUN/PAUSED 설정, DONE/상위 이벤트의 설정 차단 | PASS |
| RUN이라도 실행 허가가 없으면 설정 차단 | PASS |
| 정지 즉시 PWM/방향 LOW, 재개 시 새 주기 | PASS |
| 취소 후 속도 보존, Reset 시 50% | PASS |
| 도어 UNKNOWN/열림 상태의 실행 차단과 수동 재개 | PASS |
| 일시정지·열기·취소·만료·Reset 정지 | PASS |
| 만료와 속도 입력 동시 발생 시 만료 우선 | PASS |
| STEP 4~8 회귀 | 기존 11개 TB PASS |
| 실제 모터 회전·RPM·기동·전류·관성 | 미확인 |

`tb_motor_controller`는 가열 상태·실행 허가·버튼 이벤트를 직접 공급합니다.
축소 주기 10클럭에서 현재/다음 주기의 경계와 정지·재시작을 검사하고,
기본 주기 100,000클럭으로 네 듀티의 모든 샘플을 비교합니다.
관찰 신호는 `scenario`, `cook_state`, `run_enable`, `buttons`, `speed_level`, `duty`,
`pwm`, `in1/in2`, `default_pwm`, `default_duty`와 내부 적용 설정/카운터입니다.
기본 Timing 검사는 총 400,000클럭, 약 4 ms의 Simulation이며 실측 시간이 아닙니다.

`tb_motor_control`은 가열·도어·서보·모터를 연결합니다. tick 및 PWM/서보 주기와 도어
대기만 축소하고 실제 상태·이벤트 경로를 사용합니다. 도어 미확인 시 시작 차단,
닫은 뒤 명시적 시작, 실행/일시정지 중 속도 변경, 열기 중단·재개, 취소·만료·Reset을
검사합니다. 만료 직전 속도 증가를 같은 클럭에 공급해 출력 차단과 설정 보존을 확인합니다.
관찰 신호는 `scenario`, `cook_state`, `door_state`, `remaining_seconds`, `run_enable`,
`speed_level`, `duty`, `pwm`, `in1/in2`, `servo_pwm`입니다. 전체 Integration은 아직 아닙니다.

### 만료/속도 동시 입력 회귀

기존 실행 허가는 DONE 상태 갱신 뒤에 내려가므로, 만료와 속도 입력이 같은 클럭이면
이전 RUN 상태를 보고 다음 속도 설정이 변경될 수 있었습니다.
현재 테스트와 수정 전 가열 RTL을 build 아래 별도 복사본에서 실행해
`expiration must gate run before state update` 실패를 확인했습니다.
근거는 `build/step9_timeout_regression_before_fix/simulate.txt`입니다.

실행 허가에 현재 만료 조건을 포함하고, 모터 설정도 RUN의 실행 허가 조건을 따르도록
수정했습니다. FSM·포트·승인된 우선순위는 바꾸지 않았습니다.
같은 회귀 검사가 수정 후 PASS이며 전체 이전 테스트도 통과했습니다.

최종 컴파일·elaboration·Simulation 로그에는 경고·오류가 없습니다.
XDC와 결선은 변경하지 않았으며 실제 모터 RPM이나 정지 거리를 이 결과로 보장하지 않습니다.
재생성 Tcl도 Vivado에서 실행해 RTL 12개·TB 13개 프로젝트와 compile order를 확인했습니다.
원본 XPR의 기존 Top은 유지하고 파일 참조 26개와 문서 링크를 검사했습니다.
합성·Implementation·Timing·Bitstream·보드 실행은 이번 단계에서 수행하지 않았습니다.

## STEP 8 - 서보·도어 제어

2026-10-28, XSim 2026.1에서 `scripts/verify_step8.py`로 기존 8개와 신규 3개 TB를
실행하여 모두 PASS를 확인했습니다. 최종 근거는
`build/step8/20261028_133450_768322/`의 열한 PASS 로그와 WDB입니다.

| 완료 조건 | 실제 결과 |
| --- | --- |
| 기본 100 MHz·20 ms 프레임과 1/1.5 ms 펄스 폭 | 4,000,000클럭, 두 전체 프레임을 축소 없이 PASS |
| HIGH 도중 목표 변경 시 다음 프레임부터 반영 | PASS |
| 최초/변경 명령의 1클럭 적용 통지와 반복 프레임 중복 통지 없음 | PASS |
| disable/Reset 즉시 펄스 차단, 재활성 시 새 프레임 | PASS |
| 작은 프레임·펄스 폭, MoveTimeMs=1 계수 | PASS |
| UNKNOWN 기동, 명령 적용 전 이동 완료 금지 | PASS |
| 명령 확인 후 기본 500 tick 대기 경계 | PASS |
| 열기 우선, 중복/이동 중 요청 필터링과 계수 지속 | PASS |
| 이동 취소 후 UNKNOWN, 완료 위치에서 취소 시 유지 명령 | PASS |
| 닫힘 추정 전 시작 차단, 실행 중 열기 중단과 수동 재개 | PASS |
| 도어 FSM 수락 이벤트의 효과음 재생, 중복 요청은 BEEP만 | PASS |
| 취소 시 시간·서보 이동·대기 효과음 폐기와 닫기 복구 | PASS |
| STEP 4~7 회귀 | 기존 8개 TB PASS |
| 실제 문 위치·서보 각도/전류·기구 부하·이동 시간 | 미확인 |

`tb_servo_controller`는 기본 Parameter로 두 프레임 동안 PWM·적용 통지를 매 클럭
기대값과 대조합니다. 첫 프레임 HIGH 중 목표를 변경해도 첫 펄스는 100,000클럭,
다음 프레임 펄스는 150,000클럭인지 검사합니다. 별도 축소 인스턴스에서 disable/Reset,
중간 목표 왕복과 재시작도 확인합니다. 관찰 신호는 `scenario`, `enable`, `target_open`,
`servo_pwm`, `applied`, `default_pwm`, `default_applied`입니다.
약 40 ms 동안 고속 내부 카운터를 모두 기록하지 않고 이 외부 신호만 WDB에 기록합니다.

`tb_door_controller`는 서보 적용 통지를 직접 공급합니다. 확인 전 1,000 tick이 지나도
닫힘으로 바뀌지 않는지, 적용 확인 뒤 499/500 tick 경계와 취소 우선순위를 검사합니다.
관찰 신호는 `scenario`, `state`, `door_closed`, `servo_enable`, `target_open`,
`open_request`, `close_request`, `applied`, `open_event`, `close_event`, `cancel`입니다.
tick 간격만 줄이고 기본 500회 이동 계수는 유지합니다.

`tb_door_control`은 도어·서보·가열·부저를 연결합니다. 이 연계 TB에서만 서보 프레임과
이동 대기 Parameter를 축소합니다. 초기 UNKNOWN, 닫기와 KEY 동시 입력, 명시적 시작,
실행 중 열기, 닫힘 후 별도 KEY 재개, 이동 취소·복구, 수락된 닫기 효과음 완료와
중복 닫기의 효과음 미발생을 확인합니다. 관찰 신호는 `scenario`, `cook_state`, `door_state`,
`servo_pwm`, `applied`, `open_event/close_event`, `remaining_seconds`, `run_enable`,
`buzzer`, `sound_busy`입니다. 이는 도어 경로의 Interface 검증이며 전체 Integration은 아닙니다.

최종 컴파일·elaboration·Simulation 로그에는 경고·오류가 없습니다.
XPR의 사용자 선택 Top과 Vivado 저장 상태는 보존하고 신규 파일만 등록했습니다.
재생성 스크립트도 Vivado에서 실행해 별도 STEP 8 프로젝트 생성과 compile order 갱신을
완료했습니다. 해당 프로젝트의 RTL 11개·TB 11개와 원본 XPR의 Source 참조 23개를 확인했습니다.
XDC와 기존 가열/표시/부저 RTL은 변경하지 않았습니다.
합성·Implementation·Timing·Bitstream·보드 다운로드·실제 개폐는 수행하지 않았습니다.
펄스 폭과 이동 대기는 실기 보정 전 초기값이며 실제 닫힘 검증을 대신하지 않습니다.

## STEP 7 - 부저와 표시 연계

2026-10-28, XSim 2026.1에서 `scripts/verify_step7.py`로 기존 6개와 신규 2개 TB를
실행하여 모두 PASS를 확인했습니다. 최종 근거는
`build/step7/20261028_132252_599669/`의 여덟 PASS 로그와 WDB입니다.

| 완료 조건 | 실제 결과 |
| --- | --- |
| BEEP 40 tick ON, 20 tick 무음, 버튼마다 요청 계수 | PASS |
| 취소를 제외한 6개 버튼 동시 입력 보존 | PASS |
| 열기 ON/OFF/ON과 닫기 연속 ON 리듬 | PASS |
| BEEP 우선 재생과 도어 효과음 진행 보존·재개 | PASS |
| 도어 효과음 FIFO 순서와 동시에 dequeue/enqueue | PASS |
| BEEP 큐 동시 dequeue/enqueue | PASS |
| 큐 용량 초과의 포화/폐기와 sticky overflow 표시 | PASS |
| 취소 시 재생/대기 폐기 후 BEEP 하나만 재생 | PASS |
| Reset 즉시 출력 차단과 큐 초기화 | PASS |
| ON/OFF 및 수동 부저 carrier 모드 | PASS |
| 기본 25,000클럭 반주기, 2 kHz carrier | 축소 없이 PASS |
| 최소 계수 Parameter 1 | PASS |
| FND/종료음 동일 envelope, 3,000 DONE tick 중 1,500 ON tick | PASS |
| 종료 후 자동 IDLE, 취소/KEY 뒤 오래된 알림 없음 | PASS |
| STEP 4~6 회귀 | 기존 6개 TB PASS |
| 실제 부저 음량·음색·전류·직결 적합성 | 미확인 |

`tb_sound_controller`는 버튼·수락된 도어 이벤트·종료 envelope를 직접 공급합니다.
관찰 신호는 `scenario`, `buttons`, `open_event`, `close_event`, `alert_active/on`,
`buzzer`, `sound_active`, `busy`, `overflow`와 내부 큐·재생 단계입니다.
리듬은 실제 기본 40/20/70 tick을 유지하고 tick 간격만 4클럭으로 축소합니다.
별도 carrier 인스턴스는 기본 25,000클럭 반주기를 유지하여 75,000클럭을 대조합니다.
다중 입력, 재생 중 입력, 큐 입출력 동시성, 용량 초과와 복구를 자동 판정합니다.

`tb_display_sound`는 제어·표시·부저를 연결합니다. 도어 닫힘은 TB가 공급하고 실제 도어
수락 이벤트도 TB에서 별도로 입력합니다. 1초 가열 후 3초 종료 표시/음향 envelope,
자동 대기 복귀, 종료 중 취소·KEY, 버튼 BEEP 후 도어 효과음 순서를 확인합니다.
관찰 신호는 `scenario`, `state`, `remaining_seconds`, `alert_on`, `alert_done`,
`buzzer`, `sound_active`, `done_ticks`, `alert_on_ticks`, `seg/an`입니다.
이는 논리 출력과 Interface 검사이며 실제 청취나 전체 Hardware Integration 결과가 아닙니다.

종료 ON 구간을 표시부의 추가 출력 `alert_on`으로 공유했습니다. 출력 추가 후 기존 표시 TB의
미연결 경고를 확인하여 두 TB도 새 신호에 연결하고 위상/완료 후 소등 검사를 추가했습니다.
최종 컴파일·elaboration·Simulation 로그에는 경고·오류가 없습니다.
기존 제어 상태·우선순위와 XDC는 변경하지 않았습니다.
원래 남아 있던 `input_frontend.v` 변경은 공백 제거 비교로 기능 변화 없는 정렬임을 확인했고,
사용자 요청에 따라 이번 커밋에 포함합니다. 기존 입력 TB도 함께 통과했습니다.

Vivado 프로젝트 재생성도 실행하여 RTL 9개·TB 8개 등록과 compile order 갱신을 완료했습니다.
원본 XPR의 파일 참조와 문서 링크는 정적으로 검사했습니다. 합성·Implementation·Timing·
Bitstream·보드 다운로드·실제 청취는 이번 단계에서 수행하지 않았습니다.

## STEP 6 - FND 표시

2026-10-28, XSim 2026.1에서 `scripts/verify_step6.py`로 기존 4개와 신규 2개 TB를
실행하여 모두 PASS를 확인했습니다. 최종 Simulation 근거는
`build/step6/20261028_130517_707922/`의 여섯 PASS 로그와 WDB입니다.

| 완료 조건 | 실제 결과 |
| --- | --- |
| 00:00~59:59의 3,600개 값, 네 자리와 DP 위치 | seg/an 출력 대조 PASS |
| active-low 한 자리 선택과 자리 사이 2클럭 소등·패턴 선출력 | PASS |
| 대기 중 선택 필드 점멸과 필드 전환 시 위상 초기화 | PASS |
| 일시정지 중 숫자 유지와 구분점 점멸 | PASS |
| 실행 중 1초마다 시간/circle 화면 교대 | PASS |
| 100 ms마다 외곽 6개 선분 회전 | PASS |
| 종료 시 0000의 500 ms ON/OFF 3회 | PASS |
| 정확히 3,000 DONE tick 후 제어부의 IDLE 복귀 | PASS |
| 도어 이벤트 우선 처리 뒤 완료 통지 재시도 | PASS |
| 종료 표시 도중 취소·KEY 확인, 이후 오래된 완료 신호 없음 | PASS |
| Reset 중 소등, Parameter 1의 계수 폭·종료 처리 | PASS |
| STEP 4/5 입력·시간 제어 회귀 | 기존 4개 TB PASS |
| 실제 밝기·잔상·보드 표시와 전체 출력 통합 | 미실행 |

`tb_display_controller`는 상태·남은 초·필드 선택을 입력하고 모든 자리의 `seg/an`을
기대 패턴과 비교합니다. 관찰할 신호는 `scenario`, `state`, `remaining_seconds`,
`select_minutes`, `tick_1ms`, `seg`, `an`, `alert_done`입니다.
기본 500/1,000/100 tick 경계는 유지하고, 한 tick을 5클럭 간격으로 공급합니다.
3,600개 시간 값을 모두 대조하며 IDLE, RUN, PAUSED, DONE의 표시 정책을 별도로 검사합니다.

`tb_controller_display`는 제어부와 표시부를 연결합니다. 도어 닫힘은 TB의 상수로 공급하고,
1초 가열 만료부터 3초 종료 점멸 뒤 IDLE 복귀까지 자동 판정합니다. 완료 직후 열기 이벤트,
종료 중 취소와 KEY 확인으로 완료 통지가 누락되거나 지연 발생하지 않는지 검사합니다.
관찰 신호는 `scenario`, `state`, `remaining_seconds`, `timeout_pulse`, `alert_done`,
`done_ticks`, `seg`, `an`입니다. 이는 제어·표시 Interface 검사이며 전체 Integration은 아닙니다.

최종 컴파일·elaboration·Simulation 로그에 경고·오류는 없습니다.
WDB는 생성했지만 GUI에서 파형을 시각 검토한 결과는 아닙니다.
XDC 및 기존 시간 제어 RTL은 변경하지 않았고 합성·Implementation·Timing·Bitstream·
보드 다운로드는 수행하지 않았습니다. 이후 종료음은 같은 알림 시간 기준에 연계해야 합니다.

Vivado에서 재생성 스크립트를 실행해 RTL 8개·TB 6개의 별도 프로젝트 생성과 compile order
갱신도 완료했습니다. 원본 XPR의 등록 내용은 build 아래 복사본에서 읽기 전용으로 확인했습니다.
복사본에는 사용자 생성 산출물을 옮기지 않아 IPUserFilesDir와 이전 synth_1 GeneratedRun
파일 부재 경고가 발생했습니다. 등록된 RTL/TB와 Top 검사는 통과했으며, 이 경고를 없애기 위해
원본 설정이나 산출물을 변경하지 않았습니다.

## STEP 5 - 시간·가열 제어

2026-10-28, XSim 2026.1에서 `scripts/verify_step5.py`로 현재 TB 4개를 실행했습니다.
STEP 4 입력 테스트 2개를 포함한 회귀 검사입니다.

| 완료 조건 | 실제 결과 |
| --- | --- |
| 분/초 개별 0~59 포화와 00:00~59:59 설정 | PASS |
| 분/초 선택과 회전 동시 입력, 반대 회전 동시 입력 | PASS |
| 0초·도어 열림 상태의 시작 차단 | PASS |
| 1,000 tick 후 감소 및 01:00 -> 00:59 | PASS |
| RUN/PAUSED 편집 차단과 부분 시간 보존·재개 | PASS |
| 닫힘 조건 상실 또는 열기 요청의 실행 중단 | PASS |
| 문 닫기만으로 자동 재개하지 않음 | PASS |
| 열기 > 닫기/만료/KEY, 만료 > KEY, 취소 > 나머지 | PASS |
| DONE 확인과 한 클럭 만료 이벤트, 0초 underflow 방지 | PASS |
| IDLE/RUN/PAUSED/DONE에서 취소, DONE 외부의 alert_done 무시 | PASS |
| 원시 로터리·KEY·개폐·취소 입력부터 제어 결과까지 | PASS |
| STEP 4 입력·시간 기준 회귀 | PASS |
| 실제 보드 및 전체 출력과의 통합 | 미실행 |

`tb_microwave_controller`는 논리 이벤트를 직접 공급합니다. 입력/관찰 신호는
`scenario`, `button_pulse`, `rotary_cw/ccw`, `tick_1ms`, `door_closed`, `alert_done`,
`state`, `remaining_seconds`, `select_minutes`, `run_enable`, `timeout_pulse`,
내부 부분 시간 `r_elapsed_ms`입니다. 상태·시간·이벤트 횟수를 기대값과 자동 비교합니다.
1클럭을 1 ms tick으로 사용하되 내부 1초당 1,000 tick은 유지합니다.

`tb_input_controller`는 기존 입력 RTL과 제어부만 연결합니다. 바운스 제거 후 CW 한 클릭으로
1초를 설정하고, KEY 길게 누름으로 한 번 시작한 뒤 열기·닫기·재개·자연 만료·취소를 검사합니다.
입력과 tick Parameter만 축소합니다. 도어 상태는 TB의 논리 입력이며 실제 서보/센서가 아닙니다.
이는 단위 간 Interface 검사이며 전체 전자레인지 Integration 단계는 아닙니다.

최종 실행 근거는 `build/step5/20261028_124423_193913/`의 네 PASS 로그와 WDB입니다.
재실행 결과도 `build/step5/<실행시각>/`에 분리 저장합니다. 최종 실행의 컴파일·elaboration·
Simulation 로그에는 경고·오류가 없습니다.
파형은 기록했지만 GUI 시각 검토는 하지 않았습니다. 합성·Implementation·Timing·
Bitstream·보드 실행은 이번 단계에서 수행하지 않았습니다.

기존 XPR의 사용자 선택 Top을 유지하고 새 RTL 1개와 TB 2개를 등록했습니다.
Vivado 읽기 전용 검사로 RTL 6개·TB 4개 등록을 확인했으며 검사 전후 원본 XPR의 SHA-256은
동일했습니다. 별도 프로젝트 재생성도 현재 STEP 5 구성으로 실행하여 성공했습니다.

## STEP 4 - 입력 기반

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
