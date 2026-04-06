import json
import random
import time
from pathlib import Path
from datetime import datetime

# ==============================
# 保存ファイル
# ==============================
WORDS_JSON = "words.json"
RESULTS_JSON = "results.json"

# ==============================
# データ読み込み + 正規化 + フィルタ
# ==============================
def load_words(
    json_path: str = WORDS_JSON,
    emotion_filter=None,
    level_filter=None,
    score_filter=None,
):
    path = Path(__file__).resolve().parent / json_path
    if not path.exists():
        raise FileNotFoundError(f"{path} が見つかりません。")

    with path.open("r", encoding="utf-8") as f:
        data = json.load(f)

    items = data["words"] if isinstance(data, dict) and "words" in data else data
    if not isinstance(items, list):
        raise ValueError("words.json の形式が不正です（配列 or {'words':[...]}）。")

    def normalize(item: dict) -> dict:
        word = item.get("word") or item.get("english") or item.get("en")
        meaning = item.get("meaning") or item.get("meaning_ja") or item.get("meaning_jp") or item.get("ja")
        example = item.get("example") or item.get("example_en") or item.get("exampleEnglish")
        example_ja = item.get("example_ja") or item.get("exampleJapanese")

        score_tag = item.get("score_tag") or item.get("score_tags") or []
        if not isinstance(score_tag, list):
            score_tag = []

        return {
            "word": (word or "").strip(),
            "meaning": (meaning or "").strip(),
            "example": example or None,
            "example_ja": example_ja or None,
            "emotion": item.get("emotion") or item.get("emotion_tag") or item.get("feeling"),
            "level_tag": item.get("level_tag"),
            "score_tag": score_tag,
        }

    filtered = []
    for it in items:
        if not isinstance(it, dict):
            continue
        w = normalize(it)
        if not w["word"] or not w["meaning"]:
            continue

        # emotion filter
        if emotion_filter is not None:
            if isinstance(emotion_filter, str):
                if w.get("emotion") != emotion_filter:
                    continue
            else:
                if w.get("emotion") not in set(emotion_filter):
                    continue

        # level filter
        if level_filter is not None:
            if isinstance(level_filter, str):
                if w.get("level_tag") != level_filter:
                    continue
            else:
                if w.get("level_tag") not in set(level_filter):
                    continue

        # score filter
        if score_filter is not None:
            scores = w.get("score_tag", [])
            if isinstance(score_filter, str):
                if score_filter not in scores:
                    continue
            else:
                wanted = set(score_filter)
                if not any(s in wanted for s in scores):
                    continue

        filtered.append(w)

    if not filtered:
        raise ValueError("条件に合う単語がありません（フィルタを緩めてください）。")
    return filtered


# ==============================
# 解説
# ==============================
def build_explanation(item, direction: str):
    lines = []
    if direction == "en_to_ja":
        lines.append(f"✅ 正解：{item['word']} ＝ {item['meaning']}")
    else:
        lines.append(f"✅ 正解：{item['meaning']} ＝ {item['word']}")

    if item.get("level_tag"):
        lines.append(f"level_tag: {item['level_tag']}")
    if item.get("score_tag"):
        lines.append(f"score_tag: {', '.join(item['score_tag'])}")
    if item.get("emotion"):
        lines.append(f"emotion: {item['emotion']}")
    if item.get("example"):
        lines.append(f"例文(EN): {item['example']}")
    if item.get("example_ja"):
        lines.append(f"例文(JA): {item['example_ja']}")
    return "\n".join(lines)


