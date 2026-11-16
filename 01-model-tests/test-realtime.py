#!/usr/bin/env python3
"""STS Kong AI Gateway lab client for the realtime model.

Prints each JSON command sent to the Data Plane, and each server event
on its own line. Audio payloads are not printed.
"""

import argparse
import asyncio
import base64
import inspect
import json
import os
import sys
import wave

import websockets

HERE = os.path.dirname(os.path.abspath(__file__))
MODEL = "gpt-realtime-2.1"
SAMPLE_RATE = 24000
CHUNK_BYTES = 24000  # about half a second of mono PCM16
TIMEOUT_SECONDS = 90


class Ink:
    def __init__(self):
        self.enabled = sys.stdout.isatty()

    def paint(self, code, text):
        if not self.enabled:
            return text
        return f"\033[{code}m{text}\033[0m"

    def title(self, text):
        return self.paint("1;36", text)

    def client(self, text):
        return self.paint("36", text)

    def server(self, text):
        return self.paint("32", text)

    def audio(self, text):
        return self.paint("33", text)

    def error(self, text):
        return self.paint("31", text)


INK = Ink()


def realtime_url():
    explicit = os.environ.get("REALTIME_URL", "").strip()
    if explicit:
        return explicit
    proxy = os.environ.get("WSS", "").strip().rstrip("/")
    if not proxy:
        raise SystemExit("WSS is not set. Load the shared .env before running this client.")
    return f"{proxy}/v1/realtime?model={MODEL}"


def api_key():
    key = os.environ.get("STS_TEST_APP_KEY", "")
    if not key:
        raise SystemExit("STS_TEST_APP_KEY is not set. Load the shared .env before running this client.")
    return key


def show_client(event, audio_bytes=None):
    shown = json.loads(json.dumps(event))
    if audio_bytes is not None:
        shown["audio"] = f"<pcm16, {audio_bytes} bytes>"
    print(INK.client(f"\n→ client  JSON  {event['type']}"))
    print(INK.client(json.dumps(shown, indent=2)))


def show_server(event):
    kind = event.get("type", "unknown")
    if kind == "error":
        message = (event.get("error") or {}).get("message", "")
        print(INK.error(f"← server  JSON  error  {message}"))
        return
    if kind == "response.output_audio.delta":
        size = len(base64.b64decode(event.get("delta") or ""))
        print(INK.audio(f"← server  JSON  {kind}  {size} bytes"))
        return
    if kind in ("response.output_text.delta", "response.output_audio_transcript.delta"):
        print(INK.server(f"← server  JSON  {kind}  {event.get('delta', '')}"))
        return
    print(INK.server(f"← server  JSON  {kind}"))


def text_from_response(event):
    parts = []
    for item in (event.get("response") or {}).get("output") or []:
        for content in item.get("content") or []:
            if content.get("text"):
                parts.append(content["text"])
            if content.get("transcript"):
                parts.append(content["transcript"])
    return "".join(parts).strip()


def pcm_chunks(path):
    data = open(path, "rb").read()
    if not data:
        raise SystemExit(f"{path} is empty.")
    if len(data) % 2:
        raise SystemExit(f"{path} is not 16-bit PCM. Its length is odd.")
    return [data[start : start + CHUNK_BYTES] for start in range(0, len(data), CHUNK_BYTES)]


