# ASR API Format Documentation

**API Endpoint:** `http://127.0.0.1:8010/v1/audio/transcriptions`  
**Server:** uvicorn (Python/FastAPI)

---

## Content-Type

### Non-Streaming (default)
```
Content-Type: application/json
```

### Streaming (stream=true)
```
Content-Type: text/event-stream; charset=utf-8
Transfer-Encoding: chunked
```

---

## Request Fields

The API accepts multipart/form-data with the following fields:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `file` | binary | Yes | Audio file (WAV, MP3, etc.) |
| `stream` | boolean | No | Enable streaming response (default: false) |
| `model` | string | No | Model identifier (optional) |
| `language` | string | No | Language code or "auto" for detection |

### Example Request (curl)

```bash
curl -X POST http://127.0.0.1:8010/v1/audio/transcriptions \
  -F "file=@/path/to/audio.wav" \
  -F "stream=true" \
  -F "language=auto"
```

---

## Response Format

### Non-Streaming Response (JSON)

```json
{
  "text": "transcribed text here",
  "language": "en",
  "segments": [
    {
      "text": "segment text",
      "start": 0.0,
      "end": 1.5
    }
  ],
  "usage": {
    "prompt_tokens": 28,
    "generation_tokens": 3,
    "total_tokens": 31
  },
  "runtime": {
    "mlx_default_device": "Device(gpu, 0)",
    "total_time_s": 0.374,
    "prompt_tps": 74.87,
    "generation_tps": 8.02
  },
  "input": {
    "language": "auto",
    "mode": "auto"
  }
}
```

### Streaming Response (SSE - Server-Sent Events)

When `stream=true` is set, the response uses SSE format with `data:` prefix.

**Chunk Format:**
```
data: {"id": "transcribe-...", "object": "transcription.chunk", "created": 1771686424, "model": "...", "choices": [{"delta": {"content": "..."}, "finish_reason": "..."}]}
```

**Example Response Chunks:**
```sse
data: {"id": "transcribe-e8b8031e-b957-4a47-ad0b-ae3c07ed7cf5", "object": "transcription.chunk", "created": 1771686424, "model": "/Volumes/AigoP3500/models/lmstudio/models/mlx-community/Qwen3-ASR-0.6B-bf16", "choices": [{"delta": {"content": "language"}}]}

data: {"id": "transcribe-e8b8031e-b957-4a47-ad0b-ae3c07ed7cf5", "object": "transcription.chunk", "created": 1771686424, "model": "/Volumes/AigoP3500/models/lmstudio/models/mlx-community/Qwen3-ASR-0.6B-bf16", "choices": [{"delta": {"content": " None"}}]}

data: {"id": "transcribe-e8b8031e-b957-4a47-ad0b-ae3c07ed7cf5", "object": "transcription.chunk", "created": 1771686424, "model": "/Volumes/AigoP3500/models/lmstudio/models/mlx-community/Qwen3-ASR-0.6B-bf16", "choices": [{"delta": {"content": "<asr_text>"}}]}

data: {"id": "transcribe-e8b8031e-b957-4a47-ad0b-ae3c07ed7cf5", "object": "transcription.chunk", "created": 1771686424, "model": "/Volumes/AigoP3500/models/lmstudio/models/mlx-community/Qwen3-ASR-0.6B-bf16", "choices": [{"delta": {"content": ""}, "finish_reason": "stop", "stop_reason": null}]}

data: [DONE]
```

#### Chunk Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique transcription ID |
| `object` | string | Always `transcription.chunk` |
| `created` | integer | Unix timestamp |
| `model` | string | Model path used |
| `choices[].delta.content` | string | Incremental text (accumulates) |
| `choices[].finish_reason` | string | "stop" when complete |

#### Stream Termination

The stream ends with:
```
data: [DONE]
```

---

## Summary

| Mode | Content-Type | Transfer | Format |
|------|-------------|----------|--------|
| Non-streaming | `application/json` | Content-Length | Single JSON object |
| Streaming | `text/event-stream` | chunked | SSE with `data:` prefix |

**Key Finding:** The streaming format is **SSE (Server-Sent Events)**, not NDJSON. Each chunk is a complete JSON object prefixed with `data: `.
