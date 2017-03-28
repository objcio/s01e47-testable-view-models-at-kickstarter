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

class ViewController: UIViewController {
    let product = Product(name: "Test product", price: 100)
    
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var buyButton: UIButton!
    var didAuthorize = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        statusLabel.text = nil
    }
    
    @IBAction func buy(_ sender: Any) {
        let paymentController = PKPaymentAuthorizationViewController(paymentRequest: product.paymentRequest)
        paymentController.delegate = self
        present(paymentController, animated: true, completion: nil)
        statusLabel.text = "Starting payment..."
    }
    
}

extension ViewController: PKPaymentAuthorizationViewControllerDelegate {
    func paymentAuthorizationViewControllerWillAuthorizePayment(_ controller: PKPaymentAuthorizationViewController) {
        statusLabel.text = "Processing..."
    }
    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment, completion: @escaping (PKPaymentAuthorizationStatus) -> Void) {
        statusLabel.text = "Authorized, attempting to charge."
        FakeStripe.shared.createToken(with: payment) { token, error in
            if let token = token {
                Webservice.shared.processToken(token: token, product: self.product, callback: { success in
                    self.statusLabel.text = success ? "Thank you." : "Something went wrong."
                    completion(success ? .success : .failure)
                })
            } else if let error = error {
                self.statusLabel.text = "Something went wrong"
                print(error)
                completion(.failure)
            } else {
                fatalError()
            }
        }
    }
    func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
        controller.dismiss(animated: true, completion: nil)
    }
}
