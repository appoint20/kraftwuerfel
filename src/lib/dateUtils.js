export const WEEKDAYS = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"];
export const WEEKDAY_JS_INDEX = { Mo: 1, Di: 2, Mi: 3, Do: 4, Fr: 5, Sa: 6, So: 0 };

export const DATE_FMT = new Intl.DateTimeFormat("de-DE", { day: "2-digit", month: "2-digit" });

export function normalizeDate(d) {
  const n = new Date(d);
  n.setHours(0, 0, 0, 0);
  return n;
}

export function daysBetween(a, b) {
  return Math.round((normalizeDate(b) - normalizeDate(a)) / 86400000);
}

export function weekInfoForDate(date, startDate) {
  const diff = daysBetween(startDate, date);
  const weekIdx = Math.floor(diff / 7) + 1;
  const cycleIdx = Math.floor((weekIdx - 1) / 2); // 0-basiert: Woche 1-2 -> 0, Woche 3-4 -> 1, ...
  return { weekIdx, cycleIdx, diff };
}

export function mostRecentWeekdayOnOrBefore(refDate, weekdayLabel) {
  const targetIdx = WEEKDAY_JS_INDEX[weekdayLabel];
  const d = normalizeDate(refDate);
  const diff = (d.getDay() - targetIdx + 7) % 7;
  d.setDate(d.getDate() - diff);
  return d;
}

export function nextWeekdayOnOrAfter(refDate, weekdayLabel) {
  const targetIdx = WEEKDAY_JS_INDEX[weekdayLabel];
  const d = normalizeDate(refDate);
  const diff = (targetIdx - d.getDay() + 7) % 7;
  d.setDate(d.getDate() + diff);
  return d;
}

export const sortWeekdays = (daysSet) =>
  WEEKDAYS.filter((d) => (daysSet && daysSet.has ? daysSet.has(d) : (daysSet || []).includes(d)));
