//
//  RawDataScannerView.swift
//  LiDARTestApp
//
//  Created by 김도연 on 3/11/26.
//

import SwiftUI
import ARKit
import RealityKit // ⭐️ SceneKit 대신 RealityKit 임포트

// ⭐️ 카메라 화면 및 LiDAR 인식 영역을 그려주는 View
struct ARPreviewContainer: UIViewRepresentable {
    var session: ARSession
    
    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero)
        
        // 우리가 만든 데이터 수집용 ARSession을 뷰에 연결
        view.session = session
        
        // ⭐️ 핵심 기능: LiDAR가 인식한 3D 공간을 화려한 색상의 메쉬로 덮어줍니다!
        view.debugOptions = [.showSceneUnderstanding]
        
        return view
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
}

struct RawDataScannerView: View {
    @State private var recorder = RawDataRecorder()
    @State private var showShareSheet = false
    @Environment(\.dismiss) var dismiss // 뒤로가기 액션
    
    var body: some View {
        ZStack {
            // 1. 카메라 배경 화면
            ARPreviewContainer(session: recorder.arSession)
                .edgesIgnoringSafeArea(.all)
            
            // 2. 컨트롤 UI 레이어
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white.opacity(0.8))
                            .padding()
                    }
                }
                
                Spacer()
                
                if let zipURL = recorder.savedZipURL {
                    VStack(spacing: 15) {
                        Text("✅ 압축 및 CSV 변환 완료!")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Button(action: { showShareSheet = true }) {
                            Text("ZIP 파일 공유하기")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    .sheet(isPresented: $showShareSheet) {
                        ShareSheet(activityItems: [zipURL])
                    }
                }
                
                Button(action: {
                    if recorder.isRecording {
                        recorder.stopRecording()
                    } else {
                        recorder.savedZipURL = nil
                        recorder.startRecording()
                    }
                }) {
                    Text(recorder.isRecording ? "녹화 중지 및 압축하기" : "Raw 데이터 녹화 시작")
                        .font(.title2).bold()
                        .foregroundColor(.white)
                        .padding()
                        .frame(height: 70)
                        .frame(maxWidth: .infinity)
                        .background(recorder.isRecording ? Color.red : Color.green)
                        .cornerRadius(16)
                        .shadow(radius: 5)
                }
                .padding()
            }
        }
        .onAppear {
            recorder.startPreview()
        }
        .navigationBarHidden(true)
    }
}

// 공유 시트를 띄우기 위한 UIViewControllerRepresentable
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        return UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