# ==============================
# 問題生成（choice / written / tf）
# ==============================
def generate_choice_question(words, num_choices: int = 4, direction: str = "en_to_ja"):
    if len(words) < 2:
        raise ValueError("選択式問題は2語以上必要です。")

    num_choices = max(2, min(num_choices, len(words)))
    correct = random.choice(words)

    others = [w for w in words if w is not correct]
    wrongs = random.sample(others, num_choices - 1) if len(others) >= (num_choices - 1) else [
        random.choice(others) for _ in range(num_choices - 1)
    ]

    all_options = [correct] + wrongs
    random.shuffle(all_options)
    labels = list("ABCDEFG")[:len(all_options)]

    choices = []
    correct_label = None
    for label, opt in zip(labels, all_options):
        text = opt["meaning"] if direction == "en_to_ja" else opt["word"]
        choices.append({"label": label, "text": text})
        if opt is correct:
            correct_label = label

    prompt = f"「{correct['word']}」に最も近い意味を1つ選びなさい。" if direction == "en_to_ja" \
        else f"「{correct['meaning']}」に最も近い英単語を1つ選びなさい。"
    answer = correct["meaning"] if direction == "en_to_ja" else correct["word"]

    return {
        "type": "choice",
        "direction": direction,
        "prompt": prompt,
        "target_word": correct["word"],
        "target_meaning": correct["meaning"],
        "answer": answer,
        "choices": choices,
        "correct_label": correct_label,
        "meta": correct,  # 単語データ（統計に使う）
        "explanation": build_explanation(correct, direction),
    }


def generate_written_question(words, direction: str = "en_to_ja"):
    item = random.choice(words)
    prompt = f"次の英単語の意味を書きなさい：{item['word']}" if direction == "en_to_ja" \
        else f"次の日本語の意味に合う英単語を書きなさい：{item['meaning']}"
    answer = item["meaning"] if direction == "en_to_ja" else item["word"]

    return {
        "type": "written",
        "direction": direction,
        "prompt": prompt,
        "target_word": item["word"],
        "target_meaning": item["meaning"],
        "answer": answer,
        "meta": item,
        "explanation": build_explanation(item, direction),
    }


def generate_tf_question(words, direction: str = "en_to_ja", true_ratio: float = 0.5):
    if len(words) < 2:
        raise ValueError("True/False 問題は2語以上必要です。")

    correct = random.choice(words)
    make_true = random.random() < true_ratio

    if make_true:
        shown_word = correct["word"]
        shown_meaning = correct["meaning"]
        is_true = True
        explanation = "この文は正しいです。\n" + build_explanation(correct, direction)
    else:
        wrong = random.choice([w for w in words if w is not correct])
        shown_word = correct["word"]
        shown_meaning = wrong["meaning"]
        is_true = False
        explanation = (
            "この文は間違いです。\n"
            f"❌ 「{shown_word}」は「{shown_meaning}」ではありません。\n"
            + build_explanation(correct, direction)
        )

    statement = f"「{shown_word}」の意味は「{shown_meaning}」である。" if direction == "en_to_ja" \
        else f"「{shown_meaning}」に対応する英単語は「{shown_word}」である。"

    return {
        "type": "tf",
        "direction": direction,
        "prompt": "次の文が正しければ True、間違っていれば False を答えなさい。",
        "statement": statement,
        "answer_bool": is_true,
        "choices": [{"label": "T", "text": "True"}, {"label": "F", "text": "False"}],
        "target_word": correct["word"],        # 統計は「正解単語側」に紐づける
        "target_meaning": correct["meaning"],
        "meta": correct,
        "explanation": explanation,
    }


def generate_quiz(words, num_questions=10, num_choices=4, mode="mixed", direction="both"):
    quiz = []
    for _ in range(min(num_questions, len(words))):
        q_type = mode if mode in ("choice", "written", "tf") else random.choice(["choice", "written", "tf"])
        q_dir = direction if direction in ("en_to_ja", "ja_to_en") else random.choice(["en_to_ja", "ja_to_en"])

        if q_type == "choice":
            q = generate_choice_question(words, num_choices=num_choices, direction=q_dir)
        elif q_type == "written":
            q = generate_written_question(words, direction=q_dir)
        else:
            q = generate_tf_question(words, direction=q_dir)

        quiz.append(q)
    return quiz


# ==============================
# results.json 操作（蓄積）
# ==============================
def _safe_load_results(path=RESULTS_JSON):
    p = Path(__file__).resolve().parent / path
    if not p.exists() or p.stat().st_size == 0:
        return {"sessions": [], "per_word": {}}
    try:
        with p.open("r", encoding="utf-8") as f:
            data = json.load(f)
            if "sessions" not in data:
                data["sessions"] = []
            if "per_word" not in data:
                data["per_word"] = {}
            return data
    except json.JSONDecodeError:
        return {"sessions": [], "per_word": {}}


