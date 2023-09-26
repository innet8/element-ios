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

class FileExportManager: NSObject {
    private enum Constants {
        static let keyExportFileName = "eimchat-service.txt"
    }
    
    let destiVC: UIViewController
    private let keyExportFileURL: URL
    
    private var documentInteractionController: UIDocumentInteractionController?
    
    init(destiVC: UIViewController) {
        self.destiVC = destiVC
        self.keyExportFileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(Constants.keyExportFileName)
        super.init()
    }
    
    func exportFileToApp() {
        let documentInteractionController = UIDocumentInteractionController()
        documentInteractionController.delegate = self
    }
    
    func exportFile() {
        
    }
    
    func importFile() {
        
    }
    
    private func deleteFile() {
        let fileManager = FileManager.default
        
        if fileManager.fileExists(atPath: self.keyExportFileURL.path) {
            try? fileManager.removeItem(atPath: self.keyExportFileURL.path)
        }
    }
}

extension FileExportManager: UIDocumentInteractionControllerDelegate {
    // Note: This method is not called in all cases (see http://stackoverflow.com/a/21867096).
    func documentInteractionController(_ controller: UIDocumentInteractionController, didEndSendingToApplication application: String?) {
        self.deleteFile()
        self.documentInteractionController = nil
    }
    
    func documentInteractionControllerDidDismissOptionsMenu(_ controller: UIDocumentInteractionController) {
        self.documentInteractionController = nil
    }
}
