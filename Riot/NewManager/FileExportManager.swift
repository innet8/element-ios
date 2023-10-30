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

class FileExportManager: NSObject {
    private enum Constants {
        static let keyExportFileName = "eimchat-service-key.txt"
    }
    
    enum SelectFileResult {
        case success(String)
        case failure(Error)
        case cancel
    }
    
    var completion: ((SelectFileResult) -> Void)?
    
    let destiVC: UIViewController
    private let keyExportFileURL: URL
    
    private var documentInteractionController: UIDocumentInteractionController?
    
    @objc
    init(destiVC: UIViewController) {
        self.destiVC = destiVC
        self.keyExportFileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(Constants.keyExportFileName)
        super.init()
    }
    
    func exportFileToApp() {
        guard FileManager.default.fileExists(atPath: self.keyExportFileURL.path) else {
            MXLog.info("failFile")
            return
        }
        let avc = UIActivityViewController(activityItems: [self.keyExportFileURL], applicationActivities: nil)
        destiVC.present(avc, animated: true, completion: nil)
        
//        documentInteractionController = UIDocumentInteractionController(url: self.keyExportFileURL)
//        documentInteractionController?.name = Constants.keyExportFileName
//        documentInteractionController?.delegate = self
//        if documentInteractionController?.presentOptionsMenu(from: destiVC.view.bounds, in: destiVC.view, animated: true) == true {
//
//        } else {
//            self.encryptionKeysExportView = nil
//            self.deleteFile()
//        }
    }
    
    @objc
    func exportFile(exportContent: String) {
        
        if let exportData = exportContent.data(using: .utf8) {
            do {
                try exportData.write(to: self.keyExportFileURL)
                MXLog.info("File saved successfully to Downloads folder.")
            } catch {
                MXLog.info("Error saving file: \(error.localizedDescription)")
                return
            }
        }
        
        exportFileToApp()
    }
    
    func importFile(completion: ((SelectFileResult) -> Void)?) {
        let documentPicker = UIDocumentPickerViewController(documentTypes: ["public.data"], in: .import)
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        documentPicker.shouldShowFileExtensions = true
        destiVC.present(documentPicker, animated: true, completion: nil)
        self.completion = completion
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

extension FileExportManager: UIDocumentPickerDelegate {
    // 处理用户选择的文件
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        // 处理选择的文件
        
        if let selectedFileURL = urls.first {
            // 通过 URL 获取文件的内容
            do {
                let fileContent = try String(contentsOf: selectedFileURL)
                completion?(.success(fileContent))
            } catch {
                completion?(.failure(error))
            }
        } else {
            completion?(.failure(NSError(domain: "Error file", code: 500)))
        }
        
        
    }

    // 处理取消选择文件
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        // 当用户取消选择文件时的处理
        // ...
        completion?(.cancel)
    }
}
