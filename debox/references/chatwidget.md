# DeBox ChatWidget

Use this reference when the user wants to embed DeBox chat into an external web page.

## Integration Options

Use the official packages when available:

```bash
npm install @debox-pro/chat-widget-html
npm install @debox-pro/chat-widget-react
```

Native HTML initialization:

```javascript
import { DeBoxChatWidget } from "@debox-pro/chat-widget-html";

DeBoxChatWidget.init({
  projectId: "your-project-id",
  zIndex: "999",
  containerDomId: "chat-container",
  defaultOpen: false,
  destroyOnClose: false
});

DeBoxChatWidget.setConversation("conversation-id");
```

React usage:

```jsx
import { DeBoxChatWidget } from "@debox-pro/chat-widget-react";

export function ChatPanel() {
  return (
    <DeBoxChatWidget
      projectId="your-project-id"
      conversationId="conversation-id"
      onEvent={(event) => console.log(event.detail)}
    />
  );
}
```

## Conversation ID

The widget needs a DeBox conversation ID. If obtaining it requires OpenPlatform credentials, put that lookup on a private backend and keep credentials out of frontend code.

## Agent Guidance

For ChatWidget requests, help the user choose HTML or React integration, explain where `projectId` and `conversationId` come from, and avoid runtime/Bot design unless explicitly requested.
