import re
from flask import Flask, render_template, request, jsonify
import db

app = Flask(__name__)

# --- Helper Validation Functions ---

def parse_float_param(val, name, default=None, min_val=None, max_val=None, required=False):
    if val is None or val == "":
        if required:
            return None, f"Parameter '{name}' is required."
        return default, None
    try:
        f = float(val)
        if min_val is not None and f < min_val:
            return None, f"Parameter '{name}' must be >= {min_val}."
        if max_val is not None and f > max_val:
            return None, f"Parameter '{name}' must be <= {max_val}."
        return f, None
    except (ValueError, TypeError):
        return None, f"Parameter '{name}' must be a valid number."

def parse_int_param(val, name, default=None, min_val=None, max_val=None, required=False):
    if val is None or val == "":
        if required:
            return None, f"Parameter '{name}' is required."
        return default, None
    try:
        i = int(float(val))
        if min_val is not None and i < min_val:
            return None, f"Parameter '{name}' must be >= {min_val}."
        if max_val is not None and i > max_val:
            return None, f"Parameter '{name}' must be <= {max_val}."
        return i, None
    except (ValueError, TypeError):
        return None, f"Parameter '{name}' must be a valid integer."

def clean_blood_group(val):
    if not val or not str(val).strip():
        return None
    # URL '+' gets decoded as space by HTTP parsers, restore '+'
    cleaned = str(val).replace(" ", "+").strip().upper()
    valid_groups = {'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'}
    return cleaned if cleaned in valid_groups else None

PHONE_REGEX = re.compile(r'^[6-9][0-9]{9}$')

# Restricted keywords for SQL console safety (prevent unintended drops/alters)
BLOCKED_SQL_KEYWORDS = re.compile(r'\b(DROP\s+DATABASE|DROP\s+TABLE|TRUNCATE|ALTER\s+TABLE)\b', re.IGNORECASE)

# --- Preset Demo Queries ---

