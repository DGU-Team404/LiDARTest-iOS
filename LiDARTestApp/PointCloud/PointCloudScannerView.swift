//
//  PointCloudScannerView.swift
//  LiDARTestApp
//
//  Created by 김도연 on 3/6/26.
//

import SwiftUI
import ARKit
import SceneKit
import QuickLook

enum MeshScanState {
    case idle
    case scanning
    case completed
}

struct PointCloudScannerView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @State private var scanState: MeshScanState = .idle
    @State private var isScanning: Bool = false
    
    @State private var triggerSave: Bool = false
    @State private var savedMeshURL: URL? = nil
    @State private var show3DViewer: Bool = false
    
    @State private var vertexCount: Int = 0
    @State private var faceCount: Int = 0
    
    var body: some View {
        ZStack {
            switch scanState {
            case .idle:
                VStack(spacing: 20) {
                    Text("🌐 LiDAR 공간 스캐너")
                        .font(.largeTitle).fontWeight(.bold)
                    Text("방 전체를 스캔하여 3D Mesh 파일로 추출합니다.")
                        .foregroundColor(.gray)
                    
                    Button(action: {
                        scanState = .scanning
                        isScanning = true
                    }) {
                        Text("스캔 시작하기")
                            .font(.headline).foregroundColor(.white)
                            .frame(width: 200, height: 50)
                            .background(Color.orange).cornerRadius(12)
                    }
                    .padding(.top, 30)
                }
                
            case .scanning:
                ZStack(alignment: .bottom) {
                    SolidMeshViewRepresentable(
                        isScanning: $isScanning,
                        triggerSave: $triggerSave,
                        onSaveCompleted: { url, vCount, fCount in
                            // ⭐️ 저장 완료 시 실행되는 클로저
                            DispatchQueue.main.async {
                                if let url = url {
                                    self.savedMeshURL = url
                                    self.vertexCount = vCount
                                    self.faceCount = fCount
                                    self.printServerPayloadSimulation(url: url)
                                }
                                self.scanState = .completed
                                self.isScanning = false
                            }
                        }
                    )
                    .ignoresSafeArea()
                    
                    VStack {
                        VStack(spacing: 8) {
                            Text("방 전체를 이리저리 비춰보세요!")
                                .font(.headline).foregroundColor(.white)
                            Text("스캔된 공간이 파란색 면으로 채워집니다.")
                                .font(.subheadline).foregroundColor(.white.opacity(0.8))
                        }
                        .padding().background(Color.black.opacity(0.7)).cornerRadius(12)
                        .padding(.bottom, 20)
                        
                        Button(action: {
                            triggerSave = true
                        }) {
                            Text("스캔 완료 및 Mesh 파일 추출")
                                .font(.headline).foregroundColor(.white)
                                .frame(height: 60).frame(maxWidth: .infinity)
                                .background(Color.red).cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
                
            case .completed:
                VStack(spacing: 20) {
                    Text("🎉 스캔 및 추출 완료!")
                        .font(.title).fontWeight(.bold)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("📊 추출된 데이터 정보")
                            .font(.headline)
                        if savedMeshURL != nil {
                            Text("• 추출 성공! (파일 용량 확인 가능)")
                            Text("• 총 꼭짓점(Vertex): \(vertexCount)개")
                            Text("• 총 다각형 면(Face): \(faceCount)개")
                        } else {
                            Text("❌ 파일 추출에 실패했습니다.")
                                .foregroundColor(.red)
                        }
                    }
                    .padding().background(Color.gray.opacity(0.1)).cornerRadius(12)
                    
                    // PointCloudScannerView의 .completed 케이스 내부
                    if let url = savedMeshURL {
                        HStack(spacing: 15) {
                            Button(action: { show3DViewer = true }) {
                                Text("미리보기")
                                    .font(.headline).foregroundColor(.white)
                                    .frame(maxWidth: .infinity, minHeight: 50)
                                    .background(Color.green).cornerRadius(12)
                            }
                            
                            // ⭐️ 추가된 공유 버튼
                            Button(action: {
                                let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                                UIApplication.shared.windows.first?.rootViewController?.present(av, animated: true)
                            }) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.title2).foregroundColor(.white)
                                    .frame(width: 60, height: 50)
                                    .background(Color.blue).cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 40)
                    }
                    
                    Button(action: {
                        savedMeshURL = nil
                        scanState = .idle
                    }) {
                        Text("처음으로 돌아가기")
                            .padding().frame(width: 250)
                            .background(Color.gray.opacity(0.2)).cornerRadius(12)
                    }
                }
                .sheet(isPresented: $show3DViewer) {
                    NavigationStack {
                        Group {
                            if let url = savedMeshURL {
                                MeshQuickLookPreview(url: url)
                                    .ignoresSafeArea(edges: .bottom)
                            } else {
                                Text("파일을 찾을 수 없습니다.")
                            }
                        }
                        .navigationTitle("LiDAR Mesh 미리보기")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("닫기") { show3DViewer = false }
                                    .font(.headline)
                            }
                        }
                    }
                }
            }
            
            if scanState == .idle {
                VStack {
                    HStack {
                        Button(action: { presentationMode.wrappedValue.dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.title2).foregroundColor(.blue)
                                .padding()
                        }
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    private func printServerPayloadSimulation(url: URL) {
        print("\n========================================================")
        print("🚀 [클라이언트 -> 서버] LiDAR Mesh 파일 전송 시뮬레이션")
        print("========================================================")
        print("1. 추출된 3D 파일 (Multipart/form-data로 전송):")
        print("   - 파일 경로: \(url.path)")
        
        let jsonMock = """
        {
            "scan_info": {
                "scan_id": "\(UUID().uuidString)",
                "timestamp": "\(Date().description)",
                "device": "iPhone 14 Pro",
                "scan_type": "LiDAR_Mesh_Only"
            },
            "mesh_metadata": {
                "vertex_count": \(vertexCount),
                "face_count": \(faceCount),
                "format": "usdz"
            },
            "attached_images": []
        }
        """
        print("\n2. 메타데이터 (JSON Form 형식):")
        print(jsonMock)
        print("========================================================\n")
    }
    
    // 공유 시트를 띄우기 위한 Wrapper
    struct ShareSheet: UIViewControllerRepresentable {
        let activityItems: [Any]
        func makeUIViewController(context: Context) -> UIActivityViewController {
            UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        }
        func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
    }
}

struct SolidMeshViewRepresentable: UIViewRepresentable {
    @Binding var isScanning: Bool
    @Binding var triggerSave: Bool
    
    var onSaveCompleted: ((URL?, Int, Int) -> Void)?
    
    func makeUIView(context: Context) -> ARSCNView {
        let sceneView = ARSCNView(frame: .zero)
        sceneView.delegate = context.coordinator
        
        let config = ARWorldTrackingConfiguration()
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        
        // 미리보기 화면 설정 (입체감을 위해 기본 조명 추가)
        sceneView.automaticallyUpdatesLighting = true
        sceneView.autoenablesDefaultLighting = true
        sceneView.session.run(config)
        return sceneView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        if triggerSave {
            DispatchQueue.main.async {
                self.triggerSave = false
                
                // 1. 새로운 씬 생성
                let exportScene = SCNScene()
                var vCount = 0
                var fCount = 0
                
                // 2. 현재 스캔된 모든 앵커(메쉬 조각)들을 안전하게 복제
                guard let frame = uiView.session.currentFrame else { return }
                let meshAnchors = frame.anchors.compactMap { $0 as? ARMeshAnchor }
                
                for anchor in meshAnchors {
                    // 각 조각의 기하학 데이터 추출
                    let geometry = context.coordinator.createGeometry(from: anchor.geometry)
                    let node = SCNNode(geometry: geometry)
                    
                    // ⭐️ 중요: 각 메쉬 조각의 실제 위치(Transform)를 적용
                    node.simdTransform = anchor.transform
                    
                    // ⭐️ 저장용 재질 설정 (파란색 탈출!)
                    let material = SCNMaterial()
                    material.lightingModel = .physicallyBased // 실제 빛 반사 적용
                    material.diffuse.contents = UIColor.lightGray // 밝은 회색으로 입체감 부여
                    material.isDoubleSided = false // 밖에서 안이 보이게 설정
                    geometry.materials = [material]
                    
                    exportScene.rootNode.addChildNode(node)
                    
                    vCount += anchor.geometry.vertices.count
                    fCount += anchor.geometry.faces.count
                }
                
                // 3. 파일로 저장 (iOS 3D 뷰어와 가장 호환성이 좋은 usdz 우선 시도)
                let fileName = "LiDAR_Final_\(UUID().uuidString.prefix(4)).usdz"
                let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                
                // 씬을 파일로 굽기
                let success = exportScene.write(to: fileURL, options: nil, delegate: nil, progressHandler: nil)
                
                if success {
                    self.onSaveCompleted?(fileURL, vCount, fCount)
                } else {
                    self.onSaveCompleted?(nil, 0, 0)
                }
            }
        }
    }
    
    static func dismantleUIView(_ uiView: ARSCNView, coordinator: Coordinator) {
        uiView.session.pause()
    }
    
    func makeCoordinator() -> Coordinator { Coordinator() }
    
    class Coordinator: NSObject, ARSCNViewDelegate {
        func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
            guard let meshAnchor = anchor as? ARMeshAnchor else { return nil }
            let geometry = createGeometry(from: meshAnchor.geometry)
            let node = SCNNode(geometry: geometry)
            
            // 화면 스캔 중에는 파란색 반투명
            let material = SCNMaterial()
            material.diffuse.contents = UIColor.systemBlue.withAlphaComponent(0.4)
            material.isDoubleSided = true
            geometry.materials = [material]
            return node
        }
        
        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard let meshAnchor = anchor as? ARMeshAnchor else { return }
            node.geometry = createGeometry(from: meshAnchor.geometry)
        }
        
        // Coordinator 내부의 createGeometry를 이 로직으로 교체 (중요!)
        func createGeometry(from geometry: ARMeshGeometry) -> SCNGeometry {
            // 1. 실시간 버퍼 데이터를 안전하게 복사 (Data 객체로 전환)
            let verticesData = Data(bytes: geometry.vertices.buffer.contents(), count: geometry.vertices.stride * geometry.vertices.count)
            let normalsData = Data(bytes: geometry.normals.buffer.contents(), count: geometry.normals.stride * geometry.normals.count)
            let facesData = Data(bytes: geometry.faces.buffer.contents(), count: geometry.faces.bytesPerIndex * geometry.faces.count * geometry.faces.indexCountPerPrimitive)

            // 2. 복사된 데이터로 고정된 소스 생성
            let vertexSource = SCNGeometrySource(data: verticesData, semantic: .vertex, vectorCount: geometry.vertices.count, usesFloatComponents: true, componentsPerVector: 3, bytesPerComponent: MemoryLayout<Float>.size, dataOffset: 0, dataStride: geometry.vertices.stride)
            let normalSource = SCNGeometrySource(data: normalsData, semantic: .normal, vectorCount: geometry.normals.count, usesFloatComponents: true, componentsPerVector: 3, bytesPerComponent: MemoryLayout<Float>.size, dataOffset: 0, dataStride: geometry.normals.stride)
            let element = SCNGeometryElement(data: facesData, primitiveType: .triangles, primitiveCount: geometry.faces.count, bytesPerIndex: geometry.faces.bytesPerIndex)
            
            return SCNGeometry(sources: [vertexSource, normalSource], elements: [element])
        }
    }
}

// MARK: - 3D 뷰어 (QuickLook) Wrapper
struct MeshQuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let parent: MeshQuickLookPreview
        init(_ parent: MeshQuickLookPreview) { self.parent = parent }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { return 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return parent.url as QLPreviewItem
        }
    }
}
