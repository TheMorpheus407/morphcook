# B2B wireframes

Low-fidelity layouts for the screens that a B2B release adds. They use the look
of the app: lowercase italic titles, mono capitals for labels, handwritten notes
in the margin (`~ like this ~`), dashed rules and ink buttons.
[README.md](README.md) explains the architecture behind them, and
[api-surfaces.md](api-surfaces.md) defines the files these screens read and write.

Every copy string exists in English and German, and every screen respects the
reduced-motion setting like the rest of the app.

## App

### 1. Settings: company plan

Without a license the section is one quiet row. Nothing in the app asks a person
to enter a code.

```
┌─ settings ─────────────────────────────┐
│ ...                                    │
│ company plan                           │
│ ~ have a code from your employer? ~    │
│ - - - - - - - - - - - - - - - - - - -  │
│  [ ENTER CODE ]     [ SCAN QR ]        │
│ - - - - - - - - - - - - - - - - - - -  │
│ ...                                    │
└────────────────────────────────────────┘
```

Entering a code opens a sheet. The check runs on the device and answers at once.

```
┌─ your code ────────────────────────────┐
│ ┌────────────────────────────────────┐ │
│ │ eyJ2IjoxLCJraWQiOiIyMDI3LTAxIiwi.. │ │
│ └────────────────────────────────────┘ │
│  PASTE          CANCEL      [ CHECK ]  │
│                                        │
│  ✓ signature ok                        │
│  ✓ valid from 4 jan 2027 to 28 mar     │
│  team menu · collections · challenge   │
│                                        │
│  [ ACTIVATE ]                          │
└────────────────────────────────────────┘
```

Failures name the reason and offer the next step:

| Result | Copy |
|--------|------|
| bad signature, unknown key | "this code is not one of ours. check it for typos, or ask the person who sent it." |
| expired | "this code ran out on 28 mar 2027. ask your program for a new one." |
| not valid yet | "this code starts on 4 jan 2027. come back then." |
| already active | "this code is active already." |

An active plan shows a status card. Removing a plan removes only the license and
the packs. Recipes the person saved from a pack stay in their cookbook.

```
┌─ settings ─────────────────────────────┐
│ company plan                           │
│ ┌────────────────────────────────────┐ │
│ │ ACME HEALTH · Q1 2027              │ │
│ │ active until 28 mar 2027           │ │
│ │ team menu · collections · challenge│ │
│ │ ~ your employer sees nothing about │ │
│ │   what you cook. ~                 │ │
│ └────────────────────────────────────┘ │
│  REMOVE PLAN                           │
└────────────────────────────────────────┘
```

### 2. Plan tab: team menu

A small entry in the week header, present only with the `team-menu` entitlement.

```
┌─ plan ─────────────────────────────────┐
│ the week, penciled in.                 │
│ ══════════════════════════════════════ │
│ ‹  week 3 · 18 – 24 jan  ›  TEAM MENU  │
│ ...                                    │
└────────────────────────────────────────┘
```

```
┌─ team menu · week 3 ───────────────────┐
│ ~ from the canteen ~                   │
│                                        │
│ MON  lunch   lentil & mushroom bolog…  │
│ TUE  lunch   vegan miso mushroom ram…  │
│ WED  lunch   falafel bowl              │
│ THU  lunch   keto döner bowl           │
│ FRI  lunch   creamy vegan alfredo      │
│                                        │
│ each dish shows the version that fits  │
│ your profile.                          │
│                                        │
│ [ ADD TO MY WEEK ]                     │
│ ~ fills empty slots, keeps yours ~     │
└────────────────────────────────────────┘
```

The menu lists dishes. The version that lands in each slot is the one the
matching code picks for the person's profile, so a vegan employee gets the vegan
döner from the same menu. A dish without a fitting version shows a struck-through
row with the same note the dish page uses.

### 3. Insights: challenge card

