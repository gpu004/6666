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

2. Define message header layout (TigerBeetle-compatible shape, 256 bytes)
   - If wire compatibility is required, match TigerBeetle header fields exactly:
     - `checksum: u128`
     - `checksum_padding: u128`
     - `checksum_body: u128`
     - `checksum_body_padding: u128`
     - `nonce_reserved: u128`
     - `cluster: u128`
     - `size: u32`
     - `epoch: u32`
     - `view: u32`
     - `release: u32`
     - `protocol: u16`
     - `command: u8`
     - `replica: u8`
     - `reserved_frame: 12 bytes`
     - `reserved_command: 128 bytes`
   - Reserved/padding fields must be zeroed unless explicitly defined by command schema.
   - Total `size` is header + payload.
   - Enforce `message_size_max` and reject oversized frames.

3. Define payload encoding
   - For TigerBeetle-compatible framing, encode payload as packed fixed-size records (no mandatory leading count field).
   - Event count is derived from `(header.size - 256) / event_size` for single-batch messages.
   - Keep struct field order byte-exact (`Account`, `Transfer`, filters, and results).
   - Create results are sparse records: `{ index: u32; result: u32 }`, only for failed events.
   - If MVP introduces simplified framing (e.g. explicit count), document it as a protocol divergence.

4. Implement codecs
   - `encode_request : request -> Cstruct.t`
   - `decode_request : Cstruct.t -> (request, error) result`
   - `encode_response : response -> Cstruct.t`
   - `decode_response : Cstruct.t -> (response, error) result`

5. Checksum integration
   - `checksum payload` in encoder and store in header.
   - Validate checksum before decoding.
   - TigerBeetle uses AEGIS-128L MAC-as-checksum; using another algorithm is an intentional MVP divergence.

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

TigerBeetle clients and replicas also use multi-batch request/reply encoding with trailer metadata.
The MVP may skip this initially, but must document that limitation clearly.
