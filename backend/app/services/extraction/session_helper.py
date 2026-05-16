from datetime import date, timedelta, datetime

def _build_term_windows(session_start: date, session_end: date) -> list[dict]:
    start = session_start
    end = session_end
    def clamp(d: date) -> date:
        return d if d <= end else end

    sem1_end_candidate = start + timedelta(days=(23 * 7 - 1))
    sem1_end = clamp(sem1_end_candidate)
    windows: list[dict] = []

    windows.append({
        "id": "sem1",
        "label": "Semester 1",
        "start_date": start.isoformat(),
        "end_date": sem1_end.isoformat(),
    })

    sem2_start = sem1_end + timedelta(days=1)
    if sem2_start <= end:
        windows.append({
            "id": "sem2",
            "label": "Semester 2",
            "start_date": sem2_start.isoformat(),
            "end_date": end.isoformat(),
        })

    if not windows:
        windows.append({
            "id": "full_session",
            "label": "Full session",
            "start_date": start.isoformat(),
            "end_date": end.isoformat(),
        })

    return windows


def _assign_term_id_to_event(ev_start: datetime, ev_end: datetime, windows: list[dict]) -> str:
    for w in windows:
        wstart = datetime.fromisoformat(w["start_date"])
        wend = datetime.fromisoformat(w["end_date"])
        if wstart <= ev_start <= wend:
            return w["id"]
        # overlap fallback
        if not (ev_end < wstart or ev_start > wend):
            return w["id"]
    return windows[0]["id"]