def _save_results(data, path=RESULTS_JSON):
    p = Path(__file__).resolve().parent / path
    with p.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


def _update_per_word_stats(results_db, word_key: str, correct: bool, answer_time_sec: float, level_tag=None, score_tag=None):
    """
    per_word[word] = {
      attempts, correct, accuracy, total_time, avg_time,
      last_seen, level_tag, score_tag(set-like list)
    }
    """
    pw = results_db["per_word"].get(word_key)
    if pw is None:
        pw = {
            "attempts": 0,
            "correct": 0,
            "total_time": 0.0,
            "last_seen": None,
            "level_tag": level_tag,
            "score_tag": [],
        }

    pw["attempts"] += 1
    if correct:
        pw["correct"] += 1
    pw["total_time"] += float(answer_time_sec)
    pw["last_seen"] = datetime.now().isoformat(timespec="seconds")

    # タグは最新を優先しつつ、score_tagはユニークに
    if level_tag:
        pw["level_tag"] = level_tag

    if isinstance(score_tag, list):
        s = set(pw.get("score_tag", []))
        for t in score_tag:
            s.add(t)
        pw["score_tag"] = sorted(s)

    pw["accuracy"] = round(pw["correct"] / pw["attempts"], 4)
    pw["avg_time"] = round(pw["total_time"] / pw["attempts"], 4)

    results_db["per_word"][word_key] = pw


# ==============================
# CLI テスト（時間制限あり）
# ==============================
def run_quiz_cli(
    quiz,
    total_time_limit_sec: int = 0,      # 0なら無制限
    per_question_limit_sec: int = 0,    # 0なら無制限（※入力を強制終了はしない。超えたらtimeout扱い）
    save_results: bool = True,
    filters_info: dict | None = None,
):
    """
    注意：Python標準の input() はクロスプラットフォームで強制タイムアウトが難しいため、
          「入力は受けるが、時間を超えたらtimeoutで不正解扱い」にしています。
    """
    results_db = _safe_load_results() if save_results else None

    session = {
        "timestamp": datetime.now().isoformat(timespec="seconds"),
        "filters": filters_info or {},
        "total_time_limit_sec": total_time_limit_sec,
        "per_question_limit_sec": per_question_limit_sec,
        "questions": [],
        "summary": {},
    }

    def norm(s: str) -> str:
        return "".join(str(s).strip().split()).lower()

    start_total = time.monotonic()
    score = 0
    answered = 0

    print("\n=== QUIZ START ===")
    if total_time_limit_sec > 0:
        print(f"Total Time Limit: {total_time_limit_sec}s")
    if per_question_limit_sec > 0:
        print(f"Per Question Limit: {per_question_limit_sec}s (超えたら timeout 扱い)")
    print("==================\n")

    for idx, q in enumerate(quiz, start=1):
        # 残り時間チェック（総時間）
        if total_time_limit_sec > 0:
            elapsed_total = time.monotonic() - start_total
            remaining = total_time_limit_sec - elapsed_total
            if remaining <= 0:
                print("⏰ 時間切れ！テストを終了します。\n")
                break
            print(f"[Remaining: {int(remaining)}s]")

        print(f"[Q{idx}] {q['prompt']}")

        q_start = time.monotonic()
        user_answer = None

        # --- 入力 ---
        if q["type"] == "tf":
            print(q["statement"])
            user_answer = input("Your answer (T/F): ").strip().upper()
        elif q["type"] == "choice":
            for c in q["choices"]:
                print(f"  {c['label']}. {c['text']}")
            user_answer = input("Your answer (A/B/C...): ").strip().upper()
        else:
            user_answer = input("Your answer: ").strip()

        q_end = time.monotonic()
        answer_time = q_end - q_start

        # --- 正誤判定 ---
        timeout = False
        if per_question_limit_sec > 0 and answer_time > per_question_limit_sec:
            timeout = True

        correct = False
        correct_text = ""

        if q["type"] == "tf":
            correct_label = "T" if q["answer_bool"] else "F"
            correct_text = "True" if q["answer_bool"] else "False"
            correct = (user_answer == correct_label)
        elif q["type"] == "choice":
            correct_text = f"{q['correct_label']} ({q['answer']})"
            correct = (user_answer == q["correct_label"])
        else:
            correct_text = q["answer"]
            correct = (norm(user_answer) == norm(q["answer"]))

        # timeoutなら不正解扱い（記録も残す）
        if timeout:
            correct = False

        answered += 1
        if correct:
            score += 1
            print("✅ Correct!")
        else:
            if timeout:
                print("⏰ Time Out!（時間超過で不正解扱い）")
            else:
                print("❌ Wrong.")
            print(f"Correct: {correct_text}")

        print(f"⏱ Answer Time: {answer_time:.2f}s")
        print("\n--- Explanation ---")
        print(q.get("explanation", "(no explanation)"))
        print("\n====================\n")

        # --- セッション記録 ---
        meta = q.get("meta", {})
        word_key = (q.get("target_word") or "").strip()
        session["questions"].append({
            "index": idx,
            "type": q["type"],
            "direction": q.get("direction"),
            "word": word_key,
            "meaning": q.get("target_meaning"),
            "user_answer": user_answer,
            "correct": correct,
            "timeout": timeout,
            "answer_time_sec": round(answer_time, 4),
        })

        # --- 単語別統計更新 ---
        if save_results and results_db is not None and word_key:
            _update_per_word_stats(
                results_db,
                word_key=word_key,
                correct=correct,
                answer_time_sec=answer_time,
                level_tag=meta.get("level_tag"),
                score_tag=meta.get("score_tag", []),
            )

    session["summary"] = {
        "answered": answered,
        "score": score,
        "total_questions_generated": len(quiz),
        "accuracy": round(score / answered, 4) if answered else 0.0,
        "total_elapsed_sec": round(time.monotonic() - start_total, 4),
    }

    print(f"=== SCORE: {score}/{answered} ===")
    print(f"Accuracy: {session['summary']['accuracy']*100:.1f}%")
    print(f"Time: {session['summary']['total_elapsed_sec']}s\n")

    # 保存
    if save_results and results_db is not None:
        results_db["sessions"].append(session)
        _save_results(results_db)
        print(f"💾 results saved -> {RESULTS_JSON}")

    return session


