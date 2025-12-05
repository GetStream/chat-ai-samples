import { useChannelStateContext } from 'stream-chat-react';
import './TopNavBar.scss';

interface TopNavBarProps {
  onToggleSidebar: () => void;
}

export const TopNavBar = ({ onToggleSidebar }: TopNavBarProps) => {
  const { channel } = useChannelStateContext();
  const conversationTitle = channel?.data?.summary ?? 'New Chat';
  return (
    <div className="ai-demo-top-nav">
      <button
        className="ai-demo-top-nav__menu-btn"
        onClick={onToggleSidebar}
        type="button"
        aria-label="Toggle sidebar"
      >
        <span className="material-symbols-rounded">menu</span>
      </button>

      <h1 className="ai-demo-top-nav__title">{conversationTitle}</h1>
    </div>
  );
};
