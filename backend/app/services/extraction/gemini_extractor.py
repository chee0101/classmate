from __future__ import annotations

import asyncio
import json
import re
from datetime import date, datetime, time
from time import perf_counter

from pydantic import BaseModel, Field

from app.core.config import get_settings
from app.schemas.extraction import AcademicEventExtract


class GeminiHolidayItem(BaseModel):
    title: str = Field(min_length=1)
    start_date: date
    end_date: date


class GeminiHolidayPayload(BaseModel):
    holidays: list[GeminiHolidayItem] = Field(default_factory=list)


def _to_event(item: GeminiHolidayItem, *, sem2_start: date) -> AcademicEventExtract:
    term_id = "sem2" if item.start_date >= sem2_start else "sem1"
    start_dt = datetime.combine(item.start_date, time(0, 0, 0))
    end_dt = datetime.combine(item.end_date, time(23, 59, 0))
    return AcademicEventExtract(
        title=item.title.strip(),
        start_datetime=start_dt,
        end_datetime=end_dt,
        all_day=True,
        hide_classes_during_event=True,
        is_academic_break=False,
        term_id=term_id,
        location=None,
    )


def _slice_english_calendar_section(text: str) -> str:
    """
    Bilingual USM-style calendars often export Malay rows first, then English.
    For Gemini holiday extraction, keep only the English block (same remarks wording as PDF English column).
    If no English header is found, return full text so extraction still works.
    """
    if not text or not text.strip():
        return text

    sliced, _debug = _slice_english_calendar_section_with_debug(text)
    return sliced


