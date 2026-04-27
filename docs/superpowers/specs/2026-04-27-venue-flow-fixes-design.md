# Venue Flow Fixes Design

## Problem

The venue creation/booking flow has 6 issues that prevent a real end-to-end workflow:

1. Price input silently drops decimal values (50.5 yuan becomes 0)
2. Booking time slots hardcoded to 08:00-22:00 instead of using venue's opening_hours
3. Venue owner has no way to approve/reject bookings
4. No booking slot conflict validation (race condition)
5. No way to edit or delist a published venue
6. User's booking list doesn't show which venue the booking is for

## Fixes

### Fix 1: Decimal Price Input

**File**: `create_venue_screen.dart`

- Change `int.tryParse` to `double.tryParse`, multiply by 100, round to int
- Change keyboard type to `TextInputType.numberWithOptions(decimal: true)`
- Hint text: "0 表示免费"

### Fix 2: Dynamic Booking Time Slots

**File**: `venue_booking_sheet.dart`

- Parse `venue.openingHours` (format: `"HH:mm-HH:mm"`) to extract start/end hours
- Generate `_timeSlots` dynamically from parsed range
- Fallback to 08:00-22:00 if parsing fails

### Fix 3: Owner Booking Management

**New file**: `lib/features/venue/venue_owner_bookings_sheet.dart`

A bottom sheet showing all bookings for the owner's venues:
- Uses existing `venueOwnerBookingsProvider`
- Groups by status: pending first, then confirmed, completed, cancelled
- Each row: venue name, booker name, date, time range, amount, status badge
- Pending bookings get "Confirm" (green) and "Reject" (red) action buttons
- Calls existing `updateBookingStatus` on the repository

**Integration**:
- `VenueDetailScreen._BottomBar`: when `isOwner`, show "编辑场馆" + "管理预约"
- "管理预约" opens `VenueOwnerBookingsSheet` instead of `VenueBookingSheet`

**Model change**: Add `venueName` to `VenueBooking` for display in owner view.

### Fix 4: Booking Conflict Check

**File**: `venue_booking_sheet.dart`

Before submitting, re-fetch bookings for the selected date/venue. Check if any non-cancelled booking overlaps with the selected time range. If conflict found, show toast and abort submission.

### Fix 5: Edit & Delist Venue

**File**: `create_venue_screen.dart`

- Add optional `Venue? existingVenue` parameter
- When provided, pre-fill all fields from the existing venue
- Submit calls `update(id, payload)` instead of `create(payload)`
- In edit mode, add a "下架场馆" button that sets `status = 'inactive'` with confirmation dialog

**Routes**: Add route `/venue/:id/edit` passing the venue to CreateVenueScreen.

**Integration**: Owner's bottom bar in detail screen shows "编辑场馆" button.

### Fix 6: Venue Name in User Bookings

**Model**: Add optional `venueName` field to `VenueBooking`.

**Repository**: `bookingsByUser` query joins `venues(name)` via Supabase select syntax: `.select('*, venues(name)')`. Map `venueName` from the joined data.

**UI**: `_BookingRow` in `my_venues_screen.dart` displays venue name.

## Files Changed

| File | Change |
|------|--------|
| `lib/models/venue.dart` | Add `venueName` to `VenueBooking` |
| `lib/repositories/venues_repository.dart` | Join venues in bookingsByUser, bookingsForOwner |
| `lib/features/venue/create_venue_screen.dart` | Decimal price, edit mode, delist |
| `lib/features/venue/venue_booking_sheet.dart` | Dynamic time slots, conflict check |
| `lib/features/venue/venue_detail_screen.dart` | Owner bottom bar redesign |
| `lib/features/venue/venue_owner_bookings_sheet.dart` | **New** — owner booking management |
| `lib/features/me/my_venues_screen.dart` | Show venue name in booking rows |
| `lib/routes.dart` | Add `/venue/:id/edit` route |
| `lib/providers.dart` | Add venueDetailProvider usage for edit route |
