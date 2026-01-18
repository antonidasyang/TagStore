# System Requirement Specification

**Project:** TagStore (TS-2026)
**Version:** 1.0
**Date:** January 8, 2026

## 1. Introduction

**TagStore** is a cross-platform Digital Asset Management (DAM) tool designed for personal high-volume file organization. It solves the rigidity of file system hierarchies by decoupling **Physical Storage** (where files sit) from **Logical Retrieval** (how files are found).

### 1.1 Scope

The system will manage files through a "Hybrid" approach:

1. **Managed Mode:** Taking full ownership of files (moving them to a central library).
2. **Referenced Mode:** Indexing existing files in their current locations without moving them.

### 1.2 System Constraints

* **Target Platform:** Windows, macOS, Linux.
* **Technology Stack:** Qt 6.x framework (C++20 Backend).
* **Architecture Pattern:** MVVM (Model-View-ViewModel).
* **Performance:** All heavy operations (hashing, AI analysis) must be asynchronous to ensure a non-blocking UI.

---

## 2. Functional Requirements

### 2.1 Module A: Ingestion & Integrity

* **FR-A1 (Import Modes):**
  * **Managed Mode (Default):** Moves source file to the Library. The source file is deleted.
  * **Referenced Mode (Alt+Drop):** Links to the file in its current location. The source file remains untouched.


* **FR-A2 (Hashing):** Every file processed must be identified by a SHA-256 content hash to detect duplicates regardless of filename.
* **FR-A3 (Conflict Handling):** If a file with the same hash exists, the system must **Pause** and prompt the user with three options:
  1. **Reject:** Cancel the import.
  2. **Copy:** Import as a distinct physical copy (e.g., `Report (1).pdf`).
  3. **Merge/Alias:** Do not import the file; add the new filename as a tag/alias to the existing record.



### 2.2 Module B: Storage Management

* **FR-B1 (Library Root):** The default storage path shall be `~/Documents/TagStore_Library`, but must be user-configurable.
* **FR-B2 (Managed Hierarchy):** Managed files must be stored physically in a `[Root]/YYYY/MM/` structure based on creation date.
* **FR-B3 (Portability):** The system database (`tagstore.db`) must reside in the Root folder to allow the library to be moved between computers.

### 2.3 Module C: Intelligence (AI)

* **FR-C1 (Deferred Analysis):** AI processing must occur asynchronously via a background queue.
* **FR-C2 (Text Extraction):** The system must support text extraction from standard formats (PDF, TXT, MD, Office).
* **FR-C3 (Auto-Tagging):** Extracted text must be processed by a Local or Cloud LLM to generate JSON-formatted tags.

### 2.4 Module D: Search & Retrieval

* **FR-D1 (Faceted Search):**
  * **Intra-Category:** OR logic (e.g., "PDF" OR "DOCX").
  * **Inter-Category:** AND logic (e.g., "Filetype Match" AND "Year Match").


* **FR-D2 (Visual Scope):** Search results must visually distinguish between Managed (Local) and Referenced (External) files.

---

## 3. UI/UX Specification

### 3.1 Design Philosophy

The interface prioritizes a **"Search-First"** workflow. It abandons the traditional folder tree for a sticky top header (controls) and a fluid body (content).

### 3.2 Layout & Components

#### **Zone A: Global Header (Sticky Top)**

* **Search Input:** Large, centered text field with real-time filtering (300ms debounce).
* **Global Actions:**
  * `[+] Import`: Opens File Picker (Managed Mode).
  * `[🔗] Index`: Opens Folder Picker (Referenced Mode).
  * `[⚙️] Settings`: Library Path and AI Configuration.



#### **Zone B: Tag Filter Bar**

* **Layout:** Horizontal `Flow` layout containing **Tag Chips** (Badges).
* **States:**
  * *Normal:* Light Grey.
  * *Selected:* Primary Blue (Active Filter).
  * *AI-Generated:* Visual distinction (Purple border or Sparkle icon).


* **Ordering:** Sorted by Frequency or Recency; restricted to top ~20 tags by default with a "Show All" toggle.

#### **Zone C: Results Grid**

* **View:** Adaptive Grid resizing based on window width.
* **Card Content:** 128x128px Thumbnail, Truncated Filename.
  * **Overlays:**
  * `🔗` (Link Chain): Indicates Referenced file.
  * `✨` (Sparkle): Indicates recently AI-tagged.


* **Context Menu:** Options for "Open", "Reveal in Explorer", "Manage Tags", and "Delete".

#### **Zone D: The Floating Drop Balloon**

A separate, small, independent window that floats above all other applications.

* **Default State (Idle):**
  * **Visual:** A semi-transparent, circular floating icon (64x64px). Displays the App Logo.
  * **Position:** User-draggable. Snaps to screen edges.
  * **Opacity:** 50% (Unobtrusive).


* **Drag State (Hovering with File):**
  * **Visual:** Scales up to 100x100px. Opacity becomes 100%.
  * **Feedback:**
    * **Standard Hover:** Balloon glows **Blue** (Move/Manage Mode).
    * **Alt-Key Hover:** Balloon glows **Green** with a "Link" icon (Reference Mode).




* **Processing State:**
  * **Visual:** A progress ring spins around the border of the balloon while Hashing/Copying.
  * **Completion:** Flashes briefly before returning to Idle.



### 3.3 Interactions

  * **Filtering:** Clicking multiple tags performs an intersection (AND) query.
  * **Balloon Interaction:** Left-click toggles the Main Dashboard; Right-click opens context menu (Import/Quit).
