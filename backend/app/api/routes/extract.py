import asyncio
import logging
import tempfile
import time
from datetime import datetime, timezone
from typing import Any
from uuid import uuid4
from pydantic import BaseModel
import os

from fastapi import APIRouter, File, Form, HTTPException, UploadFile

from app.core.config import get_settings
from app.schemas.extraction import AcademicExtractionEnvelope, ExtractionEnvelope
from app.services.extraction import (
    RawDocument,
    run_academic_calendar_pipeline,
    run_task_pipeline,
    run_timetable_pipeline,
)

from app.services.extraction.gemini_service import (
    extract_full_academic_calendar_with_gemini,
    extract_task_with_gemini,
    extract_timetable_with_gemini,
    extract_event_with_gemini,
)

router = APIRouter()
logger = logging.getLogger("uvicorn.error")

_extraction_jobs: dict[str, dict[str, Any]] = {}

class TextExtractionRequest(BaseModel):
    text: str
    current_datetime: str | None = None
    session_name: str | None = None
    term_id: str | None = None
    term_start_date: str | None = None
    term_end_date: str | None = None

def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _parse_course_codes_csv(csv_value: str | None) -> list[str]:
    if not csv_value:
        return []
    out: list[str] = []
    for token in csv_value.split(","):
        normalized = token.strip().upper().replace(" ", "")
        if normalized and normalized not in out:
            out.append(normalized)
    return out