PRESET_QUERIES = [
    {
        "category": "App Screens",
        "title": "A1: Home Screen Counters",
        "sql": "SELECT * FROM v_home_stats;"
    },
    {
        "category": "App Screens",
        "title": "A2: Who can donate red cells to an A+ patient?",
        "sql": "SELECT c.donor_group AS can_donate_to_AplusPatient FROM Compatibility c WHERE c.recipient_group = 'A+' ORDER BY c.donor_group;"
    },
    {
        "category": "App Screens",
        "title": "A3: Nearby blood banks (Jaipur District Center, 25km)",
        "sql": "CALL sp_find_banks('A+', 26.9124, 75.7873, 25);"
    },
    {
        "category": "App Screens",
        "title": "A4: Nearby compatible donors (Anonymized)",
        "sql": "CALL sp_find_donors('A+', 26.9124, 75.7873, 25);"
    },
    {
        "category": "Analytics",
        "title": "B1: Stock Matrix across Jaipur Blood Banks",
        "sql": """SELECT bank,
       SUM(CASE WHEN blood_group = 'A+'  THEN units ELSE 0 END) AS `A+`,
       SUM(CASE WHEN blood_group = 'A-'  THEN units ELSE 0 END) AS `A-`,
       SUM(CASE WHEN blood_group = 'B+'  THEN units ELSE 0 END) AS `B+`,
       SUM(CASE WHEN blood_group = 'B-'  THEN units ELSE 0 END) AS `B-`,
       SUM(CASE WHEN blood_group = 'O+'  THEN units ELSE 0 END) AS `O+`,
       SUM(CASE WHEN blood_group = 'O-'  THEN units ELSE 0 END) AS `O-`,
       SUM(CASE WHEN blood_group = 'AB+' THEN units ELSE 0 END) AS `AB+`,
       SUM(CASE WHEN blood_group = 'AB-' THEN units ELSE 0 END) AS `AB-`
  FROM v_stock_by_bank_group
 WHERE district = 'Jaipur'
 GROUP BY bank ORDER BY bank;"""
    },
    {
        "category": "Analytics",
        "title": "B2: Shortage report (Zero units in Jaipur)",
        "sql": """SELECT bg.group_code AS out_of_stock_in_jaipur
  FROM Blood_Group bg
 WHERE NOT EXISTS (SELECT 1 FROM v_stock_by_bank_group s
                    WHERE s.district = 'Jaipur' AND s.blood_group = bg.group_code);"""
    },
    {
        "category": "Analytics",
        "title": "B3: Units expiring in next 7 days",
        "sql": """SELECT o.name AS bank, COUNT(*) AS units_expiring, MIN(u.expires_on) AS first_expiry
  FROM Blood_Unit u JOIN Organization o ON o.org_id = u.org_id
 WHERE u.status = 'Available' AND u.expires_on BETWEEN CURDATE() AND CURDATE() + INTERVAL 7 DAY
 GROUP BY o.org_id, o.name
HAVING COUNT(*) >= 1
 ORDER BY first_expiry;"""
    },
    {
        "category": "Analytics",
        "title": "B4: Donor Leaderboard (Window function: RANK)",
        "sql": """SELECT RANK() OVER (ORDER BY donations DESC, points DESC) AS position,
       name, blood_group, donations, points, tier
  FROM v_donor_tiers
 WHERE donations > 0
 ORDER BY position, name
 LIMIT 10;"""
    },
    {
        "category": "Integrity Trigger Tests",
        "title": "C1: Under-age Donor Rejection (Expected to FAIL)",
        "sql": """INSERT INTO Donor (name, dob, gender, blood_group, phone, district_id, latitude, longitude)
VALUES ('Too Young', CURDATE() - INTERVAL 16 YEAR, 'Male', 'O+', '9222222201', 1, 26.9, 75.8);"""
    },
    {
        "category": "Integrity Trigger Tests",
        "title": "C2: Bad Phone Number Check (Expected to FAIL)",
        "sql": """INSERT INTO Donor (name, dob, gender, blood_group, phone, district_id, latitude, longitude)
VALUES ('Bad Phone', CURDATE() - INTERVAL 30 YEAR, 'Male', 'O+', '12345', 1, 26.9, 75.8);"""
    },
    {
        "category": "Integrity Trigger Tests",
        "title": "C3: Cooldown Violation Rejection (Expected to FAIL)",
        "sql": "INSERT INTO Donation (donor_id, org_id, donation_date, volume_ml) VALUES (17, 1, CURDATE(), 450);"
    },
    {
        "category": "Performance (EXPLAIN)",
        "title": "E1: Query Plan with idx_donor_search",
        "sql": """EXPLAIN SELECT donor_id FROM Donor
 WHERE status = 'Active' AND blood_group = 'O+' AND (next_eligible_date IS NULL OR next_eligible_date <= CURDATE());"""
    }
]

# --- Core Routes ---

@app.route("/")
def index():
    return render_template("index.html")

@app.route("/api/stats")
def get_stats():
    rows = db.query("SELECT * FROM v_home_stats")
    return jsonify(rows[0] if rows else {"registered_donors": 0, "blood_centres": 0, "camps": 0})

@app.route("/api/locations")
def get_locations():
    districts = db.query("SELECT district_id, name, latitude, longitude FROM District ORDER BY name")
    hospitals = db.query("SELECT org_id, name, latitude, longitude FROM Organization WHERE org_type = 'Hospital' AND status = 'Approved' ORDER BY name")
    return jsonify({
        "districts": districts,
        "hospitals": hospitals
    })

@app.route("/api/donors-list")
def get_donors_list():
    rows = db.query("SELECT donor_id, name, blood_group, status FROM Donor ORDER BY donor_id")
    return jsonify(rows)

