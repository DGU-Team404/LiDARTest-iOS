//
//  RoomDataRequest.swift
//  LiDARTestApp
//
//  Created by 김도연 on 3/6/26.
//

import Foundation
import simd

// MARK: - 서버로 보낼 JSON 데이터 구조체 정의 (Codable)
struct RoomDataRequest: Codable {
    let walls: [RoomElementInfo]
    let objects: [RoomElementInfo]
    let defects: [DefectInfo] // ⭐️ 하자 기록 데이터 추가
}

struct RoomElementInfo: Codable {
    let category: String
    let width: Float
    let height: Float
    let depth: Float
    let transform: [Float]
}

// ⭐️ 하자 정보를 담을 구조체
struct DefectInfo: Codable {
    let id: String
    let x: Float     // 하자를 촬영했을 때 카메라의 3D X 좌표
    let y: Float     // 하자를 촬영했을 때 카메라의 3D Y 좌표
    let z: Float     // 하자를 촬영했을 때 카메라의 3D Z 좌표
    let imageFileName: String // 저장된 이미지 파일명
}

// MARK: - 4x4 행렬 변환 Helper
// ARKit의 4x4 행렬을 서버 전송용 Float 배열로 변환
extension simd_float4x4 {
    var flatArray: [Float] {
        return [
            columns.0.x, columns.0.y, columns.0.z, columns.0.w,
            columns.1.x, columns.1.y, columns.1.z, columns.1.w,
            columns.2.x, columns.2.y, columns.2.z, columns.2.w,
            columns.3.x, columns.3.y, columns.3.z, columns.3.w
        ]
    }
}
