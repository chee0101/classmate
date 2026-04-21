from __future__ import annotations

import asyncio
import json
import re
from datetime import date, datetime
from time import perf_counter

from pydantic import BaseModel, Field

from app.core.config import get_settings
from app.schemas.extraction import ClassSlotExtract, TaskExtract, TaskSubtaskExtract


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


class GeminiTaskSubtask(BaseModel):
    title: str = Field(min_length=1)
    due_datetime: datetime | None = None
    is_completed: bool = False


class GeminiTaskItem(BaseModel):
    course_code: str | None = None
    course_code_candidates: list[str] = Field(default_factory=list)
    title: str = Field(min_length=1)
    description: str | None = None
    due_datetime: datetime | None = None
    subtasks: list[GeminiTaskSubtask] = Field(default_factory=list)


class GeminiTaskPayload(BaseModel):
    tasks: list[GeminiTaskItem] = Field(default_factory=list)


class GeminiTimetableSlot(BaseModel):
    course_code: str = Field(min_length=3)
    day: str = Field(min_length=3)
    start_minutes: int = Field(ge=0, le=24 * 60)
    end_minutes: int = Field(ge=0, le=24 * 60)
    mode: str | None = None
    venue: str | None = None
    class_type: str | None = None


class GeminiTimetablePayload(BaseModel):
    slots: list[GeminiTimetableSlot] = Field(default_factory=list)


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


def _parse_english_date_time(text: str) -> datetime | None:
    s = (text or "").strip()
    if not s:
        return None
    # Normalize OCR time variants such as 11.59pm -> 11:59 PM
    s = re.sub(r"(?i)\b(\d{1,2})[.:](\d{2})\s*([ap]m)\b", r"\1:\2 \3", s)
    s = re.sub(r"\s+", " ", s).strip()
    for fmt in ("%d %B %Y %I:%M %p", "%d %b %Y %I:%M %p", "%d %B %Y", "%d %b %Y"):
        try:
            dt = datetime.strptime(s, fmt)
            if ":%M" not in fmt:
                return dt.replace(hour=23, minute=59, second=0, microsecond=0)
            return dt.replace(second=0, microsecond=0)
        except ValueError:
            continue
    return None


def _extract_mixed_row_tasks_from_markdown_table(doc_text: str) -> list[TaskExtract]:
    """
    Deterministic repair for rows like:
      "Test 1 Submission of Assignment 1 | 29 April 2026 30 April 2026, 11.59pm"
    where LLM may merge two tasks into one.
    """
    out: list[TaskExtract] = []
    for line in (doc_text or "").splitlines():
        row = line.strip()
        if not row.startswith("|"):
            continue
        cols = [c.strip() for c in row.strip("|").split("|")]
        if len(cols) < 3:
            continue
        component = cols[1]
        date_cell = cols[2]
        lc = component.lower()
        if "test" not in lc or "submission" not in lc:
            continue

        date_hits = list(
            re.finditer(
                r"(?i)\b(\d{1,2}\s+[A-Za-z]{3,9}\s+\d{4})(?:\s*,?\s*(\d{1,2}[.:]\d{2}\s*[ap]m))?",
                date_cell,
            )
        )
        parsed_dates = []
        for m in date_hits:
            dpart = m.group(1) or ""
            tpart = m.group(2) or ""
            parsed = _parse_english_date_time(f"{dpart} {tpart}".strip())
            if parsed is not None:
                parsed_dates.append(parsed)
        if len(parsed_dates) < 2:
            continue

        parsed_dates.sort()
        test_dt = parsed_dates[0].replace(hour=23, minute=59, second=0, microsecond=0)
        submission_dt = parsed_dates[-1]

        test_m = re.search(r"(?i)\btest\s*\d*\b", component)
        submission_m = re.search(r"(?i)\bsubmission(?:\s+of)?\s+[^,;/|]+", component)
        test_title = (test_m.group(0) if test_m else "Test").strip()
        submission_title = (
            submission_m.group(0).strip()
            if submission_m
            else "Submission"
        )
        submission_title = re.sub(r"\s+", " ", submission_title)
        test_title = re.sub(r"\s+", " ", test_title)

        out.append(
            TaskExtract(
                title=test_title,
                description=None,
                due_datetime=test_dt,
                course_code="",
                course_code_candidates=[],
                course_id=None,
                subtasks=[],
            )
        )
        out.append(
            TaskExtract(
                title=submission_title[0].upper() + submission_title[1:]
                if submission_title
                else "Submission",
                description=None,
                due_datetime=submission_dt,
                course_code="",
                course_code_candidates=[],
                course_id=None,
                subtasks=[],
            )
        )
    return out


