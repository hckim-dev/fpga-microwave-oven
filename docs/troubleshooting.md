# Troubleshooting

재현·수정·회귀 확인이 있는 세 가지 사례를 정리했습니다. Simulation 실패와 도구 경고는
실제 보드에서 관찰한 고장과 구분합니다.

## 만료와 속도 변경이 같은 클럭에 발생

| 항목 | 내용 |
| --- | --- |
| 증상 | 만료 경계에 속도 버튼이 들어오면 정지 우선순위 검사가 실패 |
| 원인 | 기존 실행 허가가 현재 만료 조건을 포함하지 않아 RUN 상태의 속도 변경을 허용 |
| 확인 | 수정 전 RTL로 expiration must gate run before state update 실패 재현 |
| 수정 | 실행 허가에 현재 만료 조건 포함, RUN의 속도 변경도 실행 허가 조건을 따름 |
| 결과 | 만료와 속도 입력 동시 회귀 및 전체 이전 TB PASS |
| 근거 | tb_motor_control · 수정 전 로그: build/step9_timeout_regression_before_fix/simulate.txt |

상태 레지스터가 다음 클럭에 바뀐다는 사실만으로 같은 클럭의 다른 소비 모듈까지
정지 우선순위가 전달되지는 않습니다. 공유 실행 허가의 조건을 소비 경로와 함께 확인했습니다.

## 기동 대기 조건이 비동기 Reset을 구동

| 항목 | 내용 |
| --- | --- |
| 증상 | 첫 통합 빌드에서 LUTAR-1 Methodology 경고 1개 발생 |
| 원인 | synced_reset OR !ready 조합식이 rotary decoder의 비동기 CLR을 구동 |
| 확인 | 보고서가 조합 LUT의 비동기 Reset 경로와 glitch 가능성을 지적 |
| 수정 | 비동기 Reset은 synced_reset만 사용, 기동 대기는 동기식 enable로 분리 |
| 결과 | 전체 회귀 PASS, 재빌드 후 LUTAR-1 없음 |
| 근거 | rotary_decoder·input_frontend · 수정 전 보고서: build/board/20261028_135732_12936/methodology.rpt |

실제 보드 glitch를 관찰한 사례로 표현하지 않습니다. Simulation이 통과한 구조도
합성·Methodology에서 확인할 문제가 있을 수 있다는 점을 확인했습니다.

## 잠금 해제와 KEY 누름이 같은 필터 경계에 도달

| 항목 | 내용 |
| --- | --- |
| 증상 | SW0 해제와 KEY의 필터 결과가 동시에 바뀌면 초기 잠금 구현이 시작을 허용 |
| 원인 | 현재 locked 값만 검사해 해제와 같은 시점의 누름도 새 시작으로 수용 |
| 확인 | raw 포트를 함께 바꾸는 Top TB에서 simultaneous unlock and KEY must not start 실패 |
| 수정 | 이전 잠금 상태를 한 클럭 보존해 해제 경계의 시작·재개·설정 차단 |
| 결과 | 동일 회귀·잠금 단위 경계·기존 기능을 포함한 16개 TB PASS |
| 근거 | control_lock·tb_top_control_lock · 수정 전 로그: build/step11_unlock_boundary_before_fix/simulate.txt |

[파형과 원본 데이터](verification.md)의 노란 구간에서는 KEY pulse가 1이어도
previous locked가 남아 KEY to controller는 0입니다. 가열 상태는 IDLE을 유지합니다.
정지·취소·문 개폐·종료 확인에는 추가 차단을 적용하지 않았습니다.

수정 전 로컬 로그는 Git에서 제외합니다. 현재 회귀 결과와 파형은 [검증 결과](verification.md)를 따릅니다.
