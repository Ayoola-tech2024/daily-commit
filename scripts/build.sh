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

TOTAL_FEATURES=$(jq 'length' "$DATA_DIR/features.json")
FEATURE=$(jq -r ".[$FEATURE_INDEX]" "$DATA_DIR/features.json")
FEATURE_TITLE=$(echo "$FEATURE" | jq -r '.title')
FEATURE_DESC=$(echo "$FEATURE" | jq -r '.description')

TOTAL_QUOTES=$(jq 'length' "$DATA_DIR/quotes.json")
QUOTE_INDEX=$(( FEATURE_INDEX % TOTAL_QUOTES ))
QUOTE=$(jq -r ".[$QUOTE_INDEX]" "$DATA_DIR/quotes.json")

TOTAL_TIL=$(jq 'length' "$DATA_DIR/til.json")
TIL_INDEX=$(( FEATURE_INDEX % TOTAL_TIL ))
TIL_FACT=$(jq -r ".[$TIL_INDEX]" "$DATA_DIR/til.json")

BUILD_NUM=$((FEATURE_INDEX + 1))

STREAK_ICON="🔥"
if [ "$STREAK" -ge 30 ]; then
  STREAK_ICON="🔥"
elif [ "$STREAK" -ge 7 ]; then
  STREAK_ICON="🔥"
fi

cat > "$CONTENT_DIR/$DATE_STR.md" << EOF
# Day $DAY_OF_YEAR of $YEAR — $DAY_NAME, $MONTH_NAME $DAY

Morning, Ayoola. $STREAK_ICON $STREAK-day streak.

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
  echo "$BIRTHDAY_MSG" >> "$CONTENT_DIR/$DATE_STR.md"
fi

if [ -n "$HOLIDAY_MSG" ]; then
  echo "" >> "$CONTENT_DIR/$DATE_STR.md"
  echo "$HOLIDAY_MSG" >> "$CONTENT_DIR/$DATE_STR.md"
fi

if [ -n "$MONTH_CELEBRATION" ]; then
  echo "" >> "$CONTENT_DIR/$DATE_STR.md"
  echo "$MONTH_CELEBRATION" >> "$CONTENT_DIR/$DATE_STR.md"
fi

if [ -n "$YEAR_CELEBRATION" ]; then
  echo "" >> "$CONTENT_DIR/$DATE_STR.md"
  echo "$YEAR_CELEBRATION" >> "$CONTENT_DIR/$DATE_STR.md"
fi

if [ -n "$WEEKEND_VIBE" ]; then
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

cat >> "$CONTENT_DIR/$DATE_STR.md" << EOF

---

## Build #$BUILD_NUM: $FEATURE_TITLE

$FEATURE_DESC

---

🎯 **Year Goal:** $BUILD_NUM / $YEAR_GOAL builds

$GOAL_BAR $GOAL_PCT%

[View all builds →](./index.md)

---

*Daily build #$BUILD_NUM — $DATE_STR*
*— Ayoola Damisile*
EOF

echo "✅ Created content for $DATE_STR (Build #$BUILD_NUM: $FEATURE_TITLE)"

NEXT_INDEX=$(( (FEATURE_INDEX + 1) % TOTAL_FEATURES ))
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
# Daily Build Journal — $TARGET_YEAR

by [Ayoola Damisile](https://github.com/Ayoola-tech2024)

$STREAK_ICON **$STREAK-day streak** · 🎯 **$BUILD_NUM / $YEAR_GOAL** builds completed

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
    echo "| # | Date | Build |" >> "$INDEX_FILE"
    echo "|---|---|---|" >> "$INDEX_FILE"

    local counter=1
    for f in $(ls "$CONTENT_DIR/${month_dir}-"*.md 2>/dev/null | sort); do
      local fname
      fname=$(basename "$f" .md)
      local title
      title=$(head -100 "$f" | grep "^## Build" | sed 's/## Build #[0-9]*: //' | head -1)
      if [ -z "$title" ]; then
        title="Daily entry"
      fi
      echo "| $counter | [$fname](./content/${fname}.md) | $title |" >> "$INDEX_FILE"
      counter=$((counter + 1))
    done
    echo "" >> "$INDEX_FILE"
  done

  echo "✅ Index page generated"
}

generate_index "$YEAR"

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

A daily build journal. One commit, every day.

$STREAK_ICON **$STREAK-day streak** · 🎯 **$BUILD_NUM / $YEAR_GOAL** builds

## Year Progress

$PROGRESS_BAR $PERCENTAGE%

**Days completed:** $DAY_OF_YEAR / $TOTAL_DAYS

## Latest

[View today's entry →](./content/$DATE_STR.md)

[View all builds →](./index.md)

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
        wt=$(head -100 "$wf" | grep "^## Build" | sed 's/## Build #[0-9]*: //' | head -1)
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

*— Ayoola Damisile*
EOF
    echo "✅ Weekly summary generated for week $WEEK_NUM"
  fi
fi

if [ "$MONTH" = "12" ] && [ "$DAY" = "31" ]; then
  RECAP_FILE="$CONTENT_DIR/$YEAR-recap.md"
  if [ ! -f "$RECAP_FILE" ]; then
    TOTAL_CONTENT_FILES=$(find "$CONTENT_DIR" -maxdepth 1 -name "????-??-??.md" | wc -l)

    cat > "$RECAP_FILE" << EOF
# $YEAR — The Daily Build Year

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

*— Ayoola Damisile*
EOF
    echo "✅ Year-end recap generated"
  fi
fi

git add -A

if [ "$MONTH" = "08" ] && [ "$DAY" = "29" ]; then
  COMMIT_MSG="🎂 Birthday build — $FEATURE_TITLE"
elif [ -n "$HOLIDAY_MSG" ]; then
  HOLIDAY_NAME=$(echo "$HOLIDAY_MSG" | sed 's/^[^ ]* \*\*\([^*]*\)\*\*.*/\1/')
  COMMIT_MSG="$HOLIDAY_NAME — $FEATURE_TITLE"
elif [ "$MONTH" = "01" ] && [ "$DAY" = "01" ]; then
  COMMIT_MSG="🎆 Happy New Year $YEAR! Build #1"
elif [ "$DAY" = "01" ]; then
  COMMIT_MSG="🎉 $MONTH_NAME — $FEATURE_TITLE"
else
  COMMIT_MSG="Day $DAY_OF_YEAR — $FEATURE_TITLE"
fi

git commit -m "$COMMIT_MSG"
git push
echo "✅ Pushed commit: $COMMIT_MSG"
