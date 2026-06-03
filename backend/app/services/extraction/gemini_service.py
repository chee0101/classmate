# app/services/gemini_service.py

from __future__ import annotations

import asyncio
import json
import mimetypes
import re
from datetime import date, datetime
from pathlib import Path
from time import perf_counter

from docx import Document
from pydantic import BaseModel, Field

from app.core.config import get_settings
from app.schemas.extraction import (
    ClassSlotExtract,
    EventExtract,
    TaskExtract,
    TaskSubtaskExtract,
)

# =========================================================
# CONFIG
# =========================================================

_MAX_TEXT_LENGTH = 250_000
_GEMINI_MAX_RETRIES = 3


def _get_model_candidates() -> list[str]:
    """Get primary model and backup models as a list of candidates to try."""
    settings = get_settings()
    
    # Start with primary model
    candidates = [settings.gemini_model]
    
    # Add backup models from config
    if settings.gemini_backup_models:
        backup_models = [
            m.strip() 
            for m in settings.gemini_backup_models.split(",")
            if m.strip()
        ]
        candidates.extend(backup_models)
    
    return candidates


# =========================================================
# GEMINI PAYLOAD MODELS
# =========================================================

class GeminiFullCalendarEvent(BaseModel):
    title: str = Field(min_length=1)
    start_date: date
    end_date: date


class GeminiFullCalendarPayload(BaseModel):
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
    start_minutes: int = Field(ge=0, le=1440)
    end_minutes: int = Field(ge=0, le=1440)
    mode: str | None = None
    venue: str | None = None
    class_type: str | None = None


class GeminiTimetablePayload(BaseModel):
    slots: list[GeminiTimetableSlot] = Field(default_factory=list)


class GeminiEventItem(BaseModel):
    title: str = Field(min_length=1)
    location: str | None = None
    start_datetime: datetime | None = None
    end_datetime: datetime | None = None
    all_day: bool = False


class GeminiEventPayload(BaseModel):
    events: list[GeminiEventItem] = Field(default_factory=list)


# =========================================================
# HELPERS
# =========================================================

def _extract_json_blob(
    text: str,
) -> str | None:

    if not text:
        return None

    match = re.search(
        r"```json\s*(\{.*?\}|\[.*?\])\s*```",
        text,
        flags=re.DOTALL | re.IGNORECASE,
    )

    if match:
        return match.group(1)

    match = re.search(
        r"(\{.*\}|\[.*\])",
        text,
        flags=re.DOTALL,
    )

    if match:
        return match.group(1)

    return None


def _is_transient_gemini_error(
    message: str,
) -> bool:

    lowered = message.lower()

    return any(
        x in lowered
        for x in (
            "429",
            "503",
            "timeout",
            "deadline",
            "temporarily",
            "internal",
        )
    )


def _read_docx_text(
    file_path: str,
) -> str:

    doc = Document(file_path)

    paragraphs = [
        p.text.strip()
        for p in doc.paragraphs
        if p.text.strip()
    ]

    return "\n".join(paragraphs)


def _read_txt_file(
    file_path: str,
) -> str:

    return Path(file_path).read_text(
        encoding="utf-8",
        errors="ignore",
    )


def _upload_file_to_gemini(
    file_path: str,
):

    from google import genai

    settings = get_settings()

    client = genai.Client(
        api_key=settings.gemini_api_key,
    )

    uploaded_file = client.files.upload(
        file=file_path,
    )

    return uploaded_file


def _build_contents(
    *,
    prompt: str,
    text: str | None = None,
    file_paths: list[str] | None = None,
):
    uploaded_files = []
    contents = []

    # =====================================================
    # FILE INPUT
    # =====================================================

    if file_paths:

      for file_path in file_paths:

          suffix = (
              Path(file_path)
              .suffix
              .lower()
          )

          # =====================================
          # DOCX
          # =====================================

          if suffix == ".docx":

              extracted_text = (
                  _read_docx_text(
                      file_path
                  )
              )

              if extracted_text.strip():

                  contents.append(
                      extracted_text[
                          :_MAX_TEXT_LENGTH
                      ]
                  )

          # =====================================
          # TXT
          # =====================================

          elif suffix == ".txt":

              extracted_text = (
                  _read_txt_file(
                      file_path
                  )
              )

              if extracted_text.strip():

                  contents.append(
                      extracted_text[
                          :_MAX_TEXT_LENGTH
                      ]
                  )

          # =====================================
          # PDF / IMAGE
          # =====================================

          else:

              uploaded_file = (
                  _upload_file_to_gemini(
                      file_path
                  )
              )

              contents.append(
                  uploaded_file
              )

              uploaded_files.append(
                  uploaded_file
              )

    # =====================================================
    # NATURAL LANGUAGE TEXT INPUT
    # =====================================================

    if text and text.strip():

        clean_text = text.strip()

        contents.append(
            clean_text[:_MAX_TEXT_LENGTH]
        )

    contents.append(prompt)

    # return contents
    return (
        contents,
        uploaded_files,
    )


