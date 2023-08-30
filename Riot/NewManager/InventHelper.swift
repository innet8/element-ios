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
import AFNetworking
import Alamofire

class InventHelper: NSObject {
    
    
    /// get inventCode
    /// - Parameter callBack: inventCode callback
    static func getInventAction(callBack: ((String?) -> Void)?) {
        let baseUrl = AuthenticationService.shared.state.homeserver.address
        let inventPath = "/_synapse/admin/v1/registration_link"
        
        var access_token: String
        
        guard let delegate = UIApplication.shared.delegate as? AppDelegate, let coordinator = delegate.appCoordinator as? AppCoordinator else {
            return
        }
        
        access_token = coordinator.mainMatrixSession?.credentials.accessToken ?? ""
        let headers = ["Authorization": "Bearer \(access_token)"]
        
        request(url: baseUrl+inventPath, method: .get, parameters: nil, headers: headers) { result in
            if let inventCode = result["app_invite_link"] as? String {
                callBack?(inventCode)
            } else {
                callBack?(nil)
            }
          
        } failure: { _ in
            callBack?(nil)
            
        }

    }
    
    /// call after register success
    /// - Parameter inventCode: currentInventToken
    static func confirmInventCode(inventCode: String) {
        let baseUrl = AuthenticationService.shared.state.homeserver.address
        let inventPath = "/_synapse/admin/v1/record_registration_token/\(inventCode)"
        
        var access_token: String
        
        guard let delegate = UIApplication.shared.delegate as? AppDelegate, let coordinator = delegate.appCoordinator as? AppCoordinator else {
            return
        }
        
        access_token = coordinator.mainMatrixSession?.credentials.accessToken ?? ""
        let headers = ["Authorization": "Bearer \(access_token)"]
        
        request(url: baseUrl+inventPath, method: .get, parameters: nil, headers: headers) { _ in
          
        } failure: { _ in
            
        }
    }
    
    
    /// vaild invent code is useful
    /// - Parameters:
    ///   - inventCode: invent code from link
    ///   - callback: resulte
    static func vaildInventCode(inventCode: String, callback: ((Bool) -> Void)?) {
        
        let baseUrl = AuthenticationService.shared.state.homeserver.address
        let inventPath = "/_synapse/admin/v1/registration_tokens/\(inventCode)"
        
        request(url: baseUrl+inventPath, method: .get, parameters: nil, headers: [:]) { result in
            if result["error"] != nil {
                callback?(false)
            } else {
                callback?(true)
            }
            
        } failure: { err in
            callback?(false)
            let error = err
            
        }
        
    }
    
    
    /// custom request
    /// - Parameters:
    ///   - url: url
    ///   - method: http method
    ///   - parameters: request param
    ///   - headers: header param
    ///   - success: success callback
    ///   - failure: failure callback
    static func request(url: String, method: HTTPMethod, parameters: [String: Any]?, headers: [String: String], success: (([String: Any]) -> Void)?, failure: ((Error) -> Void)?) {
        let httpHeaders = HTTPHeaders(headers)
        AF.request(url, method: method, parameters: parameters, headers: httpHeaders, requestModifier: { $0.timeoutInterval = 20 }).responseData { response in
            switch response.result {
            case .success(let data):
                do {
                    let asJSON = try JSONSerialization.jsonObject(with: data)
                    // Handle as previously success
                    if let sysJSON = asJSON as? [String: Any] {
                        success?(sysJSON)
                    } else {
                        failure?("error")
                    }
                    
                    MXLog.debug(" getSuccess: \(asJSON)")
                } catch {
                    failure?(error)
                    MXLog.debug(" getError: \(error)")
                    // Here, I like to keep a track of error if it occurs, and also print the response data if possible into String with UTF8 encoding
                    // I can't imagine the number of questions on SO where the error is because the API response simply not being a JSON and we end up asking for that "print", so be sure of it
                    
                }
            case .failure(let error):
                failure?(error)
                // Handle as previously error
            }
        }
    }
}
