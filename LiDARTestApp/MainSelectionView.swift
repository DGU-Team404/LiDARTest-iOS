//
//  MainSelectionView.swift
//  LiDARTestApp
//
//  Created by 김도연 on 3/6/26.
//

import SwiftUI

struct MainSelectionView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Text("스캔 방식 선택")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // 1. 기존 RoomPlan 방식 버튼
                NavigationLink(destination: RoomScannerView()) {
                    VStack(spacing: 10) {
                        Text("1. RoomPlan 방식 (도면화)")
                            .font(.title2).fontWeight(.bold)
                        Text("방의 구조를 인식하여 깔끔한 흰색 블록 형태의 3D 모델과 JSON 데이터를 추출합니다. (하자 사진 핀포인트 기능 포함)")
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color.blue)
                    .cornerRadius(16)
                }
                .padding(.horizontal, 20)
                
                // 2. 새로운 ARKit Point Cloud 방식 버튼
                NavigationLink(destination: PointCloudScannerView()) {
                    VStack(spacing: 10) {
                        Text("2. ARKit LiDAR Mesh 방식")
                            .font(.title2).fontWeight(.bold)
                        Text("LiDAR 센서가 수집하는 날것의 3D 메쉬(Point Cloud)를 화면에 실시간으로 시각화하여 보여줍니다.")
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color.orange)
                    .cornerRadius(16)
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .padding(.top, 50)
            .navigationBarHidden(true)
        }
    }
}