_FULL_CALENDAR_MAX_CHARS = 250_000


def _is_due_action_task(task: TaskExtract) -> bool:
    if task.due_datetime is None:
        return False
    title = (task.title or "").strip().lower()
    description = (task.description or "").strip().lower()
    text = f"{title} {description}".strip()
    if not title:
        return False
    # Exclude informational release rows.
    if any(k in text for k in ("release", "released", "publish", "published", "available")):
        return False
    # Keep actionable due items (submission/deadline) and assessments (test/quiz/exam).
    return any(
        k in text
        for k in (
            "submission",
            "submit",
            "deadline",
            "due",
            "deliver",
            "upload",
            "turn in",
            "hand in",
            "test",
            "quiz",
            "exam",
        )
    )


def _clean_task_description(raw_description: str | None) -> str | None:
    if raw_description is None:
        return None
    text = re.sub(r"\s+", " ", raw_description.strip())
    if not text:
        return None
    if text.lower().startswith("parsed from mixed table row:"):
        return None
    if re.fullmatch(r"(?i)week\s*\d+", text):
        return None
    return text


def _normalize_task_title_and_description(task: TaskExtract) -> TaskExtract:
    """
    Prefer object title (e.g., "Assignment 1") over action phrase
    (e.g., "Submission of Assignment 1"). Keep the action in description.
    """
    title = re.sub(r"\s+", " ", (task.title or "").strip())
    if not title:
        return task

    desc = _clean_task_description(task.description)
    lowered = title.lower()

    normalized_title = title
    action_note: str | None = None

    m_submission = re.match(r"(?i)^submission(?:\s+of)?\s+(.+)$", title)
    if m_submission:
        candidate = re.sub(r"\s+", " ", m_submission.group(1).strip())
        if candidate:
            normalized_title = candidate[0].upper() + candidate[1:]
            action_note = "Submission task"
    elif lowered.startswith("submit "):
        candidate = title[7:].strip()
        if candidate:
            normalized_title = candidate[0].upper() + candidate[1:]
            action_note = "Submission task"

    final_desc = desc
    if action_note:
        if not final_desc:
            final_desc = action_note
        elif action_note.lower() not in final_desc.lower():
            final_desc = f"{action_note}. {final_desc}"

    return TaskExtract(
        title=normalized_title,
        description=final_desc,
        due_datetime=task.due_datetime,
        course_code=task.course_code,
        course_code_candidates=task.course_code_candidates,
        course_id=task.course_id,
        subtasks=task.subtasks,
    )


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


