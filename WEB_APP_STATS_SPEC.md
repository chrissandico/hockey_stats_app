# 🏒 Hockey Stats Web App Analytics & API Specification

This document provides the complete technical specification, Google Sheets data schema, derived hockey statistics formulas, and JavaScript/TypeScript code snippets for implementing team analytics on the web application.

---

## 1. Google Sheets Data Schema (`Events` Tab)

Each row in the `Events` sheet represents an individual game event logged by the mobile app:

| Column | Header Name | Data Type | Description / Allowed Values |
| :---: | :--- | :--- | :--- |
| **A** | `EventId` | String | Unique UUID of the event |
| **B** | `GameId` | String | Unique ID of the game |
| **C** | `Timestamp` | String | Format: `YYYY-MM-DD HH:MM:SS` |
| **D** | `Period` | Integer | `1`, `2`, `3`, or `4` (OT) |
| **E** | `EventType` | String | `'Shot'`, `'Goal'`, or `'Penalty'` |
| **F** | `Team` | String | `'your_team'` (or team ID) vs `'opponent'` |
| **G** | `PrimaryPlayerId` | String | Player ID of shooter or penalized player |
| **H** | `AssistPlayer1Id` | String | Player ID of 1st assist (if goal) |
| **I** | `AssistPlayer2Id` | String | Player ID of 2nd assist (if goal) |
| **J** | `IsGoal` | Boolean | `TRUE` or `FALSE` |
| **K** | `GoalSituation` | String | `'Even Strength'`, `'Power Play'`, or `'Penalty Kill'` — **see the definition below; this column is the contract every calculator in every app must implement identically** |

### Column K definition (canonical — ratified 2026-10-18)

`GoalSituation` records **our team's manpower state at the moment of the event**, independent of which team the event belongs to:

| Stored value | Means | If our team scores | If the opponent scores |
| :--- | :--- | :--- | :--- |
| `'Power Play'` | **We** have the manpower advantage | Power-play goal | **Short-handed goal against** |
| `'Penalty Kill'` | **We** are short-handed | Short-handed goal for | **Power-play goal allowed** |
| `'Even Strength'` | Equal skaters (5v5, 4v4, 3v3 OT) | Even-strength goal | Even-strength goal against |
| *(empty)* | Legacy / not recorded | Treat as Even Strength in every calculation | |

> **Legacy data note:** before 2026-10-18 some stat keepers recorded this column from the *scoring team's* perspective in the per-event edit screens, while the live game screen recorded it from our team's perspective. Historical rows can therefore mix the two readings and no per-row test can tell them apart. Numbers for older games are only as exact as the style their keeper used; everything logged after the fix follows the table above. (See the fix plan: `hockey-stats-special-teams-fix-plan.md`.)
>
> **Coincident penalties:** for matching/coincident penalties (play is 4-on-4, even strength), keepers should **not** set a Power Play / Penalty Kill situation; log the penalties for penalty minutes only.
| **L** | `PenaltyType` | String | e.g. `'Tripping'`, `'Hooking'`, `'Slashing'` |
| **M** | `PenaltyDuration` | Integer | Penalty duration in minutes (e.g., `2`, `5`) |
| **N** | `yourTeamPlayersOnIce` | String | Comma-separated on-ice player IDs (e.g. `"p88,p19,p4,p2"`) |
| **O** | `goalieOnIceId` | String | Goalie ID in net facing shot (e.g. `"g50"` or `"opponent_g"`) |

### Related Sheets
- **`Players` Sheet**: Maps `PlayerId` -> `JerseyNumber`, `Position` (`C`, `LW`, `RW`, `D`, `G`).
- **`Games` Sheet**: Maps `GameId` -> `Opponent`, `Date`, `Location`, `GameType`.

---

## 2. Derived Special Teams Metrics

### ⚡ Power Play Percentage (PP%)
$$\text{PP\%} = \frac{\text{PP Goals}}{\text{PP Opportunities}} \times 100$$
- **PP Goals**: Rows where `EventType == 'Shot'`, `IsGoal == TRUE`, `Team == 'your_team'`, and `GoalSituation == 'Power Play'`.
- **PP Opportunities**: Rows where `EventType == 'Penalty'` and `Team == 'opponent'`. *(Note: If $\text{PP Goals} > \text{Penalties Drawn}$, set $\text{PP Opportunities} = \text{PP Goals}$).*

### 🛡️ Penalty Kill Percentage (PK%)
$$\text{PK\%} = \frac{\text{PK Opportunities} - \text{PP Goals Allowed}}{\text{PK Opportunities}} \times 100$$
- **PP Goals Allowed**: Rows where `EventType == 'Shot'`, `IsGoal == TRUE`, `Team == 'opponent'`, and `GoalSituation == 'Penalty Kill'` (the opponent scored while **we** were short-handed — see the Column K definition).
- **PK Opportunities**: Rows where `EventType == 'Penalty'` and `Team == 'your_team'`. *(Note: If $\text{PP Goals Allowed} > \text{Penalties Taken}$, set $\text{PK Opportunities} = \text{PP Goals Allowed}$.)*

