//
// Copyright 2021 New Vector Ltd
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

import CommonKit
import MatrixSDK
import SwiftUI

struct AuthenticationLoginCoordinatorParameters {
    let navigationRouter: NavigationRouterType
    let authenticationService: AuthenticationService
    /// The login mode to allow SSO buttons to be shown when available.
    let loginMode: LoginMode
}

enum AuthenticationLoginCoordinatorResult: CustomStringConvertible {
    /// Continue using the supplied SSO provider.
    case continueWithSSO(SSOIdentityProvider)
    /// Login was successful with the associated session created.
    case success(session: MXSession, password: String)
    /// Login was successful with the associated session created.
    case loggedInWithQRCode(session: MXSession, securityCompleted: Bool)
    /// Login requested a fallback
    case fallback
    
    /// A string representation of the result, ignoring any associated values that could leak PII.
    var description: String {
        switch self {
        case .continueWithSSO(let provider):
            return "continueWithSSO: \(provider)"
        case .success:
            return "success"
        case .loggedInWithQRCode:
            return "loggedInWithQRCode"
        case .fallback:
            return "fallback"
        }
    }
}

enum AlertPasswordResult {
    case confirm(String)
    case cancel
}

final class AuthenticationLoginCoordinator: Coordinator, Presentable {
    // MARK: - Properties
    
    // MARK: Private
    
    private let parameters: AuthenticationLoginCoordinatorParameters
    private let authenticationLoginHostingController: VectorHostingController
    private var authenticationLoginViewModel: AuthenticationLoginViewModelProtocol
    
    private var currentTask: Task<Void, Error>? {
        willSet {
            currentTask?.cancel()
        }
    }
    
    private var navigationRouter: NavigationRouterType { parameters.navigationRouter }
    private var indicatorPresenter: UserIndicatorTypePresenterProtocol
    private var waitingIndicator: UserIndicator?
    private var successIndicator: UserIndicator?
    private var langHelper: LanguagePresentHelper?
    private var errorCount = 0
    private var fileExport :FileExportManager?
    
    /// The authentication service used for the login.
    private var authenticationService: AuthenticationService { parameters.authenticationService }
    /// The wizard used to handle the login flow. Will only be `nil` if there is a misconfiguration.
    private var loginWizard: LoginWizard? { parameters.authenticationService.loginWizard }
    
    // MARK: Public

    // Must be used only internally
    var childCoordinators: [Coordinator] = []
    var callback: (@MainActor (AuthenticationLoginCoordinatorResult) -> Void)?
    
    // MARK: - Setup
    
    @MainActor init(parameters: AuthenticationLoginCoordinatorParameters) {
        self.parameters = parameters
        
        let homeserver = parameters.authenticationService.state.homeserver
        let viewModel = AuthenticationLoginViewModel(homeserver: homeserver.viewData)
        authenticationLoginViewModel = viewModel
        
        let view = AuthenticationLoginScreen(viewModel: viewModel.context)
        authenticationLoginHostingController = VectorHostingController(rootView: view)
        authenticationLoginHostingController.vc_removeBackTitle()
        authenticationLoginHostingController.enableNavigationBarScrollEdgeAppearance = true
        
        indicatorPresenter = UserIndicatorTypePresenter(presentingViewController: authenticationLoginHostingController)
    }
    
    // MARK: - Public

    func start() {
        MXLog.debug("[AuthenticationLoginCoordinator] did start.")
        Task { await setupViewModel() }
    }
    
    func toPresentable() -> UIViewController {
        authenticationLoginHostingController
    }
    
    // MARK: - Private
    
