# 문서 안내

## 먼저 볼 문서

| 목적 | 문서 |
| --- | --- |
| 프로젝트 개요·실행 | [저장소 README](../README.md) |
| 설계 구조·FSM·선택 이유 | [설계 설명](design.md) |
| 보드 결선·핀·LED | [전체 통합](integration.md) |
| 새 환경에서 재현 | [재현 절차](reproduction.md) |
| 대표 파형·빌드 수치 | [공유용 검증 근거](evidence/README.md) |
| 문제 해결 과정 | [Troubleshooting](troubleshooting.md) |
| 실기 결과·시연 준비 | [하드웨어 확인](hardware_test.md), [촬영 계획](demo_plan.md) |

## 구현 계약

| 영역 | 상세 문서 |
| --- | --- |
| 외부 입력·극성·필터 | [입력 Interface](input_interface.md) |
| 시간·가열 FSM·우선순위 | [가열 제어 Interface](controller_interface.md) |
| FND 스캔·화면·완료 통지 | [표시 Interface](display_interface.md) |
| BEEP·개폐 효과음·알림 | [부저 Interface](sound_interface.md) |
| 도어 FSM·서보 펄스·추정 상태 | [도어 Interface](door_interface.md) |
| 모터 듀티·정지·주기 갱신 | [모터 Interface](motor_interface.md) |
| SW0 조작 잠금 | [조작 잠금](control_lock.md) |

## 근거와 이력

[요구사항 추적](requirements.md)은 구현·Simulation·실기·발표 근거를 연결합니다.
[검증 기록](verification.md)은 단계별 실행과 실패 재현을,
[검토 이력](review.md)은 코드 검토 당시의 판단을 보존합니다.
과거 단계의 미구현·미확인 표현은 당시 상태이며 최신 실기 상태는
[하드웨어 확인](hardware_test.md)을 따릅니다.