```
┌─ insights ─────────────────────────────┐
│ VARIETY CHALLENGE · Q1 2027            │
│ 41 unique ingredients this quarter     │
│ ▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░  goal 60          │
│ ~ twenty to go. try a new cuisine. ~   │
│                                        │
│ [ EXPORT MY REPORT ]                   │
└────────────────────────────────────────┘
```

The card reads the numbers the insights screen already computes. With reduced
motion the bar fills at once.

### 4. Report preview

The export shows the file before it leaves the phone, in plain words and as it
will be written.

```
┌─ your report ──────────────────────────┐
│ ~ this is everything the file says ~   │
│                                        │
│ cohort            acme-2027-q1         │
│ period            4 jan – 28 mar       │
│ dishes cooked     23                   │
│ different recipes 17                   │
│ variety score     41                   │
│ plan weeks filled 9                    │
│ diets cooked      vegan 12 · classic 11│
│                                        │
│ the file holds counts and nothing else.│
│ ▸ SHOW THE RAW FILE                    │
│                                        │
│ [ SHARE FILE ]        NOT NOW          │
└────────────────────────────────────────┘
```

The button opens the OS share sheet with `morphcook-report.json`, as backups do.
Nothing is sent by the app.

## Admin console (web, separate repository)

For the HR admin of a customer. It talks to the [admin API](api-surfaces.md#admin-api).

### 5. Cohorts

```
┌─ acme health ─────────────────────────────────────────────┐
│ cohorts                                   [ NEW COHORT ]  │
│ ───────────────────────────────────────────────────────── │
│ NAME            WINDOW              SEATS    ACTIVATED    │
│ acme-2027-q1    4 jan – 28 mar      250      ~ 118 ~      │
│ acme-2026-q4    5 oct – 20 dec      250      ~ 201 ~      │
│                                                           │
│ ~ "activated" counts reports, not people ~                │
└───────────────────────────────────────────────────────────┘
```

The activated column is an estimate from the reports received. The console cannot
know how many people entered a code, because the app never says.

### 6. Issue licenses

```
┌─ acme-2027-q1 · licenses ─────────────────────────────────┐
│ seats issued 250 of 250                                   │
│ ───────────────────────────────────────────────────────── │
│ entitlements   [x] team menu  [x] collections             │
│                [x] challenge  [x] report export           │
│ valid          4 jan 2027 – 28 mar 2027                   │
│                                                           │
│ [ DOWNLOAD CODES (CSV) ]  [ DOWNLOAD QR SHEET (PDF) ]     │
│ ~ codes are shown once. keep the file. ~                  │
└───────────────────────────────────────────────────────────┘
```

### 7. Packs

```
┌─ acme-2027-q1 · packs ────────────────────────────────────┐
│ [ UPLOAD PACK ]                                           │
│ ───────────────────────────────────────────────────────── │
│ canteen-menu-w03      menu        ✓ gates passed          │
│ canteen-collection    collection  ✗ 2 issues              │
│   recipe canteen-salad-vegan: labelled vegan but its      │
│   flags say honey                                         │
│   recipe canteen-soup-classic: step 3 states a quantity   │
│                                                           │
│ published packs reach phones as files, see "share"        │
└───────────────────────────────────────────────────────────┘
```

The issues come from the same gates as the bundled corpus, worded the same way.

### 8. Reports

```
┌─ acme-2027-q1 · reports ──────────────────────────────────┐
│ received 118 · shown when 10 or more                      │
│ ───────────────────────────────────────────────────────── │
│ cooking per person   median 4   ▁▂▅▇▅▃▂                   │
│ variety score        median 38  ▁▃▆▇▄▂▁                   │
│ diets cooked         classic 46% · vegan 31% · other 23%  │
│ plan weeks filled    median 6                             │
│                                                           │
│ [ EXPORT AS CSV ]                                         │
└───────────────────────────────────────────────────────────┘
```

A cohort with fewer than 10 reports shows how many arrived and none of the
aggregates.
