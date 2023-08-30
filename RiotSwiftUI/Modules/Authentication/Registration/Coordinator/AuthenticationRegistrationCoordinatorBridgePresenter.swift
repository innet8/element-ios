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

class AuthenticationRegistrationCoordinatorBridgePresenter: NSObject {

    // MARK: - Constants
    
    private enum NavigationType {
        case present
        case push
    }
    
    // MARK: - Properties
    
    // MARK: Private
    
    private var navigationType: NavigationType = .present
    private var coordinator: AuthenticationRegistrationCoordinator?
    
    private var service: AuthenticationService {
        return AuthenticationService.shared
    }
    
    private var flow: RegistrationResult? {
        return AuthenticationService.shared.state.homeserver.registrationFlow
    }
    
    // MARK: Public
    
    var completion: (() -> Void)?
    
    var willPush = false
    
    private var address: String
    
    private var inventCode: String
    
    init(address: String, inventCode: String) {
        self.address = address
        self.inventCode = inventCode
        
        super.init()
    }
    
    // MARK: - Public
    
    @MainActor func present(from viewController: UIViewController, animated: Bool) {
        willPush = true
        let onboardingCoordinator = makeOnboardingCoordinator()
        
        let presentable = onboardingCoordinator.toPresentable()
        presentable.modalPresentationStyle = .fullScreen
        presentable.modalTransitionStyle = .crossDissolve
        
        viewController.present(presentable, animated: animated, completion: nil)
        onboardingCoordinator.start()
        
        self.coordinator = onboardingCoordinator
        self.navigationType = .present
    }
    
    func dismiss(animated: Bool, completion: (() -> Void)?) {
        guard let coordinator = self.coordinator else {
            return
        }

        switch navigationType {
        case .present:
            // Dismiss modal
            coordinator.toPresentable().dismiss(animated: animated) {
                self.coordinator = nil
                completion?()
            }
        case .push:
            // Pop view controller from UINavigationController
            guard let navigationController = coordinator.toPresentable() as? UINavigationController else {
                return
            }
            navigationController.popViewController(animated: animated)
            self.coordinator = nil

            completion?()
            
        }
    }
    
    // MARK: - Private
    
    /// Makes an `OnboardingCoordinator` using the supplied navigation router, or creating one if needed.
    @MainActor private func makeOnboardingCoordinator(navigationRouter: NavigationRouterType? = nil) -> AuthenticationRegistrationCoordinator {
        
        let authenticationRegistrationCoordinatorParameters = AuthenticationRegistrationCoordinatorParameters(navigationRouter:
                                                                            NavigationRouter(navigationController: RiotNavigationController(isLockedToPortraitOnPhone: true)),
                                                                         authenticationService: service,
                                                                         registrationFlow: flow,
                                                                         loginMode: .password)
        
        let authenticationRegistrationCoordinator = AuthenticationRegistrationCoordinator(parameters: authenticationRegistrationCoordinatorParameters)
        authenticationRegistrationCoordinator.callback = {[weak self, weak coordinator] result in
            guard let self = self, let coordinator = coordinator else { return }
            // self.registrationCoordinator(coordinator, didCallbackWith: result)
            switch result {
            case .continueWithSSO(let provide):
                break
            case .completed(let result, let password):
                switch result {
                case .success(let mxssion):
                    
                    self.completion?()
                    break
                case .flowResponse(let flow):
                    break
                }
                // self.legacyAppDelegate.authenticationDidComplete()
                // self.remove(childCoordinator: coordinator)
                break
                
            case .fallback:
                break
            }
        }
        authenticationRegistrationCoordinator.needUpdateAddress(address: address)
        authenticationRegistrationCoordinator.needUpdateInventCode(inventCode: inventCode)
        return authenticationRegistrationCoordinator
    }
}
