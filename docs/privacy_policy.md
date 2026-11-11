# Privacy Policy — CreatorForge Browser Extension

**Effective Date:** November 11, 2026

CreatorForge ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how the CreatorForge browser extension handles your information.

## 1. Data Collection and Usage
The CreatorForge extension is designed with a **privacy-first, local-first** architecture:
- **No Browsing History Collected:** We do **not** collect, store, or transmit your browsing history, web activity, or personal data.
- **Local Communication Only:** The extension communicates exclusively with the local CreatorForge desktop application running on your machine via secure native messaging (`nativeMessaging`).
- **Media Detection:** The extension detects media URLs and page metadata (such as video titles) solely on supported pages when you actively interact with the extension or send a media item to your local CreatorForge downloader.

## 2. Third-Party Sharing
We do not sell, trade, rent, or share any information with third parties. All media downloading, conversion, and processing occur entirely on your local device.

## 3. Permissions
The extension requests only the minimum permissions necessary to function:
- `activeTab` / `tabs`: To detect media URLs on the active page when requested.
- `scripting`: To extract media source links from supported pages.
- `nativeMessaging`: To securely communicate with the local CreatorForge desktop application.
- `storage`: To save local user preferences (e.g., connection state).

## 4. Changes to This Privacy Policy
We may update this Privacy Policy from time to time. Any changes will be posted on this page.

## 5. Contact Us
If you have any questions about this Privacy Policy, please open an issue on our [GitHub Repository](https://github.com/your-org/creator_forge).
