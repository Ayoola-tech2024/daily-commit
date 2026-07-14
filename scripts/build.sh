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
  FEATURE_INDEX=$(jq -r '.feature_index' "$PROGRESS_FILE")
else
  FEATURE_INDEX=0
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

BUILD_NUM=$((FEATURE_INDEX + 1))

cat > "$CONTENT_DIR/$DATE_STR.md" << EOF
# Day $DAY_OF_YEAR of $YEAR — $DAY_NAME, $MONTH_NAME $DAY

> *"$QUOTE"*

---

## 📅 $MONTH_NAME $DAY, $YEAR

| Detail | Value |
|--------|-------|
| **Day of Year** | $DAY_OF_YEAR / $TOTAL_DAYS ($PERCENTAGE%) |
| **Season** | $SEASON |
| **Weather Note** | $SEASON_DESC |

EOF

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

cat >> "$CONTENT_DIR/$DATE_STR.md" << EOF

---

## Build #$BUILD_NUM: $FEATURE_TITLE

$FEATURE_DESC

---

*Daily build #$BUILD_NUM — $DATE_STR*
EOF

echo "✅ Created content for $DATE_STR (Build #$BUILD_NUM: $FEATURE_TITLE)"

NEXT_INDEX=$(( (FEATURE_INDEX + 1) % TOTAL_FEATURES ))
jq -n --arg fi "$NEXT_INDEX" --arg ld "$DATE_STR" --arg tb "$BUILD_NUM" \
  '{feature_index: ($fi|tonumber), last_date: $ld, total_builds: ($tb|tonumber)}' > "$PROGRESS_FILE"

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

## Year Progress

$PROGRESS_BAR $PERCENTAGE%

**Days completed:** $DAY_OF_YEAR / $TOTAL_DAYS

## Latest

[View today's entry →](./content/$DATE_STR.md)

---

*Next build scheduled for tomorrow.*
EOF

git add -A

if [ -n "$HOLIDAY_MSG" ]; then
  COMMIT_MSG="$MONTH_NAME $DAY — $FEATURE_TITLE"
elif [ "$MONTH" = "01" ] && [ "$DAY" = "01" ]; then
  COMMIT_MSG="🎆 Happy New Year $YEAR! Build #1"
else
  COMMIT_MSG="Day $DAY_OF_YEAR — $FEATURE_TITLE"
fi

git commit -m "$COMMIT_MSG"
git push
echo "✅ Pushed commit: $COMMIT_MSG"
