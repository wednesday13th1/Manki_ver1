import json

# 単語リストを定義
vocab_list = [
    {
        "word": "achieve",
        "meaning": "to successfully reach a goal or result",
        "example": "She worked hard to achieve her dream of becoming a doctor."
    },
    {
        "word": "consider",
        "meaning": "to think carefully about something",
        "example": "You should consider all options before making a decision."
    },
    {
        "word": "develop",
        "meaning": "to grow or cause to grow and become more mature or advanced",
        "example": "The company plans to develop a new app for students."
    },
    {
        "word": "expand",
        "meaning": "to increase in size, range, or amount",
        "example": "The business expanded into international markets last year."
    },
    {
        "word": "influence",
        "meaning": "the power to affect others or things",
        "example": "Parents have a strong influence on their children's values."
    },
    {
        "word": "maintain",
        "meaning": "to keep something in good condition or state",
        "example": "It’s important to maintain a healthy lifestyle."
    },
    {
        "word": "participate",
        "meaning": "to take part or become involved in an activity",
        "example": "Many students participated in the science fair."
    },
    {
        "word": "recommend",
        "meaning": "to suggest something as good or suitable",
        "example": "I recommend this book to anyone who likes mysteries."
    },
    {
        "word": "solve",
        "meaning": "to find an answer or explanation for a problem",
        "example": "Can you solve this math problem?"
    },
    {
        "word": "support",
        "meaning": "to help or give assistance to someone or something",
        "example": "Friends support each other during difficult times."
    }
]

# JSONとして出力
json_data = json.dumps(vocab_list, indent=4, ensure_ascii=False)
print(json_data)
