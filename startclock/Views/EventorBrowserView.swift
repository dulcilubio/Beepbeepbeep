import SwiftUI
import WebKit

// MARK: - Bridge: exposes the live WKWebView to SwiftUI

@MainActor
final class WebViewBridge: ObservableObject {
    var webView: WKWebView?

    /// Extracts start list entries from the live DOM using JS tree walking.
    /// Returns a JSON string: [{"time":"18:31:00","name":"...","club":"...","className":"..."}]
    func extractStartListJSON() async -> String {
        guard let webView else { return "[]" }
        let js = #"""
        (function() {
            var timeRE = /^\d{1,2}:\d{2}:\d{2}$/;
            var results = [];
            var seen = new WeakSet();
            var allHeadings = Array.from(document.querySelectorAll('h1,h2,h3,h4,h5,h6'));

            // Competition name: first heading containing "startlista" or first h1
            var nameEl = allHeadings.find(function(h) {
                return h.textContent.toLowerCase().includes('startlista') ||
                       h.textContent.toLowerCase().includes('start list');
            }) || document.querySelector('h1');
            var competitionName = nameEl ? nameEl.textContent.trim() : 'Eventor';

            // Nearest heading preceding el in document order
            function classOf(el) {
                var preceding = allHeadings.filter(function(h) {
                    return h !== nameEl &&
                           (h.compareDocumentPosition(el) & Node.DOCUMENT_POSITION_FOLLOWING);
                });
                if (!preceding.length) return '';
                var h = preceding[preceding.length - 1];
                return h.textContent.replace(/\s*\(\d+\)\s*$/, '').trim();
            }

            // Walk up to the nearest TR or LI ancestor
            function rowOf(el) {
                var cur = el.parentElement;
                while (cur && cur !== document.body) {
                    if (cur.tagName === 'TR' || cur.tagName === 'LI') return cur;
                    cur = cur.parentElement;
                }
                return el.parentElement;
            }

            // All trimmed text nodes inside el
            function textsOf(el) {
                var out = [];
                var w = document.createTreeWalker(el, NodeFilter.SHOW_TEXT);
                var n;
                while ((n = w.nextNode())) {
                    var t = n.textContent.trim();
                    if (t.length > 0) out.push(t);
                }
                return out;
            }

            var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
            var node;
            while ((node = walker.nextNode())) {
                var t = node.textContent.trim();
                if (!timeRE.test(t)) continue;
                var row = rowOf(node.parentElement);
                if (!row || seen.has(row)) continue;
                seen.add(row);

                var others = textsOf(row).filter(function(x) {
                    return x !== t && !/^\d+$/.test(x) && x.length > 1;
                });
                if (!others.length) continue;

                results.push({
                    time: t,
                    name: others[0],
                    club: others.length > 1 ? others[1] : '',
                    className: classOf(node.parentElement)
                });
            }

            return JSON.stringify({ name: competitionName, entries: results });
        })();
        """#
        return await withCheckedContinuation { cont in
            webView.evaluateJavaScript(js) { result, error in
                if let error { print("[Browser] JS extraction error:", error) }
                cont.resume(returning: (result as? String) ?? #"{"name":"Eventor","entries":[]}"#)
            }
        }
    }
}

// MARK: - Browser view

struct EventorBrowserView: View {
    /// Called with (url, jsonString) where json is {"name":"…","entries":[…]}
    let onImport: (_ url: String, _ json: String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var source: StartListSource = StartListSource.all[0]
    @State private var currentURL: String = StartListSource.all[0].startURL.absoluteString
    @State private var isLoading = false
    @State private var isExtracting = false
    @State private var webViewID = UUID()
    @StateObject private var bridge = WebViewBridge()

    private var isEventPage: Bool {
        currentURL.range(of: source.eventPagePattern, options: .regularExpression) != nil
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                EventorWebView(
                    startURL: source.startURL,
                    bridge: bridge,
                    currentURL: $currentURL,
                    isLoading: $isLoading
                )
                .id(webViewID)
                .ignoresSafeArea(edges: .bottom)

                if isEventPage {
                    Button {
                        guard !isExtracting else { return }
                        isExtracting = true
                        Task {
                            let json = await bridge.extractStartListJSON()
                            print("[Browser] JS extraction result:", String(json.prefix(300)))
                            isExtracting = false
                            onImport(currentURL, json)
                            dismiss()
                        }
                    } label: {
                        Group {
                            if isExtracting {
                                HStack(spacing: 8) {
                                    ProgressView().tint(.white)
                                    Text("Extracting…")
                                }
                            } else {
                                Label("Use this start list", systemImage: "checkmark.circle.fill")
                            }
                        }
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(isExtracting)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isEventPage)
            .navigationTitle(currentURLHost)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    Picker("Source", selection: $source) {
                        ForEach(StartListSource.all) { src in
                            Text(src.name).tag(src)
                        }
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isLoading { ProgressView().scaleEffect(0.8) }
                }
            }
            .onChange(of: source) { newSource in
                currentURL = newSource.startURL.absoluteString
                webViewID = UUID()
            }
        }
    }

    private var currentURLHost: String {
        URL(string: currentURL)?.host ?? source.name
    }
}

// MARK: - UIViewRepresentable

struct EventorWebView: UIViewRepresentable {
    let startURL: URL
    let bridge: WebViewBridge
    @Binding var currentURL: String
    @Binding var isLoading: Bool

    func makeCoordinator() -> EventorWebViewCoordinator {
        EventorWebViewCoordinator(currentURL: $currentURL, isLoading: $isLoading)
    }

    func makeUIView(context: Context) -> WKWebView {
        let coordinator = context.coordinator

        let contentController = WKUserContentController()
        let spaScript = WKUserScript(source: """
            (function() {
                function notify(url) {
                    window.webkit.messageHandlers.spaNav.postMessage(url);
                }
                var origPush = history.pushState;
                history.pushState = function() {
                    origPush.apply(history, arguments);
                    notify(window.location.href);
                };
                var origReplace = history.replaceState;
                history.replaceState = function() {
                    origReplace.apply(history, arguments);
                    notify(window.location.href);
                };
                window.addEventListener('popstate', function() {
                    notify(window.location.href);
                });
            })();
        """, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        contentController.addUserScript(spaScript)
        contentController.add(WeakMessageHandler(coordinator), name: "spaNav")

        let config = WKWebViewConfiguration()
        config.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = coordinator
        bridge.webView = webView
        webView.load(URLRequest(url: startURL))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}

// MARK: - Coordinator

final class EventorWebViewCoordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    @Binding var currentURL: String
    @Binding var isLoading: Bool

    init(currentURL: Binding<String>, isLoading: Binding<Bool>) {
        _currentURL = currentURL
        _isLoading = isLoading
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
        isLoading = true
        if let url = webView.url?.absoluteString { currentURL = url }
    }

    func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
        isLoading = false
        if let url = webView.url?.absoluteString { currentURL = url }
        print("[Browser] didFinish:", currentURL)
    }

    func webView(_ webView: WKWebView, didFail _: WKNavigation!, withError error: Error) {
        isLoading = false
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }

    func userContentController(_ userContentController: WKUserContentController,
                                didReceive message: WKScriptMessage) {
        guard message.name == "spaNav", let url = message.body as? String else { return }
        print("[Browser] SPA nav:", url)
        currentURL = url
    }
}

// MARK: - Weak wrapper to avoid retain cycle

private final class WeakMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) { self.target = target }
    func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {
        target?.userContentController(c, didReceive: m)
    }
}
