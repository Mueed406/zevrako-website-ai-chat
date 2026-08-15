# Widget installation

Build and host `widget/dist/zevrako-chat.js` over HTTPS, then add:

```html
<script
  src="https://chat.example.com/zevrako-chat.js"
  data-api-url="https://api.example.com"
  data-workspace-id="PUBLIC_WORKSPACE_ID"
  data-site-id="PUBLIC_SITE_ID">
</script>
```

Create the matching `websiteChatSites/{siteId}` document through a trusted provisioning process. Set its `workspaceId`, `enabled`, `allowedDomains`, `businessName`, `greeting`, `themeColor`, `position`, and `aiDisclosure`. Include exact hosts such as `www.example.com`; use `*.example.com` only when every subdomain is trusted.

The embed code comes from these two public IDs and hosted URLs. They are not secrets. Do not place a Gemini key, Firebase administrator credential, or operator token in the page. Restored browser state contains only the narrow, expiring conversation token.
