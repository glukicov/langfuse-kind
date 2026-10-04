"""Tiny demo: ask OpenAI a few questions and send traces to the local Langfuse."""

import os
import sys
from pathlib import Path

from dotenv import load_dotenv
from langfuse import get_client, observe
from langfuse.openai import OpenAI

load_dotenv(Path(__file__).parent / ".env")

QUESTIONS = [
    "In one sentence, what is Kubernetes in Docker (kind) useful for?",
    "Give me a haiku about observability.",
    "What is the difference between a trace and a span?",
]

client = OpenAI()
model = os.environ.get("OPENAI_MODEL", "gpt-5-mini")


@observe(name="ask")
def ask(question: str) -> str:
    response = client.chat.completions.create(
        model=model,
        messages=[
            {"role": "system", "content": "You are a concise assistant."},
            {"role": "user", "content": question},
        ],
    )
    return response.choices[0].message.content or ""


def main() -> None:
    questions = sys.argv[1:] or QUESTIONS
    langfuse = get_client()
    for question in questions:
        print(f"Q: {question}\nA: {ask(question)}\n")
    langfuse.flush()
    print(f"Traces: {os.environ['LANGFUSE_BASE_URL']}/project/demo/traces")


if __name__ == "__main__":
    main()
