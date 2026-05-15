#!/usr/bin/env python3
"""Compute today's sunrise, sunset, and time-of-day window starts locally.

No network. Uses the NOAA solar position formulas (the same math behind
gml.noaa.gov/grad/solcalc/solareqns.PDF) plus user-configured offsets to
emit a small env-style file consumed by aerial_dispatch.sh.

Usage:
    compute_sun_times.py <lat> <lng> <tz_name> \
        <morning_offset_min> <day_offset_min> \
        <evening_offset_min> <night_offset_min>

Output (to stdout) -- shell-sourceable env file:
    SUNRISE="HH:MM"
    SUNSET="HH:MM"
    MORNING_START="HH:MM"
    DAY_START="HH:MM"
    EVENING_START="HH:MM"
    NIGHT_START="HH:MM"
    UPDATED_AT="YYYY-MM-DDTHH:MM:SS+ZZ:ZZ"
"""

import math
import sys
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo


def solar_event_utc(date_utc, lat_deg, lng_deg, event):
    """Return UTC datetime of sunrise or sunset on date_utc at (lat, lng).

    Uses the NOAA general solar position equations. event is "sunrise" or
    "sunset". Zenith for apparent sunrise/sunset (with atmospheric
    refraction): 90.833 degrees.
    """
    if event not in ("sunrise", "sunset"):
        raise ValueError(event)

    day_of_year = date_utc.timetuple().tm_yday
    is_leap = (date_utc.year % 4 == 0 and date_utc.year % 100 != 0) or (
        date_utc.year % 400 == 0
    )
    days_in_year = 366 if is_leap else 365

    # Fractional year (radians).
    gamma = 2 * math.pi / days_in_year * (day_of_year - 1 + 12 / 24)

    # Equation of time (minutes).
    eqtime = 229.18 * (
        0.000075
        + 0.001868 * math.cos(gamma)
        - 0.032077 * math.sin(gamma)
        - 0.014615 * math.cos(2 * gamma)
        - 0.040849 * math.sin(2 * gamma)
    )

    # Solar declination (radians).
    decl = (
        0.006918
        - 0.399912 * math.cos(gamma)
        + 0.070257 * math.sin(gamma)
        - 0.006758 * math.cos(2 * gamma)
        + 0.000907 * math.sin(2 * gamma)
        - 0.002697 * math.cos(3 * gamma)
        + 0.00148 * math.sin(3 * gamma)
    )

    lat_rad = math.radians(lat_deg)
    zenith_rad = math.radians(90.833)

    cos_ha = (math.cos(zenith_rad) - math.sin(lat_rad) * math.sin(decl)) / (
        math.cos(lat_rad) * math.cos(decl)
    )
    if cos_ha > 1 or cos_ha < -1:
        # Polar day or night: no sunrise/sunset.
        raise ValueError(
            f"No {event} at lat={lat_deg} on {date_utc.date().isoformat()} "
            "(polar day or night)"
        )

    # NOAA convention (per gml.noaa.gov/grad/solcalc/solareqns.PDF):
    #   longitude is positive EAST of Greenwich
    #   ha is POSITIVE for sunrise, NEGATIVE for sunset
    #   sunrise/sunset (UTC, minutes from midnight) = 720 - 4*(lng + ha) - eqtime
    ha_rad = math.acos(cos_ha)
    if event == "sunrise":
        ha_deg = math.degrees(ha_rad)
    else:
        ha_deg = -math.degrees(ha_rad)

    minutes_utc = 720 - 4 * (lng_deg + ha_deg) - eqtime
    minutes_utc %= 1440

    midnight_utc = datetime(
        date_utc.year, date_utc.month, date_utc.day, tzinfo=timezone.utc
    )
    return midnight_utc + timedelta(minutes=minutes_utc)


def hm(dt):
    return dt.strftime("%H:%M")


def main():
    if len(sys.argv) != 8:
        print(__doc__, file=sys.stderr)
        sys.exit(2)

    lat = float(sys.argv[1])
    lng = float(sys.argv[2])
    tz_name = sys.argv[3]
    morning_off = int(sys.argv[4])
    day_off = int(sys.argv[5])
    evening_off = int(sys.argv[6])
    night_off = int(sys.argv[7])

    tz = ZoneInfo(tz_name)
    today_local = datetime.now(tz).date()
    today_utc = datetime(
        today_local.year, today_local.month, today_local.day, tzinfo=timezone.utc
    )

    sunrise_utc = solar_event_utc(today_utc, lat, lng, "sunrise")
    sunset_utc = solar_event_utc(today_utc, lat, lng, "sunset")

    sunrise = sunrise_utc.astimezone(tz)
    sunset = sunset_utc.astimezone(tz)

    morning_start = sunrise + timedelta(minutes=morning_off)
    day_start = sunrise + timedelta(minutes=day_off)
    evening_start = sunset + timedelta(minutes=evening_off)
    night_start = sunset + timedelta(minutes=night_off)

    print(f'SUNRISE="{hm(sunrise)}"')
    print(f'SUNSET="{hm(sunset)}"')
    print(f'MORNING_START="{hm(morning_start)}"')
    print(f'DAY_START="{hm(day_start)}"')
    print(f'EVENING_START="{hm(evening_start)}"')
    print(f'NIGHT_START="{hm(night_start)}"')
    print(f'UPDATED_AT="{datetime.now(tz).isoformat(timespec="seconds")}"')
    # Location stamp -- the dispatcher uses this to detect config changes
    # and force a recompute mid-day if lat/lng/tz changed.
    print(f'LOCATION_KEY="{lat}|{lng}|{tz_name}"')


if __name__ == "__main__":
    main()