async def _generate_gemini_response(
    *,
    prompt: str,
    text: str | None = None,
    file_paths: list[str] | None = None,
):

    settings = get_settings()

    if not settings.gemini_api_key:

        return (
            None,
            0.0,
            "no_api_key",
            "",
            "",
        )

    try:
        from google import genai

    except Exception as e:

        return (
            None,
            0.0,
            "import_error",
            f"{type(e).__name__}: {e}",
            "",
        )

    (
        contents,
        uploaded_files,
    ) = _build_contents(
        prompt=prompt,
        text=text,
        file_paths=file_paths,
    )

    client = genai.Client(
        api_key=settings.gemini_api_key,
    )

    t0 = perf_counter()
    
    # Get list of model candidates: primary + backups
    model_candidates = _get_model_candidates()
    
    response = None
    last_error = ""
    model_name = ""
    
    # =====================================================
    # TRY EACH MODEL CANDIDATE
    # =====================================================
    
    for candidate_model in model_candidates:
        
        model_name = candidate_model
        last_error = ""
        
        # =================================================
        # RETRY LOGIC FOR CURRENT MODEL
        # =================================================
        
        for attempt in range(
            1,
            _GEMINI_MAX_RETRIES + 1,
        ):

            try:

                response = await asyncio.to_thread(
                    client.models.generate_content,
                    model=model_name,
                    contents=contents,
                )

                # =========================================
                # CLEANUP GEMINI FILES (success case)
                # =========================================

                for uploaded_file in uploaded_files:

                    try:

                        client.files.delete(
                            name=uploaded_file.name
                        )

                    except Exception:
                        pass

                # Successfully got response, break out of both loops
                break

            except Exception as e:

                last_error = (
                    f"{type(e).__name__}: {e}"
                )

                is_transient = _is_transient_gemini_error(
                    last_error
                )

                # =========================================
                # TRANSIENT ERROR: RETRY SAME MODEL
                # =========================================
                
                if attempt < _GEMINI_MAX_RETRIES and is_transient:
                    
                    await asyncio.sleep(
                        0.8 * attempt
                    )
                    continue

                # =========================================
                # PERMANENT ERROR OR MAX RETRIES REACHED
                # =========================================
                # Try next model candidate
                break
        
        # If we got a successful response, exit the model loop
        if response is not None:
            break

    # =====================================================
    # CLEANUP AND RETURN
    # =====================================================
    
    if response is None:

        gemini_ms_err = (
            perf_counter() - t0
        ) * 1000.0

        return (
            None,
            gemini_ms_err,
            "api_error",
            last_error,
            model_name,
        )

    gemini_ms = (
        perf_counter() - t0
    ) * 1000.0

    raw_text = (
        getattr(response, "text", "")
        or ""
    )

    blob = _extract_json_blob(
        raw_text
    )

    if not blob:

        return (
            None,
            gemini_ms,
            "no_json_blob",
            raw_text,
            model_name,
        )

    try:

        parsed = json.loads(blob)

    except Exception as e:

        return (
            None,
            gemini_ms,
            "json_parse_error",
            f"{type(e).__name__}: {e}",
            model_name,
        )

    return (
        parsed,
        gemini_ms,
        "ok",
        "",
        model_name,
    )


# =========================================================
# CALENDAR EXTRACTION
# =========================================================

async def extract_full_academic_calendar_with_gemini(
    *,
    file_paths: list[str] | None = None,
    text: str | None = None,
):

    prompt = """
      You are given an academic calendar.

      Return STRICT JSON ONLY.

      Schema:
      {
        "session_name": null,
        "session_start": "YYYY-MM-DD"|null,
        "session_end": "YYYY-MM-DD"|null,
        "events": [
          {
            "title": string,
            "start_date": "YYYY-MM-DD",
            "end_date": "YYYY-MM-DD"
          }
        ]
      }

      Rules:
      - Extract:
        - holidays
        - festivals
        - replacement leave
        - important academic events

      - Exclude:
        - teaching weeks
        - orientation
        - revision weeks
        - semester breaks
        - exam blocks

      - Many academic calendars may contain:
        - English version
        - Malay/Bahasa Melayu version

      - If the same event appears in both English and Malay:
        - prefer the English version
        - do NOT include duplicate bilingual entries
        - keep only ONE version of the same event

      - If ONLY Malay/Bahasa Melayu content is available:
        - keep the Malay event titles as-is
        - do NOT force translation to English

      - Use your judgment to detect duplicated bilingual entries.

      - Prefer:
        - English titles when available
        - cleaner wording
        - normalized event naming

      - Do not generate duplicate events.

      - Return ONLY valid JSON.
    """

    (
        parsed,
        gemini_ms,
        status,
        error_message,
        model_name,
    ) = await _generate_gemini_response(
        prompt=prompt,
        text=text,
        file_paths=file_paths,
    )

    if parsed is None:

        return (
            None,
            gemini_ms,
            status,
            error_message,
            model_name,
        )

    try:

        payload = (
            GeminiFullCalendarPayload
            .model_validate(parsed)
        )

    except Exception as e:

        return (
            None,
            gemini_ms,
            "validation_error",
            f"{type(e).__name__}: {e}",
            model_name,
        )

    return (
        payload,
        gemini_ms,
        "ok",
        "",
        model_name,
    )


