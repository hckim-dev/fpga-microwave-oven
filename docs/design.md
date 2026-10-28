# 설계 설명

## 제어 흐름

```mermaid
flowchart LR
  RAW[버튼·EC11] --> FRONT[input_frontend]
  FRONT --> LOCK[control_lock]
  SW0[SW0] --> LOCK
  LOCK --> CORE[microwave_controller]
  CORE -->|상태| LOCK
  FRONT --> DOOR[door_controller]
  DOOR -->|닫힘 추정| CORE
  DOOR -->|허가·목표| SERVO[servo_controller]
  SERVO -->|명령 적용 확인| DOOR
  LOCK --> MOTOR[motor_controller]
  CORE -->|상태·실행 허가| MOTOR
  CORE -->|상태·시간| DISPLAY[display_controller]
  DISPLAY --> SCAN[fnd_scanner]
  DISPLAY -->|alert_done| CORE
  DISPLAY -->|alert_on| SOUND[sound_controller]
  CORE -->|DONE 상태| SOUND
  FRONT -->|원래 버튼 이벤트| SOUND
  DOOR -->|수락한 개폐 이벤트| SOUND
```

전체 Top은 배선과 상태 LED를 담당합니다. 입력 계층의 Reset 동기화기·tick·debouncer·
rotary decoder를 포함해 RTL 파일은 14개입니다. 외부 입력만 비동기이며, 나머지는 모두
100 MHz `clk`를 사용합니다. `tick_1ms`는 새 클럭이 아닌 한 클럭 폭의 enable입니다.

| 경계 | 전달하는 의미 |
| --- | --- |
| 입력 → 제어 | 극성을 정규화한 누름 이벤트와 회전 방향 |
| 잠금 → 가열/모터 | 설정·시작·재개만 선별한 이벤트 |
| 도어 → 가열 | 명령·대기 시간에 따른 닫힘 추정 |
| 서보 → 도어 | 목표를 프레임 시작에서 적용했다는 확인 |
| 가열 → 모터 | RUN 상태와 정지 요청을 반영한 실행 허가 |
| 표시 → 가열/부저 | 완료 통지와 공유 종료 알림 envelope |

## 가열 FSM

```mermaid
stateDiagram-v2
  [*] --> IDLE
  IDLE --> RUN: KEY / 시간 있음·닫힘·잠금 해제
  RUN --> PAUSED: KEY 또는 열기 또는 닫힘 조건 상실
  PAUSED --> RUN: KEY / 닫힘·잠금 해제
  RUN --> DONE: 마지막 1초 만료
  DONE --> IDLE: 알림 완료 또는 KEY
  RUN --> IDLE: 취소
  PAUSED --> IDLE: 취소
  DONE --> IDLE: 취소
```

Reset은 어느 상태에서나 IDLE·0초·초 선택으로 초기화합니다. 분·초 편집은 IDLE에서만
허용하고 각 필드를 0~59로 포화시킵니다. 분수 초를 보존하므로 일시정지/재개마다
새 1초를 기다리는 방식으로 시간이 늘어나지 않습니다.

동시 이벤트 우선순위는 Reset → 취소 → 열기 → 닫기 → 닫힘 조건 상실 → 만료 →
KEY → 필드 선택 → 회전입니다. 정지 이벤트는 상태 레지스터 갱신 전에도 실행 허가를
차단합니다. 이는 입력 동기화·필터 이후의 논리 동작이며 물리 스위치의 무지연 반응을 뜻하지 않습니다.

## 도어 FSM

```mermaid
stateDiagram-v2
  [*] --> UNKNOWN
  UNKNOWN --> OPENING: 열기
  UNKNOWN --> CLOSING: 닫기
  CLOSED --> OPENING: 열기
  OPEN --> CLOSING: 닫기
  OPENING --> OPEN: 명령 적용 확인 후 대기 완료
  CLOSING --> CLOSED: 명령 적용 확인 후 대기 완료
  OPENING --> UNKNOWN: 취소
  CLOSING --> UNKNOWN: 취소
```

Reset 시 문이 닫혔다고 가정하지 않습니다. 서보 프레임에 목표가 적용된 뒤 기본 500 ms를
계수하고 OPEN/CLOSED로 추정합니다. 적용 확인은 프레임 시작을 뜻하며 실제 도착 피드백이 아닙니다.
닫힌 뒤 가열을 자동 재개하지 않고 KEY를 다시 요구합니다. 이동 중 중복·반대 요청은
무시하되 적용 확인과 대기 계수는 계속 처리합니다.

모터·서보 출력은 주기 카운터와 래치로 제어합니다. 별도 FSM을 추가하지 않았습니다.
부저는 BEEP_IDLE/BEEP_ON/BEEP_GAP 상태와 개폐 효과음 큐를 사용합니다.

## 설계 선택

| 선택 | 목적·제약 | 확인 근거 |
| --- | --- | --- |
| 2단 동기화 + 안정화 필터 | 비동기 접점과 짧은 잡음 처리, 10 ms 버튼/2 ms 로터리 기본값 | 입력 TB·기본 Timing TB·CDC |
| 단일 클럭 + enable | 상태·카운터·출력 사이 클럭 도메인 분리 방지 | Top 연결·100 MHz STA |
| 실행 허가의 조합 차단 | 취소·개폐·KEY·만료 시 다음 상태만 기다리지 않고 구동 차단 | 모터/Top TB |
| 주기 시작에서 목표 래치 | HIGH/LOW 도중 속도·서보 목표 변경에 따른 중간 펄스 변경 방지 | 모터·서보 TB |
| FND 자리 전환 시 2클럭 소등 | 패턴 선출력 후 다음 자리 활성화 | 표시 TB, 실제 잔상 측정과 구분 |
| 종료 표시·소리의 시간 기준 공유 | 두 알림의 별도 타이머 불일치 방지 | 표시/부저 연계 TB |
| 완료 통지를 DONE 종료까지 유지 | 상위 이벤트와 겹쳐도 완료 통지를 잃지 않음 | 제어/표시 연계 TB |
| 잠금 해제 직후 한 클럭 차단 | 해제와 같은 시점의 KEY·설정 이벤트 재사용 방지 | 실제 VCD·잠금 Top TB |

BEEP은 도어 효과음보다 우선하며 중단한 효과음은 이어 재생합니다. 종료 알림의 3초 기준은
상위 소리가 재생돼도 늘어나지 않습니다. 큐는 유한하며 초과 시 LD13으로 알립니다.
도어 취소는 이동 중 서보를 차단하지만 안정 위치의 유지 펄스는 계속 출력합니다.

상세 포트와 Parameter는 [모듈 문서 안내](README.md), 핀과 LED는 [전체 통합](integration.md),
검증 수치와 한계는 [검증 근거](evidence/README.md)를 따릅니다.