async def _run_job(
    job_id: str,
    kind: str,
    docs: list[RawDocument],
    *,
    course_codes_allowed: list[str] | None = None,
    ai_notes: str | None = None,
) -> None:

    job = _extraction_jobs.get(job_id)

    if job is None:
        return

    job["status"] = "running"

    job["updated_at"] = _utc_now_iso()

    logger.info(
        "[extract] job started: job_id=%s kind=%s file_count=%s",
        job_id,
        kind,
        len(docs),
    )

    started_perf = time.perf_counter()

    timeout_seconds = max(
        30,
        int(
            get_settings()
            .extraction_job_timeout_seconds
        ),
    )

    try:

        # =====================================================
        # SAVE TEMP FILES
        # =====================================================

        temp_paths = (
            await _save_raw_docs_temp(
                docs
            )
        )

        uploads_exist = (
            len(docs) > 0
        )

        try:

            # =================================================
            # CALENDAR
            # =================================================

            if kind == "academic-calendar":

                (
                    payload,
                    gemini_ms,
                    status,
                    error_message,
                    model_name,
                ) = await asyncio.wait_for(
                    extract_full_academic_calendar_with_gemini(
                        file_paths=temp_paths,
                    ),
                    timeout=timeout_seconds,
                )

                extraction_result = {

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

                        "events": [

                            {
                                "title":
                                    e.title,

                                "start_date":
                                    e.start_date
                                    .isoformat(),

                                "end_date":
                                    e.end_date
                                    .isoformat(),
                            }

                            for e
                            in (
                                payload.events
                                if payload
                                else []
                            )
                        ],
                    },

                    "assignment":
                        None,

                    "tasks":
                        [],

                    "timetable":
                        None,

                    "notes":
                        "source=file_upload",
                }

            # =================================================
            # TIMETABLE
            # =================================================

            elif kind == "timetable":

                (
                    slots,
                    gemini_ms,
                    status,
                    error_message,
                    model_name,
                ) = await asyncio.wait_for(
                    extract_timetable_with_gemini(
                        file_paths=temp_paths,
                        ai_notes=ai_notes,
                        course_codes_allowed=course_codes_allowed,
                    ),
                    timeout=timeout_seconds,
                )

                extraction_result = {

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

                            for slot
                            in slots
                        ]
                    },

                    "notes":
                        "source=file_upload",
                }

            # =================================================
            # TASK
            # =================================================

            elif kind == "task":

                (
                    tasks,
                    gemini_ms,
                    status,
                    error_message,
                    model_name,
                ) = await asyncio.wait_for(
                    extract_task_with_gemini(
                        file_paths=temp_paths,
                    ),
                    timeout=timeout_seconds,
                )

                extraction_result = {

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
                                t.title,

                            "description":
                                t.description,

                            "due_datetime":
                                (
                                    t.due_datetime
                                    .isoformat()
                                    if t.due_datetime
                                    else None
                                ),

                            "course_code":
                                t.course_code,

                            "course_code_candidates":
                                t.course_code_candidates,

                            "course_id":
                                t.course_id,

                            "subtasks": [

                                {
                                    "title":
                                        s.title,

                                    "due_datetime":
                                        (
                                            s.due_datetime
                                            .isoformat()
                                            if s.due_datetime
                                            else None
                                        ),

                                    "is_completed":
                                        s.is_completed,
                                }

                                for s
                                in t.subtasks
                            ],
                        }

                        for t
                        in tasks
                    ],

                    "timetable":
                        None,

                    "notes":
                        "source=file_upload",
                }

            else:

                raise ValueError(
                    f"Unsupported extraction kind: {kind}"
                )

        finally:

            _cleanup_temp_paths(
                temp_paths
            )

        # =====================================================
        # ORIGINAL STRUCTURE
        # =====================================================

        job["status"] = (
            "success"
            if status == "ok"
            else "failed"
        )

        job["result"] = {

            "document_kind":
                kind,

            "source_filename":
                (
                    docs[0].filename
                    if docs
                    else "uploaded_file"
                ),

            "markdown_from_docling":
                "",

            "sliced_text_for_gemini":
                "",

            "remark_text_for_gemini":
                ai_notes or "",

            "extraction":
                extraction_result,

            "warnings":
                (
                    []
                    if status == "ok"
                    else [error_message]
                ),

            "timing_ms": {

                "gemini":
                    gemini_ms,
            },
        }

        job["updated_at"] = _utc_now_iso()

        job["duration_ms"] = int(
            (
                time.perf_counter()
                - started_perf
            ) * 1000.0
        )

        logger.info(
            "[extract] job success: job_id=%s kind=%s duration_ms=%s",
            job_id,
            kind,
            job["duration_ms"],
        )

    except TimeoutError:

        job["status"] = "failed"

        job["error"] = (
            "Extraction timed out while parsing document. "
            "Try a smaller file / fewer pages or clearer screenshots."
        )

        job["updated_at"] = _utc_now_iso()

        job["duration_ms"] = int(
            (
                time.perf_counter()
                - started_perf
            ) * 1000.0
        )

        logger.exception(
            "[extract] job timed out: job_id=%s kind=%s timeout_seconds=%s duration_ms=%s",
            job_id,
            kind,
            timeout_seconds,
            job["duration_ms"],
        )

    except Exception as exc:

        job["status"] = "failed"

        job["error"] = (
            f"{type(exc).__name__}: {exc}"
        )

        job["updated_at"] = _utc_now_iso()

        job["duration_ms"] = int(
            (
                time.perf_counter()
                - started_perf
            ) * 1000.0
        )

        logger.exception(
            "[extract] job failed: job_id=%s kind=%s error=%s duration_ms=%s",
            job_id,
            kind,
            job["error"],
            job["duration_ms"],
        )

async def _read_upload(file: UploadFile) -> RawDocument:
    settings = get_settings()
    data = await file.read()
    if len(data) > settings.max_upload_bytes:
        logger.warning(
            "Upload rejected: filename=%s size=%s max=%s",
            file.filename,
            len(data),
            settings.max_upload_bytes,
        )
        raise HTTPException(
            status_code=413,
            detail=f"File exceeds max size of {settings.max_upload_bytes} bytes",
        )
    if not data:
        logger.warning("Upload rejected: empty file filename=%s", file.filename)
        raise HTTPException(status_code=400, detail="Empty file")

    return RawDocument(
        filename=file.filename or "upload",
        content_type=file.content_type,
        data=data,
    )


async def _read_uploads(
    file: UploadFile | None,
    files: list[UploadFile] | None,
) -> list[RawDocument]:
    upload_list: list[UploadFile] = []
    if file is not None:
        upload_list.append(file)
    if files:
        upload_list.extend(files)
    if not upload_list:
        raise HTTPException(status_code=400, detail="No file uploaded")
    return [await _read_upload(f) for f in upload_list]

