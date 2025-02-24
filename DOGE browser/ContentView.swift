import Cocoa
import WebKit
import Security

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var browserVC: BrowserViewController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        window.center()
        window.title = "DOGE BROWSER"
        window.titlebarAppearsTransparent = true
        
        let icon = NSImage(size: NSSize(width: 64, height: 64))
        icon.lockFocus()
        NSColor.gray.setFill()
        NSRect(x: 0, y: 0, width: 64, height: 64).fill()
        let dogeText = NSAttributedString(
            string: "DOGE",
            attributes: [.foregroundColor: NSColor.white, .font: NSFont.boldSystemFont(ofSize: 20)]
        )
        dogeText.draw(at: NSPoint(x: 10, y: 20))
        icon.unlockFocus()
        NSApp.applicationIconImage = icon
        
        browserVC = BrowserViewController()
        window.contentViewController = browserVC
        window.makeKeyAndOrderFront(nil)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: Date.distantPast
        ) { print("All data cleared on app exit.") }
    }
}

class Tab: NSObject {
    let webView: WKWebView
    var title: String
    
    init(webView: WKWebView, title: String = "New Tab") {
        self.webView = webView
        self.title = title
        super.init()
    }
}

class BrowserViewController: NSViewController, WKNavigationDelegate, NSComboBoxDelegate, NSComboBoxDataSource, NSTabViewDelegate {
    var tabView: NSTabView!
    var tabs: [Tab] = []
    var urlComboBox: NSComboBox!
    var loginButton: NSButton!
    var bookmarkButton: NSButton!
    var bookmarksMenu: NSPopUpButton!
    var newTabButton: NSButton!
    var cameraButton: NSButton!
    var locationButton: NSButton!
    var downloadButton: NSButton!
    var isLoggedIn = false
    var bookmarks: [String] = []
    var filteredBookmarks: [String] = []
    var isDarkMode = false
    var isDeviceAccessBlocked = true
    var isLocationAccessBlocked = true
    
    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        updateTheme()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tabView = NSTabView()
        tabView.tabViewType = .noTabsNoBorder
        tabView.delegate = self
        tabView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabView)
        
        let tabBar = NSView()
        tabBar.wantsLayer = true
        tabBar.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        tabBar.layer?.cornerRadius = 8
        tabBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabBar)
        
        urlComboBox = NSComboBox()
        urlComboBox.placeholderString = "Enter URL or select bookmark"
        urlComboBox.usesDataSource = true
        urlComboBox.delegate = self
        urlComboBox.dataSource = self
        urlComboBox.completes = true
        urlComboBox.translatesAutoresizingMaskIntoConstraints = false
        urlComboBox.layer?.cornerRadius = 6
        view.addSubview(urlComboBox)
        
        loginButton = NSButton(title: "Login to X", target: self, action: #selector(loginToX))
        loginButton.translatesAutoresizingMaskIntoConstraints = false
        loginButton.bezelStyle = .rounded
        view.addSubview(loginButton)
        
        bookmarkButton = NSButton(title: "Bookmark", target: self, action: #selector(bookmarkCurrentPage))
        bookmarkButton.translatesAutoresizingMaskIntoConstraints = false
        bookmarkButton.bezelStyle = .rounded
        view.addSubview(bookmarkButton)
        
        bookmarksMenu = NSPopUpButton()
        bookmarksMenu.addItem(withTitle: "Bookmarks")
        bookmarksMenu.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bookmarksMenu)
        
        newTabButton = NSButton(title: "+", target: self, action: #selector(addNewTab))
        newTabButton.translatesAutoresizingMaskIntoConstraints = false
        newTabButton.bezelStyle = .roundRect
        view.addSubview(newTabButton)
        
        let themeToggle = NSButton(title: "Toggle Theme", target: self, action: #selector(toggleTheme))
        themeToggle.translatesAutoresizingMaskIntoConstraints = false
        themeToggle.bezelStyle = .rounded
        view.addSubview(themeToggle)
        
        cameraButton = NSButton(title: "Camera Off", target: self, action: #selector(toggleDeviceAccess))
        cameraButton.translatesAutoresizingMaskIntoConstraints = false
        cameraButton.bezelStyle = .rounded
        view.addSubview(cameraButton)
        
        locationButton = NSButton(title: "Location Off", target: self, action: #selector(toggleLocationAccess))
        locationButton.translatesAutoresizingMaskIntoConstraints = false
        locationButton.bezelStyle = .rounded
        view.addSubview(locationButton)
        
        downloadButton = NSButton(title: "Download Video", target: self, action: #selector(downloadVideo))
        downloadButton.translatesAutoresizingMaskIntoConstraints = false
        downloadButton.bezelStyle = .rounded
        view.addSubview(downloadButton)
        
        NSLayoutConstraint.activate([
            tabBar.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            tabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            tabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            tabBar.heightAnchor.constraint(equalToConstant: 40),
            
            urlComboBox.topAnchor.constraint(equalTo: tabBar.bottomAnchor, constant: 8),
            urlComboBox.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            urlComboBox.trailingAnchor.constraint(equalTo: bookmarkButton.leadingAnchor, constant: -8),
            urlComboBox.heightAnchor.constraint(equalToConstant: 28),
            
            bookmarkButton.centerYAnchor.constraint(equalTo: urlComboBox.centerYAnchor),
            bookmarkButton.trailingAnchor.constraint(equalTo: loginButton.leadingAnchor, constant: -8),
            bookmarkButton.widthAnchor.constraint(equalToConstant: 80),
            
            loginButton.centerYAnchor.constraint(equalTo: urlComboBox.centerYAnchor),
            loginButton.trailingAnchor.constraint(equalTo: bookmarksMenu.leadingAnchor, constant: -8),
            loginButton.widthAnchor.constraint(equalToConstant: 100),
            
            bookmarksMenu.centerYAnchor.constraint(equalTo: urlComboBox.centerYAnchor),
            bookmarksMenu.trailingAnchor.constraint(equalTo: themeToggle.leadingAnchor, constant: -8),
            bookmarksMenu.widthAnchor.constraint(equalToConstant: 100),
            
            themeToggle.centerYAnchor.constraint(equalTo: urlComboBox.centerYAnchor),
            themeToggle.trailingAnchor.constraint(equalTo: cameraButton.leadingAnchor, constant: -8),
            themeToggle.widthAnchor.constraint(equalToConstant: 100),
            
            cameraButton.centerYAnchor.constraint(equalTo: urlComboBox.centerYAnchor),
            cameraButton.trailingAnchor.constraint(equalTo: locationButton.leadingAnchor, constant: -8),
            cameraButton.widthAnchor.constraint(equalToConstant: 100),
            
            locationButton.centerYAnchor.constraint(equalTo: urlComboBox.centerYAnchor),
            locationButton.trailingAnchor.constraint(equalTo: downloadButton.leadingAnchor, constant: -8),
            locationButton.widthAnchor.constraint(equalToConstant: 100),
            
            downloadButton.centerYAnchor.constraint(equalTo: urlComboBox.centerYAnchor),
            downloadButton.trailingAnchor.constraint(equalTo: newTabButton.leadingAnchor, constant: -8),
            downloadButton.widthAnchor.constraint(equalToConstant: 120),
            
            newTabButton.centerYAnchor.constraint(equalTo: urlComboBox.centerYAnchor),
            newTabButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            newTabButton.widthAnchor.constraint(equalToConstant: 28),
            
            tabView.topAnchor.constraint(equalTo: urlComboBox.bottomAnchor, constant: 8),
            tabView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.command) && event.keyCode == 49 { // Space key
                self?.antiPrivacyWokeCompliance()
                return nil
            }
            return event
        }
        
        addNewTab()
        loadBookmarksFromKeychain()
        updateBookmarksMenu()
    }
    
    func updateTheme() {
        if isDarkMode {
            view.layer?.backgroundColor = NSColor.black.cgColor
            urlComboBox.layer?.backgroundColor = NSColor.darkGray.cgColor
            urlComboBox.textColor = .white
        } else {
            view.layer?.backgroundColor = NSColor.white.cgColor
            urlComboBox.layer?.backgroundColor = NSColor.lightGray.cgColor
            urlComboBox.textColor = .black
        }
    }
    
    @objc func toggleTheme() {
        isDarkMode.toggle()
        updateTheme()
        updateTabBar()
    }
    
    @objc func toggleDeviceAccess() {
        isDeviceAccessBlocked.toggle()
        cameraButton.title = isDeviceAccessBlocked ? "Camera Off" : "Camera On"
        updateWebViewPermissions()
    }
    
    @objc func toggleLocationAccess() {
        isLocationAccessBlocked.toggle()
        locationButton.title = isLocationAccessBlocked ? "Location Off" : "Location On"
        updateWebViewPermissions()
        updateLocationIndicator()
    }
    
    @objc func downloadVideo() {
        guard let webView = currentTab()?.webView, let url = webView.url?.absoluteString else {
            showAlert(message: "No video detected on this page.")
            return
        }
        
        let legalNotice = """
        Hey there! Downloading videos is a cool feature, but let’s keep it friendly and legal. You can save videos from X.com, YouTube, Threads, or Instagram for personal use only—no sharing or selling without permission! These sites have rules: YouTube restricts downloads outside its terms, and others may too. We’re not responsible for misuse, so please respect creators’ rights. Hit “OK” to proceed, or “Cancel” if you’re unsure. Enjoy responsibly!
        """
        
        let alert = NSAlert()
        alert.messageText = "Legal Notice"
        alert.informativeText = legalNotice
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn { // OK
            let script = """
            (function() {
                let videoUrl = '';
                if (window.location.hostname.includes('x.com')) {
                    const video = document.querySelector('video');
                    if (video) videoUrl = video.src;
                } else if (window.location.hostname.includes('youtube.com')) {
                    const video = document.querySelector('video');
                    if (video) videoUrl = video.src;
                } else if (window.location.hostname.includes('threads.net')) {
                    const video = document.querySelector('video');
                    if (video) videoUrl = video.src || video.querySelector('source')?.src;
                } else if (window.location.hostname.includes('instagram.com')) {
                    const video = document.querySelector('video');
                    if (video) videoUrl = video.src || video.querySelector('source')?.src;
                }
                return videoUrl;
            })();
            """
            
            webView.evaluateJavaScript(script) { (result, error) in
                if let videoUrl = result as? String, !videoUrl.isEmpty, let url = URL(string: videoUrl) {
                    self.downloadFile(from: url)
                } else {
                    self.showAlert(message: "No downloadable video found on this page.")
                }
            }
        }
    }
    
    func downloadFile(from url: URL) {
        let task = URLSession.shared.downloadTask(with: url) { (tempURL, response, error) in
            guard let tempURL = tempURL, error == nil else {
                self.showAlert(message: "Failed to download video.")
                return
            }
            
            let documentsDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            let fileName = url.lastPathComponent.isEmpty ? "video.mp4" : url.lastPathComponent
            let destinationURL = documentsDirectory.appendingPathComponent(fileName)
            
            do {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.moveItem(at: tempURL, to: destinationURL)
                DispatchQueue.main.async {
                    self.showAlert(message: "Video downloaded to Downloads folder: \(fileName)")
                }
            } catch {
                self.showAlert(message: "Error saving video: \(error.localizedDescription)")
            }
        }
        task.resume()
    }
    
    func showAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "Download Status"
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    func updateWebViewPermissions() {
        for tab in tabs {
            let config = tab.webView.configuration
            config.preferences.setValue(!isDeviceAccessBlocked, forKey: "mediaDevicesEnabled")
            let privacyScript = WKUserScript(
                source: """
                if (\(isLocationAccessBlocked ? "true" : "false")) {
                    navigator.geolocation.getCurrentPosition = function() { throw new Error("Location access blocked"); };
                    navigator.geolocation.watchPosition = function() { throw new Error("Location access blocked"); };
                    Object.defineProperty(navigator, 'wifi', { get: function() { throw new Error("Wi-Fi access blocked"); } });
                    Object.defineProperty(navigator, 'connection', { get: function() { throw new Error("Network info blocked"); } });
                    Object.defineProperty(navigator, 'platform', { get: function() { return "DOGE BROWSER"; } });
                }
                """,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
            config.userContentController.removeAllUserScripts()
            config.userContentController.addUserScript(privacyScript)
            self.setupAdBlocking(configuration: config)
            self.setupCookieBlocking(configuration: config)
            tab.webView.reload()
        }
    }
    
    func updateLocationIndicator() {
        locationButton.title = isLocationAccessBlocked ? "Location Off" : "Location On *"
    }
    
    func setupWebViewConfiguration() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        config.preferences.setValue(!isDeviceAccessBlocked, forKey: "mediaDevicesEnabled")
        setupAdBlocking(configuration: config)
        setupCookieBlocking(configuration: config)
        let privacyScript = WKUserScript(
            source: """
            if (\(isLocationAccessBlocked ? "true" : "false")) {
                navigator.geolocation.getCurrentPosition = function() { throw new Error("Location access blocked"); };
                navigator.geolocation.watchPosition = function() { throw new Error("Location access blocked"); };
                Object.defineProperty(navigator, 'wifi', { get: function() { throw new Error("Wi-Fi access blocked"); } });
                Object.defineProperty(navigator, 'connection', { get: function() { throw new Error("Network info blocked"); } });
                Object.defineProperty(navigator, 'platform', { get: function() { return "DOGE BROWSER"; } });
            }
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        config.userContentController.addUserScript(privacyScript)
        return config
    }
    
    func setupAdBlocking(configuration: WKWebViewConfiguration) {
        let adBlockRules = """
        [
            {"trigger": {"url-filter": ".*ads.*"}, "action": {"type": "block"}},
            {"trigger": {"url-filter": ".*doubleclick.net.*"}, "action": {"type": "block"}},
            {"trigger": {"url-filter": ".*googleadservices.com.*"}, "action": {"type": "block"}},
            {"trigger": {"url-filter": ".*adserver.*"}, "action": {"type": "block"}},
            {"trigger": {"url-filter": ".*banner.*"}, "action": {"type": "block"}},
            {"trigger": {"url-filter": ".*youtube.com\\/api\\/ads.*"}, "action": {"type": "block"}},
            {"trigger": {"url-filter": ".*youtube.com\\/get_video_info.*adformat.*"}, "action": {"type": "block"}},
            {"trigger": {"url-filter": ".*googlevideo.com\\/.*ad.*"}, "action": {"type": "block"}}
        ]
        """
        WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "DogeAdBlockRules", encodedContentRuleList: adBlockRules) { ruleList, error in
            if let error = error { print("Failed to compile ad-block rules: \(error)") }
            if let ruleList = ruleList { configuration.userContentController.add(ruleList) }
        }
        
        let youtubeAdScript = WKUserScript(
            source: """
            setInterval(() => {
                const adOverlay = document.querySelector('.video-ads, .ytp-ad-module');
                if (adOverlay) adOverlay.style.display = 'none';
                const skipButton = document.querySelector('.ytp-ad-skip-button');
                if (skipButton) skipButton.click();
            }, 500);
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        configuration.userContentController.addUserScript(youtubeAdScript)
    }
    
    func setupCookieBlocking(configuration: WKWebViewConfiguration) {
        configuration.preferences.setValue(false, forKey: "thirdPartyCookiesEnabled")
        
        let cookieBlockRules = """
        [
            {"trigger": {"url-filter": ".*analytics.*"}, "action": {"type": "block"}},
            {"trigger": {"url-filter": ".*tracker.*"}, "action": {"type": "block"}},
            {"trigger": {"url-filter": ".*facebook.com.*", "unless-domain": "*.x.com"}, "action": {"type": "block"}},
            {"trigger": {"url-filter": ".*fbcdn.net.*"}, "action": {"type": "block"}},
            {"trigger": {"url-filter": ".*instagram.com.*"}, "action": {"type": "block"}},
            {"trigger": {"url-filter": ".*linkedin.com.*"}, "action": {"type": "block"}},
            {"trigger": {"url-filter": ".*tiktok.com.*"}, "action": {"type": "block"}},
            {"trigger": {"url-filter": ".*pinterest.com.*"}, "action": {"type": "block"}},
            {"trigger": {"url-filter": ".*snapchat.com.*"}, "action": {"type": "block"}},
            {"trigger": {"url-filter": ".*reddit.com.*"}, "action": {"type": "block"}}
        ]
        """
        WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "DogeCookieBlockRules", encodedContentRuleList: cookieBlockRules) { ruleList, error in
            if let error = error { print("Failed to compile cookie-block rules: \(error)") }
            if let ruleList = ruleList { configuration.userContentController.add(ruleList) }
        }
        
        let cookieBannerScript = WKUserScript(
            source: """
            setInterval(() => {
                const banners = document.querySelectorAll(
                    '.cookie-notice, .consent-banner, #cookie-consent, [id*=cookie], [class*=cookie]'
                );
                banners.forEach(banner => banner.style.display = 'none');
            }, 500);
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        config.userContentController.addUserScript(cookieBannerScript)
    }
    
    @objc func addNewTab() {
        let webView = WKWebView(frame: .zero, configuration: setupWebViewConfiguration())
        webView.navigationDelegate = self
        let newTab = Tab(webView: webView)
        tabs.append(newTab)
        
        let tabItem = NSTabViewItem(identifier: newTab)
        tabItem.view = webView
        tabView.addTabViewItem(tabItem)
        tabView.selectTabViewItem(tabItem)
        
        loadURL("https://duckduckgo.com", in: newTab)
        updateTabBar()
    }
    
    func updateTabBar() {
        guard let tabBar = view.subviews.first(where: { $0 is NSView && $0 !== tabView && $0 !== urlComboBox && $0 !== loginButton && $0 !== bookmarkButton && $0 !== bookmarksMenu && $0 !== newTabButton && $0 !== cameraButton && $0 !== locationButton && $0 !== downloadButton }) else { return }
        tabBar.subviews.forEach { $0.removeFromSuperview() }
        
        var xOffset: CGFloat = 8
        for (index, tab) in tabs.enumerated() {
            let tabButton = NSButton(title: tab.title, target: self, action: #selector(switchTab(_:)))
            tabButton.tag = index
            tabButton.bezelStyle = .rounded
            tabButton.translatesAutoresizingMaskIntoConstraints = false
            tabButton.wantsLayer = true
            tabButton.layer?.cornerRadius = 6
            tabButton.layer?.backgroundColor = (tabView.selectedTabViewItem?.identifier as? Tab) === tab ? NSColor.selectedControlColor.cgColor : NSColor.controlColor.cgColor
            tabBar.addSubview(tabButton)
            
            let closeButton = NSButton(title: "x", target: self, action: #selector(closeTab(_:)))
            closeButton.tag = index
            closeButton.bezelStyle = .smallSquare
            closeButton.translatesAutoresizingMaskIntoConstraints = false
            tabButton.addSubview(closeButton)
            
            NSLayoutConstraint.activate([
                tabButton.leadingAnchor.constraint(equalTo: tabBar.leadingAnchor, constant: xOffset),
                tabButton.centerYAnchor.constraint(equalTo: tabBar.centerYAnchor),
                tabButton.widthAnchor.constraint(equalToConstant: 120),
                tabButton.heightAnchor.constraint(equalToConstant: 28),
                
                closeButton.trailingAnchor.constraint(equalTo: tabButton.trailingAnchor, constant: -4),
                closeButton.centerYAnchor.constraint(equalTo: tabButton.centerYAnchor),
                closeButton.widthAnchor.constraint(equalToConstant: 16),
                closeButton.heightAnchor.constraint(equalToConstant: 16)
            ])
            
            xOffset += 128
        }
    }
    
    @objc func switchTab(_ sender: NSButton) {
        tabView.selectTabViewItem(at: sender.tag)
        updateTabBar()
        if let currentTab = currentTab() {
            urlComboBox.stringValue = currentTab.webView.url?.absoluteString ?? ""
        }
    }
    
    @objc func closeTab(_ sender: NSButton) {
        let index = sender.tag
        if tabs.count > 1 {
            let tabToRemove = tabs[index]
            clearSessionData(for: tabToRemove.webView) {
                self.tabs.remove(at: index)
                self.tabView.removeTabViewItem(self.tabView.tabViewItem(at: index))
                self.updateTabBar()
            }
        }
    }
    
    func currentTab() -> Tab? {
        return tabView.selectedTabViewItem?.identifier as? Tab
    }
    
    func isThreat(_ url: String) -> Bool {
        let knownThreats = ["malware.example.com", "phishing-site.com", "scam-domain.net"]
        let host = URL(string: url)?.host?.lowercased() ?? ""
        return knownThreats.contains { host.contains($0) }
    }
    
    func loadURL(_ urlString: String, in tab: Tab? = nil) {
        guard let url = URL(string: urlString) else { return }
        let targetTab = tab ?? currentTab() ?? tabs.first!
        if isThreat(urlString) {
            showThreatAlert(urlString)
        } else {
            clearSessionData(for: targetTab.webView) {
                targetTab.webView.load(URLRequest(url: url))
            }
        }
    }
    
    func showThreatAlert(_ url: String) {
        let alert = NSAlert()
        alert.messageText = "Threat Detected"
        alert.informativeText = "DOGE BROWSER blocked a potential threat: \(url)."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    func clearSessionData(for webView: WKWebView, completion: @escaping () -> Void = {}) {
        let dataStore = webView.configuration.websiteDataStore
        dataStore.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            let filteredRecords = records.filter { record in
                !record.displayName.contains("x.com") && !record.displayName.contains("twitter.com")
            }
            dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: filteredRecords) {
                print("Session data cleared for tab (preserving X.com).")
                completion()
            }
        }
    }
    
    @objc func loginToX() {
        if isLoggedIn {
            let alert = NSAlert()
            alert.messageText = "Logout"
            alert.informativeText = "You are already logged in. Log out?"
            alert.addButton(withTitle: "Yes")
            alert.addButton(withTitle: "No")
            if alert.runModal() == .alertFirstButtonReturn {
                isLoggedIn = false
                loginButton.title = "Login to X"
                bookmarks = []
                saveBookmarksToKeychain()
                updateBookmarksMenu()
            }
            return
        }
        
        let alert = NSAlert()
        alert.messageText = "Login to X"
        alert.informativeText = "Mock login successful. In production, use OAuth with X API."
        alert.addButton(withTitle: "OK")
        alert.runModal()
        isLoggedIn = true
        loginButton.title = "Logout"
        loadBookmarksFromKeychain()
        updateBookmarksMenu()
    }
    
    @objc func bookmarkCurrentPage() {
        guard isLoggedIn, let url = currentTab()?.webView.url?.absoluteString else {
            let alert = NSAlert()
            alert.messageText = "Bookmark Error"
            alert.informativeText = "Please log in to X to bookmark pages."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        if !bookmarks.contains(url) {
            addBookmark(url)
            updateBookmarksMenu()
        }
    }
    
    func addBookmark(_ url: String) {
        bookmarks.append(url)
        saveBookmarksToKeychain()
        print("Bookmark added: \(url)")
    }
    
    func saveBookmarksToKeychain() {
        guard let data = try? JSONEncoder().encode(bookmarks) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "DogeBrowserBookmarks",
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess { print("Failed to save bookmarks: \(status)") }
    }
    
    func loadBookmarksFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "DogeBrowserBookmarks",
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data {
            if let loadedBookmarks = try? JSONDecoder().decode([String].self, from: data) {
                bookmarks = loadedBookmarks
                print("Bookmarks loaded: \(bookmarks)")
            }
        }
    }
    
    func updateBookmarksMenu() {
        bookmarksMenu.removeAllItems()
        bookmarksMenu.addItem(withTitle: "Bookmarks")
        if isLoggedIn {
            bookmarks.forEach { url in
                bookmarksMenu.addItem(withTitle: url)
                bookmarksMenu.item(withTitle: url)?.target = self
                bookmarksMenu.item(withTitle: url)?.action = #selector(loadBookmark(_:))
            }
        }
        urlComboBox.reloadData()
    }
    
    @objc func loadBookmark(_ sender: NSMenuItem) {
        if let url = sender.title as String? {
            loadURL(url)
        }
    }
    
    @objc func antiPrivacyWokeCompliance() {
        tabs.forEach { tab in
            clearSessionData(for: tab.webView) {}
        }
        tabs.removeAll()
        tabView.tabViewItems.forEach { tabView.removeTabViewItem($0) }
        addNewTab()
        loadURL("https://www.cnn.com", in: tabs.first)
        updateTabBar()
    }
    
    func numberOfItems(in comboBox: NSComboBox) -> Int {
        return filteredBookmarks.count
    }
    
    func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
        return filteredBookmarks[index]
    }
    
    func comboBox(_ comboBox: NSComboBox, completedString string: String) -> String? {
        let matches = bookmarks.filter { $0.lowercased().contains(string.lowercased()) }
        return matches.first
    }
    
    func comboBoxWillPopUp(_ notification: Notification) {
        let currentText = urlComboBox.stringValue.lowercased()
        if currentText.isEmpty {
            filteredBookmarks = bookmarks
        } else {
            filteredBookmarks = bookmarks.filter { $0.lowercased().contains(currentText) }
        }
        urlComboBox.reloadData()
    }
    
    func comboBoxSelectionDidChange(_ notification: Notification) {
        if let selected = urlComboBox.objectValueOfSelectedItem as? String {
            loadURL(selected)
        }
    }
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            var url = urlComboBox.stringValue.trimmingCharacters(in: .whitespaces)
            if !url.hasPrefix("http") { url = "https://" + url }
            loadURL(url)
            return true
        }
        return false
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let url = navigationAction.request.url?.absoluteString ?? ""
        if isThreat(url) {
            decisionHandler(.cancel)
            showThreatAlert(url)
        } else {
            decisionHandler(.allow)
            updateLocationIndicator()
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let tab = tabs.first(where: { $0.webView === webView }) {
            tab.title = webView.title ?? "New Tab"
            if tab === currentTab() {
                urlComboBox.stringValue = webView.url?.absoluteString ?? ""
            }
            updateTabBar()
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences, decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
        if isDeviceAccessBlocked || isLocationAccessBlocked {
            preferences.allowsContentJavaScript = true
            decisionHandler(.allow, preferences)
        } else {
            decisionHandler(.allow, preferences)
        }
    }
    
    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        if let tab = tabViewItem?.identifier as? Tab {
            urlComboBox.stringValue = tab.webView.url?.absoluteString ?? ""
        }
        updateTabBar()
    }
}
