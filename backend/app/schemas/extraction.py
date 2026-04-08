"""JSON shapes aligned with Flutter/Firestore usage (field names as stored server-side)."""

from __future__ import annotations

from datetime import date, datetime
from enum import StrEnum
from typing import Literal

from pydantic import BaseModel, Field


class DocumentKind(StrEnum):
    academic_session = "academic_session"
    assignment = "assignment"
    timetable = "timetable"
    unknown = "unknown"


class TermWindowExtract(BaseModel):
    """Matches term objects built in academic_session_store (id, label, dates)."""

    id: str = Field(..., description="Stable term id, e.g. term-1")
    label: str
    start_date: date
    end_date: date


class AcademicSessionExtract(BaseModel):
    name: str
    start_date: date
    end_date: date
    terms: list[TermWindowExtract] = Field(default_factory=list)
    is_current: bool | None = None
    events: list["AcademicEventExtract"] = Field(default_factory=list)


class AcademicEventExtract(BaseModel):
    """Maps to Firestore `users/{uid}/events` documents (event fields only)."""

    title: str
    start_datetime: datetime
    end_datetime: datetime
    all_day: bool = True

    hide_classes_during_event: bool = True
    is_academic_break: bool = False

    term_id: str = "sem1"
    # location is optional; many PDFs omit it.
    location: str | None = None


AcademicSessionExtract.model_rebuild()


class AssignmentExtract(BaseModel):
    """Maps to users/{uid}/tasks — course_id optional if only code known."""

    course_code: str = Field(..., description="Normalized uppercase code")
    title: str
    description: str | None = None
    due_datetime: datetime
    course_id: str | None = None


# Mirrors Dart ClassType.name / Firestore classType string
ClassTypeName = Literal["lecture", "tutorial", "lab", "other"]


class ClassSlotExtract(BaseModel):
    """Maps to users/{uid}/classSlots — course_id filled after resolution."""

    course_code: str
    day: str = Field(..., description="Weekday label matching app constants, e.g. Monday")
    start_minutes: int = Field(..., ge=0, le=24 * 60)
    end_minutes: int = Field(..., ge=0, le=24 * 60)
    mode: str = ""
    venue: str | None = None
    class_type: ClassTypeName = "lecture"
    course_id: str | None = None


class TimetableExtract(BaseModel):
    slots: list[ClassSlotExtract] = Field(default_factory=list)


class ExtractionResult(BaseModel):
    """Exactly one of the *_extract fields should be set when kind is known."""

    kind: DocumentKind
    confidence: float = Field(ge=0.0, le=1.0, default=0.0)
    academic_session: AcademicSessionExtract | None = None
    assignment: AssignmentExtract | None = None
    timetable: TimetableExtract | None = None
    notes: str | None = Field(None, description="Model caveats or missing fields")


class ExtractionEnvelope(BaseModel):
    """What you return from POST /extract after Docling + LLM (or stub)."""

    document_kind: DocumentKind
    source_filename: str
    markdown_from_docling: str = ""
    sliced_text_for_gemini: str = ""
    remark_text_for_gemini: str = ""
    extraction: ExtractionResult | None = None
    warnings: list[str] = Field(default_factory=list)
    timing_ms: dict[str, float] = Field(
        default_factory=dict,
        description="Rough stage timings in milliseconds (docling, parse, gemini, etc.)",
    )