async def _save_raw_docs_temp(
    docs: list[RawDocument],
) -> list[str]:

    paths = []

    for doc in docs:

        suffix = os.path.splitext(
            doc.filename
        )[1]

        with tempfile.NamedTemporaryFile(
            delete=False,
            suffix=suffix,
        ) as tmp:

            tmp.write(doc.data)

            paths.append(
                tmp.name
            )

    return paths

def _cleanup_temp_paths(
    paths: list[str],
):

    for path in paths:

        try:

            if os.path.exists(path):
                os.remove(path)

        except Exception:
            pass

@router.post("/extract/academic-calendar", response_model=AcademicExtractionEnvelope)
async def extract_academic_calendar(
    file: UploadFile | None = File(
        None,
        description="Single PDF/DOCX/image upload (backward compatible).",
    ),
    files: list[UploadFile] | None = File(
        None,
        description="Multiple screenshots/images/PDFs in order.",
    ),
) -> AcademicExtractionEnvelope:
    docs = await _read_uploads(file, files)
    try:
        return await run_academic_calendar_pipeline(docs)
    except Exception:
        logger.exception(
            "Academic calendar extraction failed: file_count=%s",
            len(docs),
        )
        raise


@router.post("/extract/timetable", response_model=ExtractionEnvelope)
async def extract_timetable(
    file: UploadFile = File(..., description="PDF, DOCX, or image (per Docling support)"),
    course_codes_allowed: str | None = Form(
        None,
        description="Optional CSV whitelist of allowed course codes, e.g. CSC101,MTH120.",
    ),
    ai_notes: str | None = Form(
        None,
        description="Optional extraction notes (e.g. group filters such as 'group B1 only').",
    ),
) -> ExtractionEnvelope:
    doc = await _read_upload(file)
    try:
        return await run_timetable_pipeline(
            doc,
            course_codes_allowed=_parse_course_codes_csv(course_codes_allowed),
            ai_notes=ai_notes,
        )
    except Exception:
        logger.exception(
            "Timetable extraction failed: filename=%s ai_notes_present=%s",
            doc.filename,
            bool(ai_notes and ai_notes.strip()),
        )
        raise


@router.post("/extract/task", response_model=ExtractionEnvelope)
async def extract_task(
    file: UploadFile | None = File(
        None,
        description="Single PDF/DOCX/image upload (backward compatible).",
    ),
    files: list[UploadFile] | None = File(
        None,
        description="Multiple screenshots/images/PDFs in order.",
    ),
) -> ExtractionEnvelope:
    docs = await _read_uploads(file, files)
    try:
        return await run_task_pipeline(docs)
    except Exception:
        logger.exception("Task extraction failed: file_count=%s", len(docs))
        raise


@router.post("/extract/submit/{kind}")
async def submit_extraction_job(
    kind: str,
    file: UploadFile | None = File(
        None,
        description="Single PDF/DOCX/image upload (backward compatible).",
    ),
    files: list[UploadFile] | None = File(
        None,
        description="Multiple screenshots/images/PDFs in order.",
    ),
    course_codes_allowed: str | None = Form(
        None,
        description="Optional CSV whitelist of allowed course codes for timetable extraction.",
    ),
    ai_notes: str | None = Form(
        None,
        description="Optional extraction notes for timetable extraction.",
    ),
) -> dict[str, Any]:
    normalized_kind = kind.strip().lower()
    if normalized_kind not in {"academic-calendar", "timetable", "task"}:
        raise HTTPException(status_code=400, detail="Unsupported extraction kind")

    docs = await _read_uploads(file, files)
    if normalized_kind == "timetable" and len(docs) != 1:
        raise HTTPException(
            status_code=400,
            detail=f"{normalized_kind} extraction expects exactly one file",
        )

    job_id = uuid4().hex
    _extraction_jobs[job_id] = {
        "job_id": job_id,
        "kind": normalized_kind,
        "status": "queued",
        "created_at": _utc_now_iso(),
        "updated_at": _utc_now_iso(),
        "duration_ms": None,
        "result": None,
        "error": None,
    }
    parsed_codes = _parse_course_codes_csv(course_codes_allowed)
    logger.info(
        "[extract] job queued: job_id=%s kind=%s file_count=%s",
        job_id,
        normalized_kind,
        len(docs),
    )
    asyncio.create_task(
        _run_job(
            job_id,
            normalized_kind,
            docs,
            course_codes_allowed=parsed_codes,
            ai_notes=ai_notes,
        )
    )
    return {"job_id": job_id, "status": "queued"}


