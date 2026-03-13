//
//  SomeView.swift
//  LiDARTestApp
//
//  Created by 김도연 on 3/11/26.
//

import SwiftUI

// 프로토콜 선언 - 이 프로토콜을 받는 친구는 이 안에 있는 함수를 무조건 선언해줘야 한다.
protocol SomeProtocol {
    func doSomething()
}

// 클래스는 위 프로토콜을 따르게 됨
class SomeClass: SomeProtocol {
    // 이 함수가 없다면 Error가 발생
    func doSomething() {
        print("doSomething")
    }
}

