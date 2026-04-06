from fastapi import FastAPI
from typing import List, Dict

app = FastAPI(
    title="Vocab API",
    description="Returns English vocabulary with examples and quiz data",
    version="1.0.0"
)

# ここは今はハードコーディング。あとでLLMに置き換える。
def get_vocab_data() -> List[Dict]:
    return [
        {
            "word": "achieve",
            "meaning": "to successfully reach a goal or result",
            "example": "She worked hard to achieve her dream of becoming a doctor.",
            "quiz": {
                "question": "She worked hard to ______ her dream of becoming a doctor.",
                "answer": "achieve"
            }
        },
        {
            "word": "consider",
            "meaning": "to think carefully about something before making a choice",
            "example": "You should consider all options before you decide.",
            "quiz": {
                "question": "You should ______ all options before you decide.",
                "answer": "consider"
            }
        },
        {
            "word": "develop",
            "meaning": "to grow or create something over time",
            "example": "The team is developing a new app for language learners.",
            "quiz": {
                "question": "The team is ______ a new app for language learners.",
                "answer": "developing"
            }
        },
        {
            "word": "expand",
            "meaning": "to become larger or make something larger",
            "example": "The company plans to expand into Asia next year.",
            "quiz": {
                "question": "The company plans to ______ into Asia next year.",
                "answer": "expand"
            }
        },
        {
            "word": "influence",
            "meaning": "the power to affect how someone thinks or acts",
            "example": "Good teachers can influence students in a positive way.",
            "quiz": {
                "question": "Good teachers can ______ students in a positive way.",
                "answer": "influence"
            }
        },
        {
            "word": "maintain",
            "meaning": "to keep something in good condition or keep it the same",
            "example": "It's important to maintain a healthy sleep schedule.",
            "quiz": {
                "question": "It's important to ______ a healthy sleep schedule.",
                "answer": "maintain"
            }
        },
        {
            "word": "participate",
            "meaning": "to join or take part in an activity",
            "example": "All students are encouraged to participate in the school festival.",
            "quiz": {
                "question": "All students are encouraged to ______ in the school festival.",
                "answer": "participate"
            }
        },
        {
            "word": "recommend",
            "meaning": "to say that something is good and suggest someone should try it",
            "example": "I recommend this show if you like science fiction.",
            "quiz": {
                "question": "I ______ this show if you like science fiction.",
                "answer": "recommend"
            }
        },
        {
            "word": "solve",
            "meaning": "to find the answer to a problem",
            "example": "Can you solve this puzzle in under one minute?",
            "quiz": {
                "question": "Can you ______ this puzzle in under one minute?",
                "answer": "solve"
            }
        },
        {
            "word": "support",
            "meaning": "to help or give strength to someone or something",
            "example": "Good friends support each other during hard times.",
            "quiz": {
                "question": "Good friends ______ each other during hard times.",
                "answer": "support"
            }
        }
    ]

@app.get("/vocab")
def read_vocab():
    return {
        "count": 10,
        "level": "general_intermediate",
        "source": "static_sample",
        "data": get_vocab_data()
    }
