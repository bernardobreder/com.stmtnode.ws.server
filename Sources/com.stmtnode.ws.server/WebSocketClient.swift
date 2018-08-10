//
//  WebSocketClient.swift
//  MovappingShell
//
//  Created by Bernardo Breder on 31/07/17.
//  Copyright © 2017 com.movapping. All rights reserved.
//

import Foundation
#if SWIFT_PACKAGE
import com_stmtnode_net
#endif

public class WebSocketClient {
    
    let client: NetworkClient
    
    public init(client: NetworkClient) {
        self.client = client
    }
    
    deinit {
        let _ = client.write(data: Data(bytes: [UInt8(0x88), UInt8(0x0)]))
    }
    
    public func read() -> String? {
        guard let c1: UInt8 = client.read() else { return nil }
        let finalFragment: Bool = (c1 >> 7) == 1
        guard finalFragment else { return nil }
        let  opcode: UInt8 = c1 & 0xF
        guard opcode == 0x1 else { return nil }
        guard let c2: UInt8 = client.read() else { return nil }
        var length: Int = Int(c2) & 0x7F;
        if (length <= 125) {
        } else if (length == 126) {
            guard let c3 = client.read() else { return nil }
            guard let c4 = client.read() else { return nil }
            length = Int(c3) << 8
            length += Int(c4)
        } else {
            guard let c3 = client.read() else { return nil }
            guard let c4 = client.read() else { return nil }
            guard let c5 = client.read() else { return nil }
            guard let c6 = client.read() else { return nil }
            guard let c7 = client.read() else { return nil }
            guard let c8 = client.read() else { return nil }
            guard let c9 = client.read() else { return nil }
            guard let c10 = client.read() else { return nil }
            length = (Int(c3) << 56)
            length += (Int(c4) << 48)
            length += (Int(c5) << 40)
            length += (Int(c6) << 32)
            length += (Int(c7) << 24)
            length += (Int(c8) << 16)
            length += (Int(c9) << 8)
            length += Int(c10)
        }
        var mask: [Int] = [Int](repeating: 0, count: 4)
        for i in 0 ..< 4 {
            guard let c: UInt8 = client.read() else { return nil }
            mask[i] = Int(c)
        }
        var content: String = ""
        var i: Int = 0
        while i < length {
            guard let b1: UInt8 = client.read() else { return nil }
            let i1: UInt8 = UInt8(Int(b1) ^ mask[i % 4])
            if (i1 <= 0x7F) {
                content += String(Character(UnicodeScalar(i1)))
                i += 1
            } else if ((i1 >> 5) == 0x6) {
                guard let b2: UInt8 = client.read() else { return nil }
                i += 1
                let i2 = UInt8(Int(b2) ^ mask[i % 4])
                content += String(Character(UnicodeScalar(((i1 & 0x1F) << 6) + (i2 & 0x3F))))
            } else {
                guard let b2: UInt8 = client.read() else { return nil }
                guard let b3: UInt8 = client.read() else { return nil }
                i += 1
                let i2: UInt8 = UInt8(Int(b2) ^ mask[i % 4])
                i += 1
                let i3: UInt8 = UInt8(Int(b3) ^ mask[i % 4])
                content += String(Character(UnicodeScalar(((i1 & 0xF) << 12) + ((i2 & 0x3F) << 6) + (i3 & 0x3F))))
            }
        }
        return content
    }
    
    public func write(_ string: String) -> Bool {
        var bytes = [UInt8]()
        bytes.append(0x81)
        let utf8 = [UInt8](string.utf8)
        let length = utf8.count
        if length <= 125 {
            bytes.append(UInt8(length))
        } else if length <= 65535 {
            bytes.append(UInt8(126))
            bytes.append(UInt8(length >> 8))
            bytes.append(UInt8(length & 0xFF))
        } else {
            bytes.append(UInt8(127))
            bytes.append(UInt8((length >> 56) & 0xFF))
            bytes.append(UInt8((length >> 48) & 0xFF))
            bytes.append(UInt8((length >> 40) & 0xFF))
            bytes.append(UInt8((length >> 32) & 0xFF))
            bytes.append(UInt8((length >> 24) & 0xFF))
            bytes.append(UInt8((length >> 16) & 0xFF))
            bytes.append(UInt8((length >> 08) & 0xFF))
            bytes.append(UInt8((length >> 00) & 0xFF))
        }
        bytes.append(contentsOf: utf8)
        return client.write(data: Data(bytes: bytes))
    }
    
}
