"""Request builder for LM Studio (OpenAI-compatible chat completions).

LM Studio serves a standard OpenAI ``/v1/chat/completions`` endpoint.
We apply normalization to ensure compatibility with backends that may
not support the ``system`` role in the messages array.
"""

from __future__ import annotations

from typing import Any

from loguru import logger

from core.anthropic import ReasoningReplayMode, build_base_request_body
from core.anthropic.conversion import OpenAIConversionError
from providers.exceptions import InvalidRequestError


def _normalize_system_messages(body: dict[str, Any]) -> None:
    """Convert system messages to a format compatible with the backend.

    Some OpenAI-compatible backends (e.g. Antigravity-Manager) reject
    ``role: system`` inside the messages array.  We merge all system
    messages into the first user message as a preamble, or prepend a
    synthetic user message if no user message follows.
    """
    messages = body.get("messages")
    if not messages:
        return

    system_parts: list[str] = []
    cleaned: list[dict[str, Any]] = []

    for msg in messages:
        if msg.get("role") == "system":
            content = msg.get("content", "")
            if content:
                system_parts.append(content)
        else:
            cleaned.append(msg)

    if not system_parts:
        return  # nothing to do

    system_text = "\n\n".join(system_parts)

    # Merge into the first user message if it exists
    if cleaned and cleaned[0].get("role") == "user":
        existing = cleaned[0].get("content", "")
        cleaned[0]["content"] = f"[System Instructions]\n{system_text}\n[End System Instructions]\n\n{existing}"
    else:
        # Prepend a synthetic user message with system instructions
        cleaned.insert(0, {
            "role": "user",
            "content": f"[System Instructions]\n{system_text}\n[End System Instructions]",
        })
        # Ensure alternating user/assistant if the next message is also user
        if len(cleaned) > 1 and cleaned[1].get("role") == "user":
            cleaned.insert(1, {"role": "assistant", "content": "Understood."})

    body["messages"] = cleaned


def build_request_body(request_data: Any, *, thinking_enabled: bool) -> dict:
    """Build OpenAI-format request body from an Anthropic request for LM Studio."""
    logger.debug(
        "LMSTUDIO_REQUEST: conversion start model={} msgs={}",
        getattr(request_data, "model", "?"),
        len(getattr(request_data, "messages", [])),
    )
    try:
        body = build_base_request_body(
            request_data,
            reasoning_replay=ReasoningReplayMode.REASONING_CONTENT
            if thinking_enabled
            else ReasoningReplayMode.DISABLED,
        )
    except OpenAIConversionError as exc:
        raise InvalidRequestError(str(exc)) from exc

    request_extra = getattr(request_data, "extra_body", None)
    if isinstance(request_extra, dict) and request_extra:
        merged = dict(request_extra)
        body["extra_body"] = merged

    # Normalize system messages for backends that don't support them
    _normalize_system_messages(body)

    logger.debug(
        "LMSTUDIO_REQUEST: conversion done model={} msgs={} tools={}",
        body.get("model"),
        len(body.get("messages", [])),
        len(body.get("tools", [])),
    )
    return body
