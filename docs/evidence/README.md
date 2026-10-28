# 공유용 검증 근거

## 범위와 출처

- 기능 기준: `7bb28f1`, STEP 11 조작 잠금 포함. 이후 코드 서식·문서·프로젝트 선택 상태 변경과 구분합니다.
- 도구: Vivado/XSim 2026.1, build 6511674, 대상 `xc7a35tcpg236-1`.
- 정식 빌드: `build/board/20261028_152128_18104/`.
- 전체 회귀: `build/step11/20261028_152816_897567/`의 TB 16개 PASS.
- 아래 파형은 해당 기능의 `tb_top_control_lock` 스냅샷을 다시 실행해 VCD로 추출했습니다.
- 기본 기능·SW0 잠금은 사용자 정상 동작 확인 보고가 있습니다. 실기 사진·영상은 아직 수집 중입니다.

이 문서는 실제 보고서의 수치와 실제 Simulation 데이터를 선별한 기록입니다.
대용량 생성물·개인 PC 경로·호스트 이름은 공개 문서에 복제하지 않았습니다.

## 합성·배치배선·STA 결과

| 항목 | 도구 결과 |
| --- | --- |
| 클럭 제약 | 100 MHz, 10 ns |
| Setup WNS / TNS | +0.222 ns / 0.000 ns |
| Hold WHS / THS | +0.122 ns / 0.000 ns |
| Pulse width slack | +4.500 ns |
| Setup/Hold/Pulse 실패 endpoint | 각각 0 |
| 내부 no_clock·미제약 endpoint·loops | 0 |
| LUT | 824 / 20,800, 3.96% |
| FF | 459 / 41,600, 1.10% |
| IOB / BUFG | 45 / 1 |
| DRC 위반 / routing error | 0 / 0 |
| CDC | 동기화 정보 11개, 경고 없음 |
| 산출물 | microwave.bit 생성 완료 |

외부 출력의 동기 수신 Timing 요구는 정의하지 않았으며 Methodology의 TIMING-18 경고
32개가 남습니다. 비동기 입력의 도착 경로만 false path이고 동기화 FF 사이는 검사합니다.
기본 active 부저 모드의 미사용 반송파 제거, 모듈별 미사용 버튼 비트 경고도 기존 의도와 일치합니다.
내부 STA 통과를 모든 외부 I/O Timing·전원 조건·실제 RPM 검증으로 확대하지 않습니다.

## 대표 파형

![실제 XSim 잠금 해제 경계](control_lock_boundary.png)

| 파일 | 용도 |
| --- | --- |
| [PNG](control_lock_boundary.png) | README·발표 삽입 |
| [SVG](control_lock_boundary.svg) | 벡터 확대·편집 |
| [VCD](control_lock_boundary.vcd) | 실제 추출 데이터 중 120 ns 구간 |
| [메타데이터](control_lock_boundary.json) | 원본/잘라낸 VCD 해시, 시간 구간, 렌더러 버전 |

**이 파형은 기본 10 ms 대신 3클럭의 버튼 필터 계수를 사용한 Simulation입니다.**
클럭은 100 MHz이며 원본 시간 48,510~48,630 ns 중 동시 입력 시점 48,530 ns를 0으로 표시했습니다.
노란 45~55 ns 구간에 KEY pulse가 발생하지만 previous locked가 시작 신호를 차단합니다.
가열 상태는 IDLE, 모터 PWM은 0을 유지합니다. 하드웨어에서 45 ns에 응답했다는 뜻이 아닙니다.

KEY raw (pressed)는 TB의 `buttons[6]`으로 눌림을 1로 나타냅니다.
실제 Top의 `rotary_key` 포트는 반전한 active-low 입력입니다. 같은 Simulation 시각의
델타 갱신은 마지막 관찰값으로 그렸으며 전기적 glitch·신호 품질을 측정한 그림이 아닙니다.

## 파형 재생성

먼저 [전체 Simulation](../reproduction.md)을 실행합니다. 아래 `$simDir`는 실행 결과 경로로 바꿉니다.

```powershell
$repoRoot = (Get-Location).Path
$vivadoBin = "C:/AMDDesignTools/2026.1/Vivado/bin"
$simDir = "$repoRoot/build/step11/<실행시각>"
$env:LOCK_VCD_PATH = "$repoRoot/build/control_lock_full.vcd"
Push-Location $simDir
& "$vivadoBin/xsim.bat" tb_top_control_lock -tclbatch "$repoRoot/scripts/export_lock_waveform.tcl" -wdb "$repoRoot/build/control_lock_export.wdb"
Pop-Location
python scripts/render_lock_waveform.py build/control_lock_full.vcd --output-dir docs/evidence
```

XSim의 PASS와 오류 여부를 확인한 뒤 이미지를 생성합니다. 이미지 생성에는 Matplotlib이
필요하며 이번 실행은 3.11.1을 사용했습니다. 이 패키지는 RTL 검증의 의존성이 아닙니다.
전체 VCD는 build에 보존하고 선택 구간·PNG·SVG·해시만 docs에 저장합니다.
기록된 120 ns VCD만으로 다시 그릴 때는 원본 덮어쓰기를 피하도록 다른 출력 폴더를 사용합니다.

```powershell
python scripts/render_lock_waveform.py docs/evidence/control_lock_boundary.vcd --output-dir build/waveform_preview
```

## 원 보고서 식별

다음 SHA-256은 이번 로컬 실행의 원 보고서를 식별합니다. 보고서 헤더의 날짜나 재배치 결과가
달라지는 재실행에서 같은 해시가 나온다는 의미는 아닙니다. 전체 생성물은 저장소에서 제외하며
동작·판정은 제공한 스크립트로 다시 확인할 수 있습니다.

| 원 보고서 | SHA-256 |
| --- | --- |
| `timing_summary.rpt` | `b8104881d3eb15af6123e11e92cdcb5b24eced85022ea51528a406020c525abd` |
| `utilization.rpt` | `027e8cacfac7506cc27ef301c46a0961eee486c4f4b2e5dfa5e87fbb82f2e06d` |
| `cdc.rpt` | `8f7f954c85bbee57b55a7878fafc271f4e4957a88503b3aabdc0f6480fe432cb` |
| `drc.rpt` | `cf5ef3b5c6d397022c4a7bb162c833ff7cf48a9f2201511c5cb6c5b3a8be60c4` |
| `methodology.rpt` | `d2d7e059af9aace157fe9e649f860d5264884f29483607ebe19d8cf3dc9fe306` |

실제 실행 경위와 수정 전 실패 재현은 [전체 검증 기록](../verification.md)을 따릅니다.
