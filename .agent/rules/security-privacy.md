# Rule: Security & Privacy

## Scope
Safeguarding sensitive borrower information, Aadhaar numbers, phone contacts, and financial records.

## Rules
1. **PII Masking**:
   - Mask Aadhaar numbers in list overviews (show only last 4 digits: `XXXX-XXXX-1234`).
   - Full Aadhaar number is visible only inside the explicit Proof Viewer dialog.
2. **Local Credential Storage**:
   - Never store unencrypted raw plaintext passwords in unsecured shared locations.
3. **Restricted Export Permissions**:
   - Generating full database dumps or raw CSV customer exports is restricted strictly to `Admin` users.
4. **Photo & Proof File Protection**:
   - Store local proof photos in app-private sandboxed documents directory (`path_provider`).
   - Check file existence before loading `FileImage` to prevent unhandled runtime image render exceptions.
