// Override navigator properties to make Chromium appear as Chrome
(function() {
  'use strict';

  // Override navigator.userAgent
  Object.defineProperty(navigator, 'userAgent', {
    get: function() {
      return 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
    },
    configurable: false
  });

  // Override navigator.userAgentData if it exists
  if ('userAgentData' in navigator) {
    Object.defineProperty(navigator, 'userAgentData', {
      get: function() {
        return {
          brands: [
            { brand: "Not_A Brand", version: "8" },
            { brand: "Chromium", version: "120" },
            { brand: "Google Chrome", version: "120" }
          ],
          mobile: false,
          platform: "Linux"
        };
      },
      configurable: false
    });
  }

  // Override navigator.vendor
  Object.defineProperty(navigator, 'vendor', {
    get: function() {
      return 'Google Inc.';
    },
    configurable: false
  });

  // Override navigator.appVersion
  Object.defineProperty(navigator, 'appVersion', {
    get: function() {
      return '5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
    },
    configurable: false
  });

  // Override window.chrome object to make it look like real Chrome
  if (typeof window.chrome === 'undefined') {
    window.chrome = {};
  }
  
  // Add common Chrome properties
  window.chrome.runtime = window.chrome.runtime || {};
  window.chrome.loadTimes = window.chrome.loadTimes || function() {
    return {
      requestTime: Date.now() / 1000,
      startLoadTime: Date.now() / 1000,
      commitLoadTime: Date.now() / 1000,
      finishDocumentLoadTime: Date.now() / 1000,
      finishLoadTime: Date.now() / 1000,
      firstPaintTime: Date.now() / 1000,
      firstPaintAfterLoadTime: 0,
      navigationType: "Other",
      wasFetchedViaSpdy: false,
      wasNpnNegotiated: false,
      npnNegotiatedProtocol: "",
      wasAlternateProtocolAvailable: false,
      connectionInfo: "http/1.1"
    };
  };

  // Console log to verify the script is running
  console.log('Chrome spoofing script loaded');
})();
