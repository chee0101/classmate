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

    def _norm_key(s: str) -> str:
        return re.sub(r"[^a-z0-9.]+", "", s.lower())

    def _dedupe_markdown_table_rows(src: str) -> str:
        """
        OCR table output can repeat the same REMARKS cell many times per row.
        Collapse duplicate cells row-wise before snippet extraction.
        """
        out_lines: list[str] = []
        for raw_ln in src.splitlines():
            ln = raw_ln.strip()
            if "|" not in ln:
                out_lines.append(raw_ln)
                continue

            cells = [c.strip() for c in raw_ln.split("|")]
            uniq_cells: list[str] = []
            seen: set[str] = set()
            for c in cells:
                if not c:
                    continue
                k = _norm_key(c)
                if not k or k in seen:
                    continue
                seen.add(k)
                uniq_cells.append(c)

            if not uniq_cells:
                continue
            out_lines.append(" | ".join(uniq_cells))
        return "\n".join(out_lines)

    text = _dedupe_markdown_table_rows(text)

    t = text.replace("，", ",")
    # OCR normalization for screenshot inputs:
    # - unify fullwidth punctuation
    # - normalize dash variants
    # - insert whitespace around separators for easier regex matching
    t = t.replace("（", "(").replace("）", ")")
    t = t.replace("—", "-").replace("–", "-")
    # Separate glued date tokens: e.g. 26.10.202520.10.2025 -> 26.10.2025 20.10.2025
    t = re.sub(r"(?<=\d{4})(?=\d{1,2}\.\d{2}\.\d{4})", " ", t)
    # Separate weekday/title glue after date comma segments.
    t = re.sub(r"(,\s*[A-Za-z]{3,12})([A-Z][a-z])", r"\1 \2", t)
    t = re.sub(r"(?<=\d)-(?=[A-Za-z])", " - ", t)
    t = re.sub(r"(?<=[A-Za-z])-(?=\d)", " - ", t)
    t = re.sub(r"\s*&\s*", " & ", t)

    # Match date-like starts for remark chunks, including OCR-noisy variants:
    # - 17 & 18.02.2026,
    # - 21.03.2026 & 22.03.2026,
    # - 25.12.2025,
    # - 29&30.09.2026,
    start_re = re.compile(
        r"(?P<pair_day_full>(?P<d0>\d{1,2})\s*&\s*(?P<d1p>\d{1,2}\.\d{2}\.\d{4})(?:\s*,|\s+))"
        r"|(?P<pair_full_full>(?P<d0full>\d{1,2}\.\d{2}\.\d{4})\s*&\s*(?P<d1full>\d{1,2}\.\d{2}\.\d{4})(?:\s*,|\s+))"
        r"|(?P<full>\d{1,2}\.\d{2}\.\d{4}(?:\s*,|\s+))",
        flags=re.IGNORECASE,
    )

    # Normalize newlines to spaces so we can capture two-line cells.
    flat = re.sub(r"\s*\n\s*", " ", t)

    matches = list(start_re.finditer(flat))
    if not matches:
        # Fallback: keep only lines that look like remark text.
        lines = [ln.strip() for ln in t.splitlines() if ln.strip()]
        keep = [
            ln
            for ln in lines
            if _contains_date_token(ln)
            and (" - " in ln or "-" in ln or " & " in ln)
            and any(ch.isalpha() for ch in ln)
        ]
        return "\n".join(keep).strip()

    snippets: list[str] = []
    seen_keys: set[str] = set()

    def _compact_chunk(chunk: str) -> str:
        # Remove markdown table noise and repeated column fragments.
        parts = [p.strip() for p in chunk.split("|") if p.strip()]
        out: list[str] = []
        local_seen: set[str] = set()
        for p in parts:
            p_norm = re.sub(r"\s+", " ", p).strip()
            if not p_norm:
                continue
            key = re.sub(r"[^a-z0-9.]+", "", p_norm.lower())
            if not key or key in local_seen:
                continue
            local_seen.add(key)
            out.append(p_norm)
        if out:
            return " | ".join(out)
        return re.sub(r"\s+", " ", chunk).strip()

    for i, m in enumerate(matches):
        s = m.start()
        e = matches[i + 1].start() if i + 1 < len(matches) else len(flat)
        chunk = _compact_chunk(flat[s:e].strip())
        # Keep chunks that contain a date and title separator in OCR/noisy forms.
        if not _contains_date_token(chunk):
            continue
        if " - " not in chunk and "-" not in chunk:
            continue
        if not any(ch.isalpha() for ch in chunk):
            continue
        dedupe_key = re.sub(r"[^a-z0-9.]+", "", chunk.lower())
        if not dedupe_key or dedupe_key in seen_keys:
            continue
        seen_keys.add(dedupe_key)
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
        "- You MAY infer and repair OCR noise/typos if obvious from context (weekday misspellings like 'saturday' instead of 'Saturday',\n"
        "  glued words, missing separators/spaces).\n"
        "- You MAY add suitable spacing in event titles when text is glued (e.g. 'ChristmasDay' -> 'Christmas Day',\n"
        "  'ReplacementleaveforEid al-Fitr' -> 'Replacement leave for Eid al-Fitr').\n"
        "- Keep the original event meaning; do not translate or paraphrase to a different term.\n"
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
