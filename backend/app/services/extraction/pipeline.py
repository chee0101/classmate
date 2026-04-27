"""Orchestrates dedicated extraction pipelines by document type."""

from __future__ import annotations

import re
import time

from app.core.config import get_settings
from app.schemas.extraction import (
    AcademicExtractionEnvelope,
    AcademicExtractionResult,
)
from app.schemas.extraction import DocumentKind, ExtractionEnvelope
from app.schemas.extraction import ClassSlotExtract, ExtractionResult, TimetableExtract
from app.services.extraction.calendar_parser import classify_and_extract
from app.services.extraction.gemini_extractor import (
    extract_timetable_with_gemini,
    extract_task_with_gemini,
    slice_english_calendar_section_with_debug,
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


async def _doclings_to_markdown(
    docs: list[RawDocument],
) -> tuple[str, str, list[str], dict[str, float]]:
    warnings: list[str] = []
    timing_ms: dict[str, float] = {}
    chunks: list[str] = []
    source_names: list[str] = []
    total_docling_ms = 0.0

    for idx, doc in enumerate(docs):
        markdown, conv_warnings, per_timing = await _docling_to_markdown(doc)
        warnings.extend(conv_warnings)
        total_docling_ms += per_timing.get("docling_ms", 0.0)
        source_names.append(doc.filename)
        if markdown.strip():
            # Keep page/screenshot boundaries explicit for downstream parsing/debug.
            chunks.append(f"--- source {idx + 1}: {doc.filename} ---\n{markdown.strip()}")

    timing_ms["docling_ms"] = total_docling_ms
    timing_ms["input_count"] = float(len(docs))
    return "\n\n".join(chunks).strip(), ", ".join(source_names), warnings, timing_ms


async def run_academic_calendar_pipeline(
    docs: list[RawDocument],
) -> AcademicExtractionEnvelope:
    warnings: list[str] = []
    markdown, source_filename, conv_warnings, timing_ms = await _doclings_to_markdown(docs)
    warnings.extend(conv_warnings)
    if not markdown:
        extraction = ExtractionResult(
            kind=DocumentKind.unknown,
            confidence=0.0,
            notes="Docling conversion failed.",
        )
        return AcademicExtractionEnvelope(
            source_filename=source_filename,
            markdown_from_docling="",
            extraction=AcademicExtractionResult(
                confidence=extraction.confidence,
                academic_session=extraction.academic_session,
                notes=extraction.notes,
            ),
            warnings=warnings,
            timing_ms=timing_ms,
        )

    sliced_text_for_gemini, slice_debug = slice_english_calendar_section_with_debug(markdown)
    gemini_text_bundle = sliced_text_for_gemini
    remark_text_for_gemini = sliced_text_for_gemini
    timing_ms["slice_header_match_count"] = float(slice_debug["slice_header_match_count"])
    timing_ms["slice_start_index"] = float(slice_debug["slice_start_index"])
    t_parse0 = time.perf_counter()
    extraction, parse_timing = await classify_and_extract(
        markdown,
        source_filename,
        gemini_text_bundle=gemini_text_bundle,
    )
    timing_ms["calendar_parse_ms"] = (time.perf_counter() - t_parse0) * 1000.0
    timing_ms.update(parse_timing)
    if extraction.kind == DocumentKind.unknown:
        warnings.append("Could not classify/extract document type.")

    # If Gemini is enabled but temporarily unavailable, do not silently return
    # a session-only payload with 0 holidays. Surface a retryable error instead.
    notes_l = (extraction.notes or "").lower()
    is_session_only_fallback = "path=deterministic_session_only" in notes_l
    has_gemini_api_error = "last_gemini_status='api_error'" in notes_l
    looks_transient_unavailable = (
        "503" in notes_l
        or "unavailable" in notes_l
        or "resource_exhausted" in notes_l
        or "try again later" in notes_l
    )
    if is_session_only_fallback and has_gemini_api_error and looks_transient_unavailable:
        raise RuntimeError(
            "AI extraction service is temporarily unavailable. Please try again."
        )

    return AcademicExtractionEnvelope(
        source_filename=source_filename,
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


async def run_timetable_pipeline(
    doc: RawDocument,
    *,
    course_codes_allowed: list[str] | None = None,
    ai_notes: str | None = None,
) -> ExtractionEnvelope:
    markdown, warnings, timing_ms = await _docling_to_markdown(doc)
    group_filters = _extract_group_filters(ai_notes)
    non_numeric_group_filters = [t for t in group_filters if not t.isdigit()]
    t0 = time.perf_counter()
    slots = _extract_timetable_slots(markdown, group_filters=group_filters)
    if not slots:
        settings = get_settings()
        if settings.gemini_api_key:
            gslots, gms, gstatus, gerr, gmodel = await extract_timetable_with_gemini(
                markdown,
                ai_notes=ai_notes,
            )
            timing_ms["gemini_ms"] = gms
            if gslots:
                slots = gslots
                warnings.append(
                    f"Timetable parsed with Gemini fallback (status={gstatus!r}, model={gmodel!r})."
                )
            else:
                warnings.append(
                    f"Gemini timetable fallback returned no slots (status={gstatus!r}, error={gerr!r})."
                )
    filtered_slots, filter_warnings = _apply_timetable_rules(
        slots,
        course_codes_allowed=course_codes_allowed,
        ai_notes=ai_notes,
    )
    filtered_slots = _merge_adjacent_slots(filtered_slots)
    warnings.extend(filter_warnings)
    timing_ms["timetable_parse_ms"] = (time.perf_counter() - t0) * 1000.0
    extraction = _build_timetable_result(filtered_slots, warnings=warnings)
    return ExtractionEnvelope(
        document_kind=extraction.kind,
        source_filename=doc.filename,
        markdown_from_docling=markdown,
        extraction=extraction,
        warnings=warnings,
        timing_ms=timing_ms,
    )


async def run_task_pipeline(docs: list[RawDocument]) -> ExtractionEnvelope:
    markdown, source_filename, warnings, timing_ms = await _doclings_to_markdown(docs)
    if not markdown.strip():
        extraction = ExtractionResult(
            kind=DocumentKind.unknown,
            confidence=0.0,
            notes="Docling conversion failed for task extraction.",
        )
        warnings.append("Task extraction failed: empty Docling output.")
        return ExtractionEnvelope(
            document_kind=DocumentKind.unknown,
            source_filename=source_filename,
            markdown_from_docling=markdown,
            extraction=extraction,
            warnings=warnings,
            timing_ms=timing_ms,
        )

    tasks, gemini_ms, status, error, model_used = await extract_task_with_gemini(markdown)
    timing_ms["gemini_ms"] = gemini_ms
    if not tasks:
        extraction = ExtractionResult(
            kind=DocumentKind.unknown,
            confidence=0.0,
            notes=(
                "Task extraction did not return any valid task; "
                f"gemini_status={status!r}; model={model_used!r}; error={error!r}"
            ),
        )
        warnings.append("Task extraction returned no tasks.")
        document_kind = DocumentKind.unknown
    else:
        extraction = ExtractionResult(
            kind=DocumentKind.assignment,
            confidence=0.75,
            assignment=None,
            tasks=tasks,
            notes=(
                f"gemini_status={status!r}; model={model_used!r}; error={error!r}; task_count={len(tasks)}"
            ),
        )
        document_kind = DocumentKind.assignment

    return ExtractionEnvelope(
        document_kind=document_kind,
        source_filename=source_filename,
        markdown_from_docling=markdown,
        extraction=extraction,
        warnings=warnings,
        timing_ms=timing_ms,
    )


_COURSE_CODE_RE = re.compile(r"\b([A-Z]{2,5}\s*\d{3,4}[A-Z]?)\b")
_TIME_RANGE_RE = re.compile(
    r"\b(?P<sh>\d{1,2})[:.](?P<sm>\d{2})\s*[-–—]\s*(?P<eh>\d{1,2})[:.](?P<em>\d{2})\b"
)
_TIME_TOKEN_RE = re.compile(
    r"(?P<sh>\d{1,2})[:.](?P<sm>\d{2})\s*[-–—]\s*(?P<eh>\d{1,2})[:.](?P<em>\d{2})(?P<suffix>.*)$",
    flags=re.IGNORECASE,
)
_DAY_PATTERNS: tuple[tuple[str, tuple[str, ...]], ...] = (
    ("Monday", ("monday", "mon", "isnin")),
    ("Tuesday", ("tuesday", "tue", "selasa")),
    ("Wednesday", ("wednesday", "wed", "rabu")),
    ("Thursday", ("thursday", "thu", "khamis")),
    ("Friday", ("friday", "fri", "jumaat", "jumat")),
    ("Saturday", ("saturday", "sat", "sabtu")),
    ("Sunday", ("sunday", "sun", "ahad")),
)


def _normalize_course_code(raw: str) -> str:
    return re.sub(r"\s+", "", raw.strip().upper())


def _to_minutes(hour: int, minute: int) -> int:
    return (hour * 60) + minute


def _to_24h(hour_12: int, minute: int, token_suffix: str) -> tuple[int, int]:
    suffix = token_suffix.lower()
    if "pagi" in suffix or "am" in suffix:
        if hour_12 == 12:
            return 0, minute
        return hour_12, minute
    if "petang" in suffix or "tengah hari" in suffix or "pm" in suffix:
        if hour_12 == 12:
            return 12, minute
        return hour_12 + 12, minute
    # Default fallback keeps original hour.
    return hour_12, minute


def _class_type_for_line(line_lower: str) -> str:
    if "tutorial" in line_lower or "tut" in line_lower:
        return "tutorial"
    if "lab" in line_lower:
        return "lab"
    if "lecture" in line_lower or "lect" in line_lower:
        return "lecture"
    # Timetables usually omit explicit class type; default to lecture.
    return "lecture"


def _mode_for_line(line_lower: str) -> str:
    if any(tok in line_lower for tok in ("online", "google meet", "zoom", "webex")):
        return "online"
    if any(tok in line_lower for tok in ("hybrid", "blended")):
        return "hybrid"
    return "physical"


def _extract_day_label(line_lower: str) -> str | None:
    padded = f" {line_lower} "
    for canonical, aliases in _DAY_PATTERNS:
        for alias in aliases:
            if f" {alias} " in padded:
                return canonical
    return None


def _extract_venue(line: str) -> str | None:
    venue_match = re.search(r"(?i)\b(?:venue|room|location)\b[:\- ]+([^|,;]+)", line)
    if venue_match:
        venue = venue_match.group(1).strip()
        return venue or None
    # Common timetable style: COURSE ... (DK G31)
    paren_match = re.search(r"\(([^()]{2,60})\)\s*$", line)
    if paren_match:
        venue = paren_match.group(1).strip()
        return venue or None
    return None


def _split_markdown_row(row: str) -> list[str]:
    return [cell.strip() for cell in row.strip().strip("|").split("|")]


def _looks_like_separator_row(row_cells: list[str]) -> bool:
    if not row_cells:
        return False
    return all(re.fullmatch(r"[:\- ]+", cell or "-") is not None for cell in row_cells)


def _parse_time_range_cell(text: str) -> tuple[int, int] | None:
    m = _TIME_TOKEN_RE.search(text)
    if not m:
        return None
    sh = int(m.group("sh"))
    sm = int(m.group("sm"))
    eh = int(m.group("eh"))
    em = int(m.group("em"))
    suffix = m.group("suffix") or ""
    sh24, sm24 = _to_24h(sh, sm, suffix)
    eh24, em24 = _to_24h(eh, em, suffix)
    start = _to_minutes(sh24, sm24)
    end = _to_minutes(eh24, em24)
    if end <= start:
        return None
    return start, end


def _extract_day_from_cell(cell: str) -> str | None:
    # Accept formats like "ISNIN", "(Monday)", or mixed.
    normalized = re.sub(r"[()]", " ", cell).strip().lower()
    return _extract_day_label(normalized)


def _extract_cell_entries(cell: str) -> list[str]:
    clean = re.sub(r"\s+", " ", cell).strip()
    if not clean:
        return []
    # Split by course-code anchors to support multiple classes in one cell.
    matches = list(_COURSE_CODE_RE.finditer(clean.upper()))
    if not matches:
        return []
    entries: list[str] = []
    for idx, match in enumerate(matches):
        start = match.start()
        end = matches[idx + 1].start() if idx + 1 < len(matches) else len(clean)
        segment = clean[start:end].strip(" ;,/")
        if segment:
            entries.append(segment)
    return entries


def _extract_group_cell_value(cell: str) -> str | None:
    normalized = re.sub(r"\s+", " ", cell).strip()
    if not normalized:
        return None
    # Prefer compact tokens like "1", "B1", "G1", etc.
    m = re.search(r"(?i)\b([A-Z]?\d+[A-Z]?)\b", normalized)
    if m:
        return m.group(1).upper()
    return None


def _extract_table_slots(
    markdown: str,
    *,
    group_filters: list[str] | None = None,
) -> list[ClassSlotExtract]:
    rows_raw = [ln.strip() for ln in markdown.splitlines() if ln.strip().startswith("|")]
    if len(rows_raw) < 3:
        return []
    rows = [_split_markdown_row(r) for r in rows_raw]
    header_idx = -1
    for i, row in enumerate(rows):
        if not row:
            continue
        first = row[0].lower()
        if "hari" in first or "day" in first:
            header_idx = i
            break
    if header_idx < 0:
        return []
    if header_idx + 1 >= len(rows):
        return []
    header = rows[header_idx]
    group_col_idx = 0
    for col_idx, header_cell in enumerate(header):
        hc = header_cell.lower()
        if "kumpulan" in hc or "group" in hc:
            group_col_idx = col_idx
            break
    time_columns: dict[int, tuple[int, int]] = {}
    for col_idx in range(1, len(header)):
        parsed = _parse_time_range_cell(header[col_idx])
        if parsed is not None:
            time_columns[col_idx] = parsed
    if not time_columns:
        return []

    slots: list[ClassSlotExtract] = []
    seen: set[tuple[str, str, int, int, str]] = set()
    active_day: str | None = None
    active_group: str | None = None
    group_filters_set = {g.strip().upper() for g in (group_filters or []) if g.strip()}
    for row in rows[header_idx + 1:]:
        if _looks_like_separator_row(row):
            continue
        if not row:
            continue
        day_candidate = _extract_day_from_cell(row[0] if len(row) > 0 else "")
        if day_candidate is not None:
            active_day = day_candidate
        if group_col_idx < len(row):
            group_candidate = _extract_group_cell_value(row[group_col_idx])
            if group_candidate is not None:
                active_group = group_candidate
        if active_day is None:
            continue
        if group_filters_set and active_group not in group_filters_set:
            continue

        for col_idx, (start_minutes, end_minutes) in time_columns.items():
            if col_idx >= len(row):
                continue
            entries = _extract_cell_entries(row[col_idx])
            if not entries:
                continue
            for entry in entries:
                code_match = _COURSE_CODE_RE.search(entry.upper())
                if code_match is None:
                    continue
                course_code = _normalize_course_code(code_match.group(1))
                entry_lower = entry.lower()
                class_type = _class_type_for_line(entry_lower)
                mode = _mode_for_line(entry_lower)
                venue = _extract_venue(entry)
                signature = (
                    course_code,
                    active_day,
                    start_minutes,
                    end_minutes,
                    class_type,
                )
                if signature in seen:
                    continue
                seen.add(signature)
                slots.append(
                    ClassSlotExtract(
                        course_code=course_code,
                        day=active_day,
                        start_minutes=start_minutes,
                        end_minutes=end_minutes,
                        mode=mode,
                        venue=venue,
                        class_type=class_type,  # type: ignore[arg-type]
                    )
                )
    return slots


def _extract_timetable_slots(
    markdown: str,
    *,
    group_filters: list[str] | None = None,
) -> list[ClassSlotExtract]:
    table_slots = _extract_table_slots(markdown, group_filters=group_filters)
    if table_slots:
        return table_slots
    slots: list[ClassSlotExtract] = []
    seen: set[tuple[str, str, int, int, str]] = set()
    for raw_line in markdown.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        line_lower = line.lower()
        day = _extract_day_label(line_lower)
        time_match = _TIME_RANGE_RE.search(line)
        code_match = _COURSE_CODE_RE.search(line.upper())
        if day is None or time_match is None or code_match is None:
            continue
        sh = int(time_match.group("sh"))
        sm = int(time_match.group("sm"))
        eh = int(time_match.group("eh"))
        em = int(time_match.group("em"))
        start_minutes = _to_minutes(sh, sm)
        end_minutes = _to_minutes(eh, em)
        if end_minutes <= start_minutes:
            continue
        course_code = _normalize_course_code(code_match.group(1))
        class_type = _class_type_for_line(line_lower)
        mode = _mode_for_line(line_lower)
        venue = _extract_venue(line)
        signature = (course_code, day, start_minutes, end_minutes, class_type)
        if signature in seen:
            continue
        seen.add(signature)
        slots.append(
            ClassSlotExtract(
                course_code=course_code,
                day=day,
                start_minutes=start_minutes,
                end_minutes=end_minutes,
                mode=mode,
                venue=venue,
                class_type=class_type,  # type: ignore[arg-type]
            )
        )
    return slots


def _build_timetable_result(
    slots: list[ClassSlotExtract],
    *,
    warnings: list[str],
) -> ExtractionResult:
    if not slots:
        warnings.append("No timetable slots detected from document text.")
        return ExtractionResult(
            kind=DocumentKind.unknown,
            confidence=0.0,
            notes="No parseable timetable lines found (need course code + day + time range).",
        )
    confidence = min(0.95, 0.45 + (0.03 * len(slots)))
    return ExtractionResult(
        kind=DocumentKind.timetable,
        confidence=confidence,
        timetable=TimetableExtract(slots=slots),
        notes=f"Parsed {len(slots)} class slots using deterministic timetable parser.",
    )


def _merge_adjacent_slots(slots: list[ClassSlotExtract]) -> list[ClassSlotExtract]:
    """
    Merge consecutive slots for the same class identity when separated by a short break.
    Typical timetable blocks are 50 mins + 10 mins gap + 50 mins for one continuous class.
    """
    if len(slots) <= 1:
        return slots

    sorted_slots = sorted(
        slots,
        key=lambda s: (
            s.day,
            s.course_code,
            s.class_type,
            s.mode,
            s.venue or "",
            s.start_minutes,
        ),
    )

    merged: list[ClassSlotExtract] = []
    for slot in sorted_slots:
        if not merged:
            merged.append(slot)
            continue

        prev = merged[-1]
        same_identity = (
            prev.day == slot.day
            and prev.course_code == slot.course_code
            and prev.class_type == slot.class_type
            and prev.mode == slot.mode
            and (prev.venue or "") == (slot.venue or "")
        )
        gap = slot.start_minutes - prev.end_minutes
        if same_identity and 0 <= gap <= 10:
            merged[-1] = ClassSlotExtract(
                course_code=prev.course_code,
                day=prev.day,
                start_minutes=prev.start_minutes,
                end_minutes=max(prev.end_minutes, slot.end_minutes),
                mode=prev.mode,
                venue=prev.venue,
                class_type=prev.class_type,
                course_id=prev.course_id,
            )
            continue

        merged.append(slot)

    return merged


def _extract_group_filters(ai_notes: str | None) -> list[str]:
    if not ai_notes:
        return []
    group_tokens: list[str] = []
    # Examples supported: "Group B1 only", "section 2", "grp A".
    for m in re.finditer(
        r"(?i)\b(?:group|grp|section|sec|slot)\s*[:\- ]*\(?([A-Za-z0-9][A-Za-z0-9\-]*)\)?",
        ai_notes,
    ):
        token = m.group(1).strip().upper()
        if token and token not in group_tokens:
            group_tokens.append(token)
    return group_tokens


def _apply_timetable_rules(
    slots: list[ClassSlotExtract],
    *,
    course_codes_allowed: list[str] | None,
    ai_notes: str | None,
) -> tuple[list[ClassSlotExtract], list[str]]:
    warnings: list[str] = []
    allowed = {
        _normalize_course_code(code)
        for code in (course_codes_allowed or [])
        if code.strip()
    }
    group_filters = _extract_group_filters(ai_notes)
    non_numeric_group_filters = [token for token in group_filters if not token.isdigit()]

    kept: list[ClassSlotExtract] = []
    skipped_course = 0
    skipped_group = 0
    for slot in slots:
        normalized_code = _normalize_course_code(slot.course_code)
        if allowed and normalized_code not in allowed:
            skipped_course += 1
            continue
        if group_filters and non_numeric_group_filters:
            searchable = f"{slot.venue or ''} {slot.mode or ''}".upper()
            # Last-chance heuristic for non-table/gemini outputs:
            # avoid numeric-only substring matching (e.g., group "1" matching room "G03:117").
            matched = False
            for token in non_numeric_group_filters:
                token_u = token.upper()
                if re.search(rf"\b{re.escape(token_u)}\b", searchable):
                    matched = True
                    break
            if not matched:
                skipped_group += 1
                continue
        kept.append(slot)

    if allowed:
        warnings.append(
            f"Applied course-code whitelist ({len(allowed)} codes); skipped {skipped_course} slot(s)."
        )
    if group_filters:
        warnings.append(
            f"Applied group filters {group_filters}; skipped {skipped_group} slot(s) without matching hints."
        )
    if ai_notes and not group_filters:
        warnings.append(
            "AI notes were provided but no explicit group token was detected (expected terms like 'group B1')."
        )
    return kept, warnings
