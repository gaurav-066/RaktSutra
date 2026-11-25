# Development Log - RaktSutra (Blood Network DBMS)

## Session: 2026-11-25 (Update 8 - Git Repository Initialization & Commit)

### What was built
- Added `.gitignore` to exclude `venv/`, `__pycache__/`, `*.sock`, `*.pid`, and temp lock files.
- Initialized local Git repository on branch `main`.
- Created initial commit (`87fdcce`) containing all 23 core platform and documentation files:
  - Database scripts (`01_schema.sql`, `02_seed.sql`, `03_queries.sql`)
  - Flask backend and DB connector (`app.py`, `db.py`, `config.json`, `run.sh`)
  - Web dashboard (`templates/index.html`)
  - Illustrated documentation and generation scripts (`RaktSutra_Project_Documentation.docx`, `generate_docs.py`, `docx_builder.py`, `doc_images/`)
  - Platform distribution archive (`RaktSutra_Project.zip`)

### What was tested & passed
- `git status` clean after commit.
- Staged and committed 23 files (4425 insertions).
- Added remote `origin` (`https://github.com/gaurav-066/RaktSutra.git`).
- Pushed branch `main` to GitHub: successfully pushed 30 objects to `https://github.com/gaurav-066/RaktSutra.git`.

## Session: 2026-11-25 (Update 9 - Removed Demonstration Subtitles from UI Pages)

### What was built / changed
- Removed procedure/trigger subtitle lines under page and card headings across all dashboard tabs in `templates/index.html`:
  - Removed `sp_send_otp -> sp_verify_otp -> sp_create_request` under "Create Emergency Blood Request"
  - Removed `sp_expand_search -> sp_respond_to_request -> v_accepted_contacts` under "Active Request Matching & Donor Dispatch"
  - Removed `trg_donor_age_check` trigger note under "Donor Registration & Integrity Checks"
  - Removed `sp_evaluate_eligibility` demonstration text under "Donor Screening & Eligibility Evaluation"
  - Removed `sp_book_camp` test text under "Book a Camp Seat"
- Rebuilt `RaktSutra_Project.zip` with the updated `templates/index.html`.

### What was tested & passed
- Verified HTML diff and formatting across all affected tabs.
- Verified `RaktSutra_Project.zip` contains updated files.

## Session: 2026-11-25 (Update 10 - Removed Leaderboard Tab from UI)

### What was built / changed
- Removed Leaderboard navigation pill button (`#tab-leaderboard-btn`) from `templates/index.html`.
- Removed Leaderboard table card container (`#tab-leaderboard`) from `templates/index.html`.
- Removed `loadLeaderboard()` initialization call and its fetch function from `templates/index.html`.
- Rebuilt `RaktSutra_Project.zip` with the updated dashboard template.

### What was tested & passed
- Verified HTML diff: tab button, tab pane, and JavaScript polling removed cleanly.
- Verified `RaktSutra_Project.zip` updated with 9 core files.

### What's next
- All changes synced and live on GitHub at `https://github.com/gaurav-066/RaktSutra`.