@app.route("/api/open-requests")
def get_open_requests():
    rows = db.query("""
        SELECT r.request_id, r.requester_name, r.patient_blood_grp, r.units_needed,
               r.status, r.urgency, r.created_at, o.name AS hospital_name,
               (SELECT COUNT(*) FROM Request_Contact rc WHERE rc.request_id = r.request_id) AS contacted_count,
               (SELECT COUNT(*) FROM Request_Contact rc WHERE rc.request_id = r.request_id AND rc.status = 'Accepted') AS accepted_count
          FROM Blood_Request r
          JOIN Organization o ON o.org_id = r.hospital_org_id
         ORDER BY r.request_id DESC
         LIMIT 20;
    """)
    return jsonify(rows)

# --- Search Endpoints (with robust 400 validation) ---

@app.route("/api/find-banks")
def find_banks():
    blood_group = clean_blood_group(request.args.get("blood_group", "A+"))
    if not blood_group:
        return jsonify({"success": False, "error_message": "Invalid blood group code"}), 400

    lat, err = parse_float_param(request.args.get("lat"), "lat", default=26.9124, min_val=-90, max_val=90)
    if err:
        return jsonify({"success": False, "error_message": err}), 400

    lng, err = parse_float_param(request.args.get("lng"), "lng", default=75.7873, min_val=-180, max_val=180)
    if err:
        return jsonify({"success": False, "error_message": err}), 400

    radius, err = parse_int_param(request.args.get("radius"), "radius", default=25, min_val=1, max_val=200)
    if err:
        return jsonify({"success": False, "error_message": err}), 400

    result = db.call_procedure("sp_find_banks", [blood_group, lat, lng, radius])
    return jsonify(result)

@app.route("/api/find-donors")
def find_donors():
    blood_group = clean_blood_group(request.args.get("blood_group", "A+"))
    if not blood_group:
        return jsonify({"success": False, "error_message": "Invalid blood group code"}), 400

    lat, err = parse_float_param(request.args.get("lat"), "lat", default=26.9124, min_val=-90, max_val=90)
    if err:
        return jsonify({"success": False, "error_message": err}), 400

    lng, err = parse_float_param(request.args.get("lng"), "lng", default=75.7873, min_val=-180, max_val=180)
    if err:
        return jsonify({"success": False, "error_message": err}), 400

    radius, err = parse_int_param(request.args.get("radius"), "radius", default=25, min_val=1, max_val=200)
    if err:
        return jsonify({"success": False, "error_message": err}), 400

    result = db.call_procedure("sp_find_donors", [blood_group, lat, lng, radius])
    return jsonify(result)

@app.route("/api/inventory")
def get_inventory():
    district = request.args.get("district", "Jaipur").strip()
    sql = """
        SELECT bank,
               SUM(CASE WHEN blood_group = 'A+'  THEN units ELSE 0 END) AS `A+`,
               SUM(CASE WHEN blood_group = 'A-'  THEN units ELSE 0 END) AS `A-`,
               SUM(CASE WHEN blood_group = 'B+'  THEN units ELSE 0 END) AS `B+`,
               SUM(CASE WHEN blood_group = 'B-'  THEN units ELSE 0 END) AS `B-`,
               SUM(CASE WHEN blood_group = 'O+'  THEN units ELSE 0 END) AS `O+`,
               SUM(CASE WHEN blood_group = 'O-'  THEN units ELSE 0 END) AS `O-`,
               SUM(CASE WHEN blood_group = 'AB+' THEN units ELSE 0 END) AS `AB+`,
               SUM(CASE WHEN blood_group = 'AB-' THEN units ELSE 0 END) AS `AB-`
          FROM v_stock_by_bank_group
         WHERE district = %s
         GROUP BY bank ORDER BY bank;
    """
    rows = db.query(sql, (district,))
    
    shortage_sql = """
        SELECT bg.group_code AS out_of_stock
          FROM Blood_Group bg
         WHERE NOT EXISTS (SELECT 1 FROM v_stock_by_bank_group s
                            WHERE s.district = %s AND s.blood_group = bg.group_code);
    """
    shortages = db.query(shortage_sql, (district,))
    return jsonify({
        "matrix": rows,
        "shortages": [s["out_of_stock"] for s in shortages]
    })

