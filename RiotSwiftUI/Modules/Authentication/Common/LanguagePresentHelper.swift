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

class LanguagePresentHelper: NSObject {
    
    var compelete: ((Bool) -> Void)?
    private var navigationRouter: NavigationRouterType
    private var langPresenter: LangPresenter?

    init(navigationRouter: NavigationRouterType) {
        self.navigationRouter = navigationRouter
        super.init()
    }
    
    func presentLanguage() {
        guard let langVC = LanguagePickerViewController.init(swift: 0) else {
            return
        }
        
        langVC.selectedLanguage = Bundle.mxk_language()
        langVC.delegate = self
        
        let presenter = LangPresenter(viewController: langVC)
        langPresenter = presenter
        
        let router = NavigationRouter()
       
        router.setRootModule(presenter)
        
        navigationRouter.present(router, animated: true)
//        router.push(presenter, animated: true, popCompletion: nil)
    }
}

extension LanguagePresentHelper: MXKLanguagePickerViewControllerDelegate {
    func languagePickerViewController(_ languagePickerViewController: MXKLanguagePickerViewController!, didSelectLangugage language: String!) {
        
//        let lang = language
        var isChange = false
        
        if language != Bundle.mxk_language() || (language == nil && Bundle.mxk_language() != nil)
        {
            // , language == nil && [NSBundle mxk_language]
            Bundle.mxk_setLanguage(language)
            
            UIApplication.shared.accessibilityLanguage = language

            // Store user settings
            let sharedUserDefaults = MXKAppSettings.standard().sharedUserDefaults
            sharedUserDefaults?.setValue(language, forKey: "appLanguage")
            
            // Do a reload in order to recompute strings in the new language
            // Note that "reloadMatrixSessions:NO" will reset room summaries
            // [self startActivityIndicator];
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                AppDelegate.theDelegate().reloadMatrixSessions(false)
            }
            isChange = true

        }
        
        compelete?(isChange)
    }
}
