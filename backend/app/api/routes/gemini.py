# app/api/routes/gemini.py

from __future__ import annotations

import os
import tempfile

from fastapi import (
    APIRouter,
    File,
    Form,
    HTTPException,
    UploadFile,
)

from app.services.extraction.gemini_service import (
    extract_event_with_gemini,
    extract_full_academic_calendar_with_gemini,
    extract_task_with_gemini,
    extract_timetable_with_gemini,
)

router = APIRouter()


# =========================================================
# HELPERS
# =========================================================

async def _save_upload_file(
    file: UploadFile,
) -> str:

    suffix = os.path.splitext(
        file.filename or ""
    )[1]

    with tempfile.NamedTemporaryFile(
        delete=False,
        suffix=suffix,
    ) as tmp:

        content = await file.read()

        tmp.write(content)

        return tmp.name
    
async def _save_upload_files(
    uploads: list[UploadFile],
) -> list[str]:

    paths = []

    for upload in uploads:

        path = await _save_upload_file(
            upload
        )

        paths.append(path)

    return paths

def _cleanup_temp_files(
    file_paths: list[str],
):

    for path in file_paths:

        if (
            path
            and os.path.exists(path)
        ):
            os.remove(path)


def _parse_course_codes_csv(csv_value: str | None) -> list[str]:
    """Same rules as extract routes: CSV, strip, uppercase, collapse spaces."""
    if not csv_value:
        return []
    out: list[str] = []
    for token in csv_value.split(","):
        normalized = token.strip().upper().replace(" ", "")
        if normalized and normalized not in out:
            out.append(normalized)
    return out


# =========================================================
# CALENDAR EXTRACTION
# =========================================================

@router.post(
    "/gemini/calendar"
)
async def extract_calendar_route(
    file: UploadFile | None = File(default=None),
    files: list[UploadFile] | None = File(default=None),
    text: str | None = Form(default=None),
):

    if (
        not file
        and not files
        and not text
    ):

        raise HTTPException(
            status_code=400,
            detail=(
                "Either file/files or text "
                "must be provided."
            ),
        )

    file_paths: list[str] = []

    uploads: list[
        UploadFile
    ] = []

    try:

        # =============================================
        # SINGLE FILE
        # =============================================

        if file:
            uploads.append(file)

        # =============================================
        # MULTIPLE FILES
        # =============================================

        if files:
            uploads.extend(files)

        # =============================================
        # SAVE TEMP FILES
        # =============================================

        if uploads:

            file_paths = (
                await _save_upload_files(
                    uploads
                )
            )

        (
            payload,
            gemini_ms,
            status,
            error_message,
            model_name,
        ) = await (
            extract_full_academic_calendar_with_gemini(
                file_paths=file_paths,
                text=text,
            )
        )

        # =============================================
        # SOURCE INFO
        # =============================================

        if uploads:

            source_filename = (
                uploads[0].filename
                or "uploaded_file"
            )

        else:

            source_filename = (
                "text_input"
            )

        # =============================================
        # RAW SOURCE TEXT
        # =============================================

        raw_source_text = (
            text or ""
        )

        # =============================================
        # CALENDAR EVENTS
        # =============================================

        calendar_events = []

        if payload:

            calendar_events = [

                {
                    "title":
                        event.title,

                    "start_date":
                        event.start_date
                        .isoformat(),

                    "end_date":
                        event.end_date
                        .isoformat(),
                }

                for event
                in payload.events
            ]

        return {

            "document_kind":
                "calendar",

            "source_filename":
                source_filename,

            "markdown_from_docling":
                raw_source_text,

            "sliced_text_for_gemini":
                raw_source_text,

            "remark_text_for_gemini":
                "",

            "extraction": {

                "kind":
                    "calendar",

                "confidence":
                    0.9,

                "academic_session": {

                    "session_name":
                        (
                            payload
                            .session_name
                            if payload
                            else None
                        ),

                    "session_start":
                        (
                            payload
                            .session_start
                            .isoformat()
                            if (
                                payload
                                and payload
                                .session_start
                            )
                            else None
                        ),

                    "session_end":
                        (
                            payload
                            .session_end
                            .isoformat()
                            if (
                                payload
                                and payload
                                .session_end
                            )
                            else None
                        ),

                    "events":
                        calendar_events,
                },

                "assignment":
                    None,

                "tasks":
                    [],

                "timetable":
                    None,

                "notes":
                    (
                        "source=text_input"
                        if text
                        else "source=file_upload"
                    ),
            },

            "warnings": (
                []
                if status == "ok"
                else [error_message]
            ),

            "timing_ms": {

                "gemini":
                    gemini_ms,
            },

            "status":
                status,

            "model_used":
                model_name,
        }

    finally:

        _cleanup_temp_files(
            file_paths
        )


