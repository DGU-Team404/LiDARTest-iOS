//
//  FrameMetadata.swift
//  LiDARTestApp
//
//  Created by 김도연 on 3/11/26.
//


import Foundation
import simd

// MARK: - 데이터 구조체 및 Helper
struct FrameMetadata {
    let timestamp: Double
    let depthFileName: String
    let confidenceFileName: String // ⭐️ 이 줄이 추가되어야 합니다!
    let transform: [Float]
    let intrinsics: [Float]
}

struct IMUData: Codable {
    let timestamp: Double
    let accel: [Double]
    let gyro: [Double]
}

struct RawDataRecord {
    let device: String
    var frames: [FrameMetadata]
    var imu: [IMUData]
}
