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


@router.post("/extract/academic-calendar", response_model=AcademicExtractionEnvelope)
async def extract_academic_calendar(
    file: UploadFile = File(..., description="PDF, DOCX, or image (per Docling support)"),
) -> AcademicExtractionEnvelope:
    doc = await _read_upload(file)
    return await run_academic_calendar_pipeline(doc)


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
