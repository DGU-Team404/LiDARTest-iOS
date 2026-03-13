//
//  PLYViewerView.swift
//  LiDARTestApp
//
//  Created by 김도연 on 3/11/26.
//


import SwiftUI
import SceneKit
import SceneKit.ModelIO
import ModelIO
import UniformTypeIdentifiers

// MARK: - PLY 파일 타입 정의
extension UTType {
    static var ply: UTType {
        UTType(filenameExtension: "ply") ?? .data
    }
}

// MARK: - 메인 뷰
struct PLYViewerView: View {
    @State private var selectedFileURL: URL?
    @State private var showDocumentPicker = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            // 상단 네비게이션 바 커스텀
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                }
                Spacer()
                Text("PLY 3D 뷰어")
                    .font(.headline)
                Spacer()
                Button(action: { showDocumentPicker = true }) {
                    Image(systemName: "folder")
                        .font(.title2)
                }
            }
            .padding()
            
            // 3D 뷰어 영역
            if let url = selectedFileURL {
                SceneKitPLYView(fileURL: url)
                    .edgesIgnoringSafeArea(.bottom)
            } else {
                Spacer()
                VStack(spacing: 20) {
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 80))
                        .foregroundColor(.gray)
                    Text("우측 상단의 폴더 아이콘을 눌러\n테스트할 .ply 파일을 선택해주세요.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                }
                Spacer()
            }
        }
        .navigationBarHidden(true)
        // ⭐️ 파일 선택기 (iPhone의 '파일' 앱 연동)
        .fileImporter(
            isPresented: $showDocumentPicker,
            allowedContentTypes: [.ply],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let selectedURL = urls.first else { return }
                // 권한을 얻어 파일에 접근
                let gotAccess = selectedURL.startAccessingSecurityScopedResource()
                if gotAccess {
                    self.selectedFileURL = selectedURL
                }
            case .failure(let error):
                print("파일 선택 오류: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - SceneKit을 이용한 3D 렌더링 뷰
struct SceneKitPLYView: UIViewRepresentable {
    var fileURL: URL
    
    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.allowsCameraControl = true // ⭐️ 손가락으로 회전, 줌인 가능하게 설정
        scnView.autoenablesDefaultLighting = true // 기본 조명 켜기
        scnView.backgroundColor = UIColor.systemGray6 // 배경색
        
        loadPLY(into: scnView, from: fileURL)
        return scnView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        // 파일이 바뀌면 새로 로드
        if let currentURL = uiView.scene?.attribute(forKey: "fileURL") as? URL, currentURL == fileURL {
            return
        }
        loadPLY(into: uiView, from: fileURL)
    }
    
    private func loadPLY(into view: SCNView, from url: URL) {
        do {
            // ModelIO를 사용해 PLY 파일 파싱
            let asset = MDLAsset(url: url)
            guard let object = asset.object(at: 0) as? MDLMesh else {
                print("PLY 파일에서 Mesh를 찾을 수 없습니다.")
                return
            }
            
            // MDLMesh를 SCNNode로 변환
            let node = SCNNode(mdlObject: object)
            
            // AI가 만든 모델은 중심점이 안 맞거나 크기가 제각각일 수 있으므로 정중앙으로 보정
            let (minVec, maxVec) = node.boundingBox
            let bound = SCNVector3(
                x: maxVec.x - minVec.x,
                y: maxVec.y - minVec.y,
                z: maxVec.z - minVec.z
            )
            node.pivot = SCNMatrix4MakeTranslation(
                minVec.x + (bound.x / 2),
                minVec.y + (bound.y / 2),
                minVec.z + (bound.z / 2)
            )
            
            // 화면에 띄울 Scene 구성
            let scene = SCNScene()
            scene.rootNode.addChildNode(node)
            scene.setAttribute(url, forKey: "fileURL") // 현재 URL 저장 (업데이트 체크용)
            
            view.scene = scene
            
        } catch {
            print("PLY 로드 실패: \(error)")
        }
    }
}