@app.route("/api/camps")
def get_camps():
    rows = db.query("""
        SELECT camp_id, title, camp_date, venue, district, conducted_by, capacity, seats_left
          FROM v_upcoming_camps
         ORDER BY camp_date;
    """)
    return jsonify(rows)

@app.route("/api/book-camp", methods=["POST"])
def book_camp():
    data = request.json or {}
    camp_id, err = parse_int_param(data.get("camp_id"), "camp_id", required=True)
    if err:
        return jsonify({"success": False, "error_message": err}), 400

    donor_id, err = parse_int_param(data.get("donor_id"), "donor_id", required=True)
    if err:
        return jsonify({"success": False, "error_message": err}), 400
    
    result = db.call_procedure("sp_book_camp", [camp_id, donor_id])
    if result.get("success"):
        return jsonify({
            "success": True,
            "message": f"Camp #{camp_id} booked successfully for Donor #{donor_id}! Concurrency lock released."
        })
    return jsonify(result), 400

@app.route("/api/leaderboard")
def get_leaderboard():
    rows = db.query("""
        SELECT RANK() OVER (ORDER BY donations DESC, points DESC) AS position,
               donor_id, name, blood_group, donations, points, tier
          FROM v_donor_tiers
         WHERE donations > 0
         ORDER BY position, name
         LIMIT 15;
    """)
    return jsonify(rows)

# =====================================================================
# THE 5 CORE FLOWS: OTP, REGISTRATION, REQUEST, EXPAND, ELIGIBILITY
# =====================================================================

# 1. OTP SERVICE
@app.route("/api/otp/send", methods=["POST"])
def send_otp():
    data = request.json or {}
    phone = (data.get("phone") or "").strip()
    purpose = (data.get("purpose") or "Blood Request").strip()
    
    if not PHONE_REGEX.match(phone):
        return jsonify({"success": False, "error_message": "Invalid Indian 10-digit mobile number (starts with 6-9)."}), 400
    if purpose not in ("Donor Registration", "Blood Request"):
        return jsonify({"success": False, "error_message": "Purpose must be 'Donor Registration' or 'Blood Request'."}), 400
        
    result = db.call_procedure_with_out("sp_send_otp", [phone, purpose], ["@code"])
    if result.get("success"):
        code = result.get("out", {}).get("code")
        return jsonify({
            "success": True,
            "message": f"OTP sent to {phone}",
            "demo_otp": code  # Exposed for simulation and testing
        })
    return jsonify(result), 400

@app.route("/api/otp/verify", methods=["POST"])
def verify_otp():
    data = request.json or {}
    phone = (data.get("phone") or "").strip()
    purpose = (data.get("purpose") or "").strip()
    code = (data.get("otp_code") or "").strip()
    
    if not phone or not code or not purpose:
        return jsonify({"success": False, "error_message": "Phone, purpose, and otp_code are required."}), 400
        
    result = db.call_procedure("sp_verify_otp", [phone, purpose, code])
    if result.get("success"):
        return jsonify({
            "success": True,
            "message": f"Mobile {phone} verified successfully for '{purpose}'."
        })
    return jsonify(result), 400

