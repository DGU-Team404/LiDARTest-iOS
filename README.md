# LiDARTest-iOS
LiDAR 센서를 이용한 실시간 공간 스캔 및 3D Mesh(.usdz) 추출 가능성 테스트를 위한 레포지토리입니다.

## 사용방법

### 1. 사전 준비 (Prerequisites)
본 앱은 **LiDAR 스캐너**를 기반으로 작동하므로, 아래 기기에서만 정상적인 스캔이 가능합니다.
* **iPhone:** iPhone 12 Pro / Pro Max 이상 모델
* **iPad:** iPad Pro 11형(2세대 이상), iPad Pro 12.9형(4세대 이상)
* **iOS 버전:** iOS 14.0 이상 권장

### 2. 빌드 및 실행 가이드
1.  **Repository Clone**
    ```bash
    git clone https://github.com/DGU-Team404/LiDARTest-iOS
    ```
2.  **프로젝트 열기**
    * Xcode를 실행하고 `LiDARTestApp.xcodeproj` 파일을 엽니다.
3.  **실기기 연결**
    * LiDAR 지원 기기를 Mac에 연결합니다. (시뮬레이터는 LiDAR를 지원하지 않아 실행이 불가능합니다.)
4.  **Build & Run**
    * 상단 타겟 기기를 본인의 iPhone/iPad로 설정한 후 `Cmd + R`을 눌러 앱을 실행합니다.
