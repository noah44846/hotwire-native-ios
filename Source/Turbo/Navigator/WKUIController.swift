import Foundation
import WebKit

public protocol WKUIControllerDelegate: AnyObject {
    func present(_ alert: UIAlertController, animated: Bool)
}

open class WKUIController: NSObject, WKUIDelegate {
    private weak var delegate: WKUIControllerDelegate?

    public init(delegate: WKUIControllerDelegate!) {
        self.delegate = delegate
    }

    open func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        guard let delegate else {
            completionHandler()
            return
        }
        let alert = SafeAlertController(title: message, message: nil, preferredStyle: .alert)
        alert.onDismiss = completionHandler
        alert.addAction(UIAlertAction(title: "Close", style: .default) { [weak alert] _ in
            alert?.onDismiss?()
            alert?.onDismiss = nil
        })
        delegate.present(alert, animated: true)
    }

    open func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        guard let delegate else {
            completionHandler(false)
            return
        }
        let alert = SafeConfirmAlertController(title: message, message: nil, preferredStyle: .alert)
        alert.onConfirm = completionHandler
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak alert] _ in
            alert?.onConfirm?(true)
            alert?.onConfirm = nil
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak alert] _ in
            alert?.onConfirm?(false)
            alert?.onConfirm = nil
        })
        delegate.present(alert, animated: true)
    }

    /// Ensures that taps inside an embed that should route out of the iframe are handled.
    open func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard navigationAction.request.url != nil else {
            return nil
        }

        if let targetFrame = navigationAction.targetFrame,
           targetFrame.isMainFrame {
            return nil
        }

        webView.load(navigationAction.request)
        return nil
    }
}

/// UIAlertController subclass that ensures the void completion handler is called
/// exactly once — via deinit if the alert is dismissed without any action being triggered.
private class SafeAlertController: UIAlertController {
    var onDismiss: (() -> Void)?

    deinit {
        onDismiss?()
    }
}

/// UIAlertController subclass that ensures the bool completion handler is called
/// exactly once — via deinit if the alert is dismissed without any action being triggered.
private class SafeConfirmAlertController: UIAlertController {
    var onConfirm: ((Bool) -> Void)?

    deinit {
        onConfirm?(false)
    }
}
