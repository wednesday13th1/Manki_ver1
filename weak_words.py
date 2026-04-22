import json
from pathlib import Path

RESULTS_JSON = "results.json"

def load_results(path=RESULTS_JSON):
    p = Path(__file__).resolve().parent / path
    if not p.exists() or p.stat().st_size == 0:
        return {"sessions": [], "per_word": {}}
    with p.open("r", encoding="utf-8") as f:
        return json.load(f)

def print_weak_words(
    top_n: int = 20,
    min_attempts: int = 2,
    only_level: str | None = None,     # 例: "eiken-pre1"
    only_score: str | None = None,     # 例: "sat"
):
    db = load_results()
    per_word = db.get("per_word", {})

    rows = []
    for word, st in per_word.items():
        attempts = st.get("attempts", 0)
        if attempts < min_attempts:
            continue
        if only_level and st.get("level_tag") != only_level:
            continue
        if only_score and only_score not in (st.get("score_tag") or []):
            continue

        rows.append({
            "word": word,
            "accuracy": st.get("accuracy", 0.0),
            "attempts": attempts,
            "correct": st.get("correct", 0),
            "avg_time": st.get("avg_time", 0.0),
            "level_tag": st.get("level_tag"),
            "score_tag": st.get("score_tag", []),
            "last_seen": st.get("last_seen"),
        })

    # 正答率が低い順 → 回数多い順
    rows.sort(
    key=lambda r: (
        r["accuracy"],          # ① 正答率が低い順
        -r["attempts"],         # ② 回答回数が多い順
        -r["avg_time"],         # ③ 平均解答時間が長い順
    )
)

    print("\n=== WEAK WORDS ===")
    if only_level:
        print(f"Filter level_tag: {only_level}")
    if only_score:
        print(f"Filter score_tag: {only_score}")
    print(f"(min_attempts={min_attempts})\n")

    for i, r in enumerate(rows[:top_n], start=1):
        print(
            f"{i:02d}. {r['word']}"
            f" | acc={r['accuracy']*100:.1f}%"
            f" | {r['correct']}/{r['attempts']}"
            f" | avg_time={r['avg_time']:.2f}s"
            f" | level={r['level_tag']}"
            f" | score={','.join(r['score_tag'])}"
            f" | last={r['last_seen']}"
        )

    if not rows:
        print("まだデータがありません（まず quiz.py を実行してね）")

if __name__ == "__main__":
    # ここを好きに変更OK
    TOP_N = 30
    MIN_ATTEMPTS = 2

    ONLY_LEVEL = None   # 例: "eiken-pre1"
    ONLY_SCORE = None   # 例: "sat"

    print_weak_words(
        top_n=TOP_N,
        min_attempts=MIN_ATTEMPTS,
        only_level=ONLY_LEVEL,
        only_score=ONLY_SCORE,
    )
