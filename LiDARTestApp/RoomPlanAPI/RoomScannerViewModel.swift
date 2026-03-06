//
//  RoomScannerViewModel.swift
//  LiDARTestApp
//
//  Created by 김도연 on 3/6/26.
//

import Foundation
import RoomPlan
import CoreImage
import UIKit
import simd

@Observable
class RoomScannerViewModel {
    
    var defects: [DefectInfo] = [] // 촬영된 하자 목록을 모아둘 배열
    var savedUsdzURL: URL? = nil   // 3D 뷰어용 파일 경로
    
    // MARK: - 1. 하자 사진 캡처 및 저장
    func addDefect(transform: simd_float4x4, pixelBuffer: CVPixelBuffer) {
        // 카메라의 현재 3D 위치 (x, y, z) 추출
        let x = transform.columns.3.x
        let y = transform.columns.3.y
        let z = transform.columns.3.z
        
        // CVPixelBuffer를 UIImage로 변환
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        
        // AR 카메라는 기본적으로 가로(Landscape Right)로 찍히므로 방향을 보정해줍니다.
        let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
        
        // 이미지 파일로 디바이스에 임시 저장
        let defectID = UUID().uuidString
        let fileName = "defect_\(defectID).jpg"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        if let jpegData = uiImage.jpegData(compressionQuality: 0.8) {
            do {
                try jpegData.write(to: fileURL)
                // 하자 정보를 배열에 추가
                let newDefect = DefectInfo(id: defectID, x: x, y: y, z: z, imageFileName: fileName)
                self.defects.append(newDefect)
                print("📸 하자 사진 저장 완료! (현재까지 \(self.defects.count)개 저장됨)")
            } catch {
                print("❌ 이미지 저장 실패: \(error)")
            }
        }
    }
    
    // MARK: - 2. 스캔 완료 데이터 처리 (JSON & USDZ)
    func processScannedRoom(_ room: CapturedRoom) {
        print("✅ [ViewModel] 방 데이터 및 3D 모델 생성을 시작합니다...\n")
        
        // 1. USDZ 3D 파일 추출 및 저장
        let usdzURL = FileManager.default.temporaryDirectory.appendingPathComponent("RoomModel.usdz")
        do {
            try room.export(to: usdzURL)
            self.savedUsdzURL = usdzURL
            print("📦 USDZ 3D 파일 저장 완료: \(usdzURL.path)")
        } catch {
            print("❌ USDZ 저장 실패: \(error)")
        }
        
        // 2. 서버 전송용 JSON 데이터 매핑
        let wallsData = room.walls.map { wall in
            RoomElementInfo(category: "Wall", width: wall.dimensions.x, height: wall.dimensions.y, depth: wall.dimensions.z, transform: wall.transform.flatArray)
        }
        
        let objectsData = room.objects.map { object in
            RoomElementInfo(category: String(describing: object.category), width: object.dimensions.x, height: object.dimensions.y, depth: object.dimensions.z, transform: object.transform.flatArray)
        }
        
        let roomRequest = RoomDataRequest(walls: wallsData, objects: objectsData, defects: self.defects)
        
        // 3. JSON 출력 (테스트용)
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(roomRequest)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("🚀 [서버 전송용 최종 JSON 데이터]")
                print(jsonString)
                print("-----------------------------------")
            }
        } catch {
            print("❌ JSON 인코딩 실패")
        }
    }
}
