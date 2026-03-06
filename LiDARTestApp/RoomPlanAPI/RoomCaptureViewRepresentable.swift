//
//  RoomCaptureViewRepresentable.swift
//  LiDARTestApp
//
//  Created by 김도연 on 3/6/26.
//

import SwiftUI
import RoomPlan
import ARKit

struct RoomCaptureViewRepresentable: UIViewRepresentable {
    @Binding var isScanning: Bool
    @Binding var captureCount: Int // ⭐️ Bool 대신 Int로 변경
    
    var onDefectCaptured: ((simd_float4x4, CVPixelBuffer) -> Void)?
    var onComplete: ((CapturedRoom?) -> Void)?
    
    func makeUIView(context: Context) -> RoomCaptureView {
        let captureView = RoomCaptureView()
        captureView.delegate = context.coordinator
        return captureView
    }
    
    func updateUIView(_ uiView: RoomCaptureView, context: Context) {
        // ⭐️ 핵심 방어 로직: 버튼을 눌러서 숫자가 올라갔을 때만 딱 한 번 실행!
        if captureCount > context.coordinator.lastCaptureCount {
            context.coordinator.lastCaptureCount = captureCount // 숫자 맞춰주기
            
            if let frame = uiView.captureSession.arSession.currentFrame {
                onDefectCaptured?(frame.camera.transform, frame.capturedImage)
            }
        }
        
        // 엔진 실행 / 중지 관리
        if isScanning {
            if !context.coordinator.isSessionRunning {
                let config = RoomCaptureSession.Configuration()
                uiView.captureSession.run(configuration: config)
                context.coordinator.isSessionRunning = true
            }
        } else {
            if context.coordinator.isSessionRunning {
                uiView.captureSession.stop()
                context.coordinator.isSessionRunning = false
            }
        }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    @objc(RoomCaptureCoordinator)
    class Coordinator: NSObject, RoomCaptureViewDelegate {
        var parent: RoomCaptureViewRepresentable
        var isSessionRunning: Bool = false
        var lastCaptureCount: Int = 0 // ⭐️ 지금까지 찍은 사진 횟수 기억용
        
        init(_ parent: RoomCaptureViewRepresentable) { self.parent = parent }
        
        func captureView(shouldPresent roomDataForProcessing: CapturedRoom, error: Error?) -> Bool {
            return error == nil
        }
        
        func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
            if let _ = error {
                parent.onComplete?(nil)
                return
            }
            parent.onComplete?(processedResult)
        }
        
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        func encode(with coder: NSCoder) {}
    }
}
