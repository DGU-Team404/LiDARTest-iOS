//
//  RawDataRecorder.swift
//  LiDARTestApp
//
//  Created by 김도연 on 3/11/26.
//

import simd

// MARK: - 3x3 행렬 변환 Helper (Intrinsics 용)
extension simd_float3x3 {
    var flatArray: [Float] {
        return [
            columns.0.x, columns.0.y, columns.0.z,
            columns.1.x, columns.1.y, columns.1.z,
            columns.2.x, columns.2.y, columns.2.z
        ]
    }
}

import Foundation
import ARKit
import AVFoundation
import CoreMotion
import CoreImage
import SwiftUI
import ZIPFoundation

@Observable
class RawDataRecorder: NSObject, ARSessionDelegate {
    var isRecording = false
    var savedZipURL: URL? = nil
    
    @ObservationIgnored let arSession = ARSession()
    @ObservationIgnored private let motionManager = CMMotionManager()
    @ObservationIgnored private let imuQueue = OperationQueue()
    
    @ObservationIgnored private var assetWriter: AVAssetWriter?
    @ObservationIgnored private var videoInput: AVAssetWriterInput?
    @ObservationIgnored private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    @ObservationIgnored private var isWriterReady = false
    @ObservationIgnored private var isFirstFrame = true
    
    @ObservationIgnored private var currentRecordFolder: URL?
    @ObservationIgnored private var lastKeyframeTransform: simd_float4x4?
    
    @ObservationIgnored private var imuDataArray: [IMUData] = []
    @ObservationIgnored private var frameDataArray: [FrameMetadata] = []
    
    override init() {
        super.init()
        arSession.delegate = self
    }
    