# =========================================================
# TASK EXTRACTION
# =========================================================

async def extract_task_with_gemini(
    *,
    file_paths: list[str] | None = None,
    text: str | None = None,
    current_datetime: str | None = None,
):

    prompt = """
Extract assignment/task information.

Return STRICT JSON ONLY.

Schema:
{
  "tasks":[
    {
      "title":"string",
      "description":"string|null",
      "due_datetime":"YYYY-MM-DDTHH:MM:SS|null",
      "course_code":"string|null",
      "course_code_candidates":["string"],
      "subtasks":[
        {
          "title":"string",
          "due_datetime":"YYYY-MM-DDTHH:MM:SS|null",
          "is_completed":false
        }
      ]
    }
  ]
}

Rules:
- Extract assignments
- projects
- quizzes
- exams
- submissions
- reports
- deadlines

- For phased project schedules, prefer ONE parent task for the whole project timeline
- Parent task due_datetime should be the latest due date across all phase/milestone subtasks
- For a task with checklist/components, keep one parent task and put child items in subtasks[].
- Resolve ALL relative dates/times using the provided current datetime.
        - Examples of relative dates:
          * next Friday
          * tomorrow
          * next week
          * Monday
- Keep title concise and meaningful
- Return ONLY valid JSON.
"""

    if current_datetime:

        prompt += f"""

Current datetime:
{current_datetime}
"""

    (
        parsed,
        gemini_ms,
        status,
        error_message,
        model_name,
    ) = await _generate_gemini_response(
        prompt=prompt,
        text=text,
        file_paths=file_paths,
    )

    if parsed is None:

        return (
            [],
            gemini_ms,
            status,
            error_message,
            model_name,
        )

    try:

        payload = (
            GeminiTaskPayload
            .model_validate(parsed)
        )

    except Exception as e:

        return (
            [],
            gemini_ms,
            "validation_error",
            f"{type(e).__name__}: {e}",
            model_name,
        )

    out = []

    for item in payload.tasks:

        subtasks = [
            TaskSubtaskExtract(
                title=s.title,
                due_datetime=s.due_datetime,
                is_completed=s.is_completed,
            )
            for s in item.subtasks
        ]

        out.append(
            TaskExtract(
                title=item.title.strip(),
                description=item.description,
                due_datetime=item.due_datetime,
                course_code=(
                    item.course_code or ""
                ).upper(),
                course_code_candidates=[
                    x.upper()
                    for x in item.course_code_candidates
                ],
                course_id=None,
                subtasks=subtasks,
            )
        )

    return (
        out,
        gemini_ms,
        "ok",
        "",
        model_name,
    )


# =========================================================
# TIMETABLE EXTRACTION
# =========================================================

def _normalize_course_code(raw: str) -> str:
    """Match timetable filtering in pipeline._apply_timetable_rules."""
    return re.sub(r"\s+", "", (raw or "").strip().upper())


def _filter_timetable_slots_by_course_whitelist(
    slots: list[ClassSlotExtract],
    course_codes_allowed: list[str] | None,
) -> list[ClassSlotExtract]:
    if not course_codes_allowed:
        return slots
    allowed = {
        _normalize_course_code(c)
        for c in course_codes_allowed
        if c and str(c).strip()
    }
    if not allowed:
        return slots
    return [s for s in slots if _normalize_course_code(s.course_code) in allowed]


