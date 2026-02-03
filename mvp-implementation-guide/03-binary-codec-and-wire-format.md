# Step 03 - Binary codec and wire format

Goal: Define a stable encoding for WAL records and network requests.

## Deliverables
- Binary codec module for all requests and results
- Versioned message header
- Deterministic checksum for each record

## Files to create
- `src/codec/header.mli`
- `src/codec/header.ml`
- `src/codec/request_codec.mli`
- `src/codec/request_codec.ml`
- `src/codec/response_codec.mli`
- `src/codec/response_codec.ml`
- `src/codec/checksum.ml`

## Tasks
1. Choose encoding strategy
   - Fixed width fields, little endian.
   - No strings in MVP payloads (all integers).
   - Use `Cstruct` to write and read.

2. Define message header layout (TigerBeetle-aligned, 256 bytes)
   - Header checksum covering the rest of the header.
   - Body checksum covering the payload.
   - Cluster id, size, protocol version, command enum.
   - Reserved fields must be zeroed.
   - Total `size` is header + payload.
   - Enforce `message_size_max` and reject oversized frames.

3. Define payload encoding
   - Each request type starts with a count `u32` followed by fixed size records.
   - Example for account:
     - id (u128), ledger (u32), code (u16), flags (u16), user_data_128 (u128), user_data_64 (u64), user_data_32 (u32)
   - Include `reserved` and `timestamp` fields to match TigerBeetle’s structs.
   - Responses include count + result codes; for lookup and query, append full records for found entries.

4. Implement codecs
   - `encode_request : request -> Cstruct.t`
   - `decode_request : Cstruct.t -> (request, error) result`
   - `encode_response : response -> Cstruct.t`
   - `decode_response : Cstruct.t -> (response, error) result`

5. Checksum integration
   - `checksum payload` in encoder and store in header.
   - Validate checksum before decoding.

6. Round trip tests
   - Use QCheck to generate random requests.
   - Encode then decode and assert equality.

## Checklists
- [ ] Payload size is deterministic for each request type
- [ ] Checksum validation rejects corrupted payloads
- [ ] Decode errors are explicit and do not crash the server
- [ ] Header is 256 bytes and matches TigerBeetle-aligned field order

## Notes
This step mirrors TigerBeetle's strict layout control. The MVP does not need
schema evolution yet, but versioning should be built in from the start.