@router.post(
    "/gemini/academic-calendar",
)
async def extract_academic_calendar_alias(
    file: UploadFile | None = File(default=None),
    files: list[UploadFile] | None = File(default=None),
    text: str | None = Form(default=None),
):
    """Backward-compatible path name (same behavior as POST /gemini/calendar)."""
    return await extract_calendar_route(
        file=file,
        files=files,
        text=text,
    )


# =========================================================
# TASK EXTRACTION
# =========================================================

@router.post(
    "/gemini/task"
)
async def extract_task_route(
    file: UploadFile | None = File(default=None),
    files: list[UploadFile] | None = File(default=None),
    text: str | None = Form(default=None),
    current_datetime: str | None = Form(default=None),
):

    if (
        not file
        and not files
        and not text
    ):

        raise HTTPException(
            status_code=400,
            detail=(
                "Either file/files or text "
                "must be provided."
            ),
        )

    file_paths: list[str] = []

    uploads: list[
        UploadFile
    ] = []

    try:

        # =============================================
        # SINGLE FILE
        # =============================================

        if file:
            uploads.append(file)

        # =============================================
        # MULTIPLE FILES
        # =============================================

        if files:
            uploads.extend(files)

        # =============================================
        # SAVE TEMP FILES
        # =============================================

        if uploads:

            file_paths = (
                await _save_upload_files(
                    uploads
                )
            )

        (
            tasks,
            gemini_ms,
            status,
            error_message,
            model_name,
        ) = await (
            extract_task_with_gemini(
                file_paths=file_paths,
                text=text,
                current_datetime=current_datetime,
            )
        )

        # =============================================
        # SOURCE INFO
        # =============================================

        if uploads:

            source_filename = (
                uploads[0].filename
                or "uploaded_file"
            )

        else:

            source_filename = (
                "text_input"
            )

        # =============================================
        # RAW SOURCE TEXT
        # =============================================

        raw_source_text = (
            text or ""
        )

        return {

            "document_kind":
                "task",

            "source_filename":
                source_filename,

            "markdown_from_docling":
                raw_source_text,

            "sliced_text_for_gemini":
                raw_source_text,

            "remark_text_for_gemini":
                "",

            "extraction": {

                "kind":
                    "task",

                "confidence":
                    0.9,

                "academic_session":
                    None,

                "assignment":
                    None,

                "tasks": [

                    {
                        "title":
                            task.title,

                        "description":
                            task.description,

                        "due_datetime":
                            (
                                task.due_datetime
                                .isoformat()
                                if task.due_datetime
                                else None
                            ),

                        "course_code":
                            task.course_code,

                        "course_code_candidates":
                            task.course_code_candidates,

                        "course_id":
                            task.course_id,

                        "subtasks": [

                            {
                                "title":
                                    sub.title,

                                "due_datetime":
                                    (
                                        sub
                                        .due_datetime
                                        .isoformat()
                                        if sub.due_datetime
                                        else None
                                    ),

                                "is_completed":
                                    sub.is_completed,
                            }

                            for sub
                            in task.subtasks
                        ],
                    }

                    for task in tasks
                ],

                "timetable":
                    None,

                "notes":
                    (
                        "source=text_input"
                        if text
                        else "source=file_upload"
                    ),
            },

            "warnings": (
                []
                if status == "ok"
                else [error_message]
            ),

            "timing_ms": {

                "gemini":
                    gemini_ms,
            },

            "status":
                status,

            "model_used":
                model_name,
        }

    finally:

        _cleanup_temp_files(
            file_paths
        )


# =========================================================
# TIMETABLE EXTRACTION
# =========================================================

