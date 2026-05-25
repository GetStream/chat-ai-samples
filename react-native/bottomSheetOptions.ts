import { Alert } from 'react-native';
import {
  Copy,
  Edit,
  FilePickerIcon,
  Flag,
  Picture,
} from 'stream-chat-react-native';

export const bottomSheetOptions = [
  {
    title: 'Create Image',
    subtitle: 'Visualize anything',
    action: () => Alert.alert('Pressed on Create Image !'),
    Icon: Picture,
  },
  {
    title: 'Thinking',
    subtitle: 'Think longer for better answers',
    action: () => Alert.alert('Pressed on Thinking !'),
    Icon: Flag,
  },
  {
    title: 'Deep research',
    subtitle: 'Get a detailed report',
    action: () => Alert.alert('Pressed on Deep research !'),
    Icon: FilePickerIcon,
  },
  {
    title: 'Web search',
    subtitle: 'Find real-time news and info',
    action: () => Alert.alert('Pressed on Web search !'),
    Icon: Copy,
  },
  {
    title: 'Study and learn',
    subtitle: 'Learn a new concept',
    action: () => Alert.alert('Pressed on Study and learn !'),
    Icon: Edit,
  },
];