# 2. DONOR REGISTRATION & AGE VALIDATION TRIGGER
@app.route("/api/donor/register", methods=["POST"])
def register_donor():
    data = request.json or {}
    name = (data.get("name") or "").strip()
    dob = (data.get("dob") or "").strip()
    gender = (data.get("gender") or "").strip()
    blood_group = clean_blood_group(data.get("blood_group"))
    phone = (data.get("phone") or "").strip()
    
    if not blood_group:
        return jsonify({"success": False, "error_message": "Valid blood group (A+, A-, B+, B-, AB+, AB-, O+, O-) is required."}), 400

    district_id, err = parse_int_param(data.get("district_id"), "district_id", required=True)
    if err:
        return jsonify({"success": False, "error_message": err}), 400
        
    lat, err = parse_float_param(data.get("latitude"), "latitude", default=26.9124, min_val=-90, max_val=90)
    if err:
        return jsonify({"success": False, "error_message": err}), 400
        
    lng, err = parse_float_param(data.get("longitude"), "longitude", default=75.7873, min_val=-180, max_val=180)
    if err:
        return jsonify({"success": False, "error_message": err}), 400

    if not name or not dob or not gender:
        return jsonify({"success": False, "error_message": "Name, DOB, gender, blood group, and phone are required."}), 400
    if not PHONE_REGEX.match(phone):
        return jsonify({"success": False, "error_message": "Phone number must be a valid 10-digit Indian mobile (starts with 6-9)."}), 400

    conn = db.get_connection(autocommit=False)
    try:
        with conn.cursor() as cursor:
            # Trigger 'trg_donor_age_check' checks age between 18 and 65
            sql = """
                INSERT INTO Donor (name, dob, gender, blood_group, phone, district_id, latitude, longitude)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s);
            """
            cursor.execute(sql, (name, dob, gender, blood_group, phone, district_id, lat, lng))
            donor_id = cursor.lastrowid
            
            # Send OTP for registration
            cursor.execute("CALL sp_send_otp(%s, 'Donor Registration', @code);", (phone,))
            cursor.execute("SELECT @code AS code;")
            row = cursor.fetchone()
            demo_code = row.get("code") if row else None
            
            conn.commit()
            return jsonify({
                "success": True,
                "donor_id": donor_id,
                "message": f"Donor registered! Age verified. Please verify mobile with OTP.",
                "demo_otp": demo_code
            })
    except Exception as err:
        conn.rollback()
        err_msg = err.args[1] if len(err.args) > 1 else str(err)
        return jsonify({"success": False, "error_message": err_msg}), 400
    finally:
        conn.close()

# 3. EMERGENCY BLOOD REQUEST CREATION
@app.route("/api/request/create", methods=["POST"])
def create_request():
    data = request.json or {}
    name = (data.get("requester_name") or "").strip()
    phone = (data.get("requester_phone") or "").strip()
    blood_group = clean_blood_group(data.get("patient_blood_grp"))
    if not blood_group:
        return jsonify({"success": False, "error_message": "Valid patient blood group (A+, A-, B+, B-, AB+, AB-, O+, O-) is required."}), 400

    units, err = parse_int_param(data.get("units_needed"), "units_needed", required=True, min_val=1, max_val=10)
    if err:
        return jsonify({"success": False, "error_message": err}), 400
    hospital_id, err = parse_int_param(data.get("hospital_org_id"), "hospital_org_id", required=True)
    if err:
        return jsonify({"success": False, "error_message": err}), 400
    urgency = (data.get("urgency") or "Urgent").strip()
    valid_hours, err = parse_int_param(data.get("valid_hours"), "valid_hours", default=24, min_val=1, max_val=72)
    if err:
        return jsonify({"success": False, "error_message": err}), 400

    if not name or not phone:
        return jsonify({"success": False, "error_message": "Requester name, phone, and patient blood group are required."}), 400
    if not PHONE_REGEX.match(phone):
        return jsonify({"success": False, "error_message": "Invalid phone format."}), 400

    result = db.call_procedure_with_out(
        "sp_create_request",
        [name, phone, blood_group, units, hospital_id, urgency, valid_hours],
        ["@rid"]
    )
    if result.get("success"):
        raw_rid = result.get("out", {}).get("rid")
        try:
            rid = int(raw_rid) if raw_rid is not None else None
        except (ValueError, TypeError):
            rid = raw_rid
        return jsonify({
            "success": True,
            "request_id": rid,
            "message": f"Blood Request #{rid} created successfully! Status is Open."
        })
    return jsonify(result), 400