### 🎯 Power Play Shots Per Opportunity (S/PP)
$$\text{S/PP} = \frac{\text{Total PP Shots}}{\text{PP Opportunities}}$$
- **PP Shots**: Rows where `EventType == 'Shot'`, `Team == 'your_team'`, and `GoalSituation == 'Power Play'`.
- **Benchmark**: $\ge 1.5 - 2.0+$ shots per PP indicates strong offensive execution.

### 🧤 Shots Allowed Per Penalty Kill (SA/PK)
$$\text{SA/PK} = \frac{\text{Opponent Shots on our PK}}{\text{PK Opportunities}}$$
- **Opponent Shots on our PK**: Rows where `EventType == 'Shot'`, `Team == 'opponent'`, and `GoalSituation == 'Penalty Kill'`. (Opponent shots while **we** are on the power play — stamped `'Power Play'` — are short-handed shots against; they are **not** PK shots allowed.)
- **Benchmark**: $< 1.5$ shots allowed per PK indicates disciplined defensive structure.

### ⚖️ Net Special Teams Goals
$$\text{Net ST Goals} = (\text{PPG} + \text{SHGF}) - (\text{PPGA} + \text{SHGA})$$
- **SHGF** (Short-Handed Goals For): Goals where `Team == 'your_team'` and `GoalSituation == 'Penalty Kill'`.
- **SHGA** (Short-Handed Goals Allowed): Goals where `Team == 'opponent'` and `GoalSituation == 'Power Play'` (the opponent scored short-handed, while **we** were on the power play). SHGA is a distinct bucket — it must never be folded into PP Goals Allowed / PK goals conceded.

### 📊 Combined Special Teams Index (100% Benchmark)
$$\text{ST Index} = \text{PP\%} + \text{PK\%}$$
- **Benchmark**: $100.0\%$ (e.g. $20\%\text{ PP} + 80\%\text{ PK}$) is the standard target. $>105\%$ is elite.

