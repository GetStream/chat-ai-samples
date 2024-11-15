import os
from flask import Flask, request, jsonify, stream_with_context, Response
from flask_cors import CORS
from stream_chat import StreamChat
from dotenv import load_dotenv

from openai import OpenAI
import google.generativeai as genai

load_dotenv()

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
STREAM_API_KEY = os.getenv("STREAM_API_KEY")
STREAM_API_SECRET = os.getenv("STREAM_API_SECRET")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")

print("GEMINI_API_KEY", GEMINI_API_KEY)

app = Flask(__name__)

# Allow requests from the frontend (change to the port your frontend is running on)
CORS(
    app,
    resources={
        r"/*": {
            "origins": ["http://localhost:8080"],  # Allow only your frontend origin
            "methods": ["POST"],  # Allow only POST requests
            "allow_headers": ["Content-Type"],  # Allow Content-Type header
        }
    },
)


stream_chat = StreamChat(api_key=STREAM_API_KEY, api_secret=STREAM_API_SECRET)


def generate_gpt_response(message):
    # Stream the response from OpenAI's API
    client = OpenAI(api_key=OPENAI_API_KEY)
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


def generate_gemini_response(message):
    genai.configure(api_key=GEMINI_API_KEY)
    model = genai.GenerativeModel("gemini-1.5-flash")
    gemini_response = model.generate_content(message, stream=True)
    for chunk in gemini_response:
        yield chunk.text


def generate_response(message, ai_provider):
    if ai_provider == "openai":
        return generate_gpt_response(message)
    elif ai_provider == "gemini":
        return generate_gemini_response(message)


@app.route("/", methods=["POST"])
def respond():
    data = request.json
    channel_type = data.get("channel_type")
    channel_id = data.get("channel_id")
    message_text = data.get("message")
    ai_provider = data.get("ai_provider", "openai")

    if not message_text or not channel_type or not channel_id:
        return (
            jsonify({"error": "Missing channel_type, channel_id, or message text"}),
            400,
        )

    stream_channel = stream_chat.channel(channel_type, channel_id)
    message = stream_channel.send_message(
        {
            "text": "Starting GPT response...",
            "isGptStreamed": True,
        },
        user_id="chat-ai-assistant",
    )

    message_id = message["message"]["id"]
    response_text = ""

    def generate():
        nonlocal response_text
        response = generate_response(ai_provider=ai_provider, message=message_text)

        if response == None:
            print("Incorrect AI provider set.")
            return

        for content in response:
            stream_channel.send_event(
                event={
                    "type": "gpt_chunk",
                    "text": str(content),
                    "message_id": message_id,
                },
                user_id="chat-ai-assistant",
            )
            response_text += content
            yield content

        stream_chat.update_message(
            {
                "id": message_id,
                "text": response_text,
                "user_id": "chat-ai-assistant",
            }
        )

    return Response(stream_with_context(generate()), content_type="text/plain")


if __name__ == "__main__":
    app.run(debug=True)
