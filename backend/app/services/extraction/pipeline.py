"""Orchestrates dedicated extraction pipelines by document type."""

from __future__ import annotations

import time

from app.schemas.extraction import AcademicExtractionEnvelope, AcademicExtractionResult
from app.schemas.extraction import DocumentKind, ExtractionEnvelope
from app.schemas.extraction import ExtractionResult
from app.services.extraction.calendar_parser import classify_and_extract
from app.services.extraction.gemini_extractor import (
    _slice_english_calendar_section_with_debug,
    build_remark_text_for_debug,
)
from app.services.extraction.docling_service import (
    RawDocument,
    document_to_outputs,
)


async def _docling_to_markdown(doc: RawDocument) -> tuple[str, list[str], dict[str, float]]:
    warnings: list[str] = []
    timing_ms: dict[str, float] = {}
    try:
        t0 = time.perf_counter()
        outputs = await document_to_outputs(doc)
        timing_ms["docling_ms"] = (time.perf_counter() - t0) * 1000.0
        return outputs.markdown, warnings, timing_ms
    except Exception as e:
        warnings.append(f"Docling conversion failed: {type(e).__name__}: {e}")
        return "", warnings, timing_ms


async def run_academic_calendar_pipeline(doc: RawDocument) -> AcademicExtractionEnvelope:
    warnings: list[str] = []
    markdown, conv_warnings, timing_ms = await _docling_to_markdown(doc)
    warnings.extend(conv_warnings)
    if not markdown:
        extraction = ExtractionResult(
            kind=DocumentKind.unknown,
            confidence=0.0,
            notes="Docling conversion failed.",
        )
        return AcademicExtractionEnvelope(
            source_filename=doc.filename,
            markdown_from_docling="",
            extraction=AcademicExtractionResult(
                confidence=extraction.confidence,
                academic_session=extraction.academic_session,
                notes=extraction.notes,
            ),
            warnings=warnings,
            timing_ms=timing_ms,
        )

    gemini_text_bundle = markdown
    sliced_text_for_gemini, slice_debug = _slice_english_calendar_section_with_debug(gemini_text_bundle)
    remark_text_for_gemini = build_remark_text_for_debug(gemini_text_bundle)
    timing_ms["slice_header_match_count"] = float(slice_debug["slice_header_match_count"])
    timing_ms["slice_start_index"] = float(slice_debug["slice_start_index"])
    t_parse0 = time.perf_counter()
    extraction, parse_timing = await classify_and_extract(
        markdown,
        doc.filename,
        gemini_text_bundle=gemini_text_bundle,
    )
    timing_ms["calendar_parse_ms"] = (time.perf_counter() - t_parse0) * 1000.0
    timing_ms.update(parse_timing)
    if extraction.kind == DocumentKind.unknown:
        warnings.append("Could not classify/extract document type.")

    return AcademicExtractionEnvelope(
        source_filename=doc.filename,
        markdown_from_docling=markdown,
        sliced_text_for_gemini=sliced_text_for_gemini,
        remark_text_for_gemini=remark_text_for_gemini,
        extraction=AcademicExtractionResult(
            confidence=extraction.confidence,
            academic_session=extraction.academic_session,
            notes=extraction.notes,
        ),
        warnings=warnings,
        timing_ms=timing_ms,
    )


async def run_timetable_pipeline(doc: RawDocument) -> ExtractionEnvelope:
    markdown, warnings, timing_ms = await _docling_to_markdown(doc)
    extraction = ExtractionResult(
        kind=DocumentKind.unknown,
        confidence=0.0,
        notes="Timetable extraction pipeline is not implemented yet.",
    )
    warnings.append("Timetable extraction is not implemented yet.")
    return ExtractionEnvelope(
        document_kind=DocumentKind.unknown,
        source_filename=doc.filename,
        markdown_from_docling=markdown,
        extraction=extraction,
        warnings=warnings,
        timing_ms=timing_ms,
    )


async def run_task_pipeline(doc: RawDocument) -> ExtractionEnvelope:
    markdown, warnings, timing_ms = await _docling_to_markdown(doc)
    extraction = ExtractionResult(
        kind=DocumentKind.unknown,
        confidence=0.0,
        notes="Task extraction pipeline is not implemented yet.",
    )
    warnings.append("Task extraction is not implemented yet.")
    return ExtractionEnvelope(
        document_kind=DocumentKind.unknown,
        source_filename=doc.filename,
        markdown_from_docling=markdown,
        extraction=extraction,
        warnings=warnings,
        timing_ms=timing_ms,
    )
