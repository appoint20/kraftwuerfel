import {
  WEEKDAYS,
  normalizeDate,
  daysBetween,
  weekInfoForDate,
  mostRecentWeekdayOnOrBefore,
  nextWeekdayOnOrAfter,
  DATE_FMT,
} from "./dateUtils.js";

export function getProgress(activePlan, today = new Date()) {
  if (!activePlan) return null;
  const start = new Date(activePlan.startDate);
  const { weekIdx, cycleIdx } = weekInfoForDate(today, start);
  const finished = weekIdx > activePlan.duration;
  const todayLabel = WEEKDAYS[(today.getDay() + 6) % 7];
  const isTrainingDay = !finished && activePlan.days.includes(todayLabel);
  const daysLeftTotal = activePlan.duration * 7 - daysBetween(start, today) - 1;
  return { weekIdx, cycleIdx, finished, todayLabel, isTrainingDay, daysLeftTotal: Math.max(0, daysLeftTotal) };
}

export function getLastTrained(activePlan, day, today = new Date()) {
  if (!activePlan) return null;
  const start = new Date(activePlan.startDate);
  const recent = mostRecentWeekdayOnOrBefore(today, day);
  if (recent < normalizeDate(start)) {
    const upcoming = nextWeekdayOnOrAfter(today, day);
    return { upcoming: true, inDays: daysBetween(today, upcoming) };
  }
  const { weekIdx, cycleIdx } = weekInfoForDate(recent, start);
  return {
    upcoming: false,
    weekIdx,
    cycleIdx,
    daysAgo: daysBetween(recent, today),
    isToday: daysBetween(recent, today) === 0,
    dateLabel: DATE_FMT.format(recent),
  };
}
