"""Academic calendar parsing.

This module turns Docling-exported text/markdown into a structured representation
aligned with app:
- session start/end and term (sem1/sem2) windows derived from the PDF
- academic break events generated from the same fixed term-week logic as frontend
- holiday events extracted from the document "remarks" column

It is intentionally deterministic first. Add an LLM only if you hit PDFs that
break the known patterns.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta
from typing import Iterable

from app.core.config import get_settings
from app.schemas.extraction import (
    AcademicEventExtract,
    AcademicSessionExtract,
    DocumentKind,
    ExtractionResult,
    TermWindowExtract,
)
from app.services.extraction.gemini_extractor import extract_holidays_with_gemini

_DATE_DD_MM_YYYY = re.compile(r"(?P<d>\d{1,2})\.(?P<m>\d{2})\.(?P<y>\d{4})")

# Week-row date ranges, e.g.:
#   1  Monday, 06.10.2025 - Sunday, 12.10.2025
#   1  Isnin, 06.10.2025 - Ahad, 12.10.2025
_WEEK_RANGE = re.compile(
    # Docling/OCR can export dash separators as '-', '–' (en dash), or '—' (em dash).
    r"(?P<start>\d{1,2}\.\d{2}\.\d{4})\s*(?:\|\s*)*[-–—]\s*(?:\|\s*)*"
    r"(?:[A-Za-zÀ-ÿ]+,?\s*)?(?:\|\s*)*(?P<end>\d{1,2}\.\d{2}\.\d{4})"
)

@dataclass(frozen=True)
class WeekEntry:
    line_index: int
    start_date: date
    end_date: date


def _parse_dd_mm_yyyy(s: str) -> date:
    m = _DATE_DD_MM_YYYY.search(s.strip())
    if not m:
        raise ValueError(f"Not a dd.mm.yyyy date: {s!r}")
    d = int(m.group("d"))
    mo = int(m.group("m"))
    y = int(m.group("y"))
    return date(y, mo, d)


def _extract_week_entries(page_text: str, lines: list[str]) -> list[WeekEntry]:
    """
    Extract week start/end date ranges even when Docling splits the "start - end"
    across newlines (so per-line parsing can fail).
    """
    # Match across whitespace/newlines up to the dash and the end date.
    # We keep it fairly tight to avoid false positives.
    week_range_anywhere = re.compile(
        r"(?P<start>\d{1,2}\.\d{2}\.\d{4})"
        # Docling/OCR can export dash separators as '-', '–' (en dash), or '—' (em dash).
        r".{0,80}?[\-–—]{0,10}?.{0,40}?"
        r"(?P<end>\d{1,2}\.\d{2}\.\d{4})",
        flags=re.DOTALL,
    )

    # Map each date token to its first line index for later term splitting.
    first_line_for_date: dict[date, int] = {}
    for i, ln in enumerate(lines):
        for m in _DATE_DD_MM_YYYY.finditer(ln):
            try:
                d = _parse_dd_mm_yyyy(m.group(0))
            except Exception:
                continue
            first_line_for_date.setdefault(d, i)

    seen: set[tuple[date, date]] = set()
    weeks: list[WeekEntry] = []
    for m in week_range_anywhere.finditer(page_text):
        try:
            start_d = _parse_dd_mm_yyyy(m.group("start"))
            end_d = _parse_dd_mm_yyyy(m.group("end"))
        except Exception:
            continue

        # Teaching-week rows in your calendar are always:
        #   Monday, dd.mm.yyyy - Sunday, dd.mm.yyyy
        #
        # Don’t rely on OCR weekday text (it can be missing/corrupted on some
        # rows). Instead, validate via the parsed dates’ actual weekday.
        # Python: Monday=0, Sunday=6
        if start_d.weekday() != 0 or end_d.weekday() != 6:
            continue

        if end_d < start_d:
            continue
        key = (start_d, end_d)
        if key in seen:
            continue
        seen.add(key)
        line_index = first_line_for_date.get(start_d, 0)
        weeks.append(WeekEntry(line_index=line_index, start_date=start_d, end_date=end_d))

    # Sort by appearance (line_index) then by date, and keep stable order.
    weeks.sort(key=lambda w: (w.line_index, w.start_date))
    return weeks


def _extract_week_entries_loose(page_text: str, lines: list[str]) -> list[WeekEntry]:
    """
    Fallback extractor for noisy OCR where weekday tokens are corrupted.
    It accepts any plausible start/end date pair around one calendar week.
    """
    week_range_anywhere = re.compile(
        r"(?P<start>\d{1,2}\.\d{2}\.\d{4})"
        r".{0,80}?[\-–—]{0,10}?.{0,40}?"
        r"(?P<end>\d{1,2}\.\d{2}\.\d{4})",
        flags=re.DOTALL,
    )

    first_line_for_date: dict[date, int] = {}
    for i, ln in enumerate(lines):
        for m in _DATE_DD_MM_YYYY.finditer(ln):
            try:
                d = _parse_dd_mm_yyyy(m.group(0))
            except Exception:
                continue
            first_line_for_date.setdefault(d, i)

    seen: set[tuple[date, date]] = set()
    weeks: list[WeekEntry] = []
    for m in week_range_anywhere.finditer(page_text):
        try:
            start_d = _parse_dd_mm_yyyy(m.group("start"))
            end_d = _parse_dd_mm_yyyy(m.group("end"))
        except Exception:
            continue
        if end_d < start_d:
            continue
        span_days = (end_d - start_d).days
        if span_days < 5 or span_days > 10:
            continue
        key = (start_d, end_d)
        if key in seen:
            continue
        seen.add(key)
        line_index = first_line_for_date.get(start_d, 0)
        weeks.append(WeekEntry(line_index=line_index, start_date=start_d, end_date=end_d))

    weeks.sort(key=lambda w: (w.line_index, w.start_date))
    return weeks


def _split_pages(markdown: str) -> list[str]:
    # Docling often emits page markers like: "-- 1 of 2 --"
    parts = re.split(r"--\s*\d+\s+of\s+\d+\s*--", markdown, flags=re.IGNORECASE)
    # If there are no markers, re.split returns [markdown], which is fine.
    return [p.strip() for p in parts if p.strip()]


def _page_score(page_text: str, keywords: Iterable[str]) -> int:
    t = page_text.lower()
    return sum(1 for kw in keywords if kw.lower() in t)


def _select_english_or_best_page(markdown: str) -> str:
    pages = _split_pages(markdown)
    if len(pages) <= 1:
        return markdown

    english_weekdays = [
        "monday",
        "tuesday",
        "wednesday",
        "thursday",
        "friday",
        "saturday",
        "sunday",
    ]

    english_keywords = [
        "teaching & learning",
        "revision week",
        "examination",
        "mid semester break",
        "industrial training",
        "semester 1",
        "semester 2",
    ]
    malay_keywords = [
        "pengajaran",
        "p&p",
        "cuti pertengahan",
        "minggu ulang kaji",
        "peperiksaan",
        "latihan industri",
        "semester i",
        "semester ii",
        "t&l",
        "t&l",
    ]

    # Prefer a page that contains English weekday names.
    weekday_scores = []
    for p in pages:
        t = p.lower()
        score = 0
        for wd in english_weekdays:
            # match "Monday," or "Monday" etc.
            score += len(re.findall(rf"\\b{wd}\\b", t))
        weekday_scores.append(score)

    best_weekday_score = max(weekday_scores) if weekday_scores else 0
    if best_weekday_score > 0:
        return pages[weekday_scores.index(best_weekday_score)]

    # Fallback to keyword scoring.
    english_scores = [_page_score(p, english_keywords) for p in pages]
    best_english = max(english_scores) if english_scores else 0
    if best_english > 0:
        return pages[english_scores.index(best_english)]

    # Otherwise pick the best among Malay keywords.
    best_overall = max([_page_score(p, malay_keywords) for p in pages] or [0])
    return pages[0] if best_overall == 0 else pages[max(range(len(pages)), key=lambda i: _page_score(pages[i], malay_keywords))]


@dataclass(frozen=True)
class _SeededAcademicBreak:
    title: str
    week_start: int
    week_length: int


def _event_datetime_day_span(start: date, end: date) -> tuple[datetime, datetime]:
    start_dt = datetime.combine(start, time(0, 0, 0))
    end_dt = datetime.combine(end, time(23, 59, 0))
    return start_dt, end_dt


def _academic_breaks_for_term(term_id: str, term_label: str) -> list[_SeededAcademicBreak]:
    term_l = term_label.lower()
    is_sem1 = term_id == "sem1" or "semester 1" in term_l
    if is_sem1:
        return [
            _SeededAcademicBreak(title="Mid-Semester Break", week_start=8, week_length=1),
            _SeededAcademicBreak(title="Revision Week", week_start=16, week_length=1),
            _SeededAcademicBreak(title="Exam Week", week_start=17, week_length=3),
            _SeededAcademicBreak(title="Mid-Semester Break", week_start=20, week_length=4),
        ]

    is_sem2 = term_id == "sem2" or "semester 2" in term_l
    if is_sem2:
        return [
            _SeededAcademicBreak(title="Mid-Semester Break", week_start=8, week_length=1),
            _SeededAcademicBreak(title="Revision Week", week_start=16, week_length=1),
            _SeededAcademicBreak(title="Exam Week", week_start=17, week_length=3),
            _SeededAcademicBreak(title="Long Break", week_start=20, week_length=999),
        ]

    return []


def _build_seeded_academic_break_events(terms: list[TermWindowExtract]) -> list[AcademicEventExtract]:
    out: list[AcademicEventExtract] = []
    for term in terms:
        term_start = term.start_date
        term_end = term.end_date
        if term_end < term_start:
            continue

        for b in _academic_breaks_for_term(term.id, term.label):
            start_d = term_start + timedelta(days=(b.week_start - 1) * 7)
            end_d_raw = start_d + timedelta(days=(b.week_length * 7) - 1)
            start_d = max(start_d, term_start)
            end_d = min(end_d_raw, term_end)
            if end_d < start_d:
                continue
            start_dt, end_dt = _event_datetime_day_span(start_d, end_d)
            out.append(
                AcademicEventExtract(
                    title=b.title,
                    start_datetime=start_dt,
                    end_datetime=end_dt,
                    all_day=True,
                    hide_classes_during_event=False,
                    is_academic_break=True,
                    term_id=term.id,
                    location=None,
                )
            )

    out.sort(key=lambda e: (e.term_id, e.start_datetime))
    return out


def _derive_terms_from_session_window(session_start: date, session_end: date) -> list[TermWindowExtract]:
    """
    Derive semester windows from session bounds only (OCR-robust).
    Pattern follows frontend assumptions:
    - Semester 1 spans 23 weeks from session start.
    - Semester 2 is the remainder until session end.
    """
    sem1_end_target = session_start + timedelta(days=(23 * 7) - 1)
    sem1_end = min(sem1_end_target, session_end)
    sem2_start = min(sem1_end + timedelta(days=1), session_end)
    sem2_end = session_end
    return [
        TermWindowExtract(
            id="sem1",
            label="Semester 1",
            start_date=session_start,
            end_date=sem1_end,
        ),
        TermWindowExtract(
            id="sem2",
            label="Semester 2",
            start_date=sem2_start,
            end_date=sem2_end,
        ),
    ]


def _detect_is_academic_calendar(markdown: str) -> bool:
    # Docling/OCR may inject replacement characters like "�", and spacing/newlines
    # may vary. Normalize to alphanumeric tokens before matching.
    text = markdown.lower()
    text = text.replace("�", " ")
    text = re.sub(r"[^a-z0-9]+", " ", text)
    tokens = set(t for t in text.split() if t)

    # English title
    if {"academic", "calendar"}.issubset(tokens):
        return True
    # Malay title keywords
    if {"kalendar", "akademik"}.issubset(tokens):
        return True
    if {"sidang", "akademik"}.issubset(tokens):
        return True

    # OCR/table header patterns from bilingual USM-like calendar layouts.
    if {"sem", "weeks", "activities", "date", "remarks"}.issubset(tokens):
        return True
    if {"sem", "minggu", "aktiviti", "tarikh", "catatan"}.issubset(tokens):
        return True

    # Combined structure hints: semester markers + break/teaching/exam terms.
    has_sem_marker = any(t in tokens for t in ("one", "two", "dua", "semester", "sem"))
    has_calendar_activity = any(
        t in tokens
        for t in (
            "teaching",
            "learning",
            "p",
            "revision",
            "examination",
            "peperiksaan",
            "cuti",
            "break",
            "minggu",
        )
    )
    if has_sem_marker and has_calendar_activity:
        return True
    return False


async def classify_and_extract(
    markdown: str,
    filename: str,
    *,
    gemini_text_bundle: str | None = None,
) -> tuple[ExtractionResult, dict[str, float]]:
    empty_timing: dict[str, float] = {}

    if not _detect_is_academic_calendar(markdown):
        return (
            ExtractionResult(
                kind=DocumentKind.unknown,
                confidence=0.0,
                notes=f"Not recognized as an academic calendar: {filename}",
            ),
            empty_timing,
        )

    page_text = _select_english_or_best_page(markdown)
    lines = [ln.strip() for ln in page_text.splitlines() if ln.strip()]

    # Parse week rows (date ranges).
    week_entries = _extract_week_entries(page_text=page_text, lines=lines)

    # Heuristic: keep week ranges that look like 7-day spans.
    week_entries = [
        w for w in week_entries
        if (w.end_date - w.start_date).days >= 5 and (w.end_date - w.start_date).days <= 10
    ]

    if len(week_entries) < 5:
        # Fallback: use full markdown and looser OCR-tolerant constraints.
        all_lines = [ln.strip() for ln in markdown.splitlines() if ln.strip()]
        week_entries = _extract_week_entries_loose(page_text=markdown, lines=all_lines)
        lines = all_lines

    if len(week_entries) < 5:
        return (
            ExtractionResult(
                kind=DocumentKind.academic_session,
                confidence=0.2,
                academic_session=None,
                notes="Could not extract enough week rows for academic session (including OCR fallback).",
            ),
            {},
        )

    session_start = week_entries[0].start_date
    session_end = max(we.end_date for we in week_entries)
    terms = _derive_terms_from_session_window(session_start, session_end)
    sem2_start = terms[1].start_date

    academic_break_events = _build_seeded_academic_break_events(terms)

    settings = get_settings()
    holiday_events: list[AcademicEventExtract] = []
    holiday_source = "gemini_disabled"
    gemini_status = "disabled"
    gemini_error = ""
    gemini_model_used = ""
    gemini_ms = 0.0
    # Gemini: Docling plain text only (pipeline). No regex fallback.
    text_for_gemini = (gemini_text_bundle.strip() if gemini_text_bundle else "") or markdown
    if settings.use_gemini_holiday_extraction:
        gemini_events, gemini_ms, gemini_status, gemini_error, gemini_model_used = await extract_holidays_with_gemini(
            text_for_gemini,
            sem2_start=sem2_start,
        )
        if gemini_events:
            holiday_events = gemini_events
            holiday_source = "gemini"
        else:
            holiday_source = "gemini_empty"

    academic_session = AcademicSessionExtract(
        name=f"{session_start.year}/{session_end.year}",
        start_date=session_start,
        end_date=session_end,
        terms=terms,
        events=[*academic_break_events, *holiday_events],
        is_current=None,
    )

    # Confidence increases with extracted weeks and events.
    confidence = min(
        0.95,
        0.2
        + (len(week_entries) / 60.0)
        + (0.05 if academic_break_events else 0.0)
        + (0.05 if holiday_events else 0.0),
    )

    timing: dict[str, float] = {"gemini_ms": gemini_ms}

    return (
        ExtractionResult(
            kind=DocumentKind.academic_session,
            confidence=confidence,
            academic_session=academic_session,
            notes=(
                f"holiday_extraction_source={holiday_source}; "
                f"holiday_count={len(holiday_events)}; "
                f"gemini_status={gemini_status}; "
                f"gemini_model_used={gemini_model_used!r}; "
                f"gemini_error={gemini_error!r}"
            ),
        ),
        timing,
    )