async def extract_task_with_gemini(
    doc_text: str,
) -> tuple[list[TaskExtract], float, str, str, str]:
    """
    Extract one or more tasks (with optional subtasks) from a document.
    Returns:
      (tasks, gemini_ms, status, error_message, model_used)
    """
    settings = get_settings()
    if not settings.gemini_api_key:
        return [], 0.0, "no_api_key", "", ""

    try:
        from google import genai  # type: ignore
    except Exception as e:
        return [], 0.0, "import_error", f"{type(e).__name__}: {e}", ""

    raw = (doc_text or "").strip()
    if not raw:
        return [], 0.0, "empty_input", "", ""
    if len(raw) > _FULL_CALENDAR_MAX_CHARS:
        raw = raw[:_FULL_CALENDAR_MAX_CHARS]

    prompt = (
        "Extract assignment/task information from this academic document text.\n"
        "Return STRICT JSON with this schema:\n"
        '{"tasks":[{"title":"string","description":"string|null","due_datetime":"YYYY-MM-DDTHH:MM:SS|null","course_code":"string|null","course_code_candidates":["string"],"subtasks":[{"title":"string","due_datetime":"YYYY-MM-DDTHH:MM:SS|null","is_completed":false}]}]}\n'
        "Rules:\n"
        "- Include tasks/assignments/projects/quizzes/exams with due dates/times.\n"
        "- Return ALL identifiable tasks.\n"
        "- Keep only actionable due items (submission/deadline/due/upload/hand-in).\n"
        "- Exclude informational rows such as release/published/announcement dates.\n"
        "- For a task with checklist/components, keep one parent task and put child items in subtasks[].\n"
        "- course_code should be uppercase when known (e.g. CST312); else null.\n"
        "- Put ambiguous/alternate detected codes in course_code_candidates.\n"
        "- due_datetime must be ISO-8601 when known; if only date known, use 23:59:00. If unknown, use null.\n"
        "- If a row includes two task phrases and two dates (e.g., Test + Submission), split into two tasks.\n"
        "- In such mixed rows, map the earlier date to test/quiz and the later date/time to submission/deadline.\n"
        "- For phased project schedules (Phase 1/2/3...), use the PHASE END date as due_datetime\n"
        "  when no explicit deliverable deadline is given.\n"
        "- For phased project schedules, prefer ONE parent task for the whole project timeline,\n"
        "  and put each phase/milestone as subtasks[] rather than many separate parent tasks.\n"
        "- Parent task due_datetime should be the latest due date across all phase/milestone subtasks.\n"
        "- Example structure for phased project docs:\n"
        '  {"tasks":[{"title":"Major Project Timeline","due_datetime":"latest_due","subtasks":[...phase/milestone items...]}]}\n'
        "- Keep title concise and meaningful.\n"
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
        return [], gemini_ms_err, "api_error", f"{type(e).__name__}: {e}", ""

    gemini_ms = (perf_counter() - t0) * 1000.0
    raw_text = getattr(response, "text", "") or ""
    blob = _extract_json_blob(raw_text)
    if not blob:
        return [], gemini_ms, "no_json_blob", "", model_name

    try:
        payload = GeminiTaskPayload.model_validate(json.loads(blob))
    except Exception as e:
        return [], gemini_ms, "json_parse_error", f"{type(e).__name__}: {e}", model_name

    if not payload.tasks:
        return [], gemini_ms, "empty_result", "", model_name

    out: list[TaskExtract] = []
    for item in payload.tasks:
        title = item.title.strip()
        if not title:
            continue
        code = (item.course_code or "").strip().upper()
        candidates = [
            c.strip().upper()
            for c in item.course_code_candidates
            if c and c.strip()
        ]
        subtasks = [
            TaskSubtaskExtract(
                title=s.title.strip(),
                due_datetime=s.due_datetime,
                is_completed=s.is_completed,
            )
            for s in item.subtasks
            if s.title and s.title.strip()
        ]
        out.append(
            TaskExtract(
                title=title,
                description=_clean_task_description(item.description),
                due_datetime=item.due_datetime,
                course_code=code if code else "",
                course_code_candidates=candidates,
                course_id=None,
                subtasks=subtasks,
            )
        )

    if not out:
        return [], gemini_ms, "empty_result", "", model_name

    deterministic = _extract_mixed_row_tasks_from_markdown_table(raw)
    if deterministic:
        # Remove ambiguous merged records like "Test 1 / Assignment 1 Submission".
        filtered = []
        for t in out:
            ttl = t.title.lower()
            if "test" in ttl and ("submission" in ttl or "/" in ttl):
                continue
            filtered.append(t)
        out = filtered + deterministic

    normalized_out = [_normalize_task_title_and_description(t) for t in out]

    dedup: dict[tuple[str, str], TaskExtract] = {}
    for t in normalized_out:
        key = (
            re.sub(r"\s+", " ", t.title.strip().lower()),
            "" if t.due_datetime is None else t.due_datetime.isoformat(),
        )
        dedup[key] = t
    # Keep Gemini-structured tasks as-is (including parent tasks with subtasks).
    # Previously we filtered to only explicit "due action" titles, which could
    # drop valid phased timeline parent tasks.
    return list(dedup.values()), gemini_ms, "ok", "", model_name


async def extract_timetable_with_gemini(
    doc_text: str,
    *,
    ai_notes: str | None = None,
) -> tuple[list[ClassSlotExtract], float, str, str, str]:
    """
    Layout-agnostic timetable extraction for noisy/flexible documents.
    Returns:
      (slots, gemini_ms, status, error_message, model_used)
    """
    settings = get_settings()
    if not settings.gemini_api_key:
        return [], 0.0, "no_api_key", "", ""

    try:
        from google import genai  # type: ignore
    except Exception as e:
        return [], 0.0, "import_error", f"{type(e).__name__}: {e}", ""

    raw = (doc_text or "").strip()
    if not raw:
        return [], 0.0, "empty_input", "", ""
    if len(raw) > _FULL_CALENDAR_MAX_CHARS:
        raw = raw[:_FULL_CALENDAR_MAX_CHARS]
    notes_rule = ""
    if ai_notes and ai_notes.strip():
        notes_rule = (
            "- IMPORTANT USER REMARKS (must follow strictly): "
            f"{ai_notes.strip()}\n"
            "- If remarks specify a particular group/section, return only slots that match that group/section.\n"
            "- If uncertain whether a row matches the remarks, skip that row.\n"
        )

    prompt = (
        "Extract class timetable slots from this OCR/markdown text.\n"
        "Return STRICT JSON only using this schema:\n"
        '{"slots":[{"course_code":"string","day":"Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday","start_minutes":0,"end_minutes":0,"mode":"online|hybrid|physical|","venue":"string|null","class_type":"lecture|tutorial|lab"}]}\n'
        "Rules:\n"
        "- Extract only real class slots with a valid course code like ABC123/ABC1234.\n"
        "- Normalize day to English weekday names exactly.\n"
        "- start_minutes/end_minutes are minutes from midnight.\n"
        "- Skip non-class entries (minor/co-curriculum/ceramah/general activities) unless a valid course code exists.\n"
        "- If cell has multiple classes, output multiple slots.\n"
        "- If class type is not explicit, default class_type=lecture.\n"
        "- Use tutorial only when clearly stated (e.g. tutorial/tut).\n"
        "- Use lab only when clearly stated (e.g. lab/practical).\n"
        "- mode can be empty string if unknown.\n"
        f"{notes_rule}"
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
        return [], gemini_ms_err, "api_error", f"{type(e).__name__}: {e}", ""

    gemini_ms = (perf_counter() - t0) * 1000.0
    raw_text = getattr(response, "text", "") or ""
    blob = _extract_json_blob(raw_text)
    if not blob:
        return [], gemini_ms, "no_json_blob", "", model_name

    try:
        payload = GeminiTimetablePayload.model_validate(json.loads(blob))
    except Exception as e:
        return [], gemini_ms, "json_parse_error", f"{type(e).__name__}: {e}", model_name

    out: list[ClassSlotExtract] = []
    for item in payload.slots:
        code = re.sub(r"\s+", "", item.course_code.strip().upper())
        if not re.fullmatch(r"[A-Z]{2,5}\d{3,4}[A-Z]?", code):
            continue
        if item.end_minutes <= item.start_minutes:
            continue
        day = item.day.strip().title()
        if day not in {
            "Monday",
            "Tuesday",
            "Wednesday",
            "Thursday",
            "Friday",
            "Saturday",
            "Sunday",
        }:
            continue
        ctype = (item.class_type or "lecture").strip().lower()
        if ctype not in {"lecture", "tutorial", "lab"}:
            ctype = "lecture"
        mode = (item.mode or "").strip().lower()
        if mode not in {"online", "hybrid", "physical", ""}:
            mode = ""
        venue = (item.venue or "").strip() or None
        out.append(
            ClassSlotExtract(
                course_code=code,
                day=day,
                start_minutes=item.start_minutes,
                end_minutes=item.end_minutes,
                mode=mode,
                venue=venue,
                class_type=ctype,  # type: ignore[arg-type]
            )
        )

    if not out:
        return [], gemini_ms, "empty_result", "", model_name
    return out, gemini_ms, "ok", "", model_name
