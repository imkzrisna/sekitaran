from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from transformers import pipeline

app = FastAPI()

classifier = pipeline(
    "text-classification",
    model="taufiqdp/indonesian-sentiment",
)

class CommentRequest(BaseModel):
    text: str = Field(min_length=3, max_length=2000)

@app.post("/analyze")
def analyze_sentiment(request: CommentRequest):
    text = request.text.strip()

    if not text:
        raise HTTPException(400, "Comment cannot be empty")

    result = classifier(text, truncation=True)[0]

    return {
        "sentiment": result["label"].lower(),
        "confidence": round(float(result["score"]), 4),
    }
