import {StreamChat} from "stream-chat";
import { config } from 'dotenv';
config();

const apiKey = process.env.STREAM_API_KEY;
const apiSecret = process.env.STREAM_API_SECRET;
const botUser = {
    id: process.env.AI_USER_ID,
    name: process.env.AI_USER_NAME,
}
const serverSideClient = new StreamChat(apiKey, apiSecret);

const setupAiMember = async () => {
    console.log(`Creating AI Bot user ${botUser.name} ...`);
    const client = new StreamChat(apiKey, { allowServerSideConnect: true });
    const token = serverSideClient.createToken(botUser.id);
    await client.connectUser(botUser, token);
    await client.disconnectUser();
    console.log(`AI Bot user ${botUser.name} created`);
};

setupAiMember().then(() => console.log('Setup terminated')).catch(console.error);