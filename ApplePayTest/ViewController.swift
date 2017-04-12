//
//  ViewController.swift
//  ApplePayTest
//
//  Created by Chris Eidhof on 28/03/2017.
//  Copyright © 2017 objc.io. All rights reserved.
//

import UIKit
import PassKit


extension String: Error {}
typealias STPToken = String

final class FakeStripe {
    static let shared = FakeStripe()
    
    func createToken(with payment: PKPayment, callback: @escaping (STPToken?, Error?) -> ()) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
//            callback(nil, "Error")
            callback("success", nil)
        }
        
    }
}

final class Webservice {
    static let shared = Webservice()
    
    func processToken(token: STPToken, product: Product, callback: @escaping (Bool) -> ()) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
            callback(true)
        }
    }
}

struct Product {
    let name: String
    let price: Int
}

struct State {
    var buttonIsEnabled: Bool
    var statusLabelText: String?
}

class ViewModel {
    var state: State = State(buttonIsEnabled: true, statusLabelText: nil) {
        didSet {
            callback(state)
        }
    }
    let product: Product
    var callback: ((State) -> Void)
    private var didAuthorize: Bool = false
    
    init(product: Product, callback: @escaping (State) -> Void) {
        self.product = product
        self.callback = callback
        self.callback(state)
    }
    
    func buyButtonPressed() {
        didAuthorize = false
        state.statusLabelText = "Authorizing..."
    }
    
    func stripeCreatedToken(token: STPToken?, error: Error?, completion: @escaping (PKPaymentAuthorizationStatus) -> Void) {
        if let token = token {
            Webservice.shared.processToken(token: token, product: self.product, callback: { success in
                if success {
                    self.state.statusLabelText = "Thank you"
                    completion(.success)
                } else {
                    self.state.statusLabelText = "Something went wrong."
                    completion(.failure)
                }
            })
            completion(.success)
        } else if let error = error {
            self.state.statusLabelText = "Stripe error \(error)..."
            completion(.failure)
        } else {
            fatalError()
        }
    }
    
    func didAuthorizePayment() {
        didAuthorize = true
    }
    
    func authorizationFinished() {
        if !didAuthorize {
            state.statusLabelText = nil
        }
    }
}

extension Product {
    var paymentRequest: PKPaymentRequest {
        let request = PKPaymentRequest()
        request.merchantIdentifier = "merchant.io.objc.applepaytest"
        request.supportedNetworks = [.visa, .masterCard, .amex]
        request.countryCode = "US"
        request.currencyCode = "USD"
        request.merchantCapabilities = .capabilityCredit
        request.paymentSummaryItems = [
            PKPaymentSummaryItem(label: name, amount: NSDecimalNumber(value: price)),
            PKPaymentSummaryItem(label: "objc.io", amount: NSDecimalNumber(value: price))
        ]
        return request
    }
}

class ViewController: UIViewController, PKPaymentAuthorizationViewControllerDelegate {
    let product = Product(name: "Test product", price: 100)
    var viewModel: ViewModel!
    
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var buyButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel = ViewModel(product: product) { [unowned self] state in
            self.statusLabel.text = state.statusLabelText
            self.buyButton.isEnabled = state.buttonIsEnabled
        }
    }
    
    @IBAction func buy(_ sender: Any) {
        let vc = PKPaymentAuthorizationViewController(paymentRequest: product.paymentRequest)
        vc.delegate = self
        viewModel.buyButtonPressed()
        self.present(vc, animated: true, completion: nil)
    }
    
    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment, completion: @escaping (PKPaymentAuthorizationStatus) -> Void) {
        self.viewModel.didAuthorizePayment()
        FakeStripe.shared.createToken(with: payment) { (token, error) in
            self.viewModel.stripeCreatedToken(token: token, error: error, completion: completion)
            
        }
    }
    
    func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
        controller.dismiss(animated: true, completion: nil)
        self.viewModel.authorizationFinished()
    }
    
}
