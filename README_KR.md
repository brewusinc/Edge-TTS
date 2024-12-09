# Edge-TTS

<p align="center">
<img src="./demo_app.png" alt="Edge-TTS" title="Edge-TTS" width="557"/>
</p>

Edge-TTS는 Microsoft Edge의 텍스트 음성 변환(TTS) 서비스를 Swift로 구현한 것입니다. 이 라이브러리는 개발자가 Apple 플랫폼 애플리케이션에 고품질 음성 합성 기능을 쉽게 통합할 수 있는 간단하고 사용하기 쉬운 API 인터페이스를 제공합니다.

[English Documentation](README.md) | [日本語ドキュメント](README_JP.md) | [中文文档](README_CN.md)

## 기능

### 다양한 음성과 언어

- 400개 이상의 신경망 음성
- 100개 이상의 언어 및 지역 변형 지원
- 자연스러운 음성 합성 효과

### 유연한 음성 제어

- 조절 가능한 발화 속도 (-50% ~ +100%)
- 피치 제어 (-50Hz ~ +50Hz)
- 볼륨 제어 (-50% ~ +50%)
- 경계 유형 선택 (문장/단어)

### 풍부한 출력 옵션

- MP3 형식 내보내기 지원
- 실시간 음성 합성 스트리밍
- 비동기 변환 및 재생
- 선택적 JSON 메타데이터 내보내기
- 선택적 SRT 자막 내보내기
- 크로스 플랫폼 파일 내보내기 지원 (iOS/macOS)

### 개발 도구

- 빠른 테스트 및 일괄 처리를 위한 명령줄 도구
- 시각적 구성을 위한 네이티브 GUI 애플리케이션
- 상세한 API 문서 및 사용 예제

### 크로스 플랫폼 호환성

- macOS 13.0+
- iOS/iPadOS 15.0+

## 설치

### Swift Package Manager

Package.swift 파일에 다음 종속성을 추가하세요:

```swift
dependencies: [
    .package(url: "https://github.com/brewusinc/edge-tts.git", from: "1.0.0")
]
```

## 빠른 시작

### 기본 사용법

```swift
import EdgeTTS

// TTS 인스턴스 생성
let tts = EdgeTTS(config: Configure(
    voice: "ko-KR-SunHiNeural",
    rate: "+0%",
    pitch: "+0Hz",
    volume: "+0%",
    saveJSON: true,  // JSON 메타데이터 내보내기 활성화
    saveSRT: true,   // SRT 자막 내보내기 활성화
    boundaryType: .sentence  // 문장 경계 사용 (단어 경계는 .word)
))

// 비동기 변환
Task {
    do {
        try await tts.ttsPromise(text: "안녕하세요, 세계", audioPath: "output.mp3")
        print("변환이 완료되었습니다")
    } catch {
        print("변환에 실패했습니다: \(error)")
    }
}
```

### 명령줄 도구 사용법

명령줄 도구에는 두 가지 주요 명령이 있습니다: `list`와 `speak`

#### 사용 가능한 음성 목록 표시

```bash
# 모든 사용 가능한 음성 표시
edge-tts-cli list

# 프록시를 사용하여 음성 표시
edge-tts-cli list --proxy http://host:port
```

#### 텍스트를 음성으로 변환

```bash
# 기본 사용법 (직접 텍스트)
edge-tts-cli speak --text "안녕하세요, 세계" --output hello.mp3

# 파일에서 텍스트 읽기
edge-tts-cli speak --file input.txt --output hello.mp3

# 음성과 언어 지정
edge-tts-cli speak --text "안녕하세요, 세계" --voice ko-KR-SunHiNeural --lang ko-KR --output hello.mp3

# 음성 매개변수 조정
edge-tts-cli speak --text "안녕하세요, 세계" --rate +50% --pitch +10Hz --volume +20% --output hello.mp3

# JSON과 SRT 내보내기 활성화
edge-tts-cli speak --text "안녕하세요, 세계" --save-json --save-srt --output hello.mp3

# 경계 유형 설정
edge-tts-cli speak --text "안녕하세요, 세계" --boundary word --output hello.mp3

# 프록시 사용
edge-tts-cli speak --text "안녕하세요, 세계" --proxy http://host:port --output hello.mp3
```

`speak` 명령의 사용 가능한 옵션:

- `--text`: 변환할 텍스트
- `--file`: 입력 텍스트 파일 경로
- `--voice`: 사용할 음성 (기본값: ko-KR-SunHiNeural)
- `--lang`: 사용할 언어 (기본값: ko-KR)
- `--rate`: 발화 속도 (예: +0%, -10%)
- `--pitch`: 피치 (예: +0Hz, -10Hz)
- `--volume`: 볼륨 (예: +0%, -10%)
- `--boundary`: 경계 유형 (sentence 또는 word, 기본값: sentence)
- `--save-json`: 타이밍 정보를 JSON으로 저장
- `--save-srt`: 타이밍 정보를 SRT로 저장
- `--proxy`: 프록시 URL (예: http://host:port)
- `--output`: 출력 파일 이름 (기본값: output.mp3)

### GUI 애플리케이션 사용법

1. Edge TTS Demo의 최신 버전을 다운로드하고 설치
2. 애플리케이션을 열고 변환하고 싶은 텍스트를 입력
3. 원하는 음성과 매개변수 설정(속도, 피치, 볼륨) 선택
4. 필요에 따라 JSON/SRT 내보내기 활성화
5. 경계 유형(문장 또는 단어) 선택
6. "변환 및 재생" 버튼을 클릭하여 합성된 음성 듣기
7. 내보내기 버튼을 사용하여 파일 저장:
   - iOS: 시스템 공유 시트로 유연한 파일 처리
   - macOS: 저장 대화 상자로 저장 위치 선택

## 내보내기 기능

### 파일 유형

- MP3: 합성된 음성의 오디오 파일
- JSON: 각 문장/단어의 타이밍 메타데이터
- SRT: 타임스탬프가 있는 자막 파일

### 플랫폼별 내보내기

- iOS/iPadOS:
  - 시스템 공유 시트 통합
  - 다른 앱으로 공유
  - AirDrop 지원
  - 파일 앱에 저장
- macOS:
  - 네이티브 저장 대화 상자
  - 저장 위치 선택
  - 파일 유형 필터링
  - 자동 파일 확장자 처리

## 일반적인 음성

사용 가능한 음성 목록은 다음 방법으로 가져올 수 있습니다:

```swift
let voices = try await tts.fetchVoices()
```

일반적인 한국어 음성:

- ko-KR-SunHiNeural (여성)
- ko-KR-InJoonNeural (남성)
- ko-KR-YuJinNeural (여성)
- ko-KR-BongJinNeural (남성)

## 기여 가이드

다음을 포함한 모든 형태의 기여를 환영합니다:

- 버그 보고 및 기능 제안
- 코드 개선
- 문서 개선
- 테스트 케이스 추가

## 라이선스

이 프로젝트는 MIT 라이선스 하에 제공됩니다 - 자세한 내용은 [LICENSE.txt](LICENSE.txt)를 참조하세요.
