"""Docling: bytes -> markdown.

This is used by the FastAPI `/api/extract` endpoint:
upload PDF/DOCX/images as bytes -> write to a temp file -> Docling -> markdown.
"""

from __future__ import annotations

from dataclasses import dataclass
from functools import lru_cache
from mimetypes import guess_extension
from pathlib import Path
import asyncio
import io
import re
import tempfile

@dataclass(frozen=True)
class RawDocument:
    filename: str
    content_type: str | None
    data: bytes


@dataclass(frozen=True)
class DoclingOutputs:
    markdown: str


@lru_cache(maxsize=1)
def _get_converter():
    """
    Fixed PDF pipeline: embedded text (no OCR) for speed on digital PDFs;
    table structure + cell matching for calendar tables.
    For scanned PDFs, change do_ocr / OCR options here in code.
    """
    try:
        from docling.document_converter import DocumentConverter
    except Exception as e:
        raise RuntimeError(
            "Docling is not installed. Install with: pip install docling"
        ) from e

    try:
        from docling.datamodel.base_models import InputFormat
        from docling.datamodel.pipeline_options import PdfPipelineOptions
        from docling.document_converter import PdfFormatOption

        pipeline_options = PdfPipelineOptions()

        # Native text from PDF (no OCR). Set True in this file for scanned documents.
        if hasattr(pipeline_options, "do_ocr"):
            pipeline_options.do_ocr = False

        # if hasattr(pipeline_options, "do_table_structure"):
        #     pipeline_options.do_table_structure = True

        # try:
        #     pipeline_options.table_structure_options = TableStructureOptions(
        #         do_cell_matching=True
        #     )
        # except Exception:
        #     table_opts = getattr(pipeline_options, "table_structure_options", None)
        #     if table_opts and hasattr(table_opts, "do_cell_matching"):
        #         table_opts.do_cell_matching = True

        return DocumentConverter(
            format_options={
                InputFormat.PDF: PdfFormatOption(
                    pipeline_options=pipeline_options
                ),
            }
        )

    except Exception:
        return DocumentConverter()


async def document_to_outputs(doc: RawDocument) -> DoclingOutputs:
    ext = ""
    if doc.content_type:
        ext = guess_extension(doc.content_type) or ""
    if not ext:
        # Keep extension if filename had one (e.g. .pdf, .docx)
        ext = Path(doc.filename).suffix or ""
    if not ext:
        ext = ".bin"

    tmp_path: str | None = None
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=ext) as f:
            f.write(doc.data)
            tmp_path = f.name

        converter = _get_converter()
        # Docling conversion is CPU-heavy; move it off the event loop.
        result = await asyncio.to_thread(converter.convert, tmp_path)
        docling_doc = result.document
        return DoclingOutputs(
            markdown=docling_doc.export_to_markdown(),
        )
    finally:
        if tmp_path is not None:
            try:
                Path(tmp_path).unlink(missing_ok=True)
            except Exception:
                pass


async def document_to_markdown(doc: RawDocument) -> str:
    outputs = await document_to_outputs(doc)
    return outputs.markdown


def split_pdf_document(doc: RawDocument, *, pages_per_chunk: int) -> list[RawDocument]:
    """Split PDF bytes into smaller PDF chunks; return original doc on any failure."""
    filename = (doc.filename or "").lower()
    ctype = (doc.content_type or "").lower()
    is_pdf = filename.endswith(".pdf") or "pdf" in ctype
    if not is_pdf:
        return [doc]

    safe_pages_per_chunk = max(1, pages_per_chunk)
    try:
        from pypdf import PdfReader, PdfWriter  # type: ignore
    except Exception:
        return [doc]