@router.get("/extract/job/{job_id}")
async def get_extraction_job(job_id: str) -> dict[str, Any]:
    job = _extraction_jobs.get(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="Job not found")
    return job

@router.post('/extract/task-text')
async def extract_task_text(
    request: TextExtractionRequest,
):
    tasks, _, _, _, _ = (
        await extract_task_with_gemini(
            request.text,
            current_datetime=request.current_datetime,
        )
    )

    if not tasks:
        return {}

    return {
        "document_kind": "assignment",

        "source_filename": "text_input",

        "markdown_from_docling": request.text,

        "sliced_text_for_gemini": request.text,

        "remark_text_for_gemini": "",

        "extraction": {
            "kind": "assignment",

            "confidence": 0.9,

            "academic_session": None,

            "assignment": None,

            "tasks": [
                {
                    "title": task.title,

                    "description":
                        task.description,

                    "due_datetime":
                        task.due_datetime.isoformat()
                        if task.due_datetime
                        else None,

                    "course_code":
                        task.course_code,

                    "course_code_candidates": [],

                    "course_id": None,

                    "subtasks": [],
                }
                for task in tasks
            ],

            "timetable": None,

            "notes": "source=text_input",
        },

        "warnings": [],

        "timing_ms": {},
    }


@router.post('/extract/timetable-text')
async def extract_timetable_text(
    request: TextExtractionRequest,
):
    slots, _, _, _, _ = (
        await extract_timetable_with_gemini(
            request.text,
        )
    )

    return {
        "document_kind": "timetable",

        "source_filename": "text_input",

        "markdown_from_docling": request.text,

        "sliced_text_for_gemini": request.text,

        "remark_text_for_gemini": "",

        "extraction": {
            "kind": "timetable",

            "confidence": 0.9,

            "academic_session": None,

            "assignment": None,

            "tasks": [],

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

                        "course_id": None,
                    }
                    for slot in slots
                ]
            },

            "notes": "source=text_input",
        },

        "warnings": [],

        "timing_ms": {},
    }

@router.post('/extract/event-text')
async def extract_event_text(
    request: TextExtractionRequest,
):
    events, gemini_ms, status, error, model = (
        await extract_event_with_gemini(
            request.text,
            current_datetime=request.current_datetime,
        )
    )

    if status != "ok":
        return {
            "success": False,

            "error": {
                "status": status,
                "message": error,
            },

            "extraction": {
                "academic_session": {
                    "events": [],
                }
            },
        }

    return {
        "source_filename":
            "text_input",

        "markdown_from_docling":
            request.text,

        "sliced_text_for_gemini":
            request.text,

        "remark_text_for_gemini":
            "",

        "extraction": {
            "confidence": 0.9,

            "academic_session": {
                "name":
                    "Selected Session",

                "start_date":
                    None,

                "end_date":
                    None,

                "terms": [],

                "events": [
                    {
                        "title":
                            event.title,

                        "start_datetime": (
                            event.start_datetime
                            .isoformat()
                            if event.start_datetime
                            else None
                        ),

                        "end_datetime": (
                            event.end_datetime
                            .isoformat()
                            if event.end_datetime
                            else None
                        ),

                        "all_day":
                            event.all_day,

                        "location":
                            event.location,

                        "hide_classes_during_event":
                            True,

                        "is_academic_break":
                            False,
                    }
                    for event in events
                ],
            },

            "notes":
                "source=text_input",
        },

        "warnings": [],

        "timing_ms": {},
    }