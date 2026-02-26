from pathlib import Path

PAGE_WIDTH = 612
PAGE_HEIGHT = 792


def pdf_escape(text: str) -> str:
    return text.replace('\\', '\\\\').replace('(', '\\(').replace(')', '\\)')


lines = []
y = 756


def add_line(text: str, font: str = 'F1', size: int = 10, leading: int = 13, x: int = 54):
    global y
    lines.append((x, y, font, size, text))
    y -= leading


add_line('Snevva App - One Page Summary', font='F2', size=18, leading=26)

add_line('What it is', font='F2', size=12, leading=16)
add_line('- Snevva is a Flutter mobile health companion app using GetX for app state and flow control.')
add_line('- It combines daily health tracking, reminders, and Elly chat guidance with cloud APIs.')

add_line('Who it\'s for', font='F2', size=12, leading=16)
add_line('- Primary persona: people who want one mobile app for daily health habits and core vitals.')
add_line('- Female-profile users also get women\'s health tracking screens and reminders.')

add_line('What it does', font='F2', size=12, leading=16)
add_line('- Tracks sleep goals/progress, including background sleep monitoring.')
add_line('- Tracks daily steps with background pedometer updates and sync logic.')
add_line('- Tracks hydration intake against user goals.')
add_line('- Logs mood, vitals (BPM and blood pressure), and BMI.')
add_line('- Manages medicine, water, meal, and event reminders with alarms/notifications.')
add_line('- Provides health tips, diet plans, and mental wellness content/music.')
add_line('- Offers Chat with Elly decision-tree guidance; AI Symptom Checker is present but disabled.')

add_line('How it works (repo evidence only)', font='F2', size=12, leading=16)
add_line('- UI layer: Flutter views/widgets with bottom nav sections Home, My Health, Alerts, and Menu.')
add_line('- State layer: GetX controllers for auth, steps, sleep, hydration, reminders, mood, vitals, etc.')
add_line('- Service layer: ApiService/AuthService call endpoints at https://abdmstg.coretegra.com.')
add_line('- Security path: requests can be encrypted via EncryptionService with x-data-hash headers.')
add_line('- Local data: Hive boxes (step_history, sleep_log, reminders_box, medicine_list) and')
add_line('  SharedPreferences for sessions, flags, and cached user values.')
add_line('- Background/alerts: flutter_background_service tracks steps/sleep; Firebase Messaging and')
add_line('  local notifications drive push alerts and scheduled reminders.')
add_line('- Backend internals and database schema: Not found in repo.')

add_line('How to run (minimal)', font='F2', size=12, leading=16)
add_line('1. Install Flutter SDK. Repo Dart constraint in pubspec: ^3.7.0.')
add_line('2. From repo root: flutter pub get')
add_line('3. Launch on a device/emulator: flutter run')
add_line('4. Exact environment/bootstrap docs for .env and secrets/key.json: Not found in repo.')

if y < 40:
    raise RuntimeError(f'Content overflowed one page (y={y}).')

content_lines = []
for x, y_pos, font, size, text in lines:
    content_lines.append(
        f"BT /{font} {size} Tf 1 0 0 1 {x} {y_pos} Tm ({pdf_escape(text)}) Tj ET"
    )

content_stream = '\n'.join(content_lines).encode('latin-1', errors='replace')

objects = []
objects.append(b"<< /Type /Catalog /Pages 2 0 R >>")
objects.append(b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>")
objects.append(
    (
        "<< /Type /Page /Parent 2 0 R "
        "/MediaBox [0 0 612 792] "
        "/Resources << /Font << /F1 4 0 R /F2 5 0 R >> >> "
        "/Contents 6 0 R >>"
    ).encode('ascii')
)
objects.append(b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>")
objects.append(b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>")
objects.append(
    b"<< /Length " + str(len(content_stream)).encode('ascii') + b" >>\nstream\n" + content_stream + b"\nendstream"
)

pdf = bytearray()
pdf.extend(b"%PDF-1.4\n")

offsets = [0]
for i, obj in enumerate(objects, start=1):
    offsets.append(len(pdf))
    pdf.extend(f"{i} 0 obj\n".encode('ascii'))
    pdf.extend(obj)
    pdf.extend(b"\nendobj\n")

xref_pos = len(pdf)
pdf.extend(f"xref\n0 {len(objects) + 1}\n".encode('ascii'))
pdf.extend(b"0000000000 65535 f \n")
for off in offsets[1:]:
    pdf.extend(f"{off:010d} 00000 n \n".encode('ascii'))

pdf.extend(
    (
        "trailer\n"
        f"<< /Size {len(objects) + 1} /Root 1 0 R >>\n"
        f"startxref\n{xref_pos}\n"
        "%%EOF\n"
    ).encode('ascii')
)

output = Path('output/pdf/snevva_app_summary.pdf')
output.write_bytes(pdf)
print(output)