async def extract_timetable_with_gemini(
    *,
    file_paths: list[str] | None = None,
    text: str | None = None,
    ai_notes: str | None = None,
    course_codes_allowed: list[str] | None = None,
):

    notes = ""

    if ai_notes and ai_notes.strip():

        notes = f"""

IMPORTANT USER NOTES:
{ai_notes}
- If remarks specify a particular group/section, return only slots that match that group/section.
- If uncertain whether a row matches the remarks, skip that row.
"""

    whitelist_lines = ""
    codes_in = [c for c in (course_codes_allowed or []) if c and str(c).strip()]
    if codes_in:
        shown = ", ".join(sorted({_normalize_course_code(c) for c in codes_in}))
        whitelist_lines = f"""
CRITICAL — COURSE CODE WHITELIST:
- ONLY output slots whose course_code matches one of these codes (ignore spaces and letter case when comparing): {shown}
- Do NOT include slots for any course that is not in this list.
"""

    prompt = f"""
Extract timetable slots.

Return STRICT JSON ONLY.

Schema:
{{
  "slots":[
    {{
      "course_code":"string",
      "day":"Monday",
      "start_minutes":0,
      "end_minutes":0,
      "mode":"online|physical|",
      "venue":"string|null",
      "class_type":"lecture|tutorial|lab"
    }}
  ]
}}

TIME GRID REASONING RULES:

The timetable columns represent fixed time ranges.

Example column mapping:
- Column 1 = 08:00–08:50
- Column 2 = 09:00–09:50
- Column 3 = 10:00–10:50
- Column 4 = 11:00–11:50
- etc.

If a timetable cell visually spans across multiple adjacent columns:
- the class duration includes ALL covered columns.

Examples:
- spanning columns 1–2
  => 08:00–09:50

- spanning columns 2–4
  => 09:00–11:50

- spanning columns 3–5
  => 10:00–12:50

IMPORTANT:
- Determine duration using the visual table span, NOT only nearest text alignment.
- Use the timetable header row as the source of truth for start/end time.
- The "day" field MUST ALWAYS be in English (e.g., Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday). If the original day is in another language, translate it to English.
{whitelist_lines}
{notes}
"""

    (
        parsed,
        gemini_ms,
        status,
        error_message,
        model_name,
    ) = await _generate_gemini_response(
        prompt=prompt,
        text=text,
        file_paths=file_paths,
    )

    if parsed is None:

        return (
            [],
            gemini_ms,
            status,
            error_message,
            model_name,
        )

    try:

        payload = (
            GeminiTimetablePayload
            .model_validate(parsed)
        )

    except Exception as e:

        return (
            [],
            gemini_ms,
            "validation_error",
            f"{type(e).__name__}: {e}",
            model_name,
        )

    out = []

    for item in payload.slots:

        out.append(
            ClassSlotExtract(
                course_code=item.course_code,
                day=item.day,
                start_minutes=item.start_minutes,
                end_minutes=item.end_minutes,
                mode=item.mode or "",
                venue=item.venue,
                class_type=(
                    item.class_type
                    or "lecture"
                ),
            )
        )

    out = _filter_timetable_slots_by_course_whitelist(out, course_codes_allowed)

    return (
        out,
        gemini_ms,
        "ok",
        "",
        model_name,
    )


# =========================================================
# EVENT EXTRACTION
# =========================================================

async def extract_event_with_gemini(
    *,
    file_paths: list[str] | None = None,
    text: str | None = None,
    current_datetime: str | None = None,
):

    prompt = """
Extract event information.

Return STRICT JSON ONLY.

Schema:
{
  "events":[
    {
      "title":"string",
      "location":"string|null",
      "start_datetime":"YYYY-MM-DDTHH:MM:SS",
      "end_datetime":"YYYY-MM-DDTHH:MM:SS",
      "all_day":false,
      "hide_classes_during_event":true
    }
  ]
}

Rules:
- Extract meetings
- workshops
- seminars
- appointments
- celebrations
- hackathons
- competitions
- student events
- start_datetime and end_datetime MUST NEVER be null.
- If exact time is unknown but a date is known:
          assume an all-day event.

        - If only date exists:
          set all_day=true.
- If only start time exists:
          infer a reasonable end time.
- Convert titles into proper letter casing.
- Extract events even if they are written casually, briefly, or without punctuation.

- Return ONLY valid JSON.
"""

    if current_datetime:

        prompt += f"""

Current datetime:
{current_datetime}
"""

    (
        parsed,
        gemini_ms,
        status,
        error_message,
        model_name,
    ) = await _generate_gemini_response(
        prompt=prompt,
        text=text,
        file_paths=file_paths,
    )

    if parsed is None:

        return (
            [],
            gemini_ms,
            status,
            error_message,
            model_name,
        )

    try:

        payload = (
            GeminiEventPayload
            .model_validate(parsed)
        )

    except Exception as e:

        return (
            [],
            gemini_ms,
            "validation_error",
            f"{type(e).__name__}: {e}",
            model_name,
        )

    out = [
        EventExtract(
            title=e.title,
            location=e.location,
            start_datetime=e.start_datetime,
            end_datetime=e.end_datetime,
            all_day=e.all_day,
        )
        for e in payload.events
    ]

    return (
        out,
        gemini_ms,
        "ok",
        "",
        model_name,
    )