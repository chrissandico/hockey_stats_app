# Product Overview

## Hockey Stats Tracker

An offline-first mobile application for tracking hockey game statistics in real-time. Built for team stat trackers who need reliable data collection during games, even without internet connectivity.

## Core Purpose

Enable users to record hockey game events (shots, goals, penalties, attendance) on mobile devices without requiring internet connection, with automatic synchronization to Google Sheets when connectivity is restored.

## Key Features

- **Offline-First Architecture**: All stat tracking works without internet; data syncs automatically when online
- **Multi-Team Support**: Manage multiple teams with team-specific authentication and data isolation
- **Real-Time Collaboration**: Multiple users can track stats simultaneously for the same game
- **Google Sheets Integration**: Central data storage in Google Sheets for analysis and reporting
- **Comprehensive Tracking**: Goals, assists, shots, penalties, attendance, line configurations, goalie stats
- **PDF Export & Sharing**: Generate and share game reports via email or native sharing

## Target Users

- Team stat trackers and scorekeepers
- Coaches who need real-time game data
- Team administrators managing multiple teams
- Anyone tracking hockey statistics during live games

## Data Flow

1. **Local-First**: All events stored immediately in local Hive database
2. **Background Sync**: Automatic synchronization to Google Sheets when online
3. **Conflict Resolution**: Google Sheets is the source of truth for statistics
4. **Offline Resilience**: Full functionality without internet; queued sync when reconnected