def _slice_english_calendar_section_with_debug(text: str) -> tuple[str, dict[str, str | int]]:
    """
    Return (sliced_text, debug_info).
    Debug info helps verify whether header matching worked for bilingual tables.
    """
    if not text or not text.strip():
        return text, {
            "slice_header_match_count": 0,
            "slice_start_index": -1,
            "slice_preview": "",
        }

    t = text.replace("\r\n", "\n")

    # Match markdown/table-like header rows robustly, e.g.:
    # | SEM | WEEKS | ... | REMARKS |
    # also tolerates optional leading pipe and extra columns/order noise.
    header_re = re.compile(
        r"(?im)^\s*\|?\s*SEM\b[^\n]*\bWEEKS?\b[^\n]*\bREMARKS?\b[^\n]*$",
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

    # Fallback: search anywhere in the text for a header-like phrase.
    m = re.search(r"(?is)\bSEM\b.*?\bWEEKS?\b.*?\bREMARKS?\b", t)
    if m:
        start = m.start()
        sliced = t[start:].strip()
        return sliced, {
            "slice_header_match_count": 1,
            "slice_start_index": start,
            "slice_preview": sliced[:200],
        }

    # No match: return full text unchanged.
    return t, {
        "slice_header_match_count": 0,
        "slice_start_index": -1,
        "slice_preview": t[:200],
    }


def _extract_json_blob(text: str) -> str | None:
    # Prefer fenced JSON if present; otherwise fallback to first {...} blob.
    m = re.search(r"```json\s*(\{.*?\})\s*```", text, flags=re.DOTALL | re.IGNORECASE)
    if m:
        return m.group(1)
    m = re.search(r"(\{.*\})", text, flags=re.DOTALL)
    return m.group(1) if m else None


def _prefilter_remark_snippets(text: str) -> str:
    """
    Reduce Gemini input size by keeping only remark-style snippets:
      <date(s)>, <weekday(s)> - <title>

    This works on Docling plain text and on table-ish exports where remarks are
    appended at end of a row. It is intentionally permissive; Gemini will do the
    final structuring.
    """
    if not text or not text.strip():
        return text

    t = text.replace("，", ",")

    # Match "dd.mm.yyyy," and the multi-date variants used in the calendar:
    # - 17 & 18.02.2026,
    # - 21.03.2026 & 22.03.2026,
    # - 25.12.2025,
    start_re = re.compile(
        r"(?P<pair_day_full>(?P<d0>\d{1,2})\s*&\s*(?P<d1p>\d{1,2}\.\d{2}\.\d{4})\s*,)"
        r"|(?P<pair_full_full>(?P<d0full>\d{1,2}\.\d{2}\.\d{4})\s*&\s*(?P<d1full>\d{1,2}\.\d{2}\.\d{4})\s*,)"
        r"|(?P<full>\d{1,2}\.\d{2}\.\d{4}\s*,)",
        flags=re.IGNORECASE,
    )

    # Normalize newlines to spaces so we can capture two-line cells.
    flat = re.sub(r"\s*\n\s*", " ", t)

    matches = list(start_re.finditer(flat))
    if not matches:
        # Fallback: keep only lines that look like remarks.
        lines = [ln.strip() for ln in t.splitlines() if ln.strip()]
        keep = [ln for ln in lines if ("," in ln and " - " in ln and _contains_date_token(ln))]
        return "\n".join(keep).strip()

    snippets: list[str] = []
    for i, m in enumerate(matches):
        s = m.start()
        e = matches[i + 1].start() if i + 1 < len(matches) else len(flat)
        chunk = flat[s:e].strip()
        # Keep only chunks that look like "<date>, <weekday> - <title>"
        if " - " not in chunk:
            continue
        snippets.append(chunk)

    return "\n".join(snippets).strip()


def _contains_date_token(s: str) -> bool:
    return bool(re.search(r"\b\d{1,2}\.\d{2}\.\d{4}\b", s))


def build_remark_text_for_debug(doc_text: str) -> str:
    """
    Return the exact prefiltered remark snippets that will be sent to Gemini.
    """
    calendar_text = _slice_english_calendar_section(doc_text)
    return _prefilter_remark_snippets(calendar_text)


async def extract_holidays_with_gemini(
    doc_text: str,
    *,
    sem2_start: date,
) -> tuple[list[AcademicEventExtract], float, str, str, str]:
    """
    doc_text: Docling `export_to_text()` only (plain text). English block is sliced below.
    Returns: (events, gemini_api_ms, status, error, model_used)
    """
    settings = get_settings()
    if not settings.gemini_api_key:
        return [], 0.0, "no_api_key", "", ""

    try:
        from google import genai  # type: ignore
    except Exception as e:
        return [], 0.0, "import_error", f"{type(e).__name__}: {e}", ""

    remark_text = build_remark_text_for_debug(doc_text)
    if not remark_text.strip():
        return [], 0.0, "prefilter_empty", "", ""

    # Direct extraction from Docling text (after English slice). No “cleaning” instructions.
    prompt = (
        "Extract ONLY events from the REMARKS column of this academic calendar text.\n"
        "ONLY extract lines that match this pattern:\n"
        "<date(s)>, <weekday(s)> - <title>\n"
        "Examples:\n"
        "- '25.12.2025, Thursday - Christmas Day'\n"
        "- '17 & 18.02.2026, Tuesday & Wednesday - Chinese New Year'\n"
        "\n"
        "Ignore ALL other content, including teaching weeks, revision week, examination periods,\n"
        "mid-semester breaks, long breaks, and industrial training.\n"
        "Return STRICT JSON only (no explanation, no extra text) with this exact schema:\n"
        '{"holidays":[{"title":"string","start_date":"YYYY-MM-DD","end_date":"YYYY-MM-DD"}]}\n'
        "\n"
        "Rules:\n"
        "- Do NOT include dates or weekdays in the title.\n"
        "- If multiple dates exist (e.g. '17 & 18.02.2026' or '21.03.2026&22.03.2026'),\n"
        "  convert to a date range using earliest as start_date and latest as end_date.\n"
        "- If single-day event, start_date == end_date.\n"
        "\n"
        "Input (remark snippets only):\n"
        f"{remark_text}"
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
        return [], 0.0, "api_error", f"{type(e).__name__}: {e}", ""

    gemini_ms = (perf_counter() - t0) * 1000.0
    raw_text = getattr(response, "text", "") or ""
    blob = _extract_json_blob(raw_text)
    if not blob:
        return [], gemini_ms, "no_json_blob", "", model_name

    try:
        payload = GeminiHolidayPayload.model_validate(json.loads(blob))
    except Exception as e:
        return [], gemini_ms, "json_parse_error", f"{type(e).__name__}: {e}", model_name

    events: list[AcademicEventExtract] = []
    seen: set[tuple[str, date, date]] = set()
    for item in payload.holidays:
        if item.end_date < item.start_date:
            continue
        key = (item.title.strip().lower(), item.start_date, item.end_date)
        if key in seen:
            continue
        seen.add(key)
        events.append(_to_event(item, sem2_start=sem2_start))

    events.sort(key=lambda e: (e.term_id, e.start_datetime, e.title.lower()))
    status = "ok" if events else "empty_result"
    return events, gemini_ms, status, "", model_name