### ➕ Plus/Minus (+/-) Attribution
Award +1 / −1 to the skaters listed on the goal event (`YourTeamPlayersOnIce` / `OpponentPlayersOnIce`) **only when the scoring team was at even strength or short-handed** — a goal scored by a team on its own power play awards nothing. Resolved against the Column K definition (our team's state):

| Event | `'Power Play'` (we have PP) | `'Penalty Kill'` (we're on PK) | `'Even Strength'` / empty |
| :--- | :--- | :--- | :--- |
| Our team scores | **no +/-** (our PP goal) | **+1** (our SH goal) | **+1** |
| Opponent scores | **−1** (their SH goal) | **no +/-** (their PP goal) | **−1** |

A penalty-shot goal (where recorded) awards no +/- to anyone, regardless of the stamp.

### 🟨 Discipline Index (Net Penalty Advantage)
$$\text{Net Penalties} = \text{Penalties Drawn} - \text{Penalties Taken}$$

---

## 3. On-Ice Lineup Analytics (Player Corsi)

Parse Column N (`yourTeamPlayersOnIce`) to measure shot possession and puck control while a skater is on the ice:

### 📈 On-Ice Shots For vs. Shots Against ($SF / SA$)
- **On-Ice Shots For ($SF_{\text{on}}$)**: Count rows where `EventType == 'Shot'`, `Team == 'your_team'`, and Column N contains `playerId`.
- **On-Ice Shots Against ($SA_{\text{on}}$)**: Count rows where `EventType == 'Shot'`, `Team == 'opponent'`, and Column N contains `playerId`.
- **Net On-Ice Shot Differential**: $SF_{\text{on}} - SA_{\text{on}}$
- **On-Ice Shot Share ($SF\%$)**: $\frac{SF_{\text{on}}}{SF_{\text{on}} + SA_{\text{on}}} \times 100$

---

## 4. Goalie Advanced Analytics

### 🥅 Goalie Shots, Saves & Save %
- **Shots Against (SA)**: Rows where `EventType == 'Shot'`, `Team == 'opponent'`, and `goalieOnIceId == goalieId`.
- **Goals Against (GA)**: Rows where `EventType == 'Shot'`, `IsGoal == TRUE`, `Team == 'opponent'`, and `goalieOnIceId == goalieId`.
- **Saves (SV)**: $SA - GA$
- **Save % (SV%)**: $\frac{SV}{SA} \times 100$

### ⏱️ Situational & Period Save %
- **Even-Strength SV% vs. PK SV%**: Filter shots faced where `GoalSituation == 'Even Strength'` vs `'Power Play'`.
- **Save % by Period (P1, P2, P3, OT)**: Filter shots faced by Column D (`Period`).

---

## 5. TypeScript Reference Implementation

Copy and paste this helper file into your web application codebase:

```typescript
export interface EventRow {
  eventId: string;
  gameId: string;
  timestamp: string;
  period: number;
  eventType: 'Shot' | 'Goal' | 'Penalty';
  team: string; // 'your_team' or 'opponent'
  primaryPlayerId: string;
  assist1Id?: string;
  assist2Id?: string;
  isGoal: boolean;
  goalSituation?: 'Even Strength' | 'Power Play' | 'Penalty Kill';
  penaltyType?: string;
  penaltyDuration?: number;
  yourTeamPlayersOnIce: string[]; // parsed from Column N
  goalieOnIceId?: string;
}

export interface SpecialTeamsSummary {
  ppGoals: number;
  ppOpportunities: number;
  ppPercentage: number;
  ppShotsPerOpp: number;
  pkOpportunities: number;
  pkGoalsConceded: number;
  pkSuccesses: number;
  pkPercentage: number;
  pkShotsAllowedPerOpp: number;
  netSpecialTeamsGoals: number;
  combinedSTIndex: number;
  netPenalties: number;
}

export function calculateSpecialTeamsStats(events: EventRow[], teamId = 'your_team'): SpecialTeamsSummary {
  // Column K definition: goalSituation is OUR team's manpower state.
  // 'Power Play' = we have the advantage; 'Penalty Kill' = we are short-handed.
  // These masks intentionally mirror the reference implementation in the stats
  // viewer (_special_teams_summary_from_events) and the Flutter app
  // (StatsService.getSpecialTeamsStats) — all three must stay identical.
  let ppGoals = 0;
  let rawPpOpps = 0;
  let pkGoalsConceded = 0;
  let rawPkOpps = 0;
  let shGoalsFor = 0;
  let shGoalsAgainst = 0;
  let ppShots = 0;
  let pkShotsAllowed = 0;

  for (const event of events) {
    const isYourTeam = event.team === teamId;

    if (event.eventType === 'Shot') {
      if (event.isGoal) {
        if (event.goalSituation === 'Power Play') {
          if (isYourTeam) ppGoals++;
          else shGoalsAgainst++; // their short-handed goal — NOT a PK concession
        } else if (event.goalSituation === 'Penalty Kill') {
          if (isYourTeam) shGoalsFor++;
          else pkGoalsConceded++; // their power-play goal
        }
      }

      if (event.goalSituation === 'Power Play') {
        if (isYourTeam) ppShots++;
        // opponent shots under 'Power Play' are short-handed shots against:
        // they are NOT shots allowed on our penalty kill
      } else if (event.goalSituation === 'Penalty Kill') {
        if (!isYourTeam) pkShotsAllowed++;
      }
    } else if (event.eventType === 'Penalty') {
      if (isYourTeam) rawPkOpps++;
      else rawPpOpps++;
    }
  }

  const ppOpps = Math.max(rawPpOpps, ppGoals);
  const pkOpps = Math.max(rawPkOpps, pkGoalsConceded);

  const ppPct = ppOpps > 0 ? (ppGoals / ppOpps) * 100 : 0;
  const pkSuccesses = pkOpps - pkGoalsConceded;
  const pkPct = pkOpps > 0 ? (pkSuccesses / pkOpps) * 100 : 100;

  return {
    ppGoals,
    ppOpportunities: ppOpps,
    ppPercentage: Number(ppPct.toFixed(1)),
    ppShotsPerOpp: Number((ppOpps > 0 ? ppShots / ppOpps : 0).toFixed(1)),
    pkOpportunities: pkOpps,
    pkGoalsConceded,
    pkSuccesses,
    pkPercentage: Number(pkPct.toFixed(1)),
    pkShotsAllowedPerOpp: Number((pkOpps > 0 ? pkShotsAllowed / pkOpps : 0).toFixed(1)),
    netSpecialTeamsGoals: (ppGoals + shGoalsFor) - (pkGoalsConceded + shGoalsAgainst),
    combinedSTIndex: Number((ppPct + pkPct).toFixed(1)),
    netPenalties: rawPpOpps - rawPkOpps,
  };
}

export function calculatePlayerOnIceCorsi(events: EventRow[], playerId: string, teamId = 'your_team') {
  let shotsFor = 0;
  let shotsAgainst = 0;

  for (const event of events) {
    if (event.eventType === 'Shot' && event.yourTeamPlayersOnIce?.includes(playerId)) {
      if (event.team === teamId) shotsFor++;
      else shotsAgainst++;
    }
  }

  const netShots = shotsFor - shotsAgainst;
  const totalShots = shotsFor + shotsAgainst;
  const share = totalShots > 0 ? (shotsFor / totalShots) * 100 : 0;

  return {
    shotsFor,
    shotsAgainst,
    netShots,
    shotSharePercentage: Number(share.toFixed(1)),
  };
}
```