# 4. EXPAND SEARCH & NOTIFY DONORS
@app.route("/api/request/expand-search", methods=["POST"])
def expand_search():
    data = request.json or {}
    request_id, err = parse_int_param(data.get("request_id"), "request_id", required=True)
    if err:
        return jsonify({"success": False, "error_message": err}), 400
    min_contacts, err = parse_int_param(data.get("min_contacts"), "min_contacts", default=4, min_val=1, max_val=20)
    if err:
        return jsonify({"success": False, "error_message": err}), 400

    result = db.call_procedure("sp_expand_search", [request_id, min_contacts])
    if result.get("success"):
        summary = result.get("data", [{}])[0]
        # Query contacted donors queue
        contacts = db.query("""
            SELECT rc.contact_id, rc.donor_id, SUBSTRING_INDEX(d.name, ' ', 1) AS donor_first_name,
                   d.blood_group, rc.radius_km, rc.status, rc.contacted_at, rc.responded_at
              FROM Request_Contact rc
              JOIN Donor d ON d.donor_id = rc.donor_id
             WHERE rc.request_id = %s
             ORDER BY rc.contact_id;
        """, (request_id,))
        return jsonify({
            "success": True,
            "donors_contacted": summary.get("donors_contacted", 0),
            "radius_reached_km": summary.get("radius_reached_km", 25),
            "contacts": contacts
        })
    return jsonify(result), 400

@app.route("/api/request/<int:request_id>/status")
def get_request_status(request_id):
    req_rows = db.query("""
        SELECT r.request_id, r.requester_name, r.patient_blood_grp, r.units_needed,
               r.status, r.urgency, r.created_at, o.name AS hospital_name
          FROM Blood_Request r
          JOIN Organization o ON o.org_id = r.hospital_org_id
         WHERE r.request_id = %s;
    """, (request_id,))
    if not req_rows:
        return jsonify({"success": False, "error_message": "Request not found"}), 404
        
    contacts = db.query("""
        SELECT rc.contact_id, rc.donor_id, SUBSTRING_INDEX(d.name, ' ', 1) AS donor_first_name,
               d.blood_group, rc.radius_km, rc.status, rc.contacted_at, rc.responded_at
              FROM Request_Contact rc
              JOIN Donor d ON d.donor_id = rc.donor_id
             WHERE rc.request_id = %s
             ORDER BY rc.contact_id;
    """, (request_id,))
    
    # Check if matched and privacy reveal view
    accepted = db.query("SELECT * FROM v_accepted_contacts WHERE request_id = %s", (request_id,))
    
    return jsonify({
        "success": True,
        "request": req_rows[0],
        "contacts": contacts,
        "accepted_donors": accepted
    })

# 5. DONOR ACCEPTS OR DECLINES (WITH PRIVACY TRANSITION)
@app.route("/api/request/respond", methods=["POST"])
def respond_request():
    data = request.json or {}
    contact_id, err = parse_int_param(data.get("contact_id"), "contact_id", required=True)
    if err:
        return jsonify({"success": False, "error_message": err}), 400
    response = (data.get("response") or "").strip().capitalize()
    if response not in ("Accepted", "Declined"):
        return jsonify({"success": False, "error_message": "Response must be 'Accepted' or 'Declined'."}), 400

    result = db.call_procedure("sp_respond_to_request", [contact_id, response])
    if result.get("success"):
        # Check current request status
        row = db.query("""
            SELECT r.request_id, r.status, r.units_needed
              FROM Request_Contact rc
              JOIN Blood_Request r ON r.request_id = rc.request_id
             WHERE rc.contact_id = %s;
        """, (contact_id,))
        req_info = row[0] if row else {}
        return jsonify({
            "success": True,
            "message": f"Response '{response}' recorded successfully.",
            "request_id": req_info.get("request_id"),
            "request_status": req_info.get("status")
        })
    return jsonify(result), 400

# 6. DONOR ELIGIBILITY SELF-CHECK
@app.route("/api/eligibility/questions")
def get_eligibility_questions():
    questions = db.query("""
        SELECT question_id, question_text, disqualifying_answer, outcome, deferral_days
          FROM Eligibility_Question
         ORDER BY question_id;
    """)
    return jsonify(questions)