def write_wav(path, pcm):
    temporary = path + ".partial"
    with wave.open(temporary, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(pcm)
    os.replace(temporary, path)


async def send(ws, event, audio_bytes=None):
    show_client(event, audio_bytes)
    await ws.send(json.dumps(event))


async def receive(ws):
    raw = await asyncio.wait_for(ws.recv(), TIMEOUT_SECONDS)
    if isinstance(raw, bytes):
        raw = raw.decode()
    event = json.loads(raw)
    show_server(event)
    if event.get("type") == "error":
        message = (event.get("error") or {}).get("message", "Realtime server error")
        raise SystemExit(message)
    return event


async def until(ws, kind):
    while True:
        event = await receive(ws)
        if event.get("type") == kind:
            return event


CHAT_TURNS = (
    "My name is Nikhil and I am planning to use Kong AI Gateway.",
    "Who am I and what do I want to do?",
)


def session_update(mode):
    if mode == "audio":
        return {
            "type": "session.update",
            "session": {
                "type": "realtime",
                "instructions": (
                    "You are the voice model for the STS Kong AI Gateway lab. "
                    "Answer in one short sentence."
                ),
                "output_modalities": ["audio"],
                "audio": {
                    "input": {
                        "format": {"type": "audio/pcm", "rate": SAMPLE_RATE},
                        "turn_detection": None,
                    },
                    "output": {
                        "format": {"type": "audio/pcm", "rate": SAMPLE_RATE},
                        "voice": "marin",
                    },
                },
            },
        }
    instructions = "You are the voice model for the STS Kong AI Gateway lab. Answer in one short sentence."
    if mode == "chat":
        instructions = (
            "You are the voice model for the STS Kong AI Gateway lab. "
            "Nikhil is speaking. Reply briefly in English."
        )
    return {
        "type": "session.update",
        "session": {
            "type": "realtime",
            "instructions": instructions,
            "output_modalities": ["text"],
        },
    }


async def take(ws):
    raw = await asyncio.wait_for(ws.recv(), TIMEOUT_SECONDS)
    if isinstance(raw, bytes):
        raw = raw.decode()
    event = json.loads(raw)
    if event.get("type") == "error":
        message = (event.get("error") or {}).get("message", "Realtime server error")
        raise SystemExit(message)
    return event


def ask_nikhil(suggestion):
    """Show the suggested line in the Nikhil prompt. Enter sends it."""
    prompt = "\001\033[36m\002Nikhil > \001\033[0m\002"
    try:
        import readline

        def hook():
            readline.insert_text(suggestion)

        readline.set_startup_hook(hook)
        try:
            typed = input(prompt)
        finally:
            readline.set_startup_hook()
    except Exception:
        print(suggestion)
        typed = input("Nikhil > ")
    return typed.strip() or suggestion


async def stream_reply(ws, turn):
    print(INK.server("server > "), end="", flush=True)
    parts = []
    while True:
        event = await take(ws)
        kind = event.get("type")
        if kind == "response.output_text.delta":
            fragment = (event.get("delta") or "").replace("\n", " ").replace("\r", "")
            if not fragment:
                continue
            parts.append(fragment)
            print(INK.server(fragment), end="", flush=True)
        elif kind == "response.done":
            reply = text_from_response(event) or "".join(parts).strip()
            if not parts and reply:
                print(INK.server(reply), end="", flush=True)
            print()
            status = (event.get("response") or {}).get("status")
            if status != "completed" or not reply:
                raise SystemExit(f"Turn {turn} ended with status {status or 'missing'}.")
            return


async def run_chat():
    url = realtime_url()
    print(INK.title("STS  Kong AI Gateway lab  ·  Realtime"))
    print("mode  chat")
    print(f"url   {url}")
    print()
    print("This is one realtime session on a single WebSocket.")
    print("Each line is a user message on that same connection, and each reply is streamed back on it.")
    print("The gateway keeps the upstream session open, so the model can use the first turn when it answers the second.")
    print("A suggested line is already written at the Nikhil prompt. Press Enter to send it.")
    print()

    headers = {"apikey": api_key()}
    parameters = inspect.signature(websockets.connect).parameters
    header_argument = "additional_headers" if "additional_headers" in parameters else "extra_headers"
    try:
        async with websockets.connect(
            url,
            open_timeout=30,
            max_size=8_000_000,
            **{header_argument: headers},
        ) as ws:
            while (await take(ws)).get("type") != "session.created":
                pass
            await ws.send(json.dumps(session_update("chat")))
            while (await take(ws)).get("type") != "session.updated":
                pass

            for turn, suggestion in enumerate(CHAT_TURNS, start=1):
                text = await asyncio.get_event_loop().run_in_executor(None, ask_nikhil, suggestion)
                await ws.send(json.dumps({
                    "type": "conversation.item.create",
                    "item": {
                        "type": "message",
                        "role": "user",
                        "content": [{"type": "input_text", "text": text}],
                    },
                }))
                await ws.send(json.dumps({
                    "type": "response.create",
                    "response": {"output_modalities": ["text"]},
                }))
                await stream_reply(ws, turn)
                print()
    except SystemExit:
        raise
    except Exception as error:
        raise SystemExit(f"Realtime call failed: {error}") from None
    print(INK.server("completed"))


async def run(mode):
    if mode == "chat":
        await run_chat()
        return
    url = realtime_url()
    print(INK.title("STS  Kong AI Gateway lab  ·  Realtime"))
    print(f"mode  {mode}")
    print(f"url   {url}")
    print("Client events are the JSON this program sends. Server events are printed by type.")

    headers = {"apikey": api_key()}
    parameters = inspect.signature(websockets.connect).parameters
    header_argument = "additional_headers" if "additional_headers" in parameters else "extra_headers"

    pcm = bytearray()
    streamed = []
    try:
        async with websockets.connect(
            url,
            open_timeout=30,
            max_size=8_000_000,
            **{header_argument: headers},
        ) as ws:
            await until(ws, "session.created")
            await send(ws, session_update(mode))
            await until(ws, "session.updated")

            if mode == "text":
                await send(
                    ws,
                    {
                        "type": "conversation.item.create",
                        "item": {
                            "type": "message",
                            "role": "user",
                            "content": [
                                {
                                    "type": "input_text",
                                    "text": "Say hello in one short sentence for the STS Kong AI Gateway lab.",
                                }
                            ],
                        },
                    },
                )
                await send(
                    ws,
                    {
                        "type": "response.create",
                        "response": {"output_modalities": ["text"]},
                    },
                )
            else:
                source = os.environ.get(
                    "REALTIME_INPUT_PCM",
                    os.path.join(HERE, "artifacts", "demo-realtime-input.pcm"),
                )
                for chunk in pcm_chunks(source):
                    await send(
                        ws,
                        {"type": "input_audio_buffer.append", "audio": base64.b64encode(chunk).decode("ascii")},
                        audio_bytes=len(chunk),
                    )
                await send(ws, {"type": "input_audio_buffer.commit"})
                await send(
                    ws,
                    {
                        "type": "response.create",
                        "response": {"output_modalities": ["audio"]},
                    },
                )

            while True:
                event = await receive(ws)
                kind = event.get("type")
                if kind == "response.output_audio.delta" and event.get("delta"):
                    pcm.extend(base64.b64decode(event["delta"]))
                elif kind in ("response.output_text.delta", "response.output_audio_transcript.delta"):
                    streamed.append(event.get("delta") or "")
                elif kind == "response.done":
                    done = event
                    break
    except SystemExit:
        raise
    except Exception as error:
        raise SystemExit(f"Realtime call failed: {error}") from None

    status = (done.get("response") or {}).get("status")
    reply = text_from_response(done) or "".join(streamed).strip()
    if status != "completed":
        raise SystemExit(f"response.done status is {status or 'missing'}.")
    if mode == "text" and not reply:
        raise SystemExit("response.done completed without text.")
    if mode == "audio" and not pcm:
        raise SystemExit("response.done completed without audio.")

    if reply:
        print(INK.title(f"\nreply  {reply}"))
    if mode == "audio":
        destination = os.environ.get(
            "REALTIME_AUDIO_FILE",
            os.path.join(HERE, "artifacts", "demo-realtime-response.wav"),
        )
        os.makedirs(os.path.dirname(destination) or ".", exist_ok=True)
        write_wav(destination, bytes(pcm))
        print(INK.audio(f"wav  {destination}  {len(pcm)} bytes"))
    print(INK.server("completed"))


def main():
    parser = argparse.ArgumentParser(description="STS Kong AI Gateway realtime client.")
    parser.add_argument("mode", choices=("text", "audio", "chat"))
    args = parser.parse_args()
    asyncio.run(run(args.mode))


if __name__ == "__main__":
    main()