    func startPreview() {
        let config = ARWorldTrackingConfiguration()
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
        }
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        arSession.run(config, options: [.resetTracking, .removeExistingAnchors])
    }
    
    func startRecording() {
        let folderName = "RawData_\(Date().timeIntervalSince1970)"
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(folderName)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        currentRecordFolder = tempDir
        
        imuDataArray.removeAll()
        frameDataArray.removeAll()
        isFirstFrame = true
        
        setupVideoWriter(in: tempDir)
        startIMU()
        
        isRecording = true
    }
    
    func stopRecording() {
        isRecording = false
        motionManager.stopDeviceMotionUpdates()
        arSession.pause()
        
        assetWriter?.finishWriting { [weak self] in
            guard let self = self, let folderPath = self.currentRecordFolder else { return }
            
            self.exportCSVFiles(in: folderPath)
            
            // 📦 ZIP 압축
            let zipURL = folderPath.appendingPathExtension("zip")
            do {
                if FileManager.default.fileExists(atPath: zipURL.path) {
                    try FileManager.default.removeItem(at: zipURL)
                }
                try FileManager.default.zipItem(at: folderPath, to: zipURL)
                DispatchQueue.main.async { self.savedZipURL = zipURL }
            } catch { print("❌ ZIP 압축 실패: \(error)") }
        }
    }
    
    // MARK: - CSV 추출 (camera_matrix, odometry, imu 분리)
    private func exportCSVFiles(in folderPath: URL) {
        // 1. imu.csv
        var imuCSV = "timestamp,accel_x,accel_y,accel_z,gyro_x,gyro_y,gyro_z\n"
        let imuRows = imuDataArray.map { "\($0.timestamp),\($0.accel[0]),\($0.accel[1]),\($0.accel[2]),\($0.gyro[0]),\($0.gyro[1]),\($0.gyro[2])" }
        imuCSV += imuRows.joined(separator: "\n")
        try? imuCSV.write(to: folderPath.appendingPathComponent("imu.csv"), atomically: true, encoding: .utf8)
        
        // 2. camera_matrix.csv (Intrinsics + 연관 파일 매핑)
        var cameraCSV = "timestamp,depth_file,confidence_file,fx,fy,cx,cy\n"
        let cameraRows = frameDataArray.map { f in
            let fx = f.intrinsics[0]; let fy = f.intrinsics[4]; let cx = f.intrinsics[6]; let cy = f.intrinsics[7]
            return "\(f.timestamp),\(f.depthFileName),\(f.confidenceFileName),\(fx),\(fy),\(cx),\(cy)"
        }
        cameraCSV += cameraRows.joined(separator: "\n")
        try? cameraCSV.write(to: folderPath.appendingPathComponent("camera_matrix.csv"), atomically: true, encoding: .utf8)
        
        // 3. odometry.csv (계산된 ARKit 위치/회전 4x4 Transform)
        var odometryCSV = "timestamp,t00,t01,t02,t03,t10,t11,t12,t13,t20,t21,t22,t23,t30,t31,t32,t33\n"
        let odometryRows = frameDataArray.map { f in
            let t = f.transform.map { String($0) }.joined(separator: ",")
            return "\(f.timestamp),\(t)"
        }
        odometryCSV += odometryRows.joined(separator: "\n")
        try? odometryCSV.write(to: folderPath.appendingPathComponent("odometry.csv"), atomically: true, encoding: .utf8)
    }
    
    // MARK: - 비디오 세팅 (rgb.mp4)
    private func setupVideoWriter(in folder: URL) {
        let videoURL = folder.appendingPathComponent("rgb.mp4") // 파일명 수정됨
        assetWriter = try? AVAssetWriter(outputURL: videoURL, fileType: .mp4)
        
        let settings: [String: Any] = [AVVideoCodecKey: AVVideoCodecType.hevc, AVVideoWidthKey: 1920, AVVideoHeightKey: 1080]
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        videoInput?.expectsMediaDataInRealTime = true
        if let input = videoInput, assetWriter?.canAdd(input) == true { assetWriter?.add(input) }
        
        let attributes: [String: Any] = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput!, sourcePixelBufferAttributes: attributes)
        
        assetWriter?.startWriting()
        isWriterReady = true
    }
    
    private func startIMU() {
        motionManager.deviceMotionUpdateInterval = 1.0 / 100.0
        motionManager.startDeviceMotionUpdates(to: imuQueue) { [weak self] motion, _ in
            guard let self = self, let motion = motion, self.isRecording else { return }
            let imu = IMUData(timestamp: motion.timestamp, accel: [motion.userAcceleration.x, motion.userAcceleration.y, motion.userAcceleration.z], gyro: [motion.rotationRate.x, motion.rotationRate.y, motion.rotationRate.z])
            self.imuDataArray.append(imu)
        }
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard isRecording, isWriterReady, let folderPath = currentRecordFolder else { return }
        let timestamp = frame.timestamp
        
        // 1. RGB Video
        if videoInput?.isReadyForMoreMediaData == true {
            let time = CMTime(seconds: timestamp, preferredTimescale: 600)
            if isFirstFrame {
                assetWriter?.startSession(atSourceTime: time)
                isFirstFrame = false
            }
            pixelBufferAdaptor?.append(frame.capturedImage, withPresentationTime: time)
        }
        
        // 2. Keyframe 추출 (Depth + Confidence + Odometry)
        let currentTransform = frame.camera.transform
        if shouldCaptureKeyframe(currentTransform) {
            lastKeyframeTransform = currentTransform
            
            if let sceneDepth = frame.sceneDepth {
                let depthFileName = "depth_\(String(format: "%.3f", timestamp)).png"
                let confidenceFileName = "confidence_\(String(format: "%.3f", timestamp)).png"
                
                // Depth 맵 저장 (16-bit)
                saveDepthAsPNG(pixelBuffer: sceneDepth.depthMap, url: folderPath.appendingPathComponent(depthFileName), is16Bit: true)
                
                // Confidence 맵 저장 (8-bit)
                if let confidenceMap = sceneDepth.confidenceMap {
                    saveDepthAsPNG(pixelBuffer: confidenceMap, url: folderPath.appendingPathComponent(confidenceFileName), is16Bit: false)
                }
                
                let frameMeta = FrameMetadata(
                    timestamp: timestamp,
                    depthFileName: depthFileName,
                    confidenceFileName: confidenceFileName, // confidence 추가됨
                    transform: currentTransform.flatArray,
                    intrinsics: frame.camera.intrinsics.flatArray
                )
                frameDataArray.append(frameMeta)
            }
        }
    }
    
    private func shouldCaptureKeyframe(_ current: simd_float4x4) -> Bool {
        guard let last = lastKeyframeTransform else { return true }
        let distance = simd_distance(current.columns.3, last.columns.3)
        return distance > 0.1 // 10cm 이동 시 캡처
    }
    
    // ⭐️ Depth(16bit)와 Confidence(8bit) 통합 저장 Helper
    private func saveDepthAsPNG(pixelBuffer: CVPixelBuffer, url: URL, is16Bit: Bool) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.linearGray) else { return }
        // is16Bit 파라미터에 따라 .L16 또는 .L8 포맷으로 저장
        let format: CIFormat = is16Bit ? .L16 : .L8
        if let data = CIContext().pngRepresentation(of: ciImage, format: format, colorSpace: colorSpace) {
            try? data.write(to: url)
        }
    }
}
