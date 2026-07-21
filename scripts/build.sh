#!/bin/bash
set -e

REPO_ROOT=$(git rev-parse --show-toplevel)
CONTENT_DIR="$REPO_ROOT/content"
DATA_DIR="$REPO_ROOT/src/data"
PROGRESS_FILE="$REPO_ROOT/progress.json"

mkdir -p "$CONTENT_DIR"

YEAR=$(date +%Y)
MONTH=$(date +%m)
DAY=$(date +%d)
DAY_OF_WEEK=$(date +%u)
DAY_OF_YEAR=$(date +%j | sed 's/^0*//')
DATE_STR=$(date +%Y-%m-%d)
MONTH_NAME=$(date +%B)
DAY_NAME=$(date +%A)
WEEK_NUM=$(date +%V)

MONTH_NUM=$((10#$MONTH))
DAY_NUM=$((10#$DAY))

if (( YEAR % 4 == 0 && (YEAR % 100 != 0 || YEAR % 400 == 0) )); then
  TOTAL_DAYS=366
else
  TOTAL_DAYS=365
fi

PERCENTAGE=$(awk "BEGIN {printf \"%.1f\", ($DAY_OF_YEAR / $TOTAL_DAYS) * 100}")

if [ -f "$CONTENT_DIR/$DATE_STR.md" ]; then
  echo "Content for $DATE_STR already exists — skipping"
  exit 0
fi

if [ -f "$PROGRESS_FILE" ]; then
  FEATURE_INDEX=$(jq -r '.feature_index // 0' "$PROGRESS_FILE")
  LAST_DATE=$(jq -r '.last_date // ""' "$PROGRESS_FILE")
  PREV_STREAK=$(jq -r '.streak // 0' "$PROGRESS_FILE")
  LONGEST_STREAK=$(jq -r '.longest_streak // 0' "$PROGRESS_FILE")
  YEAR_GOAL=$(jq -r '.year_goal // 300' "$PROGRESS_FILE")
else
  FEATURE_INDEX=0
  LAST_DATE=""
  PREV_STREAK=0
  LONGEST_STREAK=0
  YEAR_GOAL=300
fi

YESTERDAY=$(date -d "yesterday" +%Y-%m-%d)
if [ "$LAST_DATE" = "$YESTERDAY" ]; then
  STREAK=$((PREV_STREAK + 1))
else
  STREAK=1
fi

if [ "$STREAK" -gt "$LONGEST_STREAK" ]; then
  LONGEST_STREAK=$STREAK
fi

if [ $MONTH_NUM -le 2 ] || [ $MONTH_NUM -eq 12 ]; then
  SEASON="Dry Season (Harmattan)"
  SEASON_DESC="Cool and dry with harmattan winds carrying dust from the Sahara"
elif [ $MONTH_NUM -le 5 ]; then
  SEASON="Early Rainy Season"
  SEASON_DESC="Increasing rainfall, fresh greenery, occasional thunderstorms"
elif [ $MONTH_NUM -le 9 ]; then
  SEASON="Peak Rainy Season"
  SEASON_DESC="Heavy rainfall, high humidity, lush vegetation"
else
  SEASON="Late Rainy Season"
  SEASON_DESC="Gradual transition back to dry season"
fi

HOLIDAY_MSG=""
HOLIDAY_MATCH=$(jq -r --arg m "$MONTH" --arg d "$DAY" '.[] | select(.month == ($m|tonumber) and .day == ($d|tonumber)) | "\(.emoji) **\(.name)** — \(.message)"' "$DATA_DIR/holidays.json" | head -1)
if [ -n "$HOLIDAY_MATCH" ]; then
  HOLIDAY_MSG="$HOLIDAY_MATCH"
fi

MONTH_CELEBRATION=""
if [ "$DAY" = "01" ] && [ "$MONTH_NUM" -ne 1 ]; then
  MONTH_CELEBRATION="🎉 Welcome to $MONTH_NAME! A new month — fresh momentum."
elif [ "$DAY" = "01" ] && [ "$MONTH_NUM" -eq 1 ]; then
  MONTH_CELEBRATION=""
fi

YEAR_CELEBRATION=""
if [ "$MONTH" = "01" ] && [ "$DAY" = "01" ]; then
  YEAR_CELEBRATION="🎆 **Happy New Year $YEAR!** Day 1 of $TOTAL_DAYS. Let's make it count."
fi

BIRTHDAY_MSG=""
if [ "$MONTH" = "08" ] && [ "$DAY" = "29" ]; then
  BIRTHDAY_MSG="🎂 **Happy Birthday, Ayoola Damisile!** 🎉 Another trip around the sun — keep building."
fi

WEEKEND_VIBE=""
if [ "$DAY_OF_WEEK" = "5" ]; then
  WEEKEND_VIBE="🚀 Friday energy — wrap up the week strong!"
elif [ "$DAY_OF_WEEK" = "6" ]; then
  WEEKEND_VIBE="🌿 Saturday — keep building, but take it easy."
elif [ "$DAY_OF_WEEK" = "7" ]; then
  WEEKEND_VIBE="☕ Sunday — rest, reflect, and plan the week ahead."
fi

TOTAL_TECH_EVENTS=$(jq ".[\"$MONTH-$DAY\"] | length" "$DATA_DIR/tech-history.json" 2>/dev/null || echo "0")
TECH_INDEX=$(( FEATURE_INDEX % (TOTAL_TECH_EVENTS > 0 ? TOTAL_TECH_EVENTS : 1) ))
TECH_YEAR=$(jq -r ".[\"$MONTH-$DAY\"][$TECH_INDEX].year" "$DATA_DIR/tech-history.json" 2>/dev/null || echo "0")
TECH_EVENT=$(jq -r ".[\"$MONTH-$DAY\"][$TECH_INDEX].event" "$DATA_DIR/tech-history.json" 2>/dev/null || echo "")
if [ -z "$TECH_EVENT" ] || [ "$TECH_EVENT" = "null" ]; then
  TECH_YEAR=""
  TECH_EVENT="No major tech event recorded for this date."
fi

# Extract recent events (2015+) for "Today" section
RECENT_EVENTS=""
if [ "$TOTAL_TECH_EVENTS" -gt 0 ]; then
  RECENT_EVENTS=$(jq -r ".[\"$MONTH-$DAY\"][] | select(.year >= 2015) | \"**\\(.year)** — \\(.event)\"" "$DATA_DIR/tech-history.json" 2>/dev/null | head -5)
fi

TOTAL_QUOTES=$(jq 'length' "$DATA_DIR/quotes.json")
QUOTE_INDEX=$(( FEATURE_INDEX % TOTAL_QUOTES ))
QUOTE=$(jq -r ".[$QUOTE_INDEX]" "$DATA_DIR/quotes.json")

TOTAL_TIL=$(jq 'length' "$DATA_DIR/til.json")
TIL_INDEX=$(( FEATURE_INDEX % TOTAL_TIL ))
TIL_FACT=$(jq -r ".[$TIL_INDEX]" "$DATA_DIR/til.json")

BUILD_NUM=$((FEATURE_INDEX + 1))

STREAK_ICON="✨"
if [ "$STREAK" -ge 30 ]; then
  STREAK_ICON="🌟"
elif [ "$STREAK" -ge 7 ]; then
  STREAK_ICON="🔥"
elif [ "$STREAK" -ge 3 ]; then
  STREAK_ICON="💪"
fi

# Day-based greeting
case $DAY_OF_WEEK in
  1) GREETING="Happy Monday" ;;
  2) GREETING="Tuesday push" ;;
  3) GREETING="Midweek grind" ;;
  4) GREETING="Thursday momentum" ;;
  5) GREETING="Friday energy" ;;
  6) GREETING="Weekend builder" ;;
  7) GREETING="Sunday reflection" ;;