def split_pdf_document_targeted_for_timetable(
    doc: RawDocument,
    *,
    pages_per_chunk: int,
    following_pages: int = 3,
    max_selected_pages: int = 10,
) -> tuple[list[RawDocument], dict[str, int | str]]:
    """
    Select pages likely containing timetable slots by course-code pattern, include nearby pages,
    then split those pages into smaller PDF chunks.
    Falls back to normal split on failure/low confidence.
    """
    filename = (doc.filename or "").lower()
    ctype = (doc.content_type or "").lower()
    is_pdf = filename.endswith(".pdf") or "pdf" in ctype
    if not is_pdf:
        return [doc], {
            "matched_pages": 0,
            "selected_pages": 0,
            "total_pages": 0,
            "strategy": "not_pdf",
        }

    safe_pages_per_chunk = max(1, pages_per_chunk)
    safe_following_pages = max(0, following_pages)
    safe_max_selected_pages = max(1, max_selected_pages)

    try:
        from pypdf import PdfReader, PdfWriter  # type: ignore
    except Exception:
        return split_pdf_document(doc, pages_per_chunk=safe_pages_per_chunk), {
            "matched_pages": 0,
            "selected_pages": 0,
            "total_pages": 0,
            "strategy": "fallback_no_pypdf",
        }

    try:
        reader = PdfReader(io.BytesIO(doc.data))
        total_pages = len(reader.pages)
        if total_pages <= safe_pages_per_chunk:
            return [doc], {
                "matched_pages": total_pages,
                "selected_pages": total_pages,
                "total_pages": total_pages,
                "strategy": "small_pdf_passthrough",
            }

        code_re = re.compile(r"\b[A-Z]{2,5}\s*\d{3,4}[A-Z]?\b")
        group_re = re.compile(
            r"\b(?:kumpulan|group|grp|seksyen|section)\b[\s:._-]*[a-z0-9]{0,4}",
            flags=re.IGNORECASE,
        )
        matched_indices: set[int] = set()
        pages_with_group_token: set[int] = set()
        for idx in range(total_pages):
            page = reader.pages[idx]
            text = page.extract_text() or ""
            if group_re.search(text):
                pages_with_group_token.add(idx)
            if code_re.search(text.upper()):
                matched_indices.add(idx)

        if not matched_indices:
            chunks = split_pdf_document(doc, pages_per_chunk=safe_pages_per_chunk)
            return chunks, {
                "matched_pages": 0,
                "selected_pages": total_pages,
                "total_pages": total_pages,
                "strategy": "fallback_no_course_code_match",
            }

        selected_indices: set[int] = set()
        for idx in matched_indices:
            if idx in pages_with_group_token:
                lo = idx
                hi = idx
            else:
                lo = idx
                hi = min(total_pages - 1, idx + safe_following_pages)
            for j in range(lo, hi + 1):
                selected_indices.add(j)

        ordered = sorted(selected_indices)
        if len(ordered) > safe_max_selected_pages:
            ordered = ordered[:safe_max_selected_pages]

        chunks: list[RawDocument] = []
        for start in range(0, len(ordered), safe_pages_per_chunk):
            sub = ordered[start : start + safe_pages_per_chunk]
            writer = PdfWriter()
            for page_idx in sub:
                writer.add_page(reader.pages[page_idx])
            buff = io.BytesIO()
            writer.write(buff)
            from_page = sub[0] + 1
            to_page = sub[-1] + 1
            chunks.append(
                RawDocument(
                    filename=f"{Path(doc.filename).stem}_sel_p{from_page}-{to_page}.pdf",
                    content_type="application/pdf",
                    data=buff.getvalue(),
                )
            )
        if not chunks:
            return [doc], {
                "matched_pages": len(matched_indices),
                "selected_pages": 0,
                "total_pages": total_pages,
            }
        return chunks, {
            "matched_pages": len(matched_indices),
            "selected_pages": len(ordered),
            "total_pages": total_pages,
            "strategy": "targeted_selection",
        }
    except Exception:
        chunks = split_pdf_document(doc, pages_per_chunk=safe_pages_per_chunk)
        return chunks, {
            "matched_pages": 0,
            "selected_pages": 0,
            "total_pages": 0,
            "strategy": "fallback_exception",
        }

    try:
        reader = PdfReader(io.BytesIO(doc.data))
        total_pages = len(reader.pages)
        if total_pages <= safe_pages_per_chunk:
            return [doc]

        chunks: list[RawDocument] = []
        for start in range(0, total_pages, safe_pages_per_chunk):
            end = min(start + safe_pages_per_chunk, total_pages)
            writer = PdfWriter()
            for idx in range(start, end):
                writer.add_page(reader.pages[idx])
            buff = io.BytesIO()
            writer.write(buff)
            chunk_data = buff.getvalue()
            chunks.append(
                RawDocument(
                    filename=f"{Path(doc.filename).stem}_p{start + 1}-{end}.pdf",
                    content_type="application/pdf",
                    data=chunk_data,
                )
            )
        return chunks or [doc]
    except Exception:
        return [doc]