@router.post(
    "/gemini/timetable"
)
async def extract_timetable_route(
    file: UploadFile | None = File(default=None),
    files: list[UploadFile] | None = File(default=None),
    text: str | None = Form(default=None),
    ai_notes: str | None = Form(default=None),
    course_codes_allowed: str | None = Form(
        default=None,
        description="Optional CSV of course codes to keep (e.g. CSC101,MTH120).",
    ),
):

    if (
        not file
        and not files
        and not text
    ):

        raise HTTPException(
            status_code=400,
            detail=(
                "Either file/files or text "
                "must be provided."
            ),
        )

    parsed_codes = _parse_course_codes_csv(course_codes_allowed)

    file_paths: list[str] = []

    uploads: list[
        UploadFile
    ] = []

    try:

        # =============================================
        # SINGLE FILE
        # =============================================

        if file:
            uploads.append(file)

        # =============================================
        # MULTIPLE FILES
        # =============================================

        if files:
            uploads.extend(files)

        # =============================================
        # SAVE TEMP FILES
        # =============================================

        if uploads:

            file_paths = (
                await _save_upload_files(
                    uploads
                )
            )

        (
            slots,
            gemini_ms,
            status,
            error_message,
            model_name,
        ) = await (
            extract_timetable_with_gemini(
                file_paths=file_paths,
                text=text,
                ai_notes=ai_notes,
                course_codes_allowed=parsed_codes or None,
            )
        )

        # =============================================
        # SOURCE INFO
        # =============================================

        if uploads:

            source_filename = (
                uploads[0].filename
                or "uploaded_file"
            )

        else:

            source_filename = (
                "text_input"
            )

        # =============================================
        # RAW SOURCE TEXT
        # =============================================

        raw_source_text = (
            text or ""
        )

        return {

            "document_kind":
                "timetable",

            "source_filename":
                source_filename,

            "markdown_from_docling":
                raw_source_text,

            "sliced_text_for_gemini":
                raw_source_text,

            "remark_text_for_gemini":
                ai_notes or "",

            "extraction": {

                "kind":
                    "timetable",

                "confidence":
                    0.9,

                "academic_session":
                    None,

                "assignment":
                    None,

                "tasks":
                    [],

                "timetable": {

                    "slots": [

                        {
                            "course_code":
                                slot.course_code,

                            "day":
                                slot.day,

                            "start_minutes":
                                slot.start_minutes,

                            "end_minutes":
                                slot.end_minutes,

                            "mode":
                                slot.mode,

                            "venue":
                                slot.venue,

                            "class_type":
                                slot.class_type,

                            "course_id":
                                None,
                        }

                        for slot in slots
                    ]
                },

                "notes":
                    (
                        "source=text_input"
                        if text
                        else "source=file_upload"
                    ),
            },

            "warnings": (
                []
                if status == "ok"
                else [error_message]
            ),

            "timing_ms": {

                "gemini":
                    gemini_ms,
            },

            "status":
                status,

            "model_used":
                model_name,
        }

    finally:

        _cleanup_temp_files(
            file_paths
        )


# =========================================================
# EVENT EXTRACTION
# =========================================================

@router.post(
    "/gemini/event"
)
async def extract_event_route(
    text: str = Form(...),
    current_datetime: str | None = Form(default=None),
):

    (
        events,
        gemini_ms,
        status,
        error_message,
        model_name,
    ) = await (
        extract_event_with_gemini(
            text=text,
            current_datetime=current_datetime,
        )
    )

    return {

        "document_kind":
            "event",

        "source_filename":
            "text_input",

        "markdown_from_docling":
            text,

        "sliced_text_for_gemini":
            text,

        "remark_text_for_gemini":
            "",

        "extraction": {

            "kind":
                "event",

            "confidence":
                0.9,

            "academic_session":
                None,

            "assignment":
                None,

            "tasks":
                [],

            "timetable":
                None,

            "events": [

                {
                    "title":
                        event.title,

                    "location":
                        event.location,

                    "start_datetime":
                        (
                            event
                            .start_datetime
                            .isoformat()
                            if event
                            .start_datetime
                            else None
                        ),

                    "end_datetime":
                        (
                            event
                            .end_datetime
                            .isoformat()
                            if event
                            .end_datetime
                            else None
                        ),

                    "all_day":
                        event.all_day,
                }

                for event
                in events
            ],

            "notes":
                "source=text_input",
        },

        "warnings": (
            []
            if status == "ok"
            else [error_message]
        ),

        "timing_ms": {

            "gemini":
                gemini_ms,
        },

        "status":
            status,

        "model_used":
            model_name,
    }