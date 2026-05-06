# `face_embeddings` 인덱스 smoke test — security 활성화 후 무손상 검증

> 연결: T-004d · spec §6 sub-issue d (재인덱싱 불필요한지 확인) · `album-deploy` PR #25 (T-004c) 의 acceptance

## 결과 요약

| 항목 | 결과 | 근거 |
|---|---|---|
| Mapping 보존 | ✅ 그대로 | knn_vector dim=512, hnsw m=24 ef_construction=128, lucene engine, 7 필드 |
| Settings 보존 | ✅ 그대로 | `index.knn=true, number_of_shards=1, number_of_replicas=0` |
| Doc count 보존 | ✅ 596 docs | reference 48 + non-reference 548 |
| 인증 (album_backend) | ✅ read 성공 | basic auth + verify_certs=False (전략 A) |
| kNN 검색 동작 | ✅ HNSW 무손상 | self-search score=1.0, 동일 인물 다른 reference=0.81, 타인=0.58 |
| 검증 일자 | 2026-05-06 | T-004c (PR #25) 머지 직후 |

**결론**: security plugin 활성화는 Lucene segment 에 무손상. **reindex 불필요**.
스펙 §5-4 의 "Security/TLS 자체는 재인덱싱 불필요" 가정을 실측으로 확인.

## 검증 1 — Mapping 보존

```bash
curl -sk -u "album_backend:$BACKEND_PW" \
  https://localhost:9200/face_embeddings/_mapping
```

```json
{
  "face_embeddings": {
    "mappings": {
      "properties": {
        "embedding": {
          "type": "knn_vector",
          "dimension": 512,
          "method": {
            "engine": "lucene",
            "space_type": "cosinesimil",
            "name": "hnsw",
            "parameters": {"ef_construction": 128, "m": 24}
          }
        },
        "face_id":     {"type": "keyword"},
        "facility_id": {"type": "keyword"},
        "is_reference":{"type": "boolean"},
        "photo_id":    {"type": "keyword"},
        "photo_url":   {"type": "keyword"},
        "resident_id": {"type": "keyword"}
      }
    }
  }
}
```

`backend/app/services/opensearch_service.py:113-142` 의 `ensure_index` 본문과
필드 단위로 일치 — security 활성화 전후 mapping 동일.

## 검증 2 — Settings 보존

```bash
curl -sk -u "album_backend:$BACKEND_PW" \
  "https://localhost:9200/face_embeddings/_settings/index.knn,index.number_of_shards,index.number_of_replicas"
```

```json
{
  "face_embeddings": {
    "settings": {
      "index": {
        "number_of_shards": "1",
        "number_of_replicas": "0",
        "knn": "true"
      }
    }
  }
}
```

`opensearch_service.py:113-118` 의 spec 과 일치. `index.knn=true` 가 살아있어야
HNSW 그래프 빌드/검색이 작동.

## 검증 3 — Doc count + reference count

```bash
curl -sk -u "album_backend:$BACKEND_PW" \
  https://localhost:9200/face_embeddings/_count
# {"count":596,...}

curl -sk -u "album_backend:$BACKEND_PW" -H "Content-Type: application/json" \
  https://localhost:9200/face_embeddings/_count \
  -d '{"query":{"term":{"is_reference":true}}}'
# {"count":48,...}
```

총 596 docs (reference 48 + non-reference 548). T-004c 머지 직전과 동일.
non-reference 548 = facility 들의 사진 매칭 결과 누적치.

## 검증 4 — 인증 + kNN 검색 동작

`album_backend` 계정 (admin backend_role → 디폴트 all_access) 으로 임의의
reference embedding 1 개를 query 로 self-search:

```bash
curl -sk -u "album_backend:$BACKEND_PW" -H "Content-Type: application/json" \
  https://localhost:9200/face_embeddings/_search \
  -d '{
    "size": 3,
    "_source": ["resident_id", "facility_id", "is_reference"],
    "query": {
      "knn": {
        "embedding": {
          "vector": <512-dim float vector — 임의의 reference doc 의 embedding>,
          "k": 3,
          "filter": {
            "bool": {"must": [
              {"term": {"facility_id": "<sample fid>"}},
              {"term": {"is_reference": true}}
            ]}
          }
        }
      }
    }
  }'
```

응답 (took=13ms):

| rank | _score | resident_id (vs query) | 해석 |
|---|---|---|---|
| 1 | 1.000 | 동일 | self-hit. cosinesimil 기준 완전 일치 |
| 2 | 0.813 | 동일 | 같은 인물의 다른 reference 사진 — HNSW 그래프가 이웃을 정확히 잡아냄 |
| 3 | 0.578 | 다름 (같은 facility) | 타인. score 가 threshold 0.6 미만 — backend `MIN_SCORE` 설정에 부합 |

→ HNSW 그래프 무손상 + 점수 분포 정상. backend 의 `search_similar` 가
운영 시 동일하게 작동할 것이라는 신뢰 확보.

## 한계

- **단일 노드** 검증. multi-node 환경의 transport TLS 동작은 본 작업 범위 밖
  (cluster 가 single-node 라 transport SSL 은 self-loop)
- **score 절댓값 검증 불가** — pre-security 시점의 동일 query/embedding 으로 비교
  불가능. 본 검증은 "kNN 의 상대적 분포가 합리적인가" 까지만 확인
- **face matching API end-to-end 검증 미포함** — backend → opensearch_service
  → REST 흐름의 통합 동작은 운영 중 자연 트래픽으로 사후 확인. 본 문서는
  cluster-side 만

## 후속

- **T-004e** (`hashed_resident_id` HMAC 도입 + 1 회 reindex) — 본 PR 머지 후
  착수. e 는 본 검증과 달리 **인덱스 데이터 변경**이 일어남
- spec §9 (b)/(c) (임베딩 라이프사이클 / 네임스페이스 격리) — launch 후 별도
- T-052 NetworkPolicy 활성화 (CNI Calico 전환 후) — verify_certs=False 의 보완
