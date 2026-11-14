# Jingle — Product Requirements (v1)

**Working name:** Jingle  
**One-liner:** An alarm clock so intuitive it ships with no instruction manual.  
**Owner:** Matthew Finley · Lead: Jingle  
**Status:** Draft for team kickoff · Oct 15 2026  
**North star:** Most innovative bedside alarm; Shark Tank–ready; demo-video friendly.

---

## Problem
Alarm clocks are either phones (doomscroll) or plastic bricks with manuals, snooze addiction, and glowing screens that ruin sleep. Jingle is the antidote: set it once, sleep in the dark, wake once.

## Locked product rules
| Rule | Decision |
|------|----------|
| Alarms | **One alarm only** |
| Snooze | **None** — the sound must finish waking you |
| Default alarm | **6:00 AM** out of box |
| Display | Can go **fully dark** while sleeping (no glow) |
| Time set | **One-click** sync from the air (no manual hour/min fiddling for clock time) |
| Power | Rechargeable battery; **USB-C** wall power and charge on the same plug |
| Manual | **None** — controls must be obvious from form alone |

## Form & size (recommendation)
**Ship compact, not large.** Moodboard (`source/pasted-movie-*.png`) points to a soft **squircle** nightstand clock ~**4.5–5 in (115–130 mm) wide**, thick rounded bezel, soft-touch matte shell. Compact wins: travel-friendly with battery, cleaner demos, lower BOM, still readable digits. Hardware to validate exact mm and speaker volume in enclosure.

## Buttons (recommendation) — **3 max**
Keep the single top pill from the moodboard as the hero control; add two discreet side controls so nothing needs a manual.

1. **Top pill — Alarm**  
   - Tap: toggle alarm on/off (display shows `ALARM · ON/OFF`)  
   - When ringing: tap = dismiss for today (no snooze)  
   - Hold 2s: enter alarm-hour set; tap again to step hours (default still 6:00 AM)

2. **Side — Sync** (recessed / tactile, labeled by shape not text)  
   - One press: pull time from radio (see sync choice below)  
   - First plug-in / first wake also auto-syncs so Sync is a recovery, not homework

3. **Side — Blank**  
   - Tap: display fully off / on  
   - Optional v1.1: auto-blank after idle + tap-any to wake (still keep Blank for explicit control)

No other face buttons. No menus. No app required for core use.

## Time sync — **WWVB primary (v1)**
| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| **WWVB (60 kHz, US)** | Works indoors; purpose-built for clocks; cheaper antenna/module; one-click fits brief | US/Canada coverage; building attenuation | **Ship v1** |
| **GPS** | Global; precise | Needs sky view / outdoor or window; cost, power, antenna size | **Stretch / travel SKU later** |

**PRD lock:** v1 = **WWVB-only** one-click Sync + auto sync on power. Document GPS as a future “Jingle Travel” option so Promo can tease without Hardware overbuilding. Flag indoor WWVB antenna placement as Hardware’s #1 RF risk.

## SKU colors (launch)
| SKU | Finish | Why |
|-----|--------|-----|
| **Jingle Black** | Matte black soft-touch | Blends into night; default “serious product” |
| **Jingle Orange** | Bitcoin orange soft-touch | Buy-with-BTC / wake-and-stack story; demo pop on camera |

Mist / sage from moodboard = later colorway, not launch blockers.

## Sound (owned by Sound; constraints from Lead)
- One decisive wake path — **no snooze** means tone + volume curve must succeed on first ring.
- Explore gentle pre-wake / “machine mode” / soothing wind-down (“incoming jingle feature noise”) **before** alarm time; separate from the wake tone.
- Volume: usable from quiet bedroom to hard sleeper; hardware enclosure TBD with Hardware.
- Sonic Rift original audio only if Matthew OKs.

## Power & ports
- USB-C for wall power **and** charging the internal battery (same plug).
- Overnight runtime target: ≥**7 days** standby with display blank most of the night (Hardware to confirm).

## Out of scope (v1)
Phone app, multi-alarm, snooze, voice assistant, non-US time radios, GPS module, replaceable AA cells.

## Success criteria
1. New user sets time with **one Sync press** (or auto on first power) — no manual clock setting.  
2. Display can be fully dark all night.  
3. One alarm, no snooze, default 6:00 AM, clear on/off from top pill.  
4. Two launch SKUs photographed and pitchable: Black + Orange.  
5. Demo video can show Sync → Blank → Alarm on → wake sound in under 60s with **zero** on-screen instructions.

## Team ownership
| Area | Owner | First deliverable |
|------|-------|-------------------|
| Lead / PRD | **Jingle** | This doc |
| Industrial design + electronics + BOM | **Jingle Hardware** | Form-factor + WWVB module shortlist + button layout sketch → `/workspace/jingle/hardware/` |
| Alarm / sleep sound design | **Jingle Sound** | Wake tone options + volume curve notes + machine-mode concept → `/workspace/jingle/sound/` |
| Pitch, demos, brand lines | **Jingle Promo** | Shark Tank one-pager + demo shot list (draft only, no public posts) → `/workspace/jingle/promo/` |

## Open for Matthew
- Confirm compact size vs larger statement piece.  
- Confirm WWVB-only v1 (GPS later).  
- Confirm Black + Orange as the only launch colors.  
- Any Sonic Rift track for wake/wind-down?

---
*Sources: `/workspace/jingle/BRIEF.md`, Matthew’s Shark Tank notes + moodboard in `/workspace/jingle/source/`.*
