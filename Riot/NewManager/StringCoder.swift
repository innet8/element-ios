// 
// Copyright 2023 New Vector Ltd
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import UIKit
import Cryptor
import CommonCrypto

class StringCoder: NSObject {
    static let defaulIv = "xy8z56abxy8z56ab"
    enum CryptAESOption {
    case encrypt
    case decrypt
    }
    
    class func cryptAES(option: CryptAESOption, data: Data, key: Data, iv: Data) -> Data? {
        
        let aseOption: Int
        switch option {
        case .encrypt:
            aseOption = kCCEncrypt
        case .decrypt:
            aseOption = kCCDecrypt
        }
        
        let cryptLength = size_t(data.count + kCCBlockSizeAES128)
        var cryptData = Data(count: cryptLength)
        
        let keyLength = size_t(kCCKeySizeAES128)
        let options = CCOptions(kCCOptionPKCS7Padding)
        
        var numBytesEncrypted: size_t = 0
        
        let cryptStatus = key.withUnsafeBytes { keyBytes in
            iv.withUnsafeBytes { ivBytes in
                data.withUnsafeBytes { dataBytes in
                    cryptData.withUnsafeMutableBytes { cryptBytes in
                        CCCrypt(
                            CCOperation(aseOption),
                            CCAlgorithm(kCCAlgorithmAES),
                            options,
                            keyBytes.baseAddress, keyLength,
                            ivBytes.baseAddress,
                            dataBytes.baseAddress, data.count,
                            cryptBytes.baseAddress, cryptLength,
                            &numBytesEncrypted
                        )
                    }
                }
            }
        }
        
        if cryptStatus == kCCSuccess {
            cryptData.count = numBytesEncrypted
            return cryptData
        } else {
            return nil
        }
    }
    
    class func encodeString(sourceString: String, keyString: String, ivString: String = "xy8z56abxy8z56ab") -> [UInt8]? {
//        let defaulIv = ivString
//        let key = CryptoUtils.byteArray(from: keyString)
//        let iv = CryptoUtils.byteArray(from: defaulIv)
//        let plainText = CryptoUtils.byteArray(from: sourceString)
        guard let sourceData: Data = sourceString.data(using: .utf8), let keyData: Data =  keyString.data(using: .utf8), let ivData: Data = ivString.data(using: .utf8) else {
            return nil
        }
        if let encodeData = cryptAES(option: .encrypt, data: sourceData, key: keyData, iv: ivData) {
            let hexString = encodeData.map { String(format: "%02x", $0) }.joined()
            MXLog.info("directEncode:\(hexString)")
            
            var uint8Array = [UInt8](repeating: 0, count: encodeData.count)
            encodeData.withUnsafeBytes { rawBufferPointer in
                let unsafeBufferPointer = rawBufferPointer.bindMemory(to: UInt8.self)
                uint8Array = Array(unsafeBufferPointer)
            }

            return uint8Array
        } else {
            return nil
        }
    }
    
    @objc
    class func ocEncodeString(sourceString: String, keyString: String, ivString: String = "xy8z56abxy8z56ab") -> String? {
//        let defaulIv = ivString
//        let key = CryptoUtils.byteArray(from: keyString)
//        let iv = CryptoUtils.byteArray(from: defaulIv)
//        let plainText = CryptoUtils.byteArray(from: sourceString)
        guard let sourceData: Data = sourceString.data(using: .utf8), let keyData: Data =  keyString.data(using: .utf8), let ivData: Data = ivString.data(using: .utf8) else {
            return nil
        }
        if let encodeData = cryptAES(option: .encrypt, data: sourceData, key: keyData, iv: ivData) {
            let hexString = encodeData.map { String(format: "%02x", $0) }.joined()
            MXLog.info("directEncode:\(hexString)")
            
            var uint8Array = [UInt8](repeating: 0, count: encodeData.count)
            encodeData.withUnsafeBytes { rawBufferPointer in
                let unsafeBufferPointer = rawBufferPointer.bindMemory(to: UInt8.self)
                uint8Array = Array(unsafeBufferPointer)
            }

            return CryptoUtils.hexString(from: uint8Array, uppercase: true)
        } else {
            return nil
        }
    }
    
    class func decodeString(sourceString: String, keyString: String, ivString: String = "xy8z56abxy8z56ab") -> String? {
        let sourceData: Data = CryptoUtils.data(fromHex: sourceString)
        guard let keyData: Data =  keyString.data(using: .utf8), let ivData: Data = ivString.data(using: .utf8) else {
            return nil
        }
        if let encodeData = cryptAES(option: .decrypt, data: sourceData, key: keyData, iv: ivData) {
            
            return String(data: encodeData, encoding: .utf8)
        } else {
            return nil
        }
    }
}
