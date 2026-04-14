from __future__ import annotations

import asyncio
import json
import re
from datetime import date
from time import perf_counter

from pydantic import BaseModel, Field

from app.core.config import get_settings


class GeminiFullCalendarEvent(BaseModel):
    title: str = Field(min_length=1)
    start_date: date
    end_date: date


class GeminiFullCalendarPayload(BaseModel):
    """Whole-document extraction; input may be tables, bullets, OCR noise, or mixed layout."""

    session_name: str | None = None
    session_start: date | None = None
    session_end: date | None = None
    events: list[GeminiFullCalendarEvent] = Field(default_factory=list)


def slice_english_calendar_section_with_debug(
    text: str,
) -> tuple[str, dict[str, str | int]]:
    """
    USM-style bilingual calendars often export Malay rows first, then English.

    When we can find an English-looking table header (SEM / WEEKS / REMARKS),
    return text starting at that header so Gemini focuses on the useful block.

    If no such header is found, return the original text unchanged.
    """
    if not text or not text.strip():
        return text, {
            "slice_header_match_count": 0,
            "slice_start_index": -1,
            "slice_preview": "",
        }

    t = text.replace("\r\n", "\n")

    header_re = re.compile(
        r"(?im)^\s*\|?\s*(?:SEM|EM)\b[^\n]*\bWEEKS?\b[^\n]*\bREMARKS?\b[^\n]*$",
    )
    matches = list(header_re.finditer(t))
    if matches:
        start = matches[-1].start()
        sliced = t[start:].strip()
        return sliced, {
            "slice_header_match_count": len(matches),
            "slice_start_index": start,
            "slice_preview": sliced[:200],
        }

    m = re.search(r"(?is)\b(?:SEM|EM)\b.*?\bWEEKS?\b.*?\bREMARKS?\b", t)
    if m:
        start = m.start()
        sliced = t[start:].strip()
        return sliced, {
            "slice_header_match_count": 1,
            "slice_start_index": start,
            "slice_preview": sliced[:200],
        }

    return t, {
        "slice_header_match_count": 0,
        "slice_start_index": -1,
        "slice_preview": t[:200],
    }


def _extract_json_blob(text: str) -> str | None:
    m = re.search(r"```json\s*(\{.*?\})\s*```", text, flags=re.DOTALL | re.IGNORECASE)
    if m:
        return m.group(1)
    m = re.search(r"(\{.*\})", text, flags=re.DOTALL)
    return m.group(1) if m else None


_FULL_CALENDAR_MAX_CHARS = 250_000


async def extract_full_academic_calendar_with_gemini(
    doc_text: str,
) -> tuple[GeminiFullCalendarPayload | None, float, str, str, str]:
    """
    Docling/OCR text; pipeline passes an English-table slice when SEM/WEEKS/REMARKS
    headers are found, otherwise the full original markdown.

    Returns:
      (payload, gemini_ms, status, error_message, model_used)
    payload is None when extraction is unusable (no events and no inferable session).
    """
    settings = get_settings()
    if not settings.gemini_api_key:
        return None, 0.0, "no_api_key", "", ""

    try:
        from google import genai  # type: ignore
    except Exception as e:
        return None, 0.0, "import_error", f"{type(e).__name__}: {e}", ""

    raw = (doc_text or "").strip()
    if not raw:
        return None, 0.0, "empty_input", "", ""

    if len(raw) > _FULL_CALENDAR_MAX_CHARS:
        raw = raw[:_FULL_CALENDAR_MAX_CHARS]

    prompt = (
        "You are given plain text from an academic calendar (may be markdown tables, bullets, "
        "mixed languages, or noisy OCR). Extract structured information.\n\n"
        "Return STRICT JSON only (no markdown fences outside JSON if possible). Schema:\n"
        "{\n"
        '  "session_name": string or null,\n'
        '  "session_start": "YYYY-MM-DD" or null,\n'
        '  "session_end": "YYYY-MM-DD" or null,\n'
        '  "events": [\n'
        "    {\n"
        '      "title": string,\n'
        '      "start_date": "YYYY-MM-DD",\n'
        '      "end_date": "YYYY-MM-DD"\n'
        "    }\n"
        "  ]\n"
        "}\n\n"
        "Rules:\n"
        "- Extract all dated events mentioned in the document, including holidays, festivals,\n"
        "  replacement leaves, observances, and notable special days.\n"
        "- If a row contains BOTH a holiday/festival and a replacement leave, output them as\n"
        "  SEPARATE events (do not merge into one title).\n"
        "- Replacement leave is important: always extract entries containing phrases like\n"
        "  'replacement leave', 'replacementleave', or 'leave for ...'.\n"
        "- Do NOT extract academic structure blocks: teaching weeks, semester/mid-semester breaks,\n"
        "  revision weeks, exam-week blocks, industrial training blocks, or orientation blocks.\n"
        "- For session bounds, prefer the earliest and latest valid dates that appear in the document text.\n"
        "- If uncertain, set session_start/session_end to null; backend will use earliest/latest dates from Docling text.\n"
        "- Repair obvious OCR issues in dates and titles when context is clear.\n"
        "- Date parsing normalization hints (VERY IMPORTANT):\n"
        "  * 1210.2025 -> 12.10.2025 (missing separator between DD and MM)\n"
        "  * 27072026 -> 27.07.2026 (compact ddmmyyyy)\n"
        "  * 2610202520102025 -> 26.10.2025 and 20.10.2025 (two glued dates)\n"
        "  * 1207 20260707 2026 -> 12.07.2026 and 07.07.2026 (split noisy grouped digits)\n"
        "  * 0410.2026 -> 04.10.2026\n"
        "- When a token can represent two dates, split into both and use context (weekday/event wording)\n"
        "  to choose the most plausible date/date-range for that row.\n"
        "- For multi-day ranges in text, set start_date and end_date to the full span.\n"
        "- Skip rows with no parseable dates.\n"
        "- Do not include dates, weekdays, or course/week labels in the event title.\n"
        "- Clean OCR title formatting while keeping same meaning: fix spacing/case/obvious typos only.\n"
        "- Examples: 'ChristmasDay' -> 'Christmas Day', 'MalaystaDay' -> 'Malaysia Day',\n"
        "  'Yang di-PertuanAqong'sBrthday' -> 'Yang di-Pertuan Agong's Birthday'.\n"
        "- Do NOT rename to a different event; only correct spelling/spacing.\n"
        "- events may be empty if no valid non-academic-break events are found.\n\n"
        "Input text:\n"
        f"{raw}"
    )

    model_name = settings.gemini_model
    t0 = perf_counter()
    try:
        client = genai.Client(api_key=settings.gemini_api_key)
        response = await asyncio.to_thread(
            client.models.generate_content,
            model=model_name,
            contents=prompt,
        )
    except Exception as e:
        gemini_ms_err = (perf_counter() - t0) * 1000.0
        return None, gemini_ms_err, "api_error", f"{type(e).__name__}: {e}", ""

    gemini_ms = (perf_counter() - t0) * 1000.0
    raw_text = getattr(response, "text", "") or ""
    blob = _extract_json_blob(raw_text)
    if not blob:
        return None, gemini_ms, "no_json_blob", "", model_name

    try:
        payload = GeminiFullCalendarPayload.model_validate(json.loads(blob))
    except Exception as e:
        return None, gemini_ms, "json_parse_error", f"{type(e).__name__}: {e}", model_name

    if not payload.events and payload.session_start is None and payload.session_end is None:
        return None, gemini_ms, "empty_result", "", model_name

    return payload, gemini_ms, "ok", "", model_name
