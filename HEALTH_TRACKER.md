# Personal Health Tracker with Nutritionist Support

A personal health tracker combined with a nutritionist support space built with Phoenix LiveView.

## Overview

This application provides a simple, calming interface for tracking health and nutrition with support for communication between a nutritionist and health seeker.

## Features

### 1. Public Home Page
- Single public home page (no authentication required)
- Clear explanation: "This is a personal health tracker combined with a nutritionist support space"
- Descriptive sections about:
  - Health tracking
  - Diet planning
  - Nutrition guidance
- Positive imagery related to health, energy, and cosmic/interstellar themes
- Primary button: "Enter Personal Space"

### 2. Access to Personal Space
- PIN-based access system
- Hardcoded PIN codes:
  - `uzair-space-nutritionist` - Nutritionist role
  - `uzair-space-seeker` - Health Seeker (client) role
- Same interface for both roles with role-specific functionality

### 3. Personal Space Interface
- Peaceful, advanced, and mystical UI theme:
  - Universe / stars / interstellar / calm cosmic background
  - Clean and modern layout
- No user accounts or authentication beyond PIN

### 4. Diet Plan Management
- Create new diet plans
- Update existing diet plans
- Diet plan features:
  - Daily meals
  - Mark meals as "taken" or "missed"
- Date-based view:
  - Show days
  - Show meals per day
  - Show completion status (taken/missed)

### 5. Daily Meal Tracking
- Select a date
- View meals planned for that date
- Mark meals as completed or missed
- Lightweight tracker (not complex analytics)

### 6. Messaging Feature
- Simple messaging interface inside personal space
- Messages exchanged between two roles only:
  - Nutritionist
  - Health Seeker
- PIN determines message sender identity
- Message storage (database)
- Emoji support (health, food, space, and energy-related)

## Technical Stack

- **Framework**: Phoenix 1.8 with LiveView
- **Database**: PostgreSQL
- **Styling**: Tailwind CSS with daisyUI
- **Real-time**: Phoenix PubSub for live updates

## PIN Codes

| PIN Code | Role |
|----------|------|
| `uzair-space-nutritionist` | Nutritionist |
| `uzair-space-seeker` | Health Seeker |

## Notes

- MVP / prototype, not a production system
- Focus on clarity, usability, and calm visual experience
- Minimal and basic functionality
