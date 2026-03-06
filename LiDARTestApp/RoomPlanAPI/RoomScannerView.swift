//
//  RoomScannerView.swift
//  LiDARTestApp
//
//  Created by 김도연 on 3/6/26.
//

import SwiftUI
import AVFoundation
import QuickLook
import RoomPlan
import VideoToolbox // ⭐️ 이미지 변환을 위해 추가

enum ScanState {
    case idle
    case scanning
    case completed
}

struct RoomScannerView: View {
    @State private var viewModel = RoomScannerViewModel()
    
    @State private var scanState: ScanState = .idle
    @State private var isScanning: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    
    @State private var captureCount: Int = 0
    @State private var showCaptureFlash: Bool = false
    
    @State private var show3DViewer: Bool = false
    @State private var showPhotoGallery: Bool = false // ⭐️ 사진 뷰어를 띄울 상태 변수 추가
    
    var body: some View {
        ZStack {
            switch scanState {
            case .idle:
                VStack(spacing: 20) {
                    Text("🏠 스마트 방 스캐너")
                        .font(.largeTitle).fontWeight(.bold)
                    Text("하자가 있는 곳을 향해 촬영 버튼을 누르세요.")
                        .foregroundColor(.gray)
                    
                    Button(action: { startScanWithPermissionCheck() }) {
                        Text("스캔 시작하기")
                            .font(.headline).foregroundColor(.white)
                            .frame(width: 200, height: 50)
                            .background(Color.blue).cornerRadius(12)
                    }.padding(.top, 30)
                }
                
            case .scanning:
                ZStack(alignment: .bottom) {
                    RoomCaptureViewRepresentable(
                        isScanning: $isScanning,
                        captureCount: $captureCount,
                        onDefectCaptured: { transform, pixelBuffer in
                            viewModel.addDefect(transform: transform, pixelBuffer: pixelBuffer)
                        },
                        onComplete: { capturedRoom in
                            guard let room = capturedRoom else {
                                DispatchQueue.main.async {
                                    alertMessage = "스캔 오류가 발생했습니다."
                                    showAlert = true
                                    scanState = .idle
                                }
                                return
                            }
                            viewModel.processScannedRoom(room)
                            withAnimation { scanState = .completed }
                        }
                    )
                    .ignoresSafeArea()
                    
                    if isScanning {
                        if showCaptureFlash {
                            Color.white.ignoresSafeArea()
                                .opacity(0.8)
                                .onAppear {
                                    withAnimation(.easeOut(duration: 0.3)) { showCaptureFlash = false }
                                }
                        }
                        
                        VStack(spacing: 15) {
                            Image(systemName: "plus")
                                .font(.system(size: 30, weight: .light))
                                .foregroundColor(.white.opacity(0.6))
                                .padding(.bottom, 150)
                            
                            HStack(spacing: 20) {
                                Button(action: {
                                    showCaptureFlash = true
                                    captureCount += 1
                                }) {
                                    VStack {
                                        Image(systemName: "camera.viewfinder")
                                            .font(.system(size: 24))
                                        Text("하자 촬영")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.white)
                                    .frame(width: 80, height: 80)
                                    .background(Color.orange)
                                    .clipShape(Circle())
                                }
                                
                                Button(action: {
                                    isScanning = false
                                }) {
                                    Text("스캔 완료")
                                        .font(.headline).foregroundColor(.white)
                                        .frame(height: 60).frame(maxWidth: .infinity)
                                        .background(Color.red).cornerRadius(12)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 40)
                        }
                    } else {
                        ProgressView("3D 도면 생성 및 데이터 추출 중...")
                            .padding().background(Color.white.opacity(0.8))
                            .cornerRadius(10).padding(.bottom, 50)
                    }
                }
                
            case .completed:
                VStack(spacing: 20) {
                    Text("🎉 스캔 및 하자 기록 완료!")
                        .font(.title).fontWeight(.bold)
                    Text("총 \(viewModel.defects.count)개의 하자가 기록되었습니다.")
                        .foregroundColor(.gray)
                    
                    // ⭐️ 3D 모델 보기 버튼
                    Button(action: { show3DViewer = true }) {
                        Text("3D 모델 확인하기 (돌려보기)")
                            .font(.headline).foregroundColor(.white)
                            .frame(width: 250, height: 50)
                            .background(Color.green).cornerRadius(12)
                    }
                    
                    // ⭐️ 하자 사진 보기 버튼 추가
                    if viewModel.defects.count > 0 {
                        Button(action: { showPhotoGallery = true }) {
                            Text("📸 촬영된 하자 사진 보기")
                                .font(.headline).foregroundColor(.white)
                                .frame(width: 250, height: 50)
                                .background(Color.orange).cornerRadius(12)
                        }
                    }
                    
                    Button(action: {
                        viewModel.defects.removeAll()
                        captureCount = 0
                        scanState = .idle
                    }) {
                        Text("처음으로 돌아가기")
                            .padding().frame(width: 250)
                            .background(Color.gray.opacity(0.2)).cornerRadius(12)
                    }
                }
                // 3D 뷰어 모달
                .sheet(isPresented: $show3DViewer) {
                    NavigationStack {
                        Group {
                            if let usdzURL = viewModel.savedUsdzURL {
                                QuickLookPreview(url: usdzURL)
                                    .ignoresSafeArea(edges: .bottom)
                            } else {
                                Text("3D 모델 파일이 없습니다.")
                            }
                        }
                        .navigationTitle("3D 모델 미리보기")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("닫기") { show3DViewer = false }
                            }
                        }
                    }
                }
                // ⭐️ 사진 갤러리 모달 추가
                .sheet(isPresented: $showPhotoGallery) {
                    DefectPhotoGalleryView(defects: viewModel.defects)
                }
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("알림"), message: Text(alertMessage), dismissButton: .default(Text("확인")))
        }
    }
    
    private func startScanWithPermissionCheck() {
        guard RoomCaptureSession.isSupported else {
            alertMessage = "LiDAR 센서를 지원하지 않습니다."
            showAlert = true; return
        }
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            withAnimation { scanState = .scanning; isScanning = true }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        withAnimation { self.scanState = .scanning; self.isScanning = true }
                    } else {
                        alertMessage = "카메라 권한이 필요합니다."
                        showAlert = true
                    }
                }
            }
        default:
            alertMessage = "설정에서 카메라 권한을 켜주세요."
            showAlert = true
        }
    }
}
// MARK: - 📸 하자 사진 갤러리 뷰 (디스크에서 이미지 불러오기)
struct DefectPhotoGalleryView: View {
    @Environment(\.dismiss) var dismiss
    
    // ⭐️ ViewModel에서 사용하는 DefectInfo 타입으로 받기
    var defects: [DefectInfo]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                    ForEach(0..<defects.count, id: \.self) { index in
                        let defect = defects[index]
                        
                        VStack {
                            // ⭐️ 저장된 파일명으로 이미지 불러오기
                            if let uiImage = loadImageFromTempDirectory(fileName: defect.imageFileName) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 150)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .shadow(radius: 3)
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 150)
                                    .overlay(Text("이미지 없음").font(.caption))
                            }
                            Text("하자 #\(index + 1)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("기록된 하자 사진")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }
    
    // ⭐️ 임시 폴더(Temporary Directory) 경로에서 파일명으로 UIImage를 읽어오는 함수
    private func loadImageFromTempDirectory(fileName: String) -> UIImage? {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        if let imageData = try? Data(contentsOf: fileURL) {
            return UIImage(data: imageData)
        }
        return nil
    }
}

// MARK: - 3D 뷰어 (QuickLook) Wrapper
struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let parent: QuickLookPreview
        init(_ parent: QuickLookPreview) { self.parent = parent }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { return 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return parent.url as QLPreviewItem
        }
    }
}