    /// Set up the view model. This method is extracted from `start()` so it can run on the `MainActor`.
    @MainActor private func setupViewModel() {
        authenticationLoginViewModel.callback = { [weak self] result in
            guard let self = self else { return }
            MXLog.debug("[AuthenticationLoginCoordinator] AuthenticationLoginViewModel did callback with result: \(result).")
            
            switch result {
            case .selectServer:
                self.presentServerSelectionScreen()
            case .parseUsername(let username):
                self.parseUsername(username)
            case .forgotPassword:
                self.showForgotPasswordScreen()
            case .login(let username, let password):
                self.login(username: username, password: password)
            case .continueWithSSO(let identityProvider):
                self.callback?(.continueWithSSO(identityProvider))
            case .fallback:
                self.callback?(.fallback)
            case .qrLogin:
                self.showQRLoginScreen()
            case .selectLanguage:
                // // Display the language picker
//                LanguagePickerViewController *languagePickerViewController = [LanguagePickerViewController languagePickerViewController];
//                languagePickerViewController.selectedLanguage = [NSBundle mxk_language];
//                languagePickerViewController.delegate = self;
//                [self pushViewController:languagePickerViewController];
                let helper = LanguagePresentHelper(navigationRouter: navigationRouter)
                langHelper = helper
                helper.compelete = { [weak self] change in
                    guard let self = self else { return }
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "schemeDidStart"), object: nil)
                    
                }
                helper.presentLanguage()
                
            case .linkHome:
                guard let link = URL(string: BuildSettings.applicationHomeLink) else {
                    return
                }
                UIApplication.shared.open(link)
            case .importFile:
                let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
                
                // 弹出密钥输入框
                alertController.addAction(UIAlertAction(title: VectorL10n.accountImportKey, style: .default, handler: { (action) in
                    self.privateEnter()
                }))
                
                // 添加一个确定按钮
                alertController.addAction(UIAlertAction(title: VectorL10n.accountImportFiles, style: .default, handler: { (action) in
                    self.importFile()
                }))
                
                // 添加一个取消按钮
                alertController.addAction(UIAlertAction(title: VectorL10n.cancel, style: .cancel, handler: { (action) in
                    
                }))
                
                // 显示弹窗
                toPresentable().present(alertController, animated: true, completion: nil)
                
                break
            }
        }
    }
    
    @MainActor private func privateEnter() {
        // 创建一个 UIAlertController
        let alertController = UIAlertController(title: VectorL10n.accountImportKey, message: nil, preferredStyle: .alert)
        
        // 添加一个密码输入框
        alertController.addTextField { (textField) in
            textField.placeholder = VectorL10n.securityServicePassword
        }
        
        // 添加一个取消按钮
        alertController.addAction(UIAlertAction(title: VectorL10n.cancel, style: .cancel, handler: { (action) in
            
            
        }))
        
        // 添加一个确定按钮
        alertController.addAction(UIAlertAction(title: VectorL10n.confirm, style: .default, handler: { [weak self] (action) in
            guard let self = self else { return }
            // 处理用户输入的密码
            if let privareKey = alertController.textFields?.first?.text {
                var appendString = ""
                for _ in 0...15 {
                    appendString = appendString+"0"
                }
                
                if let decodeString = StringCoder.decodeString(sourceString: privareKey, keyString: appendString) {
                    if decodeString.count < 4 {
                        authenticationLoginViewModel.displayError(.mxError("密钥错误"))
                        return
                    }
                    self.handelSuccessDecode(content: decodeString)
                } else {
                    authenticationLoginViewModel.displayError(.mxError("密钥错误"))
                }
            }
        }))
        
        // 显示弹窗
        toPresentable().present(alertController, animated: true, completion: nil)
        
    }
    
    @MainActor private func importFile() {
        let manager = FileExportManager(destiVC: toPresentable())
        self.fileExport = manager
        manager.importFile { result in

            switch result {
            case .success(let readContent):
                self.errorCount = 0
                let trim = readContent.trimmingCharacters(in: .whitespacesAndNewlines)
                self.decodeString(readContent: trim)

            case .failure(let error):
                self.handleError(error)

            case .cancel:
                break
            }
            self.fileExport = nil
        }
    }
    
    @MainActor private func update(homeAdress: String) {
        let homeserverAddress = HomeserverAddress.sanitized(homeAdress)
        if homeserverAddress == authenticationService.state.homeserver.address {
            return
        }
        
        startLoading(isInteractionBlocking: false)
        Task { [weak self] in
            do {
                try await self?.authenticationService.startFlow(.login, for: homeserverAddress)
                
                guard !Task.isCancelled else {
                    self?.stopLoading()
                    return
                    
                }
                
                self?.updateViewModelHomeserver()
                self?.stopLoading()
            } catch {
                self?.stopLoading()
                self?.handleError(error)
            }
        }
    }
    
    @MainActor private func decodeString(readContent: String) {
        showAESPassword { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .confirm(let password):
                var appendString = password
                for _ in password.count...15 {
                    appendString = appendString+"0"
                }
                
                MXLog.info("appendStringLength:\(appendString.count)")
                
                if let decodeString = StringCoder.decodeString(sourceString: readContent, keyString: appendString) {
                    if decodeString.count < 4 {
                        authenticationLoginViewModel.displayError(.mxError("解析结果错误"))
                        return
                    }
                    self.handelSuccessDecode(content: decodeString)
                } else {
                    self.errorCount += 1
                    if self.errorCount < 3 {
                        decodeString(readContent: readContent)
                    } else {
                        self.errorCount = 0
                        authenticationLoginViewModel.displayError(.mxError("密码错误，解析失败"))
                    }
                }
                break
            case .cancel:
                break
            }
        }
    }
    
    @MainActor private func handelSuccessDecode(content: String) {
        // @XXX:XXX
        let pattern = "@([A-Za-z0-9]+):([^\n\r]+)"
            
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(location: 0, length: content.utf16.count)
            let matches = regex.matches(in: content, options: [], range: range)
            
            for match in matches {
                
                if let nameRange = Range(match.range(at: 1), in: content), let serviceRange = Range(match.range(at: 2), in: content) {
                    
                    let nameString = content[nameRange]
                    let serviceString = content[serviceRange]
                    update(username: String(nameString))
                    update(homeAdress: String(serviceString))
                } else {
                    authenticationLoginViewModel.displayError(.mxError("解密信息解析错误"))
                }
                
            }
            
        } catch {
            authenticationLoginViewModel.displayError(.mxError("解密信息解析错误"))
//            MXLog.info("匹配失败\(error)")
        }
    }
    
    @MainActor private func showAESPassword(completion: ((AlertPasswordResult) -> Void)?) {
        // 创建一个 UIAlertController
        let alertController = UIAlertController(title: VectorL10n.loginPasswordPlaceholder, message: nil, preferredStyle: .alert)
        
        // 添加一个密码输入框
        alertController.addTextField { (textField) in
            textField.isSecureTextEntry = true
            textField.placeholder = VectorL10n.loginPasswordPlaceholder
        }
        
        // 添加一个取消按钮
        alertController.addAction(UIAlertAction(title: VectorL10n.cancel, style: .cancel, handler: { (action) in
            // 处理用户输入的密码
            completion?(.cancel)
            
        }))
        
        // 添加一个确定按钮
        alertController.addAction(UIAlertAction(title: VectorL10n.confirm, style: .default, handler: { (action) in
            // 处理用户输入的密码
            if let password = alertController.textFields?.first?.text {
                completion?(.confirm(password))
            }
        }))
        
        // 显示弹窗
        toPresentable().present(alertController, animated: true, completion: nil)
    }
    
    /// Show a blocking activity indicator whilst saving.
    @MainActor private func startLoading(isInteractionBlocking: Bool) {
        waitingIndicator = indicatorPresenter.present(.loading(label: VectorL10n.loading, isInteractionBlocking: isInteractionBlocking))
        
        if !isInteractionBlocking {
            authenticationLoginViewModel.update(isLoading: true)
        }
    }
    
    /// Hide the currently displayed activity indicator.
    @MainActor private func stopLoading() {
        authenticationLoginViewModel.update(isLoading: false)
        waitingIndicator = nil
    }
    
    /// Login with the supplied username and password.
    @MainActor private func login(username: String, password: String) {
        guard let loginWizard = loginWizard else {
            MXLog.failure("[AuthenticationLoginCoordinator] The login wizard was requested before getting the login flow.")
            return
        }
        
        startLoading(isInteractionBlocking: true)
        
        currentTask = Task { [weak self] in
            do {
                let session = try await loginWizard.login(login: username,
                                                          password: password,
                                                          initialDeviceName: UIDevice.current.initialDisplayName)
                
                guard !Task.isCancelled else { return }
                self?.callback?(.success(session: session, password: password))
                
                self?.stopLoading()
            } catch {
                self?.stopLoading()
                self?.handleError(error)
            }
        }
    }
    
    /// Processes an error to either update the flow or display it to the user.
    @MainActor private func handleError(_ error: Error) {
        if let mxError = MXError(nsError: error as NSError) {
            let message = mxError.authenticationErrorMessage()
            authenticationLoginViewModel.displayError(.mxError(message))
            return
        }
        
        if let authenticationError = error as? AuthenticationError {
            switch authenticationError {
            case .invalidHomeserver:
                authenticationLoginViewModel.displayError(.invalidHomeserver)
            case .loginFlowNotCalled:
                #warning("Reset the flow")
            case .missingMXRestClient:
                #warning("Forget the soft logout session")
            }
            return
        }
        
        authenticationLoginViewModel.displayError(.unknown)
    }
    
    @MainActor private func parseUsername(_ username: String) {
        guard MXTools.isMatrixUserIdentifier(username) else { return }
        let domain = username.components(separatedBy: ":")[1]
        let homeserverAddress = HomeserverAddress.sanitized(domain)
        
        startLoading(isInteractionBlocking: false)
        
        currentTask = Task { [weak self] in
            do {
                try await self?.authenticationService.startFlow(.login, for: homeserverAddress)
                
                guard !Task.isCancelled else { return }
                
                self?.updateViewModel()
                self?.stopLoading()
            } catch {
                self?.stopLoading()
                self?.handleError(error)
            }
        }
    }
    
    /// Presents the server selection screen as a modal.
    @MainActor private func presentServerSelectionScreen() {
        MXLog.debug("[AuthenticationLoginCoordinator] presentServerSelectionScreen")
        let parameters = AuthenticationServerSelectionCoordinatorParameters(authenticationService: authenticationService,
                                                                            flow: .login,
                                                                            hasModalPresentation: true)
        let coordinator = AuthenticationServerSelectionCoordinator(parameters: parameters)
        coordinator.callback = { [weak self, weak coordinator] result in
            guard let self = self, let coordinator = coordinator else { return }
            self.serverSelectionCoordinator(coordinator, didCompleteWith: result)
        }
        
        coordinator.start()
        add(childCoordinator: coordinator)
        
        let modalRouter = NavigationRouter()
        modalRouter.setRootModule(coordinator)
        
        navigationRouter.present(modalRouter, animated: true)
    }
    
    /// Handles the result from the server selection modal, dismissing it after updating the view.
    @MainActor private func serverSelectionCoordinator(_ coordinator: AuthenticationServerSelectionCoordinator,
                                                       didCompleteWith result: AuthenticationServerSelectionCoordinatorResult) {
        navigationRouter.dismissModule(animated: true) { [weak self] in
            if result == .updated {
                self?.updateViewModel()
            }

            self?.remove(childCoordinator: coordinator)
        }
    }

    /// Shows the forgot password screen.
    @MainActor private func showForgotPasswordScreen() {
        MXLog.debug("[AuthenticationLoginCoordinator] showForgotPasswordScreen")

        guard let loginWizard = loginWizard else {
            MXLog.failure("[AuthenticationLoginCoordinator] The login wizard was requested before getting the login flow.")
            return
        }

        let modalRouter = NavigationRouter()

        let parameters = AuthenticationForgotPasswordCoordinatorParameters(navigationRouter: modalRouter,
                                                                           loginWizard: loginWizard,
                                                                           homeserver: parameters.authenticationService.state.homeserver)
        let coordinator = AuthenticationForgotPasswordCoordinator(parameters: parameters)
        coordinator.callback = { [weak self, weak coordinator] result in
            guard let self = self, let coordinator = coordinator else { return }
            switch result {
            case .success:
                self.navigationRouter.dismissModule(animated: true, completion: nil)
                self.successIndicator = self.indicatorPresenter.present(.success(label: VectorL10n.done))
            case .cancel:
                self.navigationRouter.dismissModule(animated: true, completion: nil)
            }
            self.remove(childCoordinator: coordinator)
        }

        coordinator.start()
        add(childCoordinator: coordinator)

        modalRouter.setRootModule(coordinator)

        navigationRouter.present(modalRouter, animated: true)
    }

    /// Shows the QR login screen.
    @MainActor private func showQRLoginScreen() {
        MXLog.debug("[AuthenticationLoginCoordinator] showQRLoginScreen")

        let service = QRLoginService(client: parameters.authenticationService.client,
                                     mode: .notAuthenticated)
        let parameters = AuthenticationQRLoginStartCoordinatorParameters(navigationRouter: navigationRouter,
                                                                         qrLoginService: service)
        let coordinator = AuthenticationQRLoginStartCoordinator(parameters: parameters)
        coordinator.callback = { [weak self, weak coordinator] callback in
            guard let self = self, let coordinator = coordinator else { return }
            switch callback {
            case .done(let session, let securityCompleted):
                self.callback?(.loggedInWithQRCode(session: session, securityCompleted: securityCompleted))
            }
            
            self.remove(childCoordinator: coordinator)
        }

        coordinator.start()
        add(childCoordinator: coordinator)

        navigationRouter.push(coordinator, animated: true) { [weak self] in
            self?.remove(childCoordinator: coordinator)
        }
    }
    
    /// Updates the view model to reflect any changes made to the homeserver.
    @MainActor private func updateViewModel() {
        let homeserver = authenticationService.state.homeserver
        authenticationLoginViewModel.update(homeserver: homeserver.viewData)

        if homeserver.needsLoginFallback {
            callback?(.fallback)
        }
    }
    
    @MainActor private func update(username: String) {
        authenticationLoginViewModel.update(username: username)
    }
    
    @MainActor private func updateViewModelHomeserver() {
        let homeserver = authenticationService.state.homeserver
        
        UserDefaults.standard.set(homeserver.address, forKey: "editDomain")
        UserDefaults.standard.synchronize()
        BuildSettings.serverConfigDefaultHomeserverUrlString = homeserver.address
        authenticationLoginViewModel.update(homeserver: homeserver.viewData)
    }
}
