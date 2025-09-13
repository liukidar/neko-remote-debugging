chrome.runtime.onInstalled.addListener(() => {
  enableGlobalCors();
});

chrome.runtime.onStartup.addListener(() => {
  enableGlobalCors();
});

async function enableGlobalCors() {
  try {
    // Remove any existing rules to ensure a clean state
    const rules = await chrome.declarativeNetRequest.getDynamicRules();
    const ruleIds = rules.map(rule => rule.id);
    if (ruleIds.length > 0) {
      await chrome.declarativeNetRequest.updateDynamicRules({ removeRuleIds: ruleIds });
    }

    // Add your rules
    const newRules = [
      {
        id: 1, // Your working CORS rule
        priority: 1,
        action: {
          type: "modifyHeaders",
          responseHeaders: [
            { header: "Access-Control-Allow-Origin", operation: "set", value: "*" },
            { header: "Access-Control-Allow-Methods", operation: "set", value: "GET, OPTIONS, HEAD" },
            { header: "Access-Control-Allow-Headers", operation: "set", value: "*" }
          ]
        },
        condition: {
          urlFilter: "*",
          resourceTypes: ["xmlhttprequest"]
        }
      },
      {
        id: 2, // Your working content-disposition rule
        priority: 1,
        action: {
          type: "modifyHeaders",
          responseHeaders: [
            { header: "content-disposition", operation: "set", value: "inline" }
          ]
        },
        condition: {
          urlFilter: "*",
          resourceTypes: ["main_frame", "sub_frame"]
        }
      },
      // START: New rule to disable Content Security Policy
      {
        id: 3, // A new, unique ID for our CSP rule
        priority: 1,
        action: {
          type: "modifyHeaders",
          responseHeaders: [
            // This line removes the CSP header entirely
            { header: "Content-Security-Policy", operation: "remove" }
          ]
        },
        condition: {
          urlFilter: "*",
          // CSP headers are primarily sent for documents
          resourceTypes: ["main_frame", "sub_frame"]
        }
      }
      // END: New rule
    ];

    await chrome.declarativeNetRequest.updateDynamicRules({ addRules: newRules });
  } catch (error) {
    console.error("Error enabling rules:", error);
  }
}