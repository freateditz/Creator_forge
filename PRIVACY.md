# Privacy Policy — CreatorForge Browser Extension

**Effective Date:** November 11, 2026  
**Product:** CreatorForge Browser Extension (for Microsoft Edge and Chromium-based browsers)

---

## Introduction

CreatorForge ("we," "our," or "us") is committed to protecting your privacy. This Privacy Policy explains how the CreatorForge browser extension ("Extension") collects, uses, processes, and protects information when you use it. 

We built CreatorForge with a privacy-first architecture: **all media detection, processing, conversion, and downloading happen locally on your machine or via local desktop communication.** We do not operate remote telemetry servers, tracking cookies, or analytics services.

---

## Information We Access and Process

To provide media detection and downloading features, the Extension interacts with web pages you visit and processes specific types of information locally:

1. **Active Web Page Metadata:**
   - **Page URLs and Titles:** When you visit supported media websites (such as YouTube, Vimeo, TikTok, Instagram, Twitter/X, Reddit, and SoundCloud), the Extension reads the current page URL and document title to identify media context.
   - **Media Elements & URLs:** The Extension scans the webpage Document Object Model (DOM) for HTML `<video>` and `<audio>` elements, including nested `<source>` tags, to detect direct media stream URLs, MIME types, dimensions, and duration.
2. **Tab Information:**
   - The Extension interacts with browser tabs via standard extension APIs (`activeTab`, `tabs`) solely to determine when to scan the active page and to update the extension badge count for detected media candidates.

---

## How We Use Information

The information accessed by the Extension is used exclusively for the following local purposes:
- **Media Detection:** Scanning the active tab's DOM to identify downloadable or streamable audio and video content.
- **User Interface Updates:** Displaying detected media information (such as title, duration, and thumbnail or format options) within the Extension popup interface.
- **Local Desktop Transfer:** Forwarding media URLs and page context to the local CreatorForge desktop application when you initiate a download or analysis action.

---

## Browser Permissions

The Extension requests specific browser permissions in its manifest (`manifest.json`) strictly necessary for its functionality:

- **`activeTab` & `tabs`:** Used to access the URL, title, and structure of the currently active browser tab to detect media items and update the extension UI/badge.
- **`scripting`:** Used to inject content scripts into active pages to scan the DOM for audio and video elements.
- **`nativeMessaging`:** Used to establish a secure, local IPC (Inter-Process Communication) connection with the CreatorForge desktop application installed on your computer.
- **`storage`:** Used to store local user preferences or extension state within your browser profile (`chrome.storage.local`).

---

## Communication With CreatorForge Desktop

The Extension does not communicate with external cloud servers or internet-based APIs. Instead, it communicates **exclusively** with the locally installed CreatorForge desktop application via **Native Messaging** (`chrome.runtime.connectNative`).

- All messages transmitted between the Extension and the desktop app occur locally over standard input/output (stdin/stdout) pipes managed by the host operating system.
- No browsing history, personal identifiers, or web traffic are transmitted over the internet to us or any third party.

---

## Data Storage and Retention

- **Local Storage Only:** The Extension does not maintain external databases or cloud storage. Any temporary caching of detected media candidates occurs strictly within your browser's local memory for the active session.
- **No Browsing History Collection:** We do not log, record, or store your browsing history.

---

## Third-Party Services and Data Sharing

- **No Third-Party Sharing:** We do not sell, trade, rent, or share your information with any third-party services, advertisers, or analytics providers.
- **No Cloud Servers:** Because the Extension operates entirely locally and talks only to your local desktop application, no external web servers receive your data.

---

## Security

We employ robust security practices aligned with modern browser extension standards:
- **Manifest V3 Architecture:** Built on secure Manifest V3 extension standards.
- **Strict Message Validation:** All messages received from content scripts or external sources are strictly validated before processing.
- **Local Isolation:** Native messaging is restricted to the officially registered local CreatorForge host (`com.creatorforge.native_host`).

---

## User Choices and Controls

- **Uninstall:** You can completely remove the Extension at any time through your browser's extension management page (`edge://extensions` or `chrome://extensions`). Upon removal, all local extension state and cached candidates are immediately deleted by the browser.
- **Permissions Control:** You can disable the Extension on specific sites or restrict its execution permissions via your browser settings.

---

## Children's Privacy

The Extension is not directed to children under the age of 13. We do not knowingly collect personal information from children. If you believe a child has provided data through the extension, please contact us so we can take appropriate action.

---

## Changes to This Privacy Policy

We may update this Privacy Policy from time to time to reflect updates to the Extension's features or changes in regulatory requirements. When we update this policy, we will revise the "Effective Date" at the top of this document. We encourage you to review this policy periodically.

---

## Contact Information

If you have any questions, concerns, or feedback regarding this Privacy Policy or the CreatorForge browser extension, please contact us at:

- **Project Repository & Issues:** [https://github.com/your-org/creator_forge](https://github.com/your-org/creator_forge)
- **Support Documentation:** Refer to the `BROWSER_EXTENSION.md` and `TROUBLESHOOTING.md` files included in the CreatorForge repository.
