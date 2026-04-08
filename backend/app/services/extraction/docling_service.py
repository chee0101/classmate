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
