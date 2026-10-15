# Rule: Offline-First & Data Sync

## Scope
Strategies for operating in low-connectivity environments and syncing with central servers.

## Rules
1. **Offline Authority**:
   - Field collectors must be capable of recording all collections, finding bonds, and previewing balances completely offline.
   - Operations must write immediately to local SQLite and update UI without waiting for network ACK.
2. **Sync Status Tracking**:
   - Records should support an `isSynced` flag or sync timestamp when paired with remote backend servers.
3. **Conflict Resolution Strategy**:
   - If a conflict arises between server and client during collection sync, local collection entries take priority (collector in field is the real-world truth for cash receipts).
4. **Resilient Retry**:
   - Network calls to .NET backend must be queued and retried without blocking user interactions or throwing unhandled fatal exceptions.