# ==============================
# ここだけ変えればOK
# ==============================
if __name__ == "__main__":
    # ---- 出題形式 ----
    MODE = "mixed"                 # "choice" / "written" / "tf" / "mixed"
    NUM_QUESTIONS = 5
    NUM_CHOICES = 4
    DIRECTION = "both"             # "en_to_ja" / "ja_to_en" / "both"

    # ---- フィルタ（必要なときだけ）----
    EMOTION_FILTER = None          # 例: "happy" / ["happy","sad"]
    LEVEL_FILTER = None            # 例: "eiken-pre1" / ["eiken-3","eiken-2"]
    SCORE_FILTER = None            # 例: "sat" / ["toefl-ibt-80","ielts-6.5"]

    # ---- 時間制限 ----
    TOTAL_TIME_LIMIT_SEC = 60     # 0なら無制限（例: 180=3分）
    PER_QUESTION_LIMIT_SEC = 25    # 0なら無制限（超えたらtimeout扱い）

    words = load_words(
        emotion_filter=EMOTION_FILTER,
        level_filter=LEVEL_FILTER,
        score_filter=SCORE_FILTER,
    )
    quiz = generate_quiz(
        words,
        num_questions=NUM_QUESTIONS,
        num_choices=NUM_CHOICES,
        mode=MODE,
        direction=DIRECTION,
    )

    run_quiz_cli(
        quiz,
        total_time_limit_sec=TOTAL_TIME_LIMIT_SEC,
        per_question_limit_sec=PER_QUESTION_LIMIT_SEC,
        save_results=True,
        filters_info={
            "mode": MODE,
            "num_questions": NUM_QUESTIONS,
            "num_choices": NUM_CHOICES,
            "direction": DIRECTION,
            "emotion_filter": EMOTION_FILTER,
            "level_filter": LEVEL_FILTER,
            "score_filter": SCORE_FILTER,
        },
    )
