import asyncio
from datetime import datetime, timezone
from typing import Any
from uuid import uuid4

from fastapi import APIRouter, File, HTTPException, UploadFile

from app.core.config import get_settings
from app.schemas.extraction import AcademicExtractionEnvelope, ExtractionEnvelope
from app.services.extraction import (
    RawDocument,
    run_academic_calendar_pipeline,
    run_task_pipeline,
    run_timetable_pipeline,
)

router = APIRouter()

_extraction_jobs: dict[str, dict[str, Any]] = {}


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


async def _run_job(job_id: str, kind: str, docs: list[RawDocument]) -> None:
    job = _extraction_jobs.get(job_id)
    if job is None:
        return
    job["status"] = "running"
    job["updated_at"] = _utc_now_iso()
    try:
        if kind == "academic-calendar":
            result = await run_academic_calendar_pipeline(docs)
        elif kind == "timetable":
            result = await run_timetable_pipeline(docs[0])
        elif kind == "task":
            result = await run_task_pipeline(docs[0])
        else:
            raise ValueError(f"Unsupported extraction kind: {kind}")
        job["status"] = "success"
        job["result"] = result.model_dump(mode="json")
        job["updated_at"] = _utc_now_iso()
    except Exception as exc:
        job["status"] = "failed"
        job["error"] = f"{type(exc).__name__}: {exc}"
        job["updated_at"] = _utc_now_iso()


async def _read_upload(file: UploadFile) -> RawDocument:
    settings = get_settings()
    data = await file.read()
    if len(data) > settings.max_upload_bytes:
        raise HTTPException(
            status_code=413,
            detail=f"File exceeds max size of {settings.max_upload_bytes} bytes",
        )
    if not data:
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
    return await run_academic_calendar_pipeline(docs)


@router.post("/extract/timetable", response_model=ExtractionEnvelope)
async def extract_timetable(
    file: UploadFile = File(..., description="PDF, DOCX, or image (per Docling support)"),
) -> ExtractionEnvelope:
    doc = await _read_upload(file)
    return await run_timetable_pipeline(doc)


@router.post("/extract/task", response_model=ExtractionEnvelope)
async def extract_task(
    file: UploadFile = File(..., description="PDF, DOCX, or image (per Docling support)"),
) -> ExtractionEnvelope:
    doc = await _read_upload(file)
    return await run_task_pipeline(doc)


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
) -> dict[str, Any]:
    normalized_kind = kind.strip().lower()
    if normalized_kind not in {"academic-calendar", "timetable", "task"}:
        raise HTTPException(status_code=400, detail="Unsupported extraction kind")

    docs = await _read_uploads(file, files)
    if normalized_kind in {"timetable", "task"} and len(docs) != 1:
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
        "result": None,
        "error": None,
    }
    asyncio.create_task(_run_job(job_id, normalized_kind, docs))
    return {"job_id": job_id, "status": "queued"}


@router.get("/extract/job/{job_id}")
async def get_extraction_job(job_id: str) -> dict[str, Any]:
    job = _extraction_jobs.get(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="Job not found")
    return job
