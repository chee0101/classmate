from fastapi import APIRouter, File, HTTPException, UploadFile

from app.core.config import get_settings
from app.schemas.extraction import ExtractionEnvelope
from app.services.extraction import RawDocument, run_document_pipeline

router = APIRouter()


@router.post("/extract", response_model=ExtractionEnvelope)
async def extract_document(
    file: UploadFile = File(..., description="PDF, DOCX, or image (per Docling support)"),
) -> ExtractionEnvelope:
    """
    Upload a document; receive Docling markdown (when wired) + structured extraction stub.

    Next steps: Firebase Auth verification, session/term hints as query params, course list for resolution.
    """
    settings = get_settings()
    data = await file.read()
    if len(data) > settings.max_upload_bytes:
        raise HTTPException(
            status_code=413,
            detail=f"File exceeds max size of {settings.max_upload_bytes} bytes",
        )
    if not data:
        raise HTTPException(status_code=400, detail="Empty file")

    doc = RawDocument(
        filename=file.filename or "upload",
        content_type=file.content_type,
        data=data,
    )
    return await run_document_pipeline(doc)
