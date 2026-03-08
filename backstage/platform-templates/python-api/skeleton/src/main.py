"""
${{ values.name }}
${{ values.description }}
"""

from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI(
    title="${{ values.name }}",
    description="${{ values.description }}",
    version="0.0.1"
)


class HealthResponse(BaseModel):
    status: str
    service: str


@app.get("/health", response_model=HealthResponse)
async def health():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": "${{ values.name }}"
    }


@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "message": "Welcome to ${{ values.name }}",
        "docs": "/docs"
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
