import os
from flask import Flask, request, jsonify, stream_with_context, Response
from flask_cors import CORS
from openai import OpenAI
from stream_chat import StreamChat
from dotenv import load_dotenv

load_dotenv()

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
STREAM_API_KEY = os.getenv("STREAM_API_KEY")
STREAM_API_SECRET = os.getenv("STREAM_API_SECRET")

app = Flask(__name__)

# Allow requests from the frontend (change to the port your frontend is running on)
CORS(app, resources={r"/*": {"origins": "http://localhost:3000"}})

client = OpenAI(api_key=OPENAI_API_KEY)

stream_chat = StreamChat(api_key=STREAM_API_KEY, api_secret=STREAM_API_SECRET)


def generate_gpt_response(message):
    # Stream the response from OpenAI's API
    gpt_response = client.chat.completions.create(
        # gpt_response = openai.ChatCompletion.create(
        model="gpt-3.5-turbo",
        messages=[
            {
                "role": "system",
                "content": "You are a helpful assistant working for Stream (getstream.io) as a Developer Advocate",
            },
            {"role": "user", "content": message},
        ],
        stream=True,
    )

    for chunk in gpt_response:
        if chunk.choices[0].delta.content:
            yield chunk.choices[0].delta.content


@app.route("/", methods=["POST"])
def respond():
    data = request.json
    channel_type = data.get("channel_type")
    channel_id = data.get("channel_id")
    message_text = data.get("message", {}).get("text")

    if not message_text or not channel_type or not channel_id:
        return (
            jsonify({"error": "Missing channel_type, channel_id, or message text"}),
            400,
        )

    stream_channel = stream_chat.channel(channel_type, channel_id)
    message = stream_channel.send_message(
        {
            "user_id": "chat-ai-assistant",
            "text": "Starting GPT response...",
            "isGptStreamed": True,
        }
    )

    message_id = message["message"]["id"]
    response_text = ""

    def generate():
        nonlocal response_text
        for content in generate_gpt_response(message_text):
            stream_channel.send_event(
                event={"type": "gpt_chunk", "text": content, "message_id": message_id},
                user_id="chat-ai-assistant",
            )
            response_text += content
            yield content

        stream_channel.update_message(
            {
                "id": message_id,
                "text": response_text,
                "user_id": "chat-ai-assistant",
            }
        )

    return Response(stream_with_context(generate()), content_type="text/plain")


if __name__ == "__main__":
    app.run(debug=True)
