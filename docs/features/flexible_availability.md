# Flexible Hour-by-Hour Availability

## Overview
Users can set specific hour ranges (e.g., 14:00-16:00) in addition to preset shortcuts (Morning/Afternoon/Evening) to indicate when they're available for sports activities.

## Data Model
Availability is stored as a `[String: [String]]` dictionary where:
- **Keys**: Day names (e.g., "Monday", "Tuesday")
- **Values**: Array of availability entries that can be:
  - Shortcut strings: "Morning", "Afternoon", "Evening"
  - Specific hour ranges: "HH:00" format (e.g., "14:00", "16:00")

Example:
```json
{
  "Monday": ["Morning", "14:00", "15:00", "16:00"],
  "Wednesday": ["Afternoon"],
  "Friday": ["10:00", "11:00", "18:00", "19:00"]
}
```

## Backend Implementation

### expand_availability()
Converts user-defined availability to normalized hour sets for compatibility computation:
- Expands shortcut strings to their hour ranges:
  - "Morning": 06:00-12:00
  - "Afternoon": 12:00-18:00
  - "Evening": 18:00-23:00
- Parses specific hour strings (e.g., "14:00") as individual hours
- Returns set of hours available on each day

## iOS Implementation

### AvailabilityHelper.swift
Provides utility functions for availability management:
- **expand()**: Converts shortcuts and hours to full hour sets
- **format()**: Displays availability in human-readable format
- **group()**: Groups consecutive hours into ranges for display

### HourPickerSheet
User interface for adding/editing specific hour ranges:
- Day selector to choose which day to modify
- Start hour picker (00:00 - 23:00)
- End hour picker (must be after start hour)
- Add button creates continuous hour entries for the selected range

## Integration
Availability data is sent with user profile and used by the compatible_playtimes feature to compute session overlaps.
