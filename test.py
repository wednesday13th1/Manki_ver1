from openai import OpenAI
import os
import json
import re

client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

EMOTIONS = [
    "positive", "negative", "neutral", "happy", "sad",
    "fear", "anger", "surprise", "motivational", "calm"
]


def safe_load_words(path="words.json"):
    """words.json がない・空・壊れていても安全に読み込む"""
    if not os.path.exists(path) or os.path.getsize(path) == 0:
        return []

    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except json.JSONDecodeError:
        return []


def generate_words():
    """AIから10個の単語＋意味＋例文＋感情タグをJSONで取得"""
    
    prompt = f"""
    英単語を10単語生成して、意味を日本語訳でください。
    出力は必ず JSON のみとし、以下の形式で返してください。

    [
      {{
        "word": "",
        "meaning": "",
        "example": "",
        "emotion": ""
      }}
    ]

    emotion は以下の10種類のいずれかを必ず1つ選んでください：
    {", ".join(EMOTIONS)}

    説明・文章・コードブロック記号 ``` は絶対に書かない。
    JSON のみ返してください。
    """

    resp = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[{"role": "user", "content": prompt}],
    )

    raw = resp.choices[0].message.content.strip()

    # 安全のため JSON 部分だけ抽出
    match = re.search(r"\[.*\]", raw, re.DOTALL)
    if not match:
        raise ValueError("AIからJSONが見つかりませんでした。出力:\n" + raw)

    clean_json = match.group()

    return json.loads(clean_json)


if __name__ == "__main__":
    # 既存の words.json を読み込む
    current_words = safe_load_words()

    # AIで新しい単語セットを生成
    new_words = generate_words()

    # 既存に追加
    current_words.extend(new_words)

    # 保存
    with open("words.json", "w", encoding="utf-8") as f:
        json.dump(current_words, f, ensure_ascii=False, indent=4)

    print("🎉 10単語を感情タグ付きで words.json に追加しました！")
