# STEP 6 FND 표시 Interface

`display_controller`는 가열 상태와 남은 총 초를 화면 패턴으로 바꾸고,
`fnd_scanner`가 네 자리를 순차 구동합니다. 기존 stopwatch의 숫자 디코딩과
회전 선분 패턴을 활용하되 시간 형식, 화면 전환과 종료 알림 제어를 추가했습니다.
기존 시간·입력 RTL, XDC와 핀 배정은 변경하지 않았습니다.

## 포트와 기본 Timing

| 포트/Parameter | 계약 |
| --- | --- |
| `clk`, `reset` | 100 MHz와 동기 해제된 active-high Reset |
| `tick_1ms` | 한 클럭 폭의 1 ms enable, scanner 동작상 최소 3클럭 간격 |
| `state` | IDLE=0, RUN=1, PAUSED=2, DONE=3 |
| `remaining_seconds` | 0~3,599, 총 초 |
| `select_minutes` | 0=초 선택, 1=분 선택 |
| `seg[7:0]` | active-low `{DP,g,f,e,d,c,b,a}` |
| `an[3:0]` | active-low 자리 선택. an[0]은 가장 오른쪽 자리 |
| `alert_done` | DONE에서 3회 점멸 완료 후 1, 제어부가 DONE을 떠날 때까지 유지 |
| `BlinkHalfMs` | 기본 500, 선택 필드/구분점/종료 점멸의 반주기 |
| `ScreenPeriodMs` | 기본 1,000, RUN의 시간/circle 화면 교대 간격 |
| `CircleStepMs` | 기본 100, 외곽 선분 회전 간격 |

계수 Parameter는 1 이상의 정수입니다. Simulation에서는 tick 간격을 줄일 수 있지만
scanner의 소등·패턴 출력·자리 활성화에 필요한 클럭 간격을 유지해야 합니다.

Basys3는 공통 애노드 4자리이며 보드 회로에서 AN과 segment/DP가 모두 active-low입니다.
1 ms마다 자리를 바꾸므로 전체 4자리 주기는 4 ms입니다.
근거: [Digilent Basys3 Reference Manual, §8.1](https://digilent.com/reference/_media/basys3:basys3_rm.pdf).

## 화면 규칙

| 상태 | 화면 |
| --- | --- |
| IDLE | MM.SS, 선택 필드만 500 ms ON/OFF. 구분점은 유지 |
| RUN | 진입 후 첫 1초는 MM.SS, 다음 1초는 네 자리 circle, 반복 |
| PAUSED | 남은 시간은 계속 표시, 구분점만 500 ms ON/OFF |
| DONE | 남은 시간 입력과 관계없이 0000을 500 ms ON/OFF로 3회 |

분·초는 앞자리 0을 표시합니다. 구분점은 왼쪽에서 두 번째 자리의 DP입니다.
circle은 모든 자리에 같은 위상을 표시하며 a -> b -> c -> d -> e -> f 순서로 회전합니다.
회전 위상은 RUN 전체에서 진행하므로 circle 화면 시작 시 항상 a부터 시작하지는 않습니다.
상태 전환 또는 IDLE의 선택 필드 전환은 점멸/화면 위상을 초기화합니다.
전환을 처음 관찰한 클럭의 tick은 계수하지 않습니다.

## 자리 스캔

각 tick에서 모든 자리를 소등하고 다음 자리를 선택합니다. 다음 클럭에는 segment 패턴을
먼저 출력하고, 그다음 클럭에 해당 AN을 활성화합니다. 100 MHz에서 자리 전환마다
2클럭(20 ns)의 소등 구간을 둡니다. Reset 중에는 seg/an을 모두 1로 유지합니다.
이는 RTL의 출력 전환 순서를 정의한 것이며 실제 보드의 잔상 제거를 측정한 결과는 아닙니다.
표시 데이터는 실시간 반영하며 한 프레임 전체를 별도 래치하지 않습니다.

## 종료 완료 통지

DONE 진입 후 3,000개의 유효 tick을 계수하고 표시를 소등합니다.
완료 신호를 한 클럭으로 제한하면 기존 제어부의 열기/닫기 우선순위와 겹칠 때
완료 통지를 놓칠 수 있어, `alert_done`을 DONE 종료까지 유지합니다.
제어부의 기존 Interface와 우선순위는 바꾸지 않았습니다.
취소 또는 KEY로 먼저 DONE을 떠나면 남은 점멸을 중단하고 이후 완료 신호를 만들지 않습니다.

현재 완료 통지는 표시 기준입니다. 다음 부저 단계에서 종료음도 이 종료 시간 기준에
맞춰야 합니다. 이번 단계에는 음향 및 실제 도어/모터 제어를 포함하지 않습니다.

## 실기 확인 예정

자리/선분/DP 순서, 밝기와 잔상, 실제 점멸·교대 간격을 보드에서 확인해야 합니다.
현재는 Simulation만 완료했으며 보드용 Top/XDC 적용과 다운로드는 하지 않았습니다.