@app.route("/api/eligibility/submit", methods=["POST"])
def submit_eligibility():
    data = request.json or {}
    donor_id, err = parse_int_param(data.get("donor_id"), "donor_id", required=True)
    if err:
        return jsonify({"success": False, "error_message": err}), 400
    answers = data.get("answers") or {}
    if not answers:
        return jsonify({"success": False, "error_message": "Answers to screening questions are required."}), 400

    # Ensure all 9 screening questions from Eligibility_Question are answered
    expected_questions = db.query("SELECT question_id FROM Eligibility_Question ORDER BY question_id;")
    expected_ids = {int(q["question_id"]) for q in expected_questions}
    
    parsed_answers = {}
    for q_id_raw, ans in answers.items():
        try:
            q_id = int(q_id_raw)
        except (ValueError, TypeError):
            return jsonify({"success": False, "error_message": f"Invalid question ID: '{q_id_raw}'"}), 400
        parsed_answers[q_id] = "Yes" if str(ans).lower() in ("yes", "true", "1") else "No"

    missing = expected_ids - set(parsed_answers.keys())
    if missing:
        missing_sorted = sorted(list(missing))
        return jsonify({
            "success": False,
            "error_message": f"All {len(expected_ids)} screening questions must be answered. Missing questions: {missing_sorted}"
        }), 400

    conn = db.get_connection(autocommit=False)
    try:
        with conn.cursor() as cursor:
            # 1. Create eligibility check header
            cursor.execute("INSERT INTO Eligibility_Check (donor_id) VALUES (%s);", (donor_id,))
            check_id = cursor.lastrowid
            
            # 2. Insert answers
            for q_id in sorted(parsed_answers.keys()):
                cursor.execute(
                    "INSERT INTO Eligibility_Answer (check_id, question_id, answer) VALUES (%s, %s, %s);",
                    (check_id, q_id, parsed_answers[q_id])
                )
                
            # 3. Evaluate eligibility
            cursor.execute("CALL sp_evaluate_eligibility(%s);", (check_id,))
            res = cursor.fetchall()
            eval_data = res[0] if res else {"result": "Unknown", "deferred_until": None}
            
            conn.commit()
            return jsonify({
                "success": True,
                "check_id": check_id,
                "donor_id": donor_id,
                "result": str(eval_data.get("result")),
                "deferred_until": str(eval_data.get("deferred_until")) if eval_data.get("deferred_until") else None,
                "message": f"Eligibility evaluated: {eval_data.get('result')}"
            })
    except Exception as err:
        conn.rollback()
        err_msg = err.args[1] if len(err.args) > 1 else str(err)
        return jsonify({"success": False, "error_message": err_msg}), 400
    finally:
        conn.close()

# --- Interactive SQL & Presets ---

@app.route("/api/demo-queries")
def get_demo_queries():
    return jsonify(PRESET_QUERIES)

@app.route("/api/execute-sql", methods=["POST"])
def execute_sql():
    data = request.json or {}
    sql = data.get("sql", "").strip()
    if not sql:
        return jsonify({"success": False, "error_message": "SQL query cannot be empty."}), 400
    
    # Block destructive statements in interactive console to prevent accidental table destruction
    if BLOCKED_SQL_KEYWORDS.search(sql):
        return jsonify({
            "success": False,
            "error_message": "Destructive SQL commands (DROP DATABASE/TABLE, TRUNCATE, ALTER TABLE) are blocked in this console for safety."
        }), 403

    result = db.execute_raw(sql)
    return jsonify(result)

if __name__ == "__main__":
    cfg = db.load_config()
    server_cfg = cfg.get("server", {})
    app.run(
        host=server_cfg.get("host", "127.0.0.1"),
        port=int(server_cfg.get("port", 5000)),
        debug=server_cfg.get("debug", True),
        use_reloader=False
    )
