"""Academic calendar parsing.

This module turns Docling-exported text/markdown into a structured representation
aligned with app:
- session start/end and term (sem1/sem2) windows derived from the PDF
- academic break events generated from the same fixed term-week logic as frontend
- holiday events extracted from the document "remarks" column

When Gemini is configured, extraction tries the full document first (any layout).
Otherwise/week-parse failure falls back to deterministic week rows + seeded breaks.
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
from app.services.extraction.gemini_extractor import (
    GeminiFullCalendarPayload,
    extract_full_academic_calendar_with_gemini,
)

_DATE_DD_MM_YYYY = re.compile(r"(?P<d>\d{1,2})\.(?P<m>\d{2})\.(?P<y>\d{4})")
_ENABLE_REPLACEMENT_LEAVE_FALLBACK = True  # temp test toggle
_ENABLE_EVENT_DEDUP = True  # temp test toggle

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


def _normalize_ocr_date_mashes(text: str) -> str:
    """
    Fix common Docling/OCR glues so dd.mm.yyyy patterns match.

    Examples from real phone captures:
    - Sunday,1210.2025 -> Sunday,12.10.2025 (missing dot between day and month)
    - Monday.13.102025 -> Monday.13.10.2025 (missing dot before 4-digit year)
    """
    def squash_ddmm_dot_yyyy(m: re.Match[str]) -> str:
        d, mo, y = m.group(1), m.group(2), m.group(3)
        di, mi = int(d), int(mo)
        if 1 <= di <= 31 and 1 <= mi <= 12:
            return f"{d}.{mo}.{y}"
        return m.group(0)

    # 1210.2025 -> 12.10.2025 (four digits + dot + year, no dot between DD and MM)
    out = re.sub(
        r"(?<![\d.])(\d{2})(\d{2})\.(\d{4})(?![\d.])",
        squash_ddmm_dot_yyyy,
        text,
    )

    def dot_dm_merge_yyyy(m: re.Match[str]) -> str:
        d_s, mo, y = m.group(1), m.group(2), m.group(3)
        d = int(d_s)
        if 1 <= d <= 31:
            return f"{d_s}.{mo}.{y}"
        return m.group(0)

    # 13.102025 -> 13.10.2025 (year concatenated to month without a dot)
    out = re.sub(
        r"(?<![\d])(\d{1,2})\.(\d{2})(\d{4})(?![\d])",
        dot_dm_merge_yyyy,
        out,
    )
    # 26.10.202520.10.2025 -> 26.10.2025 20.10.2025 (glued date tokens)
    # Use capture groups instead of look-behind (Python requires fixed-width look-behind).
    out = re.sub(
        r"(\d{1,2}\.\d{2}\.\d{4})(\d{1,2}\.\d{2}\.\d{4})",
        r"\1 \2",
        out,
    )
    return out


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


def _extract_all_dates_from_docling_text(text: str) -> list[date]:
    out: list[date] = []
    seen: set[date] = set()
    for m in _DATE_DD_MM_YYYY.finditer(text):
        try:
            d = _parse_dd_mm_yyyy(m.group(0))
        except Exception:
            continue
        if d in seen:
            continue
        seen.add(d)
        out.append(d)
    out.sort()
    return out


def _extract_compact_ddmmyyyy_dates(text: str) -> list[date]:
    out: list[date] = []
    seen: set[date] = set()

    def _push(raw: str) -> None:
        d = int(raw[0:2])
        mo = int(raw[2:4])
        y = int(raw[4:8])
        if not (1 <= d <= 31 and 1 <= mo <= 12 and 1900 <= y <= 2100):
            return
        try:
            parsed = date(y, mo, d)
        except Exception:
            return
        if parsed in seen:
            return
        seen.add(parsed)
        out.append(parsed)

    # Easy case: standalone 8-digit date tokens.
    for m in re.finditer(r"(?<!\d)(\d{8})(?!\d)", text):
        _push(m.group(1))

    # OCR glue case: long digit runs like "2610202520102025" (two ddmmyyyy dates stuck together).
    for run_m in re.finditer(r"\d{9,}", text):
        run = run_m.group(0)
        # If length is a multiple of 8, split into consecutive 8-char chunks first.
        if len(run) % 8 == 0:
            for i in range(0, len(run), 8):
                _push(run[i:i + 8])
            continue

        # Otherwise, slide window to recover any valid ddmmyyyy token in noisy runs.
        for i in range(0, len(run) - 7):
            _push(run[i:i + 8])

    out.sort()
    return out


def _extract_dates_after_calendar_header(text: str) -> list[date]:
    """
    Prefer dates from the main calendar table body (after header), not random preface text.
    """
    header_re = re.compile(
        r"(?im)^\s*\|?\s*(?:SEM|EM)\b[^\n]*\bWEEKS?\b[^\n]*\bREMARKS?\b[^\n]*$",
    )
    matches = list(header_re.finditer(text))
    if matches:
        section = text[matches[-1].start():]
    else:
        m = re.search(r"(?is)\b(?:SEM|EM)\b.*?\bWEEKS?\b.*?\bREMARKS?\b", text)
        section = text[m.start():] if m else text

    parsed = _extract_all_dates_from_docling_text(section)
    compact = _extract_compact_ddmmyyyy_dates(section)
    merged = sorted(set(parsed) | set(compact))
    return merged


def _norm_token(s: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", s.lower())


def _normalize_event_title(title: str) -> str:
    """
    Normalize OCR title spacing/spelling without changing event meaning.
    """
    t = title.strip()
    if not t:
        return t
    # Split camel/glued words: ChristmasDay -> Christmas Day
    t = re.sub(r"([a-z])([A-Z])", r"\1 \2", t)
    # Normalize separators and spacing
    t = t.replace("&", " & ")
    t = re.sub(r"\s+", " ", t).strip(" -,:;*")

    # Targeted typo/spacing repairs seen in OCR outputs.
    fixes = {
        "newyearof2025": "New Year 2025",
        "newyear": "New Year",
        "christmasday": "Christmas Day",
        "labourday": "Labour Day",
        "malaystaday": "Malaysia Day",
        "yangdipertuanaqongsbrthday": "Yang di-Pertuan Agong's Birthday",
        "yangdipertuanaqongsbirthday": "Yang di-Pertuan Agong's Birthday",
        "eidalfit": "Eid al-Fitr",
        "eidalfitr": "Eid al-Fitr",
        "chinesenewyear": "Chinese New Year",
        "sultanofkelantansbirthday": "Sultan of Kelantan's Birthday",
    }
    key = _norm_token(t)
    if key in fixes:
        return fixes[key]
    return t


def _near_duplicate_title(a: str, b: str) -> bool:
    """
    Lightweight near-duplicate matcher for OCR variants of same title.
    """
    ak = _norm_token(a)
    bk = _norm_token(b)
    if not ak or not bk:
        return False
    if ak == bk:
        return True
    if ak in bk or bk in ak:
        return True
    # replacementleaveforEidalFit vs replacementleaveforEidalFitr
    if ak.startswith("replacementleavefor") and bk.startswith("replacementleavefor"):
        core_a = ak.removeprefix("replacementleavefor")
        core_b = bk.removeprefix("replacementleavefor")
        if core_a == core_b or core_a in core_b or core_b in core_a:
            return True
    return False


def _dates_near_title_in_text(source_text: str, title: str) -> list[date]:
    """
    Extract date hints from lines/chunks that mention the same holiday title.
    Helps correct OCR carry-over where one holiday name is repeated on many rows.
    """
    title_key = _norm_token(title)
    if not title_key:
        return []

    candidates: set[date] = set()
    for raw_ln in source_text.splitlines():
        line = raw_ln.strip()
        if not line:
            continue
        line_key = _norm_token(line)
        if not line_key or title_key not in line_key:
            continue

        for m in _DATE_DD_MM_YYYY.finditer(line):
            try:
                candidates.add(_parse_dd_mm_yyyy(m.group(0)))
            except Exception:
                continue
        for d in _extract_compact_ddmmyyyy_dates(line):
            candidates.add(d)

    out = sorted(candidates)
    return out


def _extract_replacement_leave_events_from_text(
    source_text: str,
    *,
    sem2_start: date,
) -> list[AcademicEventExtract]:
    """
    OCR-safe safety net: explicitly recover replacement-leave rows even when
    Gemini misses them in mixed table lines.
    """
    events: list[AcademicEventExtract] = []
    seen: set[tuple[str, date]] = set()
    repl_re = re.compile(r"(?i)replacement\s*leave(?:\s*for)?\s*([^\n|,;]*)")

    for raw_ln in source_text.splitlines():
        line = raw_ln.strip()
        if not line:
            continue
        m = repl_re.search(line)
        if not m:
            continue

        tail = (m.group(1) or "").strip()
        if not tail:
            tail = "Replacement Leave"
        title = f"Replacement leave for {tail}".strip()
        title = re.sub(r"\s+", " ", title).strip(" -,:;*")
        title = _normalize_event_title(title)

        # Collect date candidates from this line and pick one closest before phrase.
        date_spans: list[tuple[int, date]] = []
        for dmatch in _DATE_DD_MM_YYYY.finditer(line):
            try:
                date_spans.append((dmatch.start(), _parse_dd_mm_yyyy(dmatch.group(0))))
            except Exception:
                continue
        for cmatch in re.finditer(r"(?<!\d)(\d{8})(?!\d)", line):
            compact = cmatch.group(1)
            try:
                parsed = date(int(compact[4:8]), int(compact[2:4]), int(compact[0:2]))
            except Exception:
                continue
            date_spans.append((cmatch.start(), parsed))

        if not date_spans:
            continue
        date_spans.sort(key=lambda x: x[0])
        repl_pos = m.start()
        before = [item for item in date_spans if item[0] <= repl_pos]
        chosen_date = before[-1][1] if before else date_spans[0][1]

        key = (_norm_token(title), chosen_date)
        if key in seen:
            continue
        seen.add(key)
        term_id = "sem2" if chosen_date >= sem2_start else "sem1"
        events.append(
            AcademicEventExtract(
                title=title,
                start_datetime=datetime.combine(chosen_date, time(0, 0, 0)),
                end_datetime=datetime.combine(chosen_date, time(23, 59, 0)),
                all_day=True,
                hide_classes_during_event=True,
                is_academic_break=False,
                term_id=term_id,
                location=None,
            )
        )

    events.sort(key=lambda ev: (ev.term_id, ev.start_datetime, ev.title.lower()))
    return events


def _looks_like_non_holiday_event_title(title: str) -> bool:
    normalized = re.sub(r"[^a-z0-9]+", " ", title.lower()).strip()
    if not normalized:
        return True
    blocked_phrases = (
        "teaching",
        "learning",
        "revision week",
        "exam",
        "examination",
        "mid semester break",
        "semester break",
        "long break",
        "industrial training",
        "orientation",
        "week ",
        "weeks",
        "t l",
        "tl7weeks",
    )
    return any(phrase in normalized for phrase in blocked_phrases)


def _session_from_gemini_payload(
    payload: GeminiFullCalendarPayload,
    source_text: str,
) -> AcademicSessionExtract | None:
    dates: list[date] = []
    for e in payload.events:
        if e.end_date < e.start_date:
            continue
        dates.extend([e.start_date, e.end_date])

    # User-requested behavior: session bounds come from earliest/latest date
    # found in the full Docling text (not from extracted event dates only).
    text_dates = sorted(
        set(_extract_all_dates_from_docling_text(source_text))
        | set(_extract_compact_ddmmyyyy_dates(source_text))
    )

    session_start = payload.session_start
    session_end = payload.session_end

    # Prefer earliest date seen after table header for session start.
    if text_dates:
        session_start = text_dates[0]
    # Requested behavior: end date follows the latest date that appears in Docling text.
    if text_dates:
        session_end = text_dates[-1]

    if session_start is None and dates:
        session_start = min(dates)
    if session_start is None and text_dates:
        session_start = text_dates[0]
    if session_end is None and dates:
        session_end = max(dates)
    if session_start is None or session_end is None:
        return None
    if session_end < session_start:
        session_start, session_end = session_end, session_start

    terms = _derive_terms_from_session_window(session_start, session_end)
    sem2_start = terms[1].start_date

    out_events: list[AcademicEventExtract] = []
    seen: set[tuple[str, date, date]] = set()
    for e in payload.events:
        if e.end_date < e.start_date:
            continue
        title = _normalize_event_title(e.title.strip())
        if _looks_like_non_holiday_event_title(title):
            continue
        key = (title.lower(), e.start_date, e.end_date)
        if key in seen:
            continue
        seen.add(key)
        term_id = "sem2" if e.start_date >= sem2_start else "sem1"
        start_dt = datetime.combine(e.start_date, time(0, 0, 0))
        end_dt = datetime.combine(e.end_date, time(23, 59, 0))
        out_events.append(
            AcademicEventExtract(
                title=title,
                start_datetime=start_dt,
                end_datetime=end_dt,
                all_day=True,
                hide_classes_during_event=True,
                is_academic_break=False,
                term_id=term_id,
                location=None,
            )
        )

    # Single dedup strategy: deduplicate only once at the end, after all sources
    # (Gemini + replacement-leave fallback) are merged.

    if _ENABLE_REPLACEMENT_LEAVE_FALLBACK:
        # Add explicit replacement-leave events recovered from OCR text.
        replacement_events = _extract_replacement_leave_events_from_text(
            source_text,
            sem2_start=sem2_start,
        )
        if replacement_events:
            existing = {
                (_norm_token(ev.title), ev.start_datetime.date(), ev.end_datetime.date())
                for ev in out_events
            }
            for ev in replacement_events:
                sig = (_norm_token(ev.title), ev.start_datetime.date(), ev.end_datetime.date())
                if sig in existing:
                    continue
                existing.add(sig)
                out_events.append(ev)

    # Important: fallback merge can introduce near-duplicates (e.g. Fit vs Fitr),
    # so run one more lightweight dedup pass after all sources are merged.
    if _ENABLE_EVENT_DEDUP:
        final_events_after_merge: list[AcademicEventExtract] = []
        for ev in out_events:
            merged = False
            for i, kept in enumerate(final_events_after_merge):
                if not _near_duplicate_title(ev.title, kept.title):
                    continue
                if kept.start_datetime.date() != ev.start_datetime.date():
                    continue
                if kept.end_datetime.date() != ev.end_datetime.date():
                    continue
                kept_score = len(kept.title) - kept.title.count("*")
                ev_score = len(ev.title) - ev.title.count("*")
                if ev_score > kept_score:
                    final_events_after_merge[i] = ev
                merged = True
                break
            if not merged:
                final_events_after_merge.append(ev)
        out_events = final_events_after_merge

    out_events.sort(key=lambda ev: (ev.term_id, ev.start_datetime, ev.title.lower()))
    # Generate session name from final bounds instead of trusting extracted title text.
    name = f"{session_start.year}/{session_end.year}"
    return AcademicSessionExtract(
        name=name.strip(),
        start_date=session_start,
        end_date=session_end,
        terms=terms,
        events=out_events,
        is_current=None,
    )


async def classify_and_extract(
    markdown: str,
    _filename: str,
    *,
    gemini_text_bundle: str | None = None,
) -> tuple[ExtractionResult, dict[str, float]]:
    markdown = _normalize_ocr_date_mashes(markdown)
    text_for_gemini = _normalize_ocr_date_mashes(
        (gemini_text_bundle.strip() if gemini_text_bundle else "") or markdown
    )

    settings = get_settings()
    gemini_ms = 0.0
    gstatus = ""
    gerr = ""
    gmodel = ""

    # Full-document Gemini first: any layout, no English-block or remarks-only slicing.
    if (
        settings.use_gemini_holiday_extraction
        and settings.gemini_api_key
    ):
        payload, gemini_ms, gstatus, gerr, gmodel = await extract_full_academic_calendar_with_gemini(
            text_for_gemini
        )
        if payload is not None:
            session = _session_from_gemini_payload(payload, markdown)
            if session is not None:
                confidence = min(
                    0.92,
                    0.35 + 0.02 * len(session.events) + (0.08 if payload.session_name else 0.0),
                )
                return (
                    ExtractionResult(
                        kind=DocumentKind.academic_session,
                        confidence=confidence,
                        academic_session=session,
                        notes=(
                            f"path=gemini_full_document; gemini_status={gstatus!r}; "
                            f"model={gmodel!r}; error={gerr!r}; event_count={len(session.events)}"
                        ),
                    ),
                    {"gemini_ms": gemini_ms},
                )

    page_text = _select_english_or_best_page(markdown)
    lines = [ln.strip() for ln in page_text.splitlines() if ln.strip()]

    week_entries = _extract_week_entries(page_text=page_text, lines=lines)

    week_entries = [
        w for w in week_entries
        if (w.end_date - w.start_date).days >= 5 and (w.end_date - w.start_date).days <= 10
    ]

    if len(week_entries) < 4:
        all_lines = [ln.strip() for ln in markdown.splitlines() if ln.strip()]
        week_entries = _extract_week_entries_loose(page_text=markdown, lines=all_lines)
        lines = all_lines

    if len(week_entries) < 4:
        extra = ""
        if settings.use_gemini_holiday_extraction and settings.gemini_api_key:
            extra = f" Gemini fallback already attempted (status={gstatus!r}, err={gerr!r})."
        return (
            ExtractionResult(
                kind=DocumentKind.academic_session,
                confidence=0.2,
                academic_session=None,
                notes=(
                    "Could not extract enough week rows (need at least 4 valid week date-ranges; "
                    "OCR fallback included). Enable/configure Gemini for layout-agnostic extraction."
                    + extra
                ),
            ),
            {"gemini_ms": gemini_ms},
        )

    session_start = week_entries[0].start_date
    session_end = max(we.end_date for we in week_entries)
    terms = _derive_terms_from_session_window(session_start, session_end)

    academic_session = AcademicSessionExtract(
        name=f"{session_start.year}/{session_end.year}",
        start_date=session_start,
        end_date=session_end,
        terms=terms,
        events=[],
        is_current=None,
    )

    confidence = min(
        0.95,
        0.2
        + (len(week_entries) / 60.0),
    )

    cfg = (
        f"gemini_configured={bool(settings.gemini_api_key)}; "
        f"use_gemini_flag={settings.use_gemini_holiday_extraction}"
    )
    attempt = (
        f" last_gemini_status={gstatus!r} last_gemini_err={gerr!r}"
        if (gstatus or gerr)
        else ""
    )
    return (
        ExtractionResult(
            kind=DocumentKind.academic_session,
            confidence=confidence,
            academic_session=academic_session,
            notes=(
                "path=deterministic_session_only; "
                f"week_row_count={len(week_entries)}; gemini_ms={gemini_ms}; "
                f"{cfg}{attempt}"
            ),
        ),
        {"gemini_ms": gemini_ms},
    )
