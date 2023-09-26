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

class StringCoder {
    static let defaulIv = "11212121"
    
    class func encodeString(sourceString: String, key: String, iv: String?) -> [UInt8]? {
        let defaulIv = iv ?? defaulIv
        let key = CryptoUtils.byteArray(from: key)
        let iv = CryptoUtils.byteArray(from: defaulIv)
        let plainText = CryptoUtils.byteArray(from: sourceString)
        
        var textToCipher = plainText
        if plainText.count % Cryptor.Algorithm.aes.blockSize != 0 {
            textToCipher = CryptoUtils.zeroPad(byteArray: plainText, blockSize: Cryptor.Algorithm.aes.blockSize)
        }
        do {
            guard let cipherText = try Cryptor(operation: .encrypt, algorithm: .aes, options: .none, key: key, iv: iv).update(byteArray: textToCipher)?.final() else {
                return nil
            }
                
            // print(CryptoUtils.hexString(from: cipherText!))
                
//            guard let decryptedText = try Cryptor(operation: .decrypt, algorithm: .aes, options: .none, key: key, iv: iv).update(byteArray: cipherText)?.final() else {
//                return nil
//            }

            // print(CryptoUtils.hexString(from: decryptedText!))
            return cipherText
        } catch let error {
            guard let err = error as? CryptorError else {
                // Handle non-Cryptor error...
                return nil
            }
            // Handle Cryptor error... (See Status.swift for types of errors thrown)
        }
        return nil
    }
    
    class func decodeString(sourceString: [UInt8], key: String, iv: String?) -> String? {
        let defaulIv = iv ?? defaulIv
        let key = CryptoUtils.byteArray(from: key)
        let iv = CryptoUtils.byteArray(from: defaulIv)
        let plainText = sourceString
        
        var textToCipher = plainText
        if plainText.count % Cryptor.Algorithm.aes.blockSize != 0 {
            textToCipher = CryptoUtils.zeroPad(byteArray: plainText, blockSize: Cryptor.Algorithm.aes.blockSize)
        }
        do {
             
            // print(CryptoUtils.hexString(from: cipherText!))
                
            guard let decryptedText = try Cryptor(operation: .decrypt, algorithm: .aes, options: .none, key: key, iv: iv).update(byteArray: textToCipher)?.final() else {
                return nil
            }

            // print(CryptoUtils.hexString(from: decryptedText!))
            return CryptoUtils.hexString(from: decryptedText)
        } catch let error {
            guard let err = error as? CryptorError else {
                // Handle non-Cryptor error...
                return nil
            }
            // Handle Cryptor error... (See Status.swift for types of errors thrown)
        }
        return nil
    }
}