esac

# Find prev/next entries
SORTED_FILES=$(ls "$CONTENT_DIR"/*.md 2>/dev/null | grep -v "week-\|recap" | sort)
PREV_FILE=""
NEXT_FILE=""
PREV_SET=0
for sf in $SORTED_FILES; do
  sfname=$(basename "$sf" .md)
  if [ "$sfname" = "$DATE_STR" ]; then
    PREV_SET=1
    continue
  fi
  if [ "$PREV_SET" -eq 0 ]; then
    PREV_FILE="$sfname"
  else
    if [ -z "$NEXT_FILE" ]; then
      NEXT_FILE="$sfname"
    fi
  fi
done

cat > "$CONTENT_DIR/$DATE_STR.md" << EOF
# Day $DAY_OF_YEAR of $YEAR — $DAY_NAME, $MONTH_NAME $DAY

$GREETING, Ayoola. $STREAK_ICON $STREAK-day streak.

> *"$QUOTE"*

---

💡 **TIL:** $TIL_FACT

---

## 📅 $MONTH_NAME $DAY, $YEAR

| Detail | Value |
|--------|-------|
| **Day of Year** | $DAY_OF_YEAR / $TOTAL_DAYS ($PERCENTAGE%) |
| **Season** | $SEASON |
| **Weather Note** | $SEASON_DESC |

EOF

if [ -n "$BIRTHDAY_MSG" ]; then
  echo "" >> "$CONTENT_DIR/$DATE_STR.md"
  echo "> $BIRTHDAY_MSG" >> "$CONTENT_DIR/$DATE_STR.md"
fi

if [ -n "$HOLIDAY_MSG" ]; then
  echo "" >> "$CONTENT_DIR/$DATE_STR.md"
  echo "> $HOLIDAY_MSG" >> "$CONTENT_DIR/$DATE_STR.md"
fi

if [ -n "$MONTH_CELEBRATION" ]; then
  echo "" >> "$CONTENT_DIR/$DATE_STR.md"
  echo "> $MONTH_CELEBRATION" >> "$CONTENT_DIR/$DATE_STR.md"
fi

if [ -n "$YEAR_CELEBRATION" ]; then
  echo "" >> "$CONTENT_DIR/$DATE_STR.md"
  echo "> $YEAR_CELEBRATION" >> "$CONTENT_DIR/$DATE_STR.md"
fi

if [ -n "$WEEKEND_VIBE" ]; then
  echo "" >> "$CONTENT_DIR/$DATE_STR.md"
  echo "" >> "$CONTENT_DIR/$DATE_STR.md"
  echo "$WEEKEND_VIBE" >> "$CONTENT_DIR/$DATE_STR.md"
fi

GOAL_FILLED=$(( BUILD_NUM * 20 / YEAR_GOAL ))
GOAL_BAR=""
for ((i=1; i<=20; i++)); do
  if [ $i -le $GOAL_FILLED ]; then
    GOAL_BAR="${GOAL_BAR}█"
  else
    GOAL_BAR="${GOAL_BAR}░"
  fi
done
GOAL_PCT=$(awk "BEGIN {printf \"%.1f\", ($BUILD_NUM / $YEAR_GOAL) * 100}")

# Create Wikipedia search link from event keywords
TECH_KEYWORDS=$(echo "$TECH_EVENT" | head -c 80 | sed 's/[^a-zA-Z0-9 ]//g' | sed 's/  */+/g' | sed 's/^+//;s/+$//')
TECH_WIKI_URL="https://en.wikipedia.org/w/index.php?search=${TECH_KEYWORDS// /+}"

cat >> "$CONTENT_DIR/$DATE_STR.md" << EOF

---

<div class="tech-history-section">

## 📜 Tech History — $MONTH_NAME $DAY

**$TECH_YEAR** — $TECH_EVENT

<small>[Learn more on Wikipedia]($TECH_WIKI_URL)</small>

</div>

EOF

# Add "Today" section with recent events if available
if [ -n "$RECENT_EVENTS" ]; then
  cat >> "$CONTENT_DIR/$DATE_STR.md" << EOF

<div class="today-section">

## 📰 Today in Tech — $MONTH_NAME $DAY

$RECENT_EVENTS

</div>

EOF
fi

cat >> "$CONTENT_DIR/$DATE_STR.md" << EOF

---

🎯 **Year Goal:** $BUILD_NUM / $YEAR_GOAL entries

$GOAL_BAR $GOAL_PCT%

[View all entries](/)

---

<nav class="entry-nav">
EOF

if [ -n "$PREV_FILE" ]; then
  cat >> "$CONTENT_DIR/$DATE_STR.md" << EOF
← [Previous](./${PREV_FILE}.md)
EOF
fi

cat >> "$CONTENT_DIR/$DATE_STR.md" << EOF
<span class="entry-nav-spacer"></span>
EOF

if [ -n "$NEXT_FILE" ]; then
  cat >> "$CONTENT_DIR/$DATE_STR.md" << EOF
[Next](./${NEXT_FILE}.md) →
EOF
fi

cat >> "$CONTENT_DIR/$DATE_STR.md" << EOF
</nav>

*Daily entry #$BUILD_NUM — $DATE_STR*
*— [Ayoola Damisile](https://github.com/Ayoola-tech2024)*
EOF

echo "✅ Created content for $DATE_STR (Tech: $TECH_YEAR)"

NEXT_INDEX=$(( FEATURE_INDEX + 1 ))
jq -n \
  --arg fi "$NEXT_INDEX" \
  --arg ld "$DATE_STR" \
  --arg tb "$BUILD_NUM" \
  --arg sk "$STREAK" \
  --arg ls "$LONGEST_STREAK" \
  --arg yg "$YEAR_GOAL" \
  '{feature_index: ($fi|tonumber), last_date: $ld, total_builds: ($tb|tonumber), streak: ($sk|tonumber), longest_streak: ($ls|tonumber), year_goal: ($yg|tonumber)}' > "$PROGRESS_FILE"

generate_index() {
  local TARGET_YEAR="$1"
  local INDEX_FILE="$REPO_ROOT/index.md"

  cat > "$INDEX_FILE" << EOF
---
layout: default
---

# Daily Entry Journal — $TARGET_YEAR

<span class="hero-subtitle">by **Ayoola Damisile**</span>

$STREAK_ICON **$STREAK-day streak** &middot; 🎯 **$BUILD_NUM / $YEAR_GOAL** entries

---

EOF

  for month_dir in $(ls "$CONTENT_DIR"/*.md 2>/dev/null | xargs -I{} basename {} .md | grep "^$TARGET_YEAR" | cut -d'-' -f1,2 | sort -u); do
    MONTH_NAME=$(echo "$month_dir" | awk -F'-' '{print $2}' | sed 's/^0//')

    local month_name_display=""
    case $MONTH_NAME in
      1) month_name_display="January";; 2) month_name_display="February";; 3) month_name_display="March";;
      4) month_name_display="April";; 5) month_name_display="May";; 6) month_name_display="June";;
      7) month_name_display="July";; 8) month_name_display="August";; 9) month_name_display="September";;
      10) month_name_display="October";; 11) month_name_display="November";; 12) month_name_display="December";;
    esac

    echo "## $month_name_display" >> "$INDEX_FILE"
    echo "| # | Date | Entry |" >> "$INDEX_FILE"
    echo "|---|---|---|" >> "$INDEX_FILE"

    local counter=1
    for f in $(ls "$CONTENT_DIR/${month_dir}-"*.md 2>/dev/null | sort); do
      local fname
      fname=$(basename "$f" .md)
      local title
      title=$(head -100 "$f" | grep -A1 "^## 📜 Tech History" | tail -1 | sed 's/^\*\*[0-9]*\*\* — //' | head -1)
      if [ -z "$title" ]; then
        title="Daily entry"
      fi
      echo "| $counter | [$fname](./content/${fname}.md) | <span class=\"title-truncate\">$title</span> |" >> "$INDEX_FILE"
      counter=$((counter + 1))
    done
    echo "" >> "$INDEX_FILE"
  done

  # Add streak calendar
  echo "## Streak Calendar" >> "$INDEX_FILE"
  echo '<div class="streak-calendar">' >> "$INDEX_FILE"

  for ((d=1; d<=DAY_OF_YEAR; d++)); do
    CAL_DATE=$(date -d "$TARGET_YEAR-01-01 + $((d-1)) days" +%Y-%m-%d 2>/dev/null)
    if [ -f "$CONTENT_DIR/$CAL_DATE.md" ]; then
      if [ "$CAL_DATE" = "$DATE_STR" ]; then
        echo '<div class="streak-day filled today" title="'"$CAL_DATE"'"></div>' >> "$INDEX_FILE"
      else
        echo '<div class="streak-day filled" title="'"$CAL_DATE"'"></div>' >> "$INDEX_FILE"
      fi
    else
      echo '<div class="streak-day" title="'"$CAL_DATE"'"></div>' >> "$INDEX_FILE"
    fi
  done

  echo '</div>' >> "$INDEX_FILE"

  echo "✅ Index page generated"
}

generate_index "$YEAR"

generate_rss() {
  RSS_FILE="$REPO_ROOT/feed.xml"

  cat > "$RSS_FILE" << 'RSSEOF'
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
<channel>
  <title>Daily Entry Journal</title>
  <link>https://daily-commit.vercel.app</link>
  <description>One commit, every day — a year-long building journey</description>
  <language>en</language>
  <atom:link href="https://daily-commit.vercel.app/feed.xml" rel="self" type="application/rss+xml"/>
RSSEOF

  echo "  <lastBuildDate>$(date -R)</lastBuildDate>" >> "$RSS_FILE"

  for f in $(ls "$CONTENT_DIR"/*.md 2>/dev/null | grep -v "week-\|recap" | sort -r | head -20); do
    local fname title
    fname=$(basename "$f" .md)
    title=$(head -100 "$f" | grep -A1 "^## 📜 Tech History" | tail -1 | sed 's/^\*\*[0-9]*\*\* — //' | head -1)

    if [ -n "$title" ]; then
      cat >> "$RSS_FILE" << EOF
<item>
  <title>Day $fname — $title</title>
  <link>https://daily-commit.vercel.app/content/$fname.html</link>
  <pubDate>$(date -R -d "$fname")</pubDate>
  <guid>https://daily-commit.vercel.app/content/$fname.html</guid>
</item>
EOF
    fi
  done

  echo "</channel>" >> "$RSS_FILE"
  echo "</rss>" >> "$RSS_FILE"
  echo "✅ RSS feed generated"
}

generate_rss

BLOCKS_FILLED=$(( DAY_OF_YEAR * 20 / TOTAL_DAYS ))
PROGRESS_BAR=""
for ((i=1; i<=20; i++)); do
  if [ $i -le $BLOCKS_FILLED ]; then
    PROGRESS_BAR="${PROGRESS_BAR}█"
  else
    PROGRESS_BAR="${PROGRESS_BAR}░"
  fi
done

cat > "$REPO_ROOT/README.md" << EOF
# Daily Commit — $YEAR

A daily entry journal. One commit, every day.

$STREAK_ICON **$STREAK-day streak** · 🎯 **$BUILD_NUM / $YEAR_GOAL** builds

## Year Progress

$PROGRESS_BAR $PERCENTAGE%

**Days completed:** $DAY_OF_YEAR / $TOTAL_DAYS

## Latest

[View today's entry →](./content/$DATE_STR.md)

[View all builds](/)

---

*Next build scheduled for tomorrow.*
EOF

if [ "$DAY_OF_WEEK" = "7" ]; then
  WEEK_FILE="$CONTENT_DIR/week-$WEEK_NUM-$YEAR.md"
  if [ ! -f "$WEEK_FILE" ]; then
    WEEKLY_FILES=$(find "$CONTENT_DIR" -maxdepth 1 -name "*.md" ! -name "week-*" ! -name "*recap*" | sort -r | head -7)
    WEEKLY_BUILDS=""
    WEEK_COUNT=0
    while IFS= read -r wf; do
      if [ -n "$wf" ]; then
        wt=$(head -100 "$wf" | grep -A1 "^## 📜 Tech History" | tail -1 | sed 's/^\*\*[0-9]*\*\* — //' | head -1)
        wd=$(basename "$wf" .md)
        if [ -n "$wt" ]; then
          WEEKLY_BUILDS="$WEEKLY_BUILDS- $wd: $wt"$'\n'
          WEEK_COUNT=$((WEEK_COUNT + 1))
        fi
      fi
    done <<< "$WEEKLY_FILES"

    WEEK_QUOTE_INDEX=$(( WEEK_NUM % TOTAL_QUOTES ))
    WEEK_QUOTE=$(jq -r ".[$WEEK_QUOTE_INDEX]" "$DATA_DIR/quotes.json")

    cat > "$WEEK_FILE" << EOF
# Week $WEEK_NUM — $YEAR

*$(date -d "$(date +%Y)-01-01 + $(( (WEEK_NUM - 1) * 7 )) days" +%B %d 2>/dev/null)*

---

## Builds Completed

$WEEKLY_BUILDS

---

**Total this week:** $WEEK_COUNT builds · $STREAK_ICON $STREAK-day streak

> *"$WEEK_QUOTE"*

---

*— [Ayoola Damisile](https://github.com/Ayoola-tech2024)*
EOF
    echo "✅ Weekly summary generated for week $WEEK_NUM"
  fi
fi

if [ "$MONTH" = "12" ] && [ "$DAY" = "31" ]; then
  RECAP_FILE="$CONTENT_DIR/$YEAR-recap.md"
  if [ ! -f "$RECAP_FILE" ]; then
    TOTAL_CONTENT_FILES=$(find "$CONTENT_DIR" -maxdepth 1 -name "????-??-??.md" | wc -l)

    cat > "$RECAP_FILE" << EOF
# $YEAR — The Daily Entry Year

---

## 🏆 Year in Review

| Metric | Value |
|--------|-------|
| **Total Builds** | $BUILD_NUM |
| **Days Completed** | $TOTAL_CONTENT_FILES / $TOTAL_DAYS |
| **Longest Streak** | $LONGEST_STREAK days |
| **Year Goal** | $BUILD_NUM / $YEAR_GOAL |

---

Thank you for following along. See you next year. 🚀

*— [Ayoola Damisile](https://github.com/Ayoola-tech2024)*
EOF
    echo "✅ Year-end recap generated"
  fi
fi

git add -A

if [ "$MONTH" = "08" ] && [ "$DAY" = "29" ]; then
  COMMIT_MSG="🎂 Birthday build — $TECH_YEAR $TECH_EVENT"
elif [ -n "$HOLIDAY_MSG" ]; then
  HOLIDAY_NAME=$(echo "$HOLIDAY_MSG" | sed 's/^[^ ]* \*\*\([^*]*\)\*\*.*/\1/')
  COMMIT_MSG="$HOLIDAY_NAME — $TECH_YEAR"
elif [ "$MONTH" = "01" ] && [ "$DAY" = "01" ]; then
  COMMIT_MSG="🎆 Happy New Year $YEAR! Build #1"
elif [ "$DAY" = "01" ]; then
  COMMIT_MSG="🎉 $MONTH_NAME — $TECH_YEAR"
else
  COMMIT_MSG="Day $DAY_OF_YEAR — $TECH_YEAR"
fi

git commit -m "$COMMIT_MSG"
git push
echo "✅ Pushed commit: $COMMIT_MSG"